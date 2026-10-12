# Bar Plugin

`plugins/bar/` owns the multi-monitor top panel, compact widgets, workspace UI, notification toasts, and dropdowns directly attached to bar widgets.

Standalone IPC plugins live beside this folder and are documented in [`plugins/README.md`](../README.md).

## `Bar.qml`

`Bar.qml` is a process-wide `Scope` containing:

- a registry of every per-screen `ClockWidget`;
- focused-monitor routing for clock-anchored IPC plugins;
- four `IpcHandler` targets;
- a `Variants` tree that creates one bar and one toast overlay per screen.

### Focused-monitor routing

`focusedClockWidget()` compares each bar window's screen with `Hyprland.focusedMonitor`. IPC requests are sent to that screen's clock. If Hyprland temporarily has no focused monitor, the first live bar is used as a fallback.

Before opening an IPC popup, `routeSwitcher()` asks every other screen's clock to close any IPC popup. This prevents duplicate theme, wallpaper, app, or logout managers across monitors.

### Per-screen layout

Each `PanelWindow` is anchored to the top, left, and right edges and has `implicitHeight: 45`.

| Region | Anchor | Active components |
| --- | --- | --- |
| `left_layout` | Left, 14 px margin | `Workspaces` |
| `middle_layout` | Center | `ClockWidget` |
| `right_layout` | Right, 14 px margin | `WifiWidget`, `BluetoothWidget`, `VolumeWidget`, `PowerWidget` |

The right-side order is important. Widgets are anchored from right to left: battery stays fixed at the edge, volume is left of battery, Bluetooth is left of volume, and Wi-Fi is left of Bluetooth.

`NotificationWidget` exists but is commented out in `middle_layout`. `NotificationToasts` is active independently and appears below the bar on every screen.

## Compact component primitives

### `Pill.qml`

The base 33 px-high rounded rectangle. It supports an optional Material Symbol `icon`, text `label`, custom children through its default property, and a native border used by focused workspace pills.

Default visual roles:

- background: `BarColors.surfaceBackground`;
- icon/text: `BarColors.primaryText`;
- radius: half the height.

### `TrayDropdownWidget.qml`

Base item for the right-side Wi-Fi, Bluetooth, and volume controls.

- The visible compact pill stays 33×33 and is anchored to the item's right edge.
- When its dropdown opens, `implicitWidth` follows `dropdown.animatedWidth`.
- Because right-side widgets are chained from right to left, this extra width pushes only earlier/leftward widgets.
- The compact pill disappears while the popup is visible, preventing a ghost surface behind the expanding card.

### `DropdownController.qml`

Serializes Wi-Fi/Bluetooth/volume popups. If a different dropdown is requested, it closes the current popup, waits for `closeFinished`, then opens the pending popup on the next event-loop turn.

## Bar widgets

| Component | Display | Interaction |
| --- | --- | --- |
| `ClockWidget` | `Time.time` in a centered pill | Left click opens `ClockGui`; right click opens the compact `Calendar`. Hosts every clock-anchored plugin. |
| `WifiWidget` | Material Symbol from `Wifi.icon` | Left click opens Wi-Fi GUI; right click opens hidden-network setup. |
| `BluetoothWidget` | Material Symbol from `Bluetooth.icon` | Left click opens Bluetooth GUI. |
| `VolumeWidget` | Audio icon plus symmetric Canvas progress ring | Left click opens volume GUI; right click toggles mute; wheel changes volume by 5%. |
| `PowerWidget` | Battery icon and percentage | Read-only display driven by `Power`. |
| `NotificationWidget` | Notification/DND icon | Left click toggles notification center; right click toggles DND. Present but not mounted in `Bar.qml`. |

Compact bar icons intentionally use monochrome `BarColors` even when their services expose theme-aware `iconColor` properties. Semantic colors are reserved for detailed popup content and alerts.

## `ClockWidget.qml`

The clock is both a widget and a popup coordinator. It instantiates:

- `Calendar`;
- `ClockGui`;
- `ThemeSwitcher`;
- `WallpaperSwitcher`;
- `AppLauncher`;
- `LogoutManager`.

`togglePopup()` enforces mutual exclusion. `pendingPopup` ensures switching between two open clock popups plays a complete close animation before the next one opens. `anyOpen` hides the compact clock during popup ownership.

The public routing surface used by `Bar.qml` is:

- `handleIpcSwitcher(kind, action)`;
- `closeIpcSwitchers()`.

Kinds are `theme`, `wallpaper`, `app`, and `logout`; actions are `open`, `close`, and toggle-by-default.

## Workspaces

`Workspaces.qml` is a `Pill` containing smaller workspace pills.

### Workspace allocation

- Single monitor/laptop: base workspaces 1–5.
- Multi-monitor built-in display (`eDP*`): base workspaces 1–5.
- Multi-monitor external display: base workspaces 6–10.
- Active workspaces outside the base range are included, and reasonable gaps are filled up to the highest active ID.

The module listens to raw Hyprland events, focused workspace changes, and focused monitor changes. Width expands and contracts as workspace pills appear or disappear.

