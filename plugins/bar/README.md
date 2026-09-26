# Bar Plugin (`plugins/bar/`)

The `plugins/bar/` directory contains the visual top bar, widget pills, application icon mappings, and popup GUI dropdowns.

---

## 1. Top Bar Layout Architecture (`Bar.qml`)

`Bar.qml` defines the primary desktop panel rendered across all connected monitors:

```qml
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            anchors { top: true; right: true; left: true }
            implicitHeight: 40
            color: "transparent"
            ...
```

### Layout Sections
The bar is divided into three distinct `RowLayout` containers to ensure items never overlap:
1. **`left_layout`** (`anchors.left: parent.left`, `spacing: 15`): Reserved for left-side modules (e.g. system status or launchers).
2. **`middle_layout`** (`anchors.centerIn: parent`, `spacing: 5`): Hosts the centered **`Workspaces`** module.
3. **`right_layout`** (`anchors.right: parent.right`, `spacing: 15`): Hosts system widgets:
   - `WifiWidget` (Circular pill, height 33)
   - `BluetoothWidget` (Circular pill, height 33)
   - `VolumeWidget` (Circular pill with progress ring, height 33)
   - `ClockWidget` (Pill, height 33)
   - `PowerWidget` (Pill, height 33)

---

## 2. Widget Components (`components/`)

### `Pill.qml`
The foundational styling primitive used for pill-shaped widgets.
- **Dimensions**: `implicitHeight: 33`, `radius: height / 2`.
- **Styling**: Background `Theme.colors.bg0`.
- **Slots**: Accepts an `icon` (Material Symbols Rounded) and a `label` (`SF Pro Display`), or custom child content inserted directly into its internal `RowLayout`.

---

### `ClockWidget.qml`
- Uses `Pill.qml`.
- Displays `"nest_clock_farsight_analog"` icon and `Time.time`.

---

### `PowerWidget.qml`
- Uses `Pill.qml`.
- Displays `Power.battery` with `Power.icon`.
- Dynamically updates icon color to `Theme.colors.red` / `yellow` / `text_accent` based on remaining charge.

---

