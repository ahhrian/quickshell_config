# Quickshell Desktop Bar & Services Architecture

This repository contains the complete [Quickshell](https://quickshell.org) configuration for Wayland / Hyprland, providing a high-performance, modular status bar, system services, and interactive GUI dropdowns.

> **AI Context & Fast-Path Orientation**:
> When continuing work on this project in new sessions, read this document first. It summarizes the directory structure, singleton data flow, theming conventions, and component interaction models.

---

## 1. High-Level Architectural Flow

The architecture strictly follows a unidirectional reactive model:

```
┌────────────────────────────────────────────────────────┐
│                   System Subsystems                    │
│    (NetworkManager, PipeWire, UPower, Hyprland, Clock) │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│                   services/ (Singletons)               │
│   • Single Source of Truth for system state & actions  │
│   • Registered in services/qmldir                      │
│   • Formats data and exposes reactive properties       │
└──────────────┬──────────────────────────┬──────────────┘
               │                          │
               ▼                          ▼
┌─────────────────────────────┐ ┌─────────────────────────────┐
│  plugins/bar/components/    │ │   plugins/bar/widget_gui/   │
│  (Bar Widgets / Pills)      │ │   (Interactive Dropdowns)   │
│  • Reads from services/     │ │  • PopupWindow components   │
│  • Emits UI actions back    │ │  • Anchored to barWindow    │
│    to the services          │ │  • Advanced GUI controls    │
└──────────────┬──────────────┘ └──────────────┬──────────────┘
               │                               │
               └──────────────┬────────────────┘
                              ▼
┌────────────────────────────────────────────────────────┐
│                   plugins/bar/Bar.qml                  │
│   • PanelWindow layer-shell anchored to screen top     │
│   • Arranges left, center, and right RowLayout groups  │
└────────────────────────────────────────────────────────┘
```

### Key Principles
1. **Services are Singletons**: All system data (Audio, Wi-Fi, Battery, Time) lives in `services/`. Widgets must **never** query external processes or hardware directly if a service exists.
2. **Formatting in Services**: State formatting (e.g. converting battery percentage to Material Symbol icon, Wi-Fi speed into 3 tiers) belongs in the singleton service, not scattered across widgets.
3. **Components Only Display and Trigger**: Components in `plugins/bar/components/` read singleton properties and invoke service functions (e.g., `Audio.setVolume()`, `Wifi.toggleWifi()`).
4. **Layout with RowLayouts**: Widgets are placed inside `RowLayout`s within `Bar.qml`. Widgets declare their own `implicitWidth` and `implicitHeight` (standard height: `33px`), allowing them to automatically push adjacent widgets without overlapping.

---

## 2. Directory Structure

```
.
├── shell.qml                         # Quickshell entrypoint (loads plugins/bar and shared)
├── README.md                         # This architecture guide
│
├── services/                         # System service singletons (Source of Truth)
│   ├── qmldir                        # Registers Time, Power, Audio, Wifi, Bluetooth, Notifications singletons
│   ├── README.md                     # Services subsystem documentation
│   ├── Audio.qml                     # PipeWire volume, mute tracking & output device switcher
│   ├── Bluetooth.qml                 # BlueZ Bluetooth controller state, device tracking & pairing
│   ├── Notifications.qml             # Desktop notification daemon (NotificationServer), tracking & DND
│   ├── Power.qml                     # UPower battery percentage, charging state & icon
│   ├── Time.qml                      # SystemClock date & time formatting
│   ├── Wifi.qml                      # NetworkManager Wi-Fi status, bitrate & management
│   └── scripts/                      # Backend automation scripts
│       ├── audio_ctl.py              # Fast JSON wrapper for pactl sink query & default sink switching
│       ├── bluetooth_ctl.py          # Fast JSON wrapper for bluetoothctl operations
│       └── wifi_scan.py              # Fast JSON scanner for known & in-range networks
│
├── plugins/
│   └── bar/                          # Top bar plugin
│       ├── README.md                 # Bar components & dropdown documentation
│       ├── Bar.qml                   # Main PanelWindow layer-shell layout
│       ├── workspaceIcons.jsonc      # Nerd Font icon dictionary for Hyprland apps
│       ├── components/               # Bar pill widgets (height: 33px)
│       │   ├── Pill.qml              # Base pill container with icon & label
│       │   ├── BluetoothWidget.qml   # Circular pill with Bluetooth status & dropdown toggle
│       │   ├── ClockWidget.qml       # Clock pill displaying Time.time
│       │   ├── NotificationToasts.qml# Real-time toast notifications overlay with FIFO upward displacement
│       │   ├── NotificationWidget.qml# Circular pill with notification count & DND indicator
│       │   ├── PowerWidget.qml       # Battery pill displaying Power.battery
│       │   ├── VolumeWidget.qml      # Circular pill with 360° symmetric progress ring & dropdown toggle
│       │   ├── WifiWidget.qml        # Circular pill with Wi-Fi signal & dropdown toggle
│       │   └── Workspaces.qml        # Hyprland workspace switcher with Nerd Font icons
│       └── widget_gui/               # Full GUI dropdown panels
│           ├── BluetoothGui.qml      # Minimalist Bluetooth device management popup
│           ├── NotificationGui.qml   # Minimalist notification center with DND & Clear All
│           ├── VolumeGui.qml         # Minimalist volume slider & audio output switcher popup
│           └── WifiGui.qml           # Minimalist Omarchy-style Wi-Fi management popup
│
└── shared/                           # Shared design tokens and utilities
    ├── qmldir                        # Registers Theme singleton
    ├── README.md                     # Theming & design system documentation
    ├── Theme.qml                     # Global theme manager exposing colors
    └── colors/
        └── Catpuccin.qml             # Catppuccin Frappé palette definitions
```

---

## 3. Design System & Theming

The entire UI is unified under the Catppuccin Frappé palette via `shared/Theme.qml`.

### Color Tokens (`Theme.colors.<token>`)
| Token | Hex | Usage |
| :--- | :--- | :--- |
| `bg0` | `#232634` | Main container and pill background |
| `bg1` | `#303446` | Hovered pill background, active row highlights |
| `bg2` | `#414559` | Borders, divider lines, switch track off-state |
| `bg3` | `#51576d` | Input borders, elevated elements |
| `bg4` | `#626880` | Muted labels, secondary descriptions, inactive icons |
| `fg` | `#c6d0f5` | Primary text and default icons |
| `text_accent` | `#81c8be` (Aqua) | Active network, volume fill, positive highlights |
| `alt_accent` | `#8caaee` (Blue) | Secondary highlights, workspace indicators |
| `container_accent`| `#ca9ee6` (Purple)| Container accents |
| `red` | `#e78284` | Mute indicator, alert status, disconnect buttons |

### Typography & Icons
- **System Typography**: `"SF Pro Display"` (sans-serif fallback).
- **Iconography**: `"Material Symbols Rounded"` used for all system indicators (Volume, Power, Wi-Fi, Clock).
- **Workspace App Glyphs**: Nerd Font glyphs loaded from `plugins/bar/workspaceIcons.jsonc`.

---

## 4. Subsystem Integrations

- **Hyprland**: Integrated via `Quickshell.Hyprland` in `Workspaces.qml` to track active workspace IDs and window classes for automatic icon rewriting.
- **PipeWire**: Integrated via `Quickshell.Services.Pipewire` in `Audio.qml` with `PwObjectTracker` monitoring `Pipewire.defaultAudioSink`.
- **UPower**: Integrated via `Quickshell.Services.UPower` in `Power.qml` tracking `UPower.displayDevice`.
- **NetworkManager**: Dual-layer integration via native `Quickshell.Networking` plus fast `nmcli` / `iw` netlink queries in `Wifi.qml` and `services/scripts/wifi_scan.py`.
- **BlueZ / Bluetooth**: Integrated via `bluetoothctl` in `Bluetooth.qml` and `services/scripts/bluetooth_ctl.py` to control power, discovery, connection, pairing, and battery status.

---

## 5. Development, Running & Hot-Reload

- **Running the Shell**:
  ```bash
  qs -p /home/aryan/.config/quickshell
  ```
- **Hot-Reload**: Quickshell monitors all `.qml`, `.jsonc`, and `.py` files in the directory tree and reloads instantly on file save.
- **Log Location**:
  Logs are written to `/run/user/1000/quickshell/by-id/<instance_id>/log.log` and `log.qslog`. Always check these logs if investigating syntax errors or binding loops.
