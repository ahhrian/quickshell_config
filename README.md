# Quickshell Desktop Shell

This repository is a modular Quickshell configuration for Hyprland. It provides a multi-monitor top bar, hardware and notification services, animated popup controls, an application launcher, theme and wallpaper selectors, a logout manager, and a PAM-authenticated Wayland session lock.

This file is the starting point for a new contributor or agent with no prior context. Read the subsystem documents next:

1. [`shared/README.md`](shared/README.md) — color ownership, theme palettes, typography, and UI rules.
2. [`services/README.md`](services/README.md) — singleton state and system-control APIs.
3. [`plugins/bar/README.md`](plugins/bar/README.md) — bar layout, widgets, workspace behavior, and dropdown internals.
4. [`plugins/README.md`](plugins/README.md) — clock-anchored plugins, IPC endpoints, focus, and keyboard behavior.

## Runtime architecture

```text
Hyprland / PipeWire / NetworkManager / BlueZ / UPower / awww
                              │
                              ▼
                    services/*.qml singletons
             reactive state + narrowly scoped actions
                              │
              ┌───────────────┴────────────────┐
              ▼                                ▼
 plugins/bar/components                 popup components
 compact status widgets          bar dropdowns + IPC plugins
              └───────────────┬────────────────┘
                              ▼
                    plugins/bar/Bar.qml
              one PanelWindow for every screen
```

`shell.qml` is intentionally small and instantiates `Bar`. `Bar.qml` owns per-screen panel windows and process-wide IPC routing. Service singletons are registered in `services/qmldir`; shared singletons are registered in `shared/qmldir`.

## Repository map

```text
.
├── shell.qml                     Quickshell entrypoint
├── launch.sh                     Restarts Quickshell as a daemon and syncs GTK icon theme
├── shared/
│   ├── Theme.qml                 Runtime Catppuccin/Everforest/Gruvbox selector
│   ├── BarColors.qml             Fixed monochrome bar and shell-chrome palette
│   ├── colors/
│   │   ├── Catpuccin.qml         Catppuccin palette (legacy spelling is intentional)
│   │   ├── Everforest.qml        Everforest palette
│   │   └── Gruvbox.qml           Gruvbox palette
│   └── qmldir                    Registers Theme and BarColors
├── services/
│   ├── Audio.qml                 PipeWire volume, mute, and output sinks
│   ├── Bluetooth.qml             BlueZ status, scan, pair, connect, and remove
│   ├── Notifications.qml         Freedesktop notification server and DND state
│   ├── Power.qml                 UPower battery state
│   ├── Time.qml                  Minute-resolution clock
│   ├── Wallpaper.qml             Per-theme wallpaper history and awww application
│   ├── Wifi.qml                  NetworkManager status, scanning, and actions
│   ├── scripts/                  Python adapters for audio, Bluetooth, and Wi-Fi
│   └── qmldir                    Registers every service singleton
└── plugins/
    ├── bar/
    │   ├── Bar.qml               Multi-screen panel and IPC router
    │   ├── components/           Compact 33 px bar widgets and toast overlay
    │   ├── widget_gui/           Calendar, clock, and right-side dropdowns
    │   └── workspaceIcons.jsonc  Preserved custom glyph map; currently disabled
    ├── appLauncher/              Searchable five-row desktop-entry launcher
    ├── lockScreen/               Secure multi-monitor session lock and PAM prompt
    ├── logoutManager/            Suspend, logout, reboot, and poweroff UI
    ├── themeSelector/            Runtime palette selector
    └── wallpaperSwitcher/        Theme-specific wallpaper browser
```

## Bar layout

`Bar.qml` creates one 45 px-tall `PanelWindow` per `Quickshell.screens` entry.

| Region | Contents | Notes |
| --- | --- | --- |
| Left | `Workspaces` | Workspaces 1–5 on the laptop/single monitor and 6–10 on an external monitor, expanding for active extra workspaces. |
| Center | `ClockWidget` | The visual and animation origin for the calendar, clock GUI, and every IPC plugin. |
| Right | Wi-Fi, Bluetooth, volume, battery | Ordered left-to-right. Wi-Fi/Bluetooth/volume expand leftward and push only widgets to their left. |

