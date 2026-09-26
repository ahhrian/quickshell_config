pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Networking
import Quickshell.Io

import "../shared"

Singleton {
    id: root

    // Reactive properties
    property bool enabled: true
    property bool connected: false
    property bool hasInternet: false
    property string ssid: ""
    property int signalStrength: 0 // 0 - 100%
    property real speedMbps: 0.0   // Connection bitrate in Mbps
    property int band: 0           // 1: lowest band, 2: 2nd band, 3: top band, 0: disconnected

    readonly property string bandName: getBandName()
    readonly property string icon: getIcon()
    readonly property color iconColor: getIconColor()

    // Scanned networks list
    property var knownNetworks: []
    property var availableNetworks: []
    property bool scanning: false
    property string connectingSsid: ""
    property string connectError: ""

    // Find the active WiFi device from Quickshell.Networking
    readonly property var wifiDevice: {
        const devs = Networking.devices?.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].networks !== undefined || devs[i].type === 1) {
                return devs[i];
            }
        }
        return null;
    }

    // Find the connected network from Quickshell.Networking
    readonly property var activeNetwork: {
        if (!wifiDevice || !wifiDevice.connected) return null;
        const nets = wifiDevice.networks?.values ?? [];
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].connected) return nets[i];
        }
        return null;
    }

    function calculateBand() {
        if (!root.connected) {
            return 0;
        }
        // Generalized connection speed bands:
        // Top Band (3): >= 100 Mbps (or signal >= 67%)
        // 2nd Band (2): 25 - 100 Mbps (or signal 34% - 66%)
        // Lowest Band (1): < 25 Mbps (or signal 1% - 33%)
        if (root.speedMbps > 0) {
            if (root.speedMbps >= 100) return 3;
            if (root.speedMbps >= 25) return 2;
            return 1;
        }
        if (root.signalStrength >= 67) return 3;
        if (root.signalStrength >= 34) return 2;
        return 1;
    }

    function getBandName() {
        switch (root.band) {
            case 3: return "Top Band (Fast)";
            case 2: return "2nd Band (Medium)";
            case 1: return "Lowest Band (Low)";
            default: return "Disconnected";
        }
    }

    function getIcon() {
        // 1. No network connected or Wi-Fi disabled
        if (!root.enabled || !root.connected) {
            return "android_wifi_4_bar_off";
        }
        // 2. Network connected but no internet connection
        if (!root.hasInternet) {
            return "android_wifi_3_bar_alert";
        }
        // 3. Connection speed bands
        if (root.band === 3) {
            return "android_wifi_4_bar";
        }
        if (root.band === 2) {
            return "android_wifi_3_bar";
        }
        return "wifi_2_bar";
    }

    function getIconColor() {
        if (!root.enabled || !root.connected) {
            return Theme.colors.bg4;
        }
        if (!root.hasInternet) {
            return Theme.colors.red;
        }
        return Theme.colors.secondary_accent;
    }

    function updateState(newConnected, newSsid, newSignal, newSpeed, newInternet, newEnabled) {
        if (newEnabled !== undefined) root.enabled = newEnabled;
        if (newConnected !== undefined) root.connected = newConnected;
        if (newSsid !== undefined) root.ssid = newSsid;
        if (newSignal !== undefined) root.signalStrength = newSignal;
        if (newSpeed !== undefined) root.speedMbps = newSpeed;
        if (newInternet !== undefined) root.hasInternet = newInternet;

        root.band = calculateBand();
    }

    // Process to query link speed bitrate, signal, and connectivity
    Process {
        id: wifiQueryProcess
        running: true
        command: [
            "bash",
            "-c",
            "RADIO=$(nmcli radio wifi 2>/dev/null); " +
            "IFACE=$(iw dev 2>/dev/null | awk '$1==\"Interface\"{print $2; exit}'); " +
            "LINK=$([ -n \"$IFACE\" ] && iw dev \"$IFACE\" link 2>/dev/null); " +
            "SSID=$(echo \"$LINK\" | awk '$1==\"SSID:\"{print $2}'); " +
            "SIG=$(echo \"$LINK\" | awk '$1==\"signal:\"{print $2}'); " +
            "RATE=$(echo \"$LINK\" | grep -E '(rx|tx) bitrate' | head -n 1 | awk '{print $3}'); " +
            "CONN=$(nmcli networking connectivity 2>/dev/null); " +
            "echo \"RADIO=$RADIO;SSID=$SSID;SIG=$SIG;RATE=$RATE;CONN=$CONN\""
        ]
        stdout: SplitParser {
            onRead: data => {
                let radioVal = "enabled";
                let ssidVal = "";
                let sigDbm = NaN;
                let rateMbps = 0.0;
                let connVal = "";

                const parts = data.trim().split(";");
                for (let i = 0; i < parts.length; i++) {
                    const kv = parts[i].split("=");
                    if (kv.length === 2) {
                        const k = kv[0];
                        const v = kv[1];
                        if (k === "RADIO") radioVal = v;
                        else if (k === "SSID") ssidVal = v;
                        else if (k === "SIG") sigDbm = parseFloat(v);
                        else if (k === "RATE") rateMbps = parseFloat(v) || 0.0;
                        else if (k === "CONN") connVal = v;
                    }
                }

                const isEnabled = (radioVal === "enabled");
                const isConnected = isEnabled && (ssidVal !== "");
                let signalPct = 0;
                if (!isNaN(sigDbm)) {
                    signalPct = Math.max(0, Math.min(100, Math.round(2 * (sigDbm + 100))));
                } else if (root.activeNetwork) {
                    signalPct = Math.round((root.activeNetwork.signalStrength || 0) * 100);
                }

                const isInternet = (connVal === "full") || (Networking.connectivity === NetworkConnectivity.Full);

                root.updateState(isConnected, ssidVal, signalPct, rateMbps, isInternet, isEnabled);
            }
        }
    }

    // Process to scan networks and parse JSON
    Process {
        id: scanProcess
        command: ["/home/aryan/.config/quickshell/services/scripts/wifi_scan.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    if (parsed.known) root.knownNetworks = parsed.known;
                    if (parsed.available) root.availableNetworks = parsed.available;
                } catch(e) {
                    console.warn("Scan parse error:", e);
                }
                root.scanning = false;
            }
        }
        onExited: (code, status) => {
            root.scanning = false;
        }
    }

    // Process to toggle Wi-Fi radio
    Process {
        id: toggleProcess
        onExited: (code, status) => {
            root.recheck();
            if (root.enabled) {
                root.scanNetworks();
            }
        }
    }

    // Process to connect / disconnect / forget
    Process {
        id: actionProcess
        stdout: SplitParser {
            onRead: data => {
                console.warn("Action output:", data);
            }
        }
        stderr: SplitParser {
            onRead: data => {
                console.warn("Action error:", data);
                root.connectError = data;
            }
        }
        onExited: (code, status) => {
            root.connectingSsid = "";
            root.recheck();
            root.scanNetworks();
        }
    }

    // Action Methods
    function toggleWifi() {
        const next = !root.enabled;
        root.enabled = next;
        Networking.wifiEnabled = next;
        toggleProcess.command = ["nmcli", "radio", "wifi", next ? "on" : "off"];
        toggleProcess.running = true;
    }

    function scanNetworks() {
        if (!root.enabled || root.scanning) return;
        root.scanning = true;
        scanProcess.running = true;
    }

    function connectToNetwork(targetSsid, password) {
        if (!targetSsid) return;
        root.connectingSsid = targetSsid;
        root.connectError = "";

        let cmd = ["nmcli", "dev", "wifi", "connect", targetSsid];
        if (password && password.trim() !== "") {
            cmd.push("password");
            cmd.push(password.trim());
        }
        actionProcess.command = cmd;
        actionProcess.running = true;
    }

    function disconnectNetwork(targetSsid) {
        root.connectingSsid = targetSsid || root.ssid;
        actionProcess.command = ["bash", "-c", "nmcli connection down id \"" + (targetSsid || root.ssid) + "\" 2>/dev/null || nmcli dev disconnect iface $(iw dev 2>/dev/null | awk '$1==\"Interface\"{print $2; exit}')"];
        actionProcess.running = true;
    }

    function forgetNetwork(targetSsid) {
        if (!targetSsid) return;
        actionProcess.command = ["nmcli", "connection", "delete", "id", targetSsid];
        actionProcess.running = true;
    }

    function openHiddenNetworkDialog() {
        // Launch GNOME Wi-Fi Settings or NM connection editor
        Quickshell.execDetached(["bash", "-c", "gnome-control-center wifi 2>/dev/null || nm-connection-editor --create --type=802-11-wireless"]);
    }

    // React to Quickshell.Networking signals
    Connections {
        target: Networking
        function onConnectivityChanged() {
            root.recheck();
        }
        function onWifiEnabledChanged() {
            root.enabled = Networking.wifiEnabled;
            root.recheck();
            if (root.enabled) root.scanNetworks();
        }
    }

    // Periodic check to keep link speed, signal, and connection fresh
    Timer {
        id: pollTimer
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            wifiQueryProcess.running = true;
        }
    }

    function recheck() {
        wifiQueryProcess.running = true;
    }
}
