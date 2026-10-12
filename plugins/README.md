# Standalone Plugins

This directory contains the top bar, four keybind-driven popup plugins, and a secure session-lock plugin. The popup plugins are instantiated inside every `ClockWidget`, but process-wide IPC routing in `bar/Bar.qml` opens only the copy on the currently focused monitor. The lock screen is instantiated once at bar scope and creates a protected surface for every output.

| Folder | Component | IPC target | Purpose |
| --- | --- | --- | --- |
| `themeSelector/` | `ThemeSwitcher.qml`, `apply-theme.sh` | `themeSwitcher` | Select a palette and apply its wallpaper and application settings. |
| `wallpaperSwitcher/` | `WallpaperSwitcher.qml` | `wallpaperSwitcher` | Browse and apply wallpapers for the active theme. |
| `appLauncher/` | `AppLauncher.qml` | `appLauncher` | Search and launch desktop applications. |
| `logoutManager/` | `LogoutManager.qml` | `logoutManager` | Suspend, leave Hyprland, reboot, or power off. |
| `lockScreen/` | `LockScreen.qml` | `lockScreen` | Cover every output and unlock only after PAM authentication. |

All targets expose the same functions:

```bash
qs ipc call <target> open
qs ipc call <target> close
qs ipc call <target> toggle
```

The lock screen is the exception: `lock`, `open`, and `toggle` all acquire or re-focus the lock. It deliberately exposes no `close` or `unlock` IPC method. Only a successful PAM result releases it.

During lock-screen development there is one explicitly temporary exception: `lockScreenEmergency.unlock` bypasses PAM and releases the Wayland session lock. It must be deleted once normal authentication is reliable.

## Shared popup contract

Each standalone plugin is a `PopupWindow` with this integration surface:

```qml
property var barWindow
property var anchorItem
property real collapsedWidth
property color collapsedColor

signal openRequested()
signal closeFinished()

function openPopup()
function closePopup()
function requestOpen()
```

`ClockWidget` supplies its bar window, itself as the anchor, its compact clock width, and the current clock-pill color. `requestOpen()` emits `openRequested` so `ClockWidget` can close any current popup before opening the new one.

Each native popup is wider/taller than its card by `overshootPadding`. This transparent space allows the spring overshoot without clipping.

## Animation and visual handoff

The plugins intentionally duplicate the same small animation pattern. Keep these values synchronized unless a new design decision changes all clock-origin popups:

- `expansionProgress`: the only geometry animation source.
- `animatedWidth`: interpolates from `collapsedWidth` to `targetWidth`.
- `animatedHeight`: interpolates from 33 px to `targetHeight`.
- opening: 260 ms, `Easing.OutBack`, overshoot 0.8.
- closing: 170 ms, `Easing.InOutCubic`.
- `contentProgress`: clamped progress used for opacity and border alpha.

The content item is always laid out at target size. The animated card clips it instead of allowing layouts to reflow on every frame. During close, the card blends from its full background to `collapsedColor`, and a compact `Time.time` label fades in so the surface visually becomes the clock before `ClockWidget` shows its own pill again.

Do not introduce separate width and height animations; even equal durations can become visually desynchronized by independent starts, layout work, or easing state.

## Focus and monitor behavior

Every plugin uses `HyprlandFocusGrab` with only the popup in `windows`. Once active, the popup forces focus onto the card or search input. This provides reliable key handling immediately after a keybind opens the plugin.

- Escape calls `closePopup()`.
- Losing the focus grab calls `closePopup()`.
- The native window remains visible until the close animation finishes.
- `Bar.focusedClockWidget()` routes IPC to `Hyprland.focusedMonitor`.
- Other monitors close their IPC plugins before the focused monitor opens one.

Adding the bar window to the focus-grab list can cause Hyprland to focus the bar instead of the popup; do not do it.

## `ThemeSwitcher.qml`

Displays `Theme.availableThemes` horizontally. Each option contains its display name and five palette swatches. The selected theme and keyboard-highlighted theme receive theme-aware fills/borders.

Controls:

- Left/Right or Up/Down: move highlight with wraparound.
- Enter/Return or click: call `Theme.setTheme(id)`, run `apply-theme.sh <id> <remembered-wallpaper>`, then close.
- Escape: close.

The active theme is currently not persisted across a full Quickshell restart; Catppuccin is the default. Wallpaper selections are persisted per theme. `apply-theme.sh` is the central place for side effects outside Quickshell: it restores the selected theme's wallpaper through `awww`; atomically repoints `~/.config/kitty/colors` to `~/.config/kitty/themes/<theme>.conf` and reloads running Kitty processes; and repoints `~/.config/hypr/colors.lua` to `~/.config/hypr/themes/<theme>.lua` for theme-aware decoration accents. Keep future application-specific theme updates in clearly labeled sections of that script.

## `WallpaperSwitcher.qml`

Displays a three-column `GridView` of image previews from the selected theme's directory:

```text
~/Pictures/Wallpapers/catpuccin
~/Pictures/Wallpapers/everforest
```

Supported file types: JPG, JPEG, PNG, WebP, and BMP. Files are sorted by name.

Controls:

- Left/Right: move one cell.
- Up/Down: move one row (three cells).
- Enter/Return or click: call `Wallpaper.selectWallpaper()` and close.
- Escape: close.

When opened, it highlights the wallpaper remembered for the current theme, falling back to the first entry. Applying uses `awww` with the configured wipe transition through the wallpaper service.

## `AppLauncher.qml`

Uses `DesktopEntries.applications.values`, filters hidden/non-application entries upstream through Quickshell, sorts names alphabetically, and applies a case-insensitive name query.

UI behavior:

- The search input receives focus as soon as the popup opens.
- Typing updates the application model immediately.
- The viewport is exactly five 46 px rows with 6 px spacing; only five applications are visible at once.
- Up/Down changes `highlightedIndex` and `positionViewAtIndex(..., ListView.Contain)` scrolls by the minimum required amount.
- Enter/Return calls the selected desktop entry's `execute()` and closes.
- Hover updates the keyboard highlight; click launches.
- Escape closes.

Each row shows the desktop entry's natural icon through `Quickshell.iconPath()` followed by its name. The process-wide `QS_ICON_THEME` set by `launch.sh` makes named icons follow the GTK-selected pack.

The launcher deliberately has no heading and no selection border; fill color alone indicates the highlighted application.

## `LogoutManager.qml`

Displays four horizontal options using monochrome shell colors:

| Option | Command |
| --- | --- |
| Suspend | Acquire `lockScreen`, wait for the compositor-secure state, then run `systemctl suspend` |
| Logout | `hyprctl dispatch exit` |
| Restart | `systemctl reboot` |
| Shutdown | `systemctl poweroff` |

Left/Right and Up/Down all move through the options with wraparound. Enter/Return or click selects an action. Escape closes without setting an action.

Selected actions are stored in `pendingAction`, the popup plays its full close animation, and only then does its `Process` run the command. This preserves the visual handoff and avoids leaving the popup visible during session shutdown.

Never test this component by selecting an action unless the user explicitly intends the corresponding system operation. Runtime tests should call only the IPC `open` and `close` functions.

## `LockScreen.qml`

`LockScreen` uses `WlSessionLock`, not a fullscreen application window. The compositor creates one protected `WlSessionLockSurface` per monitor and does not reveal client windows if Quickshell exits unexpectedly. Every surface renders the active theme's remembered wallpaper from `Wallpaper.qml`, applies a Qt `MultiEffect` blur, and adds a black dim layer. If no image is available, the opaque `BarColors.deepBackground` surface remains in place.

Launch and unlock use one shared opacity animation across every output. The session-lock surfaces remain fully opaque in `BarColors.deepBackground`: after the compositor reports that the session is secure, their wallpaper and controls fade in over 260 ms. Successful authentication fades that content back to black over 200 ms, then releases the Wayland session lock. This ordering deliberately avoids a translucent transition that could reveal open client windows.