`NotificationWidget` exists but is currently commented out in the center layout. `NotificationToasts` remains active on every screen.

## Popup families

There are two deliberately different popup systems.

### Clock-anchored popups

`Calendar`, `ClockGui`, `ThemeSwitcher`, `WallpaperSwitcher`, `AppLauncher`, and `LogoutManager` expand around the centered clock. `ClockWidget` allows only one of these to be active, animates the current popup closed before opening another, and hides its compact clock pill while the popup owns that visual origin.

IPC plugins are routed by `Bar.qml` to the `ClockWidget` on `Hyprland.focusedMonitor`. A popup on another output is closed before the focused output opens its copy.

### Right-side dropdowns

`WifiGui`, `BluetoothGui`, and `VolumeGui` inherit `LeftExpandingPopup`. Their top-right corner remains fixed at the compact widget while width grows to the left. `TrayDropdownWidget` exposes the animated width to the bar, which pushes preceding right-side widgets left without moving widgets to the popup's right. `DropdownController` serializes transitions so only one right-side dropdown is active.

## IPC endpoints

Each target provides `open`, `close`, and `toggle`:

```bash
qs ipc call themeSwitcher toggle
qs ipc call wallpaperSwitcher toggle
qs ipc call appLauncher toggle
qs ipc call logoutManager toggle
```

The secure lock screen has intentionally one-way IPC: `lock`, `open`, and `toggle` all lock or re-focus it, and there is no `close` endpoint:

```bash
qs ipc call lockScreen lock
```

Under normal operation it can only be released by successful PAM authentication.

Temporary development exception: `qs ipc call lockScreenEmergency unlock` force-releases the lock without PAM so authentication failures can be debugged without rebooting. This is a security bypass and must be removed, along with its locked Hyprland keybind, once authentication is reliable.

The temporary in-surface recovery chord is `Ctrl+Alt+Shift+F12`; unlike the IPC binding, it is handled directly by the focused lock-screen input.

Before using the lock screen, install its root-owned PAM policy:

```bash
bash ~/.config/quickshell/plugins/lockScreen/install-pam.sh
```

The lock component refuses to acquire the Wayland session lock if `/etc/pam.d/quickshell-lock` is absent.

New `IpcHandler` declarations can require a full Quickshell restart before they appear in `qs ipc show`; ordinary QML visual changes normally hot-reload.

## UI and animation contract

### Motion

Popup geometry must be driven by one scalar `expansionProgress`. Width and height are derived from that same value, which guarantees they start and finish together and produces the intended diagonal expansion instead of sequential horizontal/vertical motion.

- Open: `260 ms`, `Easing.OutBack`, overshoot `0.8`.
- Close: `170 ms`, `Easing.InOutCubic`.
- Collapsed height: `33 px`, matching the clock or tray pill.
- Content is laid out at its final size and revealed by clipping/opacity; do not animate nested layout dimensions independently.
- Overshoot padding belongs to the transparent native popup surface so the card is not clipped.
- The compact pill is hidden during handoff to prevent a translucent pre-image behind the expanding card.
- Dynamic right-side popup height changes use a separate short resize only after the opening animation completes.

### Focus and dismissal

Interactive popups use `HyprlandFocusGrab` with `windows: [root]`. When activated, the popup calls `forceActiveFocus()` on its key-handling item. The bar itself is not included in the focus grab. Losing the grab closes the popup, and Escape always starts the close animation rather than instantly hiding the native window.

Keyboard-oriented plugins use arrow keys for selection and Enter/Return for activation. Mouse hover updates the same highlighted index so mouse and keyboard state never diverge.

### Colors

The shell has two color domains:

- `BarColors` is the stable monochrome palette for bar pills, hardware dropdowns, calendar/clock UI, app/logout plugins, common text, borders, hover fills, and disabled states.
- `Theme.colors` is the switchable Catppuccin/Everforest/Gruvbox palette for semantic accents, previews, selected calendar dates, warnings, and the intentionally theme-aware theme/wallpaper switcher surfaces.