### Application icons

The active path is `resolveSystemAppIcon()`:

1. Collect Wayland app ID, current class, and initial class.
2. Ask `DesktopEntries.heuristicLookup()` and `DesktopEntries.byId()` for the system desktop entry.
3. Resolve its icon through `Quickshell.iconPath()`.
4. Try the app ID directly against the active system icon theme.
5. Fall back to `application-x-executable` or `system-run`.

`launch.sh` exports the GTK-selected icon theme as `QS_ICON_THEME`, so this lookup follows the pack selected by `nwg-look` after a restart.

`workspaceIcons.jsonc`, its `FileView`, parser, `findNerdFontIcon()`, alias-based resolver, and Nerd Font rendering branch are deliberately preserved but commented/unused. Do not delete them; they exist so custom mappings can be restored later. Active `openApps` entries always set `isNerdFont: false`.

### Urgency

Urgent window addresses and workspace IDs are tracked from Hyprland events. Unfocused urgent workspaces use `Theme.colors.red` for the number and a small red badge over natural application icons. Focusing the workspace clears its tracked urgency.

### Focus styling

Focused and unfocused inner pills currently share the monochrome surface fill. Focus is communicated by a 2 px `Theme.colors.default_accent` border and a small width increase. Empty workspaces show a subdued dot.

## Right-side dropdown base

`widget_gui/LeftExpandingPopup.qml` supplies shared behavior to Wi-Fi, Bluetooth, and volume panels.

Geometry:

- the transparent native `PopupWindow` is anchored to `barWindow`;
- its top-right corner is mapped from `anchorItem` immediately before placement;
- the card remains anchored right while `animatedWidth` grows leftward;
- width and height derive from one `expansionProgress` scalar;
- the input mask follows only the visible card.

Animation:

- open: 260 ms `Easing.OutBack`, overshoot 0.8;
- close: 170 ms `Easing.InOutCubic`;
- post-open content-height changes: 160 ms `Easing.OutCubic`;
- final-size content fades in and is clipped by the card.

Focus:

- `HyprlandFocusGrab` targets only the popup window;
- the card receives active focus;
- Escape and focus loss call `closePopup()` so the closing animation is preserved.

## Right-side GUI panels

### `WifiGui.qml`

Width 380 px, maximum height 540 px. Shows connection state, bitrate/signal, radio toggle, refresh, saved networks, available networks, password entry, hidden-network launch, connect/disconnect, and forget actions. Rows can expand for contextual actions.

### `BluetoothGui.qml`

Width 380 px, maximum height 540 px. Shows controller status, power toggle, scan, paired devices, discovered devices, battery metadata where available, and connect/disconnect/pair/forget actions.

### `VolumeGui.qml`

Width 350 px, maximum height 520 px. Shows mute state, draggable/clickable/scrollable master volume control, refresh, and a scrollable output-device list. Selecting a sink calls `Audio.setDefaultSink()`.

## Clock-attached built-in GUIs

### `Calendar.qml`

A compact 240×88 weekly strip. It shows the current time and Monday-through-Sunday dates, emphasizing today. It shares the clock popup animation and closes on Escape/focus loss.

### `ClockGui.qml`

A 280×282 month calendar with previous/next controls, current-day accent, out-of-month dimming, weekend warnings, and a footer that returns to today.

Both popups anchor around the clock center and blend back to `collapsedColor` while shrinking so the handoff to the clock pill is visually continuous.

## Notifications

### `NotificationToasts.qml`

A non-exclusive overlay panel below the bar. It listens to `Notifications.toastRequested`, maintains up to five toast records, and displays app icon, summary/body, close control, and actions. Toasts auto-dismiss after two seconds; hovering pauses the timer and progress animation. DND suppresses new toast requests.

### `NotificationGui.qml`

A separate notification-history popup with DND control, count, individual dismissal, actions, empty state, and staggered “Clear All” animation. It does not currently inherit `LeftExpandingPopup` and is only reachable if `NotificationWidget` is mounted again.

## Styling rules

- Neutral shells, pills, list rows, borders, and text use `BarColors`.
- Theme accents are for semantic state, urgency, and calendar selection.
- Text uses `SF Pro Display`; symbol glyphs use `Material Symbols Rounded`.
- Avoid hardcoded grayscale literals in bar code.
- Selection should normally use fill; add a focus border only when it carries information not already conveyed by the fill.
- Keep compact controls 33 px high so animation origins align.

## Adding a bar widget or dropdown

1. Decide whether it belongs on the right tray, centered clock group, or left workspace area.
2. Reuse `Pill`, `TrayDropdownWidget`, or `LeftExpandingPopup` rather than reproducing their handoff behavior.
3. Put reusable system state/actions in a service singleton.
4. If it is a right-side dropdown, register it with the per-screen `DropdownController`.
5. If it expands from the clock, integrate it into `ClockWidget` mutual exclusion and, when keybound, into the `Bar.qml` focused-monitor IPC router.
6. Validate open, close, popup switching, focus loss, Escape, and multi-monitor placement.
