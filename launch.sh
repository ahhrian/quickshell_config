#!/bin/bash

set -euo pipefail

shell_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
launch_mode="${1:---restart}"
case "$launch_mode" in
    --start|--restart) ;;
    *) printf 'Usage: %s [--start|--restart]\n' "$0" >&2; exit 2 ;;
esac

# Login must use the same theme setup as SUPER+R, without killing an instance
# that is already running. Never terminate an active session-lock owner.
if [[ "$launch_mode" == --restart ]]; then
    lock_status="$(qs ipc -p "$shell_dir" call lockScreen status 2>/dev/null || true)"
    if [[ "$lock_status" == *'"locked":true'* ]]; then
        printf 'Quickshell is locked; unlock before restarting it.\n' >&2
        exit 1
    fi
    qs kill -p "$shell_dir" >/dev/null 2>&1 || true
    # kill sends a signal and returns before shutdown finishes. Wait for the
    # old instance to release its registration before --no-duplicate starts.
    for ((attempt = 0; attempt < 50; attempt++)); do
        instances="$(qs list -p "$shell_dir" 2>/dev/null || true)"
        [[ "$instances" == *'Process ID:'* ]] || break
        sleep 0.1
    done
    if [[ "$instances" == *'Process ID:'* ]]; then
        printf 'Quickshell did not finish shutting down; try again shortly.\n' >&2
        exit 1
    fi
fi

gtk_icon_theme=""

# nwg-look updates the desktop interface setting on this system. Prefer it so
# Quickshell and GTK applications resolve icons from the same theme.
if command -v gsettings >/dev/null 2>&1; then
    gtk_icon_theme="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || true)"
    gtk_icon_theme="${gtk_icon_theme#\'}"
    gtk_icon_theme="${gtk_icon_theme%\'}"
fi

# Some environments only persist the GTK settings.ini value.
if [[ -z "$gtk_icon_theme" ]]; then
    gtk_settings_file="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini"
    if [[ -r "$gtk_settings_file" ]]; then
        gtk_icon_theme="$(sed -n 's/^[[:space:]]*gtk-icon-theme-name[[:space:]]*=[[:space:]]*//p' "$gtk_settings_file" | head -n 1)"
    fi
fi

if [[ -n "$gtk_icon_theme" ]]; then
    export QS_ICON_THEME="$gtk_icon_theme"
else
    unset QS_ICON_THEME
fi

exec qs -p "$shell_dir" --no-duplicate -d