Do not replace neutral bar surfaces with `Theme.colors`; switching themes must not recolor the black-and-white shell chrome. Do not add one-off gray literals—add or reuse a semantic `BarColors` role. See [`shared/README.md`](shared/README.md).

### Fonts and icons

- Text: `SF Pro Display`.
- UI glyphs: `Material Symbols Rounded`.
- Application icons: `DesktopEntries` metadata resolved through `Quickshell.iconPath()`.
- `launch.sh` reads the global GTK icon theme (`gsettings`, then GTK 3 settings as fallback), exports it as `QS_ICON_THEME`, and starts Quickshell with `qs -d`. This makes workspace and launcher icons follow the theme selected by `nwg-look` after a restart.

The preserved `workspaceIcons.jsonc` Nerd Font mapping is currently commented out in `Workspaces.qml`; natural system icons are the active path.

## Theme and wallpaper coupling

`Theme.qml` exposes `availableThemes`, `currentTheme`, `colors`, `paletteFor()`, and `setTheme()`. The available IDs are `catpuccin`, `everforest`, and `gruvbox`.

The selected Quickshell theme is stored in `Quickshell.statePath("theme-selection.json")` and restored after reloads and reboots. Restoration updates only the in-process palette and deliberately does not rerun system-wide theme commands.

When `ThemeSwitcher` selects a theme, it passes the theme ID and its remembered wallpaper to `plugins/themeSelector/apply-theme.sh`. This script is the central integration point for settings outside Quickshell: it applies the wallpaper; updates and reloads Kitty; repoints Hyprland's color module; and rebuilds `~/.config/starship.toml` from `themeSelector/starship/base.toml` plus the selected semantic palette. `~/.config/starship/colors.toml` points at the active palette source. After rebuilding, the script sends `Ctrl+C` through every live Kitty remote-control socket (`/tmp/mykitty` or its PID-suffixed variants) only to Bash windows, so they draw the new Starship prompt immediately. This safely avoids executing partial input, but cancels any unsubmitted text. Add future application theme updates to separate labeled sections in this script.

`Wallpaper.qml` remembers the last wallpaper independently for each theme in `Quickshell.statePath("wallpaper-history.json")`. Wallpapers live in:

```text
~/Pictures/Wallpapers/catpuccin
~/Pictures/Wallpapers/everforest
~/Pictures/Wallpapers/gruvbox
```

Applying a wallpaper runs:

```bash
awww img <path> --transition-type wipe --transition-fps 60
```

## Service boundaries

- Put long-lived system state and reusable actions in `services/`.
- Register every new singleton in `services/qmldir`.
- Widgets consume service properties and call service methods; they should not duplicate polling logic.
- Plugin-local one-shot actions are acceptable when they are not reusable state, such as the logout manager's power commands.
- Keep external parsing in `services/scripts/` when shell output is complex.

## Running and validation

Use the launcher so icon-theme synchronization and daemonization are applied:

```bash
./launch.sh
```

Useful diagnostics:

```bash
qs list
qs ipc show
qs log -p . --any-display -t 80 --no-color
```

Before handing off changes:

1. Run `git diff --check`.
2. Confirm the live log reaches `Configuration Loaded` without errors from changed files.
3. For a new IPC target, restart using `launch.sh`, then verify it appears in `qs ipc show`.
4. Exercise popup open and close through IPC, but never invoke suspend, logout, reboot, or poweroff as a test.
5. Treat unrelated missing icon, portal, or transient PipeWire warnings separately from QML load failures.

## Dependencies

Core runtime dependencies include Quickshell built with Wayland session-lock and PAM support, Hyprland, Qt 6/QML (including `QtQuick.Effects`), Linux PAM, PipeWire/PulseAudio tools (`pactl`), NetworkManager (`nmcli`), `iw`, BlueZ (`bluetoothctl`), UPower, Python 3, and `awww`. The configured fonts and the selected system icon theme must also be installed.
