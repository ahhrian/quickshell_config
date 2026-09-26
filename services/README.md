# Services Subsystem (`services/`)

The `services/` directory contains all **system service singletons**. These singletons serve as the **Single Source of Truth** for all hardware, networking, and system-level state across the desktop environment.

---

## 1. How Services Work in Quickshell

Every service in this directory adheres to the QML singleton pattern:

1. **`pragma Singleton`**: Must be the first line of the `.qml` file.
2. **`Singleton { id: root ... }`**: Root item declared using Quickshell's `Singleton` type.
3. **Registration in `services/qmldir`**:
   ```
   singleton Time 1.0 Time.qml
   singleton Power 1.0 Power.qml
   singleton Audio 1.0 Audio.qml
   singleton Wifi 1.0 Wifi.qml
   singleton Bluetooth 1.0 Bluetooth.qml
   ```
   > [!IMPORTANT]
   > Any new singleton file added to `services/` **MUST** be explicitly listed in `services/qmldir`, otherwise QML components importing `services` will throw `ReferenceError: <Service> is not defined`.

4. **Importing in Components**:
   ```qml
   import "../../../services"
   // Directly access properties:
   Text { text: Audio.icon }
   ```

---

## 2. Singleton Reference

### `Audio.qml`
Tracks PipeWire audio state and provides reactive volume & mute control as well as output device enumeration and switching.
- **Backend**: `Quickshell.Services.Pipewire` via `Pipewire.defaultAudioSink` and `PwObjectTracker`, augmented with `services/scripts/audio_ctl.py` for sink enumeration and default device switching.
- **Properties**:
  - `sink`: The default output node.
  - `audio`: The `PwNodeAudio` interface of the sink.
  - `volume`: `real` between `0.0` and `1.0`.
  - `volumePercent`: `int` rounded percentage (`0` to `100`).
  - `muted`: `bool` system mute status.
  - `icon`: Material Symbol icon (`"volume_up"`, `"volume_down"`, `"volume_mute"`, `"volume_off"`).
  - `sinks`: `Array` of currently available/connected audio sinks (`id`, `name`, `display_name`, `description`, `icon`, `is_default`, `volume_percent`, `muted`).
  - `allSinks`: `Array` of all detected sinks including disconnected endpoints.
  - `defaultSinkName`: `string` name of current default audio sink.
- **Methods**:
  - `setVolume(real newVolume)`: Clamps volume between `0.0` and `1.0`.
  - `toggleMute()`: Inverts current mute state.
  - `setDefaultSink(string sinkName)`: Sets default sink via `audio_ctl.py set-default <sinkName>`.
  - `recheck()`: Triggers an immediate refresh of sink states.

---

### `Power.qml`
Tracks battery capacity, charging status, and dynamic warning colors.
- **Backend**: `Quickshell.Services.UPower` tracking `UPower.displayDevice` and `UPower.onBattery`.
- **Properties**:
  - `device`: The UPower battery device.
  - `battery`: Formatted string (`"85%"` or `"N.A"`).
  - `isCharging`: `bool` whether the battery is currently charging or plugged into AC power.
  - `icon`: Material Symbol battery icon:
    - **Charging**: `battery_charging_20`, `battery_charging_30`, `battery_charging_50`, `battery_charging_60`, `battery_charging_80`, `battery_charging_90`, `battery_charging_full`.
    - **Discharging**: `battery_alert` (< 15%), `battery_X_bar` (1..6 bars), `battery_full` (> 90%).
  - `color`: Dynamic color indicator (`Theme.colors.red` below 15%, `yellow` below 30%, `default_accent` otherwise).

---

### `Time.qml`
Provides the system time updated every minute.
- **Backend**: `Quickshell`'s `SystemClock` with `SystemClock.Minutes` precision.
- **Properties**:
  - `time`: Formatted string (e.g. `"14:05"`).

---

### `Wifi.qml`
Complete Wi-Fi network monitor, speed calculator, and manager.
- **Backend**:
  - Native `Quickshell.Networking` (device & network signals).
  - `Process` netlink query: `iw dev <iface> link` for instantaneous bitrate & signal dBm.
  - `Process` NetworkManager queries: `nmcli radio wifi`, `nmcli networking connectivity`.
  - Python helper: `services/scripts/wifi_scan.py` for structured network scanning.
- **Properties**:
  - `enabled`: `bool` Wi-Fi radio power status.
  - `connected`: `bool` whether connected to an access point.
  - `hasInternet`: `bool` whether the connection has full internet access.
  - `ssid`: `string` SSID of the connected network.
  - `signalStrength`: `int` percentage ($0 - 100\%$).
  - `speedMbps`: `real` negotiated PHY bitrate in Mbps.
  - `band`: `int` ($3$ = Top band, $2$ = 2nd band, $1$ = Lowest band, $0$ = Disconnected).
  - `bandName`: `string` readable speed band description.
  - `icon`: Material Symbol icon mapping:
    - Top band ($\ge 100\text{ Mbps}$ or signal $\ge 67\%$): `"android_wifi_4_bar"`
    - 2nd band ($25 - 100\text{ Mbps}$ or signal $34\% - 66\%$): `"android_wifi_3_bar"`
    - Lowest band ($< 25\text{ Mbps}$ or signal $1\% - 33\%$): `"wifi_2_bar"`
    - Connected without internet: `"android_wifi_3_bar_alert"`
    - Disconnected / Radio off: `"android_wifi_4_bar_off"`
  - `iconColor`: `Theme.colors.text_accent` (connected), `red` (alert), or `bg4` (disconnected).
  - `knownNetworks`: `Array` of saved network objects.
  - `availableNetworks`: `Array` of in-range nearby network objects.
  - `scanning`: `bool` whether a Wi-Fi scan is actively running.
  - `connectingSsid`: `string` SSID of the network currently being connected to.
