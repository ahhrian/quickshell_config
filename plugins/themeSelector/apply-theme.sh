#!/usr/bin/env bash

# Apply system settings which must follow the selected Quickshell theme.
# Add future application-specific updates as separate sections below.

set -uo pipefail

theme=${1:-}
wallpaper_path=${2:-}

if [[ -z "$theme" || "$theme" == *[!a-z0-9_-]* ]]; then
    echo "apply-theme: invalid or missing theme id" >&2
    exit 2
fi

user_home=${HOME:?apply-theme: HOME is not set}
result=0

# Kitty ---------------------------------------------------------------------
# kitty.conf includes ~/.config/kitty/colors. Repoint that stable include to
# the selected theme without modifying kitty.conf itself.
kitty_dir="$user_home/.config/kitty"
kitty_theme="$kitty_dir/themes/$theme.conf"
kitty_colors="$kitty_dir/colors"

if [[ -f "$kitty_theme" ]]; then
    temporary_link="$kitty_dir/.colors.$$.tmp"
    if ln -s "$kitty_theme" "$temporary_link" \
            && mv -Tf "$temporary_link" "$kitty_colors"; then
        # Kitty does not always notice a replaced symlink as a file write.
        # SIGUSR1 performs its supported config reload, causing every running
        # instance to re-read kitty.conf and its `include colors` directive.
        mapfile -t kitty_pids < <(pgrep -u "$EUID" -x kitty)
        for kitty_pid in "${kitty_pids[@]}"; do
            kill -USR1 "$kitty_pid" 2>/dev/null || true
        done
    else
        echo "apply-theme: could not update Kitty colors link" >&2
        rm -f -- "$temporary_link"
        result=1
    fi
else
    echo "apply-theme: Kitty theme does not exist: $kitty_theme" >&2
    result=1
fi

# Hyprland ------------------------------------------------------------------
# The Lua decorations module requires ~/.config/hypr/colors.lua. Repoint that
# stable module path so its border accents follow the selected theme.
hypr_dir="$user_home/.config/hypr"
hypr_theme="$hypr_dir/themes/$theme.lua"
hypr_colors="$hypr_dir/colors.lua"

if [[ -f "$hypr_theme" ]]; then
    if ! ln -sf -- "$hypr_theme" "$hypr_colors"; then
        echo "apply-theme: could not update Hyprland colors link" >&2
        result=1
    fi
else
    echo "apply-theme: Hyprland theme does not exist: $hypr_theme" >&2
    result=1
fi

# Wallpaper -----------------------------------------------------------------
# Quickshell passes the last wallpaper used by this theme. As a startup
# fallback, use the first supported image in the theme's wallpaper directory.
if [[ -z "$wallpaper_path" ]]; then
    wallpaper_dir="$user_home/Pictures/Wallpapers/$theme"
    if [[ -d "$wallpaper_dir" ]]; then
        while IFS= read -r -d '' candidate; do
            wallpaper_path=$candidate
            break
        done < <(find "$wallpaper_dir" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
               -o -iname '*.webp' -o -iname '*.bmp' \) \
            -print0 | sort -z)
    fi
fi

if [[ -n "$wallpaper_path" && -f "$wallpaper_path" ]]; then
    if ! awww img "$wallpaper_path" --transition-type wipe --transition-fps 60; then
        echo "apply-theme: awww could not apply $wallpaper_path" >&2
        result=1
    fi
else
    echo "apply-theme: no wallpaper found for theme: $theme" >&2
    result=1
fi

exit "$result"
