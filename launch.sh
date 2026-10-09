#!/bin/bash

qs kill >/dev/null 2>&1 || pkill qs

gtk_icon_theme=""

# nwg-look updates the desktop interface setting on this system. Prefer it so
# Quickshell and GTK applications resolve icons from the same theme.
if command -v gsettings >/dev/null 2>&1; then
    gtk_icon_theme="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null)"
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

qs -d
