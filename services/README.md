# Services

`services/` contains the reactive system layer. A service is the single source of truth for a subsystem and exposes formatted state plus narrowly scoped actions to widgets and plugins.

Do not put visual layout or popup state here. Do not make multiple widgets independently poll the same subsystem.

## Singleton contract

Every service uses `pragma Singleton`, a Quickshell `Singleton` root, and an entry in `services/qmldir`.

```qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root
}
```

Current registrations:

```text
Time, Power, Audio, Wifi, Bluetooth, Notifications, Wallpaper
```

Consumers import the directory and access a service directly:

```qml
import "../../../services"

Text { text: Audio.volumePercent + "%" }
MouseArea { onClicked: Audio.toggleMute() }
```

## Service overview

| Service | Primary backend | Main consumers |
| --- | --- | --- |
| `Time` | `SystemClock` | Clock pill, popup handoff states, and lock-screen clock/date. |
| `Power` | UPower | Battery pill. |
| `Audio` | PipeWire plus `audio_ctl.py`/`pactl` | Volume widget and volume GUI. |
| `Wifi` | Quickshell Networking, `nmcli`, `iw`, `wifi_scan.py` | Wi-Fi widget and Wi-Fi GUI. |
| `Bluetooth` | `bluetooth_ctl.py`/`bluetoothctl` | Bluetooth widget and Bluetooth GUI. |
| `Notifications` | Freedesktop `NotificationServer` | Toast overlay and optional notification center. |
| `Wallpaper` | Folder models, persistent state, `awww` | Theme/wallpaper switchers and lock-screen background. |

## `Time.qml`

Uses `SystemClock` at minute precision.

- `time`: formatted `HH:mm` string.

Popups reference `Time.time` both for display and as a daily/minute refresh dependency.

## `Power.qml`

Uses `UPower.displayDevice` and `UPower.onBattery`.

Properties:

- `battery`: rounded percentage string or `N.A`.
- `isCharging`: charging, pending charge, or fully charged while on AC.
- `icon`: Material Symbol chosen from battery level and charging state.
- `color`: theme red below 15%, theme yellow through 30%, otherwise `BarColors.primaryText`.

This service reports battery state only. Suspend, logout, reboot, and poweroff are one-shot actions owned by `plugins/logoutManager/LogoutManager.qml`.

## `Audio.qml`

The default sink is tracked natively through `Quickshell.Services.Pipewire`. `PwObjectTracker` keeps its audio interface alive. Sink enumeration and default-device switching are delegated to `scripts/audio_ctl.py`.

Reactive properties:

- `sink`, `audio`: current PipeWire node and audio interface.
- `volume`: normalized `0.0`–`1.0` value.
- `volumePercent`: rounded integer percentage.
- `muted`: default sink mute state.
- `icon`: `volume_off`, `volume_mute`, `volume_down`, or `volume_up`.
- `sinks`: usable connected output endpoints.
- `allSinks`: all endpoints, including disconnected ones.
- `defaultSinkName`: PipeWire/Pulse sink name.

Methods:

- `setVolume(value)` clamps and writes native PipeWire volume.
- `toggleMute()` toggles native mute.
- `setDefaultSink(name)` invokes the helper and refreshes state.
- `recheck()` refreshes sink metadata.

Sink metadata refreshes on PipeWire node changes, Bluetooth connection changes, and a 3-second timer.

## `Wifi.qml`

Wi-Fi combines several sources because no single API supplies every needed field:

- `Quickshell.Networking` supplies reactive devices, networks, connectivity, and radio state.
- `iw` supplies link signal and negotiated bitrate.
- `nmcli` supplies radio state, connectivity, saved profiles, scans, and actions.
- `scripts/wifi_scan.py` emits structured known/available network JSON.

Reactive properties:

- `enabled`, `connected`, `hasInternet`.
- `ssid`, `signalStrength`, `speedMbps`.
- `band` and `bandName`: disconnected/low/medium/fast classification.
- `icon`, `iconColor`: semantic status representation. Bar chrome may deliberately ignore `iconColor` and render white.
- `knownNetworks`, `availableNetworks`.
- `scanning`, `connectingSsid`, `connectError`.

