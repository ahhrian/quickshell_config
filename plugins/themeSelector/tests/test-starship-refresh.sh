#!/usr/bin/env bash

# End-to-end test for apply-theme.sh's live Starship refresh. It starts a
# hidden Kitty instance with an isolated Bash prompt, runs the real theme
# application script against temporary config fixtures, and verifies that
# Bash's PROMPT_COMMAND runs again after the remote Ctrl+C.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
theme_selector_dir=$(cd -- "$script_dir/.." && pwd)
apply_theme="$theme_selector_dir/apply-theme.sh"
test_bashrc="$script_dir/refresh-test.bashrc"

test_dir=$(mktemp -d /tmp/qs-starship-refresh-test.XXXXXX)
test_home="$test_dir/home"
test_bin="$test_dir/bin"
kitty_socket="$test_dir/kitty.socket"
prompt_marker="$test_dir/prompts"
kitty_log="$test_dir/kitty.log"

cleanup() {
    if [[ -S "$kitty_socket" ]]; then
        kitty @ --to "unix:$kitty_socket" close-window \
            --match all --ignore-no-match >/dev/null 2>&1 || true
    fi

    if [[ "$test_dir" == /tmp/qs-starship-refresh-test.* ]]; then
        rm -rf -- "$test_dir"
    fi
}
trap cleanup EXIT

mkdir -p -- \
    "$test_home/.config/kitty/themes" \
    "$test_home/.config/hypr/themes" \
    "$test_home/Pictures/Wallpapers/catpuccin" \
    "$test_bin"

printf 'foreground #ffffff\n' \
    > "$test_home/.config/kitty/themes/catpuccin.conf"
printf 'return { accent = "0xffca9ee6" }\n' \
    > "$test_home/.config/hypr/themes/catpuccin.lua"
printf 'test wallpaper\n' \
    > "$test_home/Pictures/Wallpapers/catpuccin/test.png"
: > "$prompt_marker"

# Keep the integration test self-contained: do not signal real Kitty
# processes or invoke the real wallpaper daemon.
printf '#!/usr/bin/env bash\nexit 1\n' > "$test_bin/pgrep"
printf '#!/usr/bin/env bash\nexit 0\n' > "$test_bin/awww"
chmod +x "$test_bin/pgrep" "$test_bin/awww"

QS_REFRESH_TEST_MARKER="$prompt_marker" kitty \
    --config NONE \
    --override allow_remote_control=socket-only \
    --override shell_integration=disabled \
    --listen-on "unix:$kitty_socket" \
    --start-as hidden \
    --detach \
    --detached-log "$kitty_log" \
    bash --noprofile --rcfile "$test_bashrc" -i

for attempt in {1..50}; do
    [[ -S "$kitty_socket" ]] && break
    sleep 0.1
done
[[ -S "$kitty_socket" ]] || {
    echo "FAIL: the test Kitty socket was not created" >&2
    exit 1
}

for attempt in {1..50}; do
    prompts_before=$(wc -l < "$prompt_marker")
    (( prompts_before >= 1 )) && break
    sleep 0.1
done
(( prompts_before >= 1 )) || {
    echo "FAIL: the test Bash prompt did not initialize" >&2
    exit 1
}

HOME="$test_home" \
PATH="$test_bin:$PATH" \
QS_KITTY_SOCKET_BASE="$kitty_socket" \
    bash "$apply_theme" catpuccin \
        "$test_home/Pictures/Wallpapers/catpuccin/test.png"

for attempt in {1..50}; do
    prompts_after=$(wc -l < "$prompt_marker")
    (( prompts_after > prompts_before )) && break
    sleep 0.1
done

[[ $(readlink -f "$test_home/.config/kitty/colors") \
    == "$test_home/.config/kitty/themes/catpuccin.conf" ]] || {
    echo "FAIL: Kitty theme link was not updated" >&2
    exit 1
}
[[ $(readlink -f "$test_home/.config/hypr/colors.lua") \
    == "$test_home/.config/hypr/themes/catpuccin.lua" ]] || {
    echo "FAIL: Hyprland theme link was not updated" >&2
    exit 1
}
rg -q '^default_accent = "#ca9ee6"$' \
    "$test_home/.config/starship.toml" || {
    echo "FAIL: generated Starship palette is incorrect" >&2
    exit 1
}
(( prompts_after > prompts_before )) || {
    echo "FAIL: apply-theme.sh did not redraw the Bash prompt" >&2
    exit 1
}

printf 'PASS: theme links, Starship config, and live prompt refresh verified\n'