### `VolumeWidget.qml`
- **Shape**: Circular pill ($33\times33\text{ px}$, `radius: height / 2`).
- **Symmetric Progress Ring**:
  - Implemented with an HTML5 `<Canvas>`.
  - Features a background ring (`Theme.colors.bg2`, width 2.5px).
  - An active volume progress ring starts at the top-middle (12 o'clock) and sweeps symmetrically in both directions.
  - Color flips to `Theme.colors.red` when muted, or `Theme.colors.text_accent` when active.
- **Interactions**:
  - **Scroll Wheel**: Increases or decreases volume by $\pm 5\%$.
  - **Left Click**: Toggles the interactive `VolumeGui` dropdown.
  - **Right Click**: Quick-toggles system mute via `Audio.toggleMute()`.

---

### `WifiWidget.qml`
- **Shape**: Circular pill ($33\times33\text{ px}$, `radius: height / 2`).
- **Icon**: Renders `Wifi.icon` at 16px using `Material Symbols Rounded`.
- **Dynamic Styling**: Color transitions between `Theme.colors.text_accent` (connected), `red` (alert / no internet), or `bg4` (disconnected).
- **Interactions**:
  - **Left Click**: Toggles the interactive `WifiGui` dropdown.
  - **Right Click**: Launches GNOME's hidden network setup.

---

### `BluetoothWidget.qml`
- **Shape**: Circular pill ($33\times33\text{ px}$, `radius: height / 2`).
- **Icon**: Renders `Bluetooth.icon`:
  - `"bluetooth"` when enabled with no device connected.
  - `"bluetooth_connected"` when a device is connected.
  - `"bluetooth_disabled"` when turned off.
- **Dynamic Styling**: Icon color transitions between `Theme.colors.text_accent` (connected), `Theme.colors.fg` (enabled), and `Theme.colors.bg4` (disabled).
- **Interactions**:
  - **Left Click**: Toggles the interactive `BluetoothGui` dropdown.

---

### `NotificationWidget.qml`
- **Shape**: Circular pill ($33\times33\text{ px}$, `radius: height / 2`).
- **Icon**: Renders dynamic bell state:
  - `"notifications_off"` with red accent when Do Not Disturb is active.
  - `"notifications_active"` with purple accent and an unread dot badge when notifications are present.
  - `"notifications"` in neutral text color when idle with zero notifications.
- **Interactions**:
  - **Left Click**: Toggles the `NotificationGui` dropdown.
  - **Right Click**: Quick-toggles Do Not Disturb mode on/off directly from the bar.

---

### `NotificationToasts.qml`
An overlay popup toast system that presents real-time notifications on screen:
- **Layer & Anchoring**:
  - `PanelWindow` on the Wayland `WlrLayer.Overlay` with `exclusionMode: ExclusionMode.Ignore`.
  - Anchored `top: true, right: true` with a `topOffset` positioning toasts right below the bar (`implicitHeight + 8px`) and `14px` right margin.
- **Max 5 Queue & Upward Displacement**:
  - Automatically maintains a maximum of 5 concurrent toasts on screen.
  - When more than 5 notifications arrive, the earliest received toast (top of the stack) is evicted, the remaining 4 smoothly glide upwards (`displaced: Transition`), and the new notification enters smoothly from the right at the bottom (`add: Transition`).
- **Auto-Dismiss & Progress Countdown**:
  - Each toast has a 2-second auto-dismiss `Timer`.
  - A subtle 2px progress bar animates along the bottom edge, indicating remaining time.
  - Both timer and progress bar pause when the cursor is hovering over the toast card.
- **Manual Dismiss & Interaction**:
  - Dedicated circular close button ("close" icon) on the top right of each toast for early dismissal.
  - Clicking the toast card triggers the notification's primary action (if defined) and dismisses the toast.
- **DND Integration**: Automatically suppressed when Do Not Disturb is enabled.

---

### `Workspaces.qml`
- **Dynamic Workspace Sizing**:
  - Displays a minimum of 5 workspaces per monitor at all times.
  - If additional active workspaces are opened beyond the base range, the module dynamically appends them and smoothly animates its width with `Behavior on implicitWidth` (`450ms`, `Easing.OutCubic`).
  - When temporary empty workspaces are abandoned, they are cleaned up and the module smoothly contracts back to 5 workspaces.
- **Per-Monitor Workspace Partitioning**:
  - Receives the screen context from `Bar.qml` (`screen: modelData`).
  - **Dual Monitor Setup**:
    - **Laptop Display (`eDP-1`)**: Displays workspaces **1–5** (minimum 5), plus any active workspaces assigned to `eDP-1` ($> 5$).
    - **External Monitor (e.g. `HDMI-A-1`)**: Displays workspaces **6–10** (minimum 5), plus any active workspaces assigned to the external monitor ($> 10$).
  - **Single Monitor Setup (Laptop Only)**:
    - If no external monitor is connected, all workspaces across the system belong to the laptop display. Displays workspaces **1–5** (minimum 5), dynamically expanding to include any active workspaces beyond 5 (e.g. 6, 7).
- **Hyprland Event Reactivity**:
  - Connects to `Hyprland.onRawEvent`, `onFocusedWorkspaceChanged`, and `onFocusedMonitorChanged` to guarantee instantaneous reactivity when windows or workspaces are created, moved, or destroyed.
  - Clicking any workspace pill dispatches `hl.dsp.focus({ workspace = <id> })`.
- **Urgent Workspace Highlighting**:
  - Automatically identifies when an unfocused workspace or any of its windows are marked urgent by the Hyprland compositor (e.g. notifications from Telegram, background links opened in Firefox, terminal alerts).
  - Listens for Hyprland `urgent` events via `onRawEvent` and checks `workspace.urgent` / `toplevel.urgent` properties.
  - Dynamically highlights the workspace number and application icons in `Theme.colors.red` (with a small red badge for natural desktop image icons).
  - As soon as the workspace is focused or clicked, the urgency flag is automatically cleared and the workspace smoothly transitions to its focused state.
- **App Icon Rewriting**:
  - Parses `plugins/bar/workspaceIcons.jsonc` via `Quickshell.Io.FileView`.
  - Automatically strips JSONC comments.
  - Matches the open window's `class` or `initialClass` against the dictionary.
  - Renders the corresponding **Nerd Font glyph**.
  - **Fallback**: If an application is not found in the dictionary, it falls back to rendering the application's natural desktop icon (`resolveNaturalAppIcon`).
  - **Empty Workspaces**: Renders a subtle circular dot indicator when no windows are open in that workspace.

---

## 3. Dropdown GUI System (`widget_gui/`)

### `WifiGui.qml`
A complete Wi-Fi management popup inspired by Omarchy's Quickshell network panel.

```
┌────────────────────────────────────────────────────────┐
│  [󰤨]  Galaxy S26 CD7A                   [🔄]  [●───]   │
│       Connected • 865 Mbps                     Toggle  │
├────────────────────────────────────────────────────────┤
│  KNOWN NETWORKS                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [󰤨] DAKM_1 (Connected)                       [🔒]│  │
│  │     Security: WPA2           [ Disconnect ]      │  │
│  └──────────────────────────────────────────────────┘  │
│  AVAILABLE NETWORKS                     [+ Hidden...]  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [󰤥] Mitra-1                                  [🔒]│  │
│  │     [ Enter password...                       ]  │  │
│  │     [ Cancel ]                     [ Connect ]   │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **Popup Architecture & Focus Grab**:
  - Declared as a `PopupWindow` anchored to `barWindow` directly beneath `WifiWidget`.
  - Configured with `grabFocus: true` so it immediately grabs focus and automatically collapses whenever clicked outside.
- **Header**:
  - Shows the connected network SSID in bold, live status subtitle (bitrate or signal %), a refresh/rescan button, and a smooth animated toggle switch.
- **Centering & Pill Architecture**:
  - All network pills feature a standard collapsed height of `48px` with `anchors.verticalCenter: parent.verticalCenter` and `Layout.alignment: Qt.AlignVCenter`.
  - Guarantees completely symmetrical 8px margins on top and bottom between pill borders and icons/text.
  - Header click targets are constrained to the top 48px, preventing click interception on expanded controls (password input, connect/forget buttons).
- **Known Networks**:
  - Saved profiles displayed with active connection highlighted in `Theme.colors.bg1`.
  - Click to expand and view security details or disconnect/forget.
- **Available Networks**:
  - Features a `[+ Hidden...]` button on the header to launch GNOME Wi-Fi manager.
  - Expandable network pills with `NumberAnimation` on height.
  - Inline password input field with show/hide eye toggle for secured networks.
  - Direct `Connect` action with real-time "Connecting..." feedback.

---

### `BluetoothGui.qml`
A comprehensive Bluetooth device management popup following the same design philosophy as `WifiGui.qml`.

```
┌────────────────────────────────────────────────────────┐
│  [󰂯]  Aryan's Buds3 Pro                 [🔄]  [●───]   │
│       Connected                                Toggle  │
├────────────────────────────────────────────────────────┤
│  PAIRED DEVICES (3)                                    │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [󰋋] Aryan's Buds3 Pro (Connected)             [✔]│  │
│  │     B0:54:76:D6:99:FD   [ Forget ] [ Disconnect ]│  │
│  └──────────────────────────────────────────────────┘  │
│  AVAILABLE DEVICES (2)                                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [󰌌] POP Icon Keys                             [>]│  │
│  │     DC:48:EA:C2:32:3F            [ Pair & Connect]│  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **Popup Architecture & Focus Grab**:
  - Declared as a `PopupWindow` anchored to `barWindow` directly beneath `BluetoothWidget`.
  - Uses `grabFocus: true` for focus management and automatic dismissal when clicking outside.
- **Centering & Pill Architecture**:
  - Standard collapsed height of `48px` with vertical centering and equal margins, matching `WifiGui.qml`.
- **Header**:
  - Live status icon, device/connection title, subtitle description, rescan button, and animated toggle switch.
- **Device Type Icon Heuristics**:
  - Automatically maps device icon metadata and names to specialized Material Symbols:
    - Headphones / Earbuds (`"headphones"`)
    - Speakers / Soundbars (`"speaker"`)
    - Keyboards (`"keyboard"`)
    - Mice / Trackpads (`"mouse"`)
    - Smartphones (`"smartphone"`)
    - Computers / Laptops (`"computer"`)
    - General Bluetooth devices (`"bluetooth"`)
- **Paired Devices**:
  - Displays all paired devices with connected device highlighted.
  - Shows battery percentage when reported by BlueZ.
  - Smooth height animation on click to reveal MAC address, `Connect` / `Disconnect` buttons, and a `Forget` (remove) button.
- **Available Devices**:
  - Displays newly discovered in-range devices with an interactive `Pair & Connect` button.
  - Shows real-time scanning status and feedback during pairing transactions.

---

### `NotificationGui.qml`
A clean, minimalist desktop notification center replacing external notification panels.

```
┌────────────────────────────────────────────────────────┐
│  Do not disturb                                 [●───] │
│                                                 Toggle │
│  Notifications  (2)                        [Clear All] │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │ [󰭹] Discord • 2m ago                          [X]│  │
│  │     New message from Alex                           │  │
│  │     Hey, are we still meeting today at 5?           │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [󰓇] Spotify • Just now                        [X]│  │
│  │     Song Playing                                    │  │
│  │     The Eulogy of You and Me • Huddy                │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **Popup Architecture & Focus Grab**:
  - Declared as a `PopupWindow` anchored to `barWindow` beneath `NotificationWidget`.
  - Uses `grabFocus: true` for automatic dismissal when clicking outside.
- **Header**:
  - **Do Not Disturb Row**: Dedicated row with an animated toggle switch to mute/suppress alerts.
  - **Notifications Row**: Displays the "Notifications" title, an active count badge, and a "Clear All" button pill (disabled when empty).
- **Empty State**:
  - When no notifications exist, displays a clean centered view with a large bell icon and "No Notifications" subtitle, matching the design aesthetic of the system.
- **Notification Cards & Dismissal Animations**:
  - Application icon (via `IconImage` with fallback to Material Symbols).
  - App name, bullet separator, and auto-updating relative timestamp ("Just now", "2m ago", etc.).
  - Summary and body text with clean wrapping and typography.
  - **Individual Close Animation**: Clicking the "close" button smoothly slides the single card to the right (`Easing.InQuad`, 180ms) before invoking `Notifications.dismiss(modelData)`.
  - Action buttons support for notifications with interactive actions.
- **Android-Style Domino "Clear All" Cascade**:
  - When clicking "Clear All", cards execute a staggered, cascading wave of slide-out animations.
  - Card 0 begins sliding immediately, followed by Card 1 after 45ms, Card 2 after 90ms, etc. (`SequentialAnimation` with `PauseAnimation { duration: index * 45 }`).
  - Each card accelerates off the right edge (`x: 0 -> width + 40`) and fades (`opacity: 1 -> 0`) over 200ms using `Easing.InQuad`.
  - The "Clear All" button and notification badge immediately dim and disable to prevent race conditions.
  - When the final card completes its slide, `Notifications.clearAll()` executes, and the card smoothly resizes to the empty state height via `Behavior on implicitHeight`.

---

### `VolumeGui.qml`
A dedicated audio management dropdown for master volume adjustment and output device switching.

```
┌────────────────────────────────────────────────────────┐
│  []  Volume Control                               []│
│       Built-in Speaker                          Mute   │
│  ┌──────────────────────────────────────────────────┐  │
│  │ []  [═════════════════●─────────────]   50%     │  │
│  └──────────────────────────────────────────────────┘  │
├────────────────────────────────────────────────────────┤
│  OUTPUT DEVICE                                     [🔄]│
│  ┌──────────────────────────────────────────────────┐  │
│  │ [] Built-in Speaker                         [✓] │  │
│  │     Active Output                                │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [] Sony WH-1000XM4 Headphones               [○] │  │
│  │     Sony WH-1000XM4 Headphones                   │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

- **Popup Architecture & Focus Grab**:
  - Declared as a `PopupWindow` anchored to `barWindow` directly beneath `VolumeWidget`.
  - Configured with `grabFocus: true` for automatic dismissal when clicking outside.
  - Sized with `implicitWidth: 350`, adhering to the standard Catppuccin Frappé palette.
- **Header**:
  - Circular master volume icon badge (`Audio.icon`) and "Volume Control" title.
  - Displays the currently active output sink as the subtitle.
  - Includes a quick mute toggle pill button (`Audio.toggleMute()`).
- **Interactive Master Volume Slider**:
  - Background track in `Theme.colors.bg2`, filled progress track in `Theme.colors.secondary_accent` (switches to `Theme.colors.red` when muted).
  - Circular thumb handle centered at the current volume position.
  - Supports click-to-seek, smooth click-and-drag, and mouse scroll wheel ($\pm 5\%$).
  - Real-time numerical percentage indicator (`XX%` or `Muted`).
- **Output Device Switcher**:
  - Enumerates connected audio sinks via `services/scripts/audio_ctl.py` and `services/Audio.qml`.
  - Filters out disconnected physical ports (e.g. unplugged HDMI jacks) while automatically listing plugged-in headphones, Bluetooth headsets, external monitors, and internal speakers.
  - Automatically maps Material Symbols based on device type (`speaker`, `headphones`, `tv`, `bluetooth`, `volume_up`).
  - Highlights the current default output with an active checkmark badge (`check`).
  - Clicking any output seamlessly routes default system audio to that device via `pactl set-default-sink`.