The large clock and weekday/date are backed by the minute-resolution `Time` service. Password state is shared across outputs, and each lock surface forces focus to its password `TextInput`. Enter submits through `PamContext` using the root-owned `/etc/pam.d/quickshell-lock` policy; Escape clears the field but never closes the lock. Failed attempts clear the secret and return focus. The submitted password is retained only for the active PAM conversation and is cleared on completion.

The dedicated PAM policy uses `pam_unix` and `pam_faillock` without including Fedora's `login`/`system-auth` stack. That system stack places `pam_fprintd` before `pam_unix`, so a password-only UI can otherwise remain waiting for a fingerprint attempt instead of verifying the submitted password. If fingerprint unlocking is added later, it needs a separate concurrent conversation and UI state rather than being inserted ahead of password verification.

Install the repository template before enabling the keybind:

```bash
bash ~/.config/quickshell/plugins/lockScreen/install-pam.sh
```

The installer uses `sudo` to copy `pam.d/quickshell-lock` to `/etc/pam.d/quickshell-lock` with root ownership and mode `0644`. `LockScreen` watches that system file and refuses to acquire a session lock while it is missing, preventing an unauthenticatable lock screen.

Check readiness before testing:

```bash
qs ipc call lockScreen status
```

`pamConfigured` must be `true`. The remaining fields expose requested, protocol-lock, compositor-secure, and authentication state without changing them.

Use this endpoint from a Hyprland keybind:

```bash
qs ipc call lockScreen lock
```

Repeated calls while already locked are safe and only request keyboard focus again. Do not test authentication with an automated or guessed password. The temporary emergency target below is the sole IPC unlock path and must not be copied or treated as a permanent interface.

### Temporary emergency unlock

The current development build exposes this security bypass:

```bash
qs ipc call lockScreenEmergency unlock
```

For a Hyprland keybind to execute while a session-lock surface owns the screen, mark the bind as `locked`:

```lua
local qs_emergencyUnlock = "qs ipc call lockScreenEmergency unlock"
hl.bind(mainMod .. " + CTRL + SHIFT + L", hl.dsp.exec_cmd(qs_emergencyUnlock), { locked = true })
```

The handler aborts any active PAM attempt, clears the password state, and assigns `WlSessionLock.locked = false`, matching the release mechanism used by Omarchy. Anyone who can execute that keybind or IPC call can bypass authentication. Remove the binding, `lockScreenEmergency` handler, and `emergencyUnlock()` function as soon as the PAM issue is resolved.

While the bypass exists, the focused lock-surface input also handles `Ctrl+Alt+Shift+F12`. This calls the same `emergencyUnlock()` function without relying on Hyprland to spawn `qs ipc`, so it is the recovery path to use if the external emergency binding cannot run. Delete this `Keys.onPressed` branch together with the other emergency bypass code.

Do not kill or restart Quickshell while the session is locked. By protocol design the compositor keeps the session covered if the lock client disappears, which is secure but can require relaunching Quickshell from a TTY before the graphical session is usable again.

## IPC registration

`bar/Bar.qml` owns `IpcHandler` objects because it exists once, outside the per-screen `Variants`. Each handler calls `routeSwitcher(kind, action)`.

`ClockWidget.switcherForKind()` maps the kind to a local popup instance. Its mutual-exclusion logic also includes non-IPC `Calendar` and `ClockGui`, so opening a keybound plugin cleanly closes either built-in clock popup first.

After adding a brand-new `IpcHandler`, perform a full restart:

```bash
./launch.sh
qs ipc show
```

Hot reload may update QML while retaining the old process IPC registry.

## Adding another clock-anchored plugin

1. Create `plugins/<name>/<Component>.qml` with the shared popup contract.
2. Use the common `expansionProgress`, focus-grab, close-animation, and clock-handoff pattern.
3. Import and instantiate it in `ClockWidget.qml`.
4. Add it to `anyOpen`, current-popup detection, `switcherForKind()`, and `closeIpcSwitchers()`.
5. Add one process-wide `IpcHandler` to `Bar.qml`.
6. Use `BarColors` for neutral chrome and `Theme.colors` only for theme-dependent semantics.
7. Restart Quickshell, confirm the target with `qs ipc show`, and test open/close on each focused monitor.