Methods:

- `toggleWifi()`.
- `scanNetworks()`.
- `connectToNetwork(ssid, password)`.
- `disconnectNetwork(ssid)`.
- `forgetNetwork(ssid)`.
- `openHiddenNetworkDialog()`; tries GNOME Wi-Fi settings, then `nm-connection-editor`.
- `recheck()`.

Link state is refreshed every 4 seconds and on Quickshell networking signals. UI code should call the methods above rather than invoking `nmcli` itself.

## `Bluetooth.qml`

Bluetooth operations are performed by `scripts/bluetooth_ctl.py`, which wraps `bluetoothctl` and returns JSON.

Reactive properties:

- `enabled`, `connected`, `connectedCount`, `connectedDeviceName`.
- `pairedDevices`, `availableDevices`.
- `scanning`, `connectingMac`, `lastError`.
- `icon`, `iconColor`.

Methods:

- `togglePower(turnOn)`.
- `scanDevices()`; the helper performs a five-second discovery scan.
- `connectDevice(mac)`.
- `disconnectDevice(mac)`.
- `pairDevice(mac)`; helper pairs, trusts, and connects.
- `forgetDevice(mac)`.
- `recheck()`.

Status is polled every 4 seconds and refreshed after actions.

## `Notifications.qml`

Hosts the shell's freedesktop notification server with actions, body markup, body images, and application images enabled. Notifications remain tracked across QML reloads.

Reactive properties and signals:

- `dnd`: in-memory Do Not Disturb flag.
- `trackedNotifications`: server object model.
- `list`: array view of tracked notifications.
- `count`: active notification count.
- `toastRequested(notification)`: emitted only when DND is off.

Methods:

- `toggleDnd()`.
- `clearAll()`.
- `dismiss(notification)`.
- `getById(id)`.
- `getTimeAgo(id)`; a 15-second pulse keeps relative timestamps current.

`NotificationToasts.qml` listens for `toastRequested`. `NotificationGui.qml` provides history and dismissal UI, but its compact bar widget is currently disabled in `Bar.qml`.

## `Wallpaper.qml`

Wallpaper state is theme-aware and persistent.

Paths:

```text
~/Pictures/Wallpapers/catpuccin
~/Pictures/Wallpapers/everforest
Quickshell.statePath("wallpaper-history.json")
```

Supported formats are JPG, JPEG, PNG, WebP, and BMP. Folder models are sorted by filename.

Methods:

- `normaliseTheme(name)` maps unknown values to `catpuccin`.
- `wallpaperForTheme(name)` returns the remembered path.
- `rememberWallpaper(name, path)` updates and atomically saves history.
- `selectWallpaper(name, path)` remembers and applies a choice.
- `applyForTheme(name)` restores that theme's previous wallpaper or selects its first file.
- `applyWallpaper(path)` runs `awww img` with a 60 FPS wipe transition.

If folder models have not loaded when a theme is selected, `pendingTheme` defers application until files become available.

## Helper scripts

### `scripts/audio_ctl.py`

Uses `pactl` to return output-sink JSON and switch the default sink. It filters unavailable physical ports and classifies common output types for Material Symbol names.

Commands:

```text
audio_ctl.py status
audio_ctl.py set-default <sink-name>
```

### `scripts/bluetooth_ctl.py`

Wraps `bluetoothctl`, parses paired/discovered devices and battery state, and emits JSON.

Commands include `status`, `scan`, `power`, `connect`, `disconnect`, `pair`, and `remove`.

### `scripts/wifi_scan.py`

Parses saved NetworkManager connections and nearby access points. It removes empty SSIDs, deduplicates BSSIDs by strongest signal, and marks known, secure, and connected networks.

## Adding or changing a service

1. Reuse an existing service when the state already belongs to its subsystem.
2. Keep polling intervals conservative and react to native signals where possible.
3. Never interpolate untrusted values into a shell command when an argv array is possible.
4. Put complicated command output parsing in a helper script.
5. Register a new singleton in `services/qmldir`.
6. Update this README and the root architecture map.
7. Validate QML reloads and exercise only safe, reversible actions.