- **Methods**:
  - `toggleWifi()`: Inverts Wi-Fi radio power.
  - `scanNetworks()`: Executes `services/scripts/wifi_scan.py` to refresh network lists.
  - `connectToNetwork(ssid, password)`: Connects to a target Wi-Fi network via `nmcli`.
  - `disconnectNetwork(ssid)`: Disconnects the active connection.
  - `forgetNetwork(ssid)`: Deletes the NetworkManager connection profile.
  - `openHiddenNetworkDialog()`: Launches GNOME's hidden network connection utility.
  - `recheck()`: Forces an immediate status refresh.

---

### `Bluetooth.qml`
Complete BlueZ Bluetooth controller monitor, scanner, and connection manager.
- **Backend**:
  - `Process` wrapper around `services/scripts/bluetooth_ctl.py`.
  - Underlying tools: `bluetoothctl` and BlueZ D-Bus APIs.
- **Properties**:
  - `enabled`: `bool` whether the Bluetooth controller is powered on.
  - `connected`: `bool` whether any device is currently connected.
  - `connectedDeviceName`: `string` primary connected device name or summary.
  - `connectedCount`: `int` number of active connected devices.
  - `pairedDevices`: `Array` of paired device objects (`{mac, name, icon, connected, paired, battery}`).
  - `availableDevices`: `Array` of discovered nearby devices ready for pairing.
  - `scanning`: `bool` whether a 5-second discovery scan is actively running.
  - `connectingMac`: `string` MAC address of the device currently in a connection/pairing transaction.
  - `icon`: Material Symbol icon mapping:
    - Disabled: `"bluetooth_disabled"`
    - Enabled with active connection: `"bluetooth_connected"`
    - Enabled without active connection: `"bluetooth"`
  - `iconColor`: `Theme.colors.text_accent` (connected), `Theme.colors.fg` (enabled), or `Theme.colors.bg4` (disabled).
- **Methods**:
  - `togglePower(turnOn)`: Powers controller on/off via `bluetoothctl power on/off`.
  - `scanDevices()`: Starts a 5-second discovery scan.
  - `connectDevice(mac)`: Connects to a paired device.
  - `disconnectDevice(mac)`: Disconnects an active device.
  - `pairDevice(mac)`: Pairs, trusts, and connects to an available device.
  - `forgetDevice(mac)`: Removes/unpairs device via `bluetoothctl remove <mac>`.
  - `recheck()`: Forces an immediate status update.

---

### `Notifications.qml`
Desktop notification daemon and manager implementing the freedesktop Desktop Notifications specification (`org.freedesktop.Notifications`).
- **Backend**:
  - Hosts native `Quickshell.Services.Notifications.NotificationServer`.
  - Configured with `keepOnReload: true`, `actionsSupported: true`, `bodySupported: true`, `bodyMarkupSupported: true`, `imageSupported: true`.
- **Properties**:
  - `dnd`: `bool` whether Do Not Disturb is enabled (mutes/suppresses banners).
  - `trackedNotifications`: `ObjectModel<Notification>` of all active notifications.
  - `list`: `Array` of notification objects for simple iteration.
  - `count`: `int` current number of tracked notifications.
- **Methods**:
  - `toggleDnd()`: Toggles Do Not Disturb mode on/off.
  - `clearAll()`: Dismisses all tracked notifications and clears timestamp cache.
  - `dismiss(n)`: Dismisses a specific notification.
  - `getTimeAgo(id)`: Reactive helper calculating relative time (e.g. "Just now", "2m ago", "1h ago") based on a 15-second timer pulse.

---

## 3. Automation Scripts (`services/scripts/`)

- **`audio_ctl.py`**:
  Standalone Python 3 controller interfacing with PulseAudio / PipeWire via `pactl`.
  - Supports `status` (or `sinks`) and `set-default <sink_name>`.
  - Filters out disconnected physical ports while listing plugged-in headphones, Bluetooth devices, external monitors, and internal speakers.
  - Automatically maps Material Symbols based on device type (`speaker`, `headphones`, `tv`, `bluetooth`, `volume_up`).
  - Outputs single-line JSON directly consumed by `Audio.qml`.

- **`bluetooth_ctl.py`**:
  Standalone Python 3 controller interfacing with `bluetoothctl`.
  - Supports `status`, `scan`, `power on|off`, `connect <mac>`, `disconnect <mac>`, `pair <mac>`, and `remove <mac>`.
  - Parses paired devices, connected devices, device icon types (headphones, speakers, keyboards, mice, phones), and battery levels.
  - Outputs single-line JSON directly consumed by `Bluetooth.qml`.

- **`wifi_scan.py`**:
  A standalone Python 3 script that parses `nmcli -t connection show` and `nmcli -t dev wifi list`.
  - Automatically filters out hidden empty SSIDs (`::`).
  - Deduplicates multiple BSSIDs for the same SSID, keeping the strongest signal.
  - Flags whether each network is `known`, `secure`, and `connected`.
  - Outputs a JSON object `{ "known": [...], "available": [...] }` consumed directly by `Wifi.qml`.
