pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Io

import "../shared"

Singleton {
    id: root

    // Reactive properties
    property bool enabled: true
    property bool connected: false
    property string connectedDeviceName: ""
    property int connectedCount: 0

    readonly property string icon: getIcon()
    readonly property color iconColor: getIconColor()

    // Scanned device lists
    property var pairedDevices: []
    property var availableDevices: []
    property bool scanning: false
    property string connectingMac: ""
    property string lastError: ""

    readonly property string scriptPath: (Quickshell.env("HOME") || "/home/aryan") + "/.config/quickshell/services/scripts/bluetooth_ctl.py"

    function getIcon() {
        if (!root.enabled) {
            return "bluetooth_disabled";
        }
        if (root.connected) {
            return "bluetooth_connected";
        }
        return "bluetooth";
    }

    function getIconColor() {
        if (!root.enabled) {
            return Theme.colors.bg4;
        }
        // if (root.connected) {
        //     return Theme.colors.secondary_accent;
        // }
        return Theme.colors.secondary_accent;
    }

    function recheck() {
        if (!statusProcess.running) {
            statusProcess.running = true;
        }
    }

    function togglePower(turnOn) {
        root.enabled = turnOn;
        if (!turnOn) {
            root.connected = false;
            root.connectedDeviceName = "";
            root.connectedCount = 0;
        }
        if (actionProcess.running) actionProcess.running = false;
        actionProcess.command = [scriptPath, "power", turnOn ? "on" : "off"];
        actionProcess.running = true;
    }

    function scanDevices() {
        if (root.scanning || !root.enabled) return;
        root.scanning = true;
        if (!scanProcess.running) {
            scanProcess.running = true;
        }
    }

    function connectDevice(mac) {
        if (!mac) return;
        root.connectingMac = mac;
        if (actionProcess.running) actionProcess.running = false;
        actionProcess.command = [scriptPath, "connect", mac];
        actionProcess.running = true;
    }

    function disconnectDevice(mac) {
        if (!mac) return;
        root.connectingMac = mac;
        if (actionProcess.running) actionProcess.running = false;
        actionProcess.command = [scriptPath, "disconnect", mac];
        actionProcess.running = true;
    }

    function pairDevice(mac) {
        if (!mac) return;
        root.connectingMac = mac;
        if (actionProcess.running) actionProcess.running = false;
        actionProcess.command = [scriptPath, "pair", mac];
        actionProcess.running = true;
    }

    function forgetDevice(mac) {
        if (!mac) return;
        if (actionProcess.running) actionProcess.running = false;
        actionProcess.command = [scriptPath, "remove", mac];
        actionProcess.running = true;
    }

    // Periodic status polling timer
    Timer {
        id: pollTimer
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.recheck()
    }

    // Status query process
    Process {
        id: statusProcess
        running: true
        command: [root.scriptPath, "status"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    root.enabled = !!parsed.enabled;
                    root.connectedCount = parsed.connected_count || 0;
                    root.connected = (root.connectedCount > 0);
                    root.connectedDeviceName = parsed.primary_device || "";
                    if (parsed.paired !== undefined) root.pairedDevices = parsed.paired;
                    if (parsed.available !== undefined) root.availableDevices = parsed.available;
                } catch(e) {
                    console.warn("Bluetooth status parse error:", e);
                }
            }
        }
    }

    // Scan process (runs 5s discovery)
    Process {
        id: scanProcess
        command: [root.scriptPath, "scan"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    root.enabled = !!parsed.enabled;
                    root.connectedCount = parsed.connected_count || 0;
                    root.connected = (root.connectedCount > 0);
                    root.connectedDeviceName = parsed.primary_device || "";
                    if (parsed.paired !== undefined) root.pairedDevices = parsed.paired;
                    if (parsed.available !== undefined) root.availableDevices = parsed.available;
                } catch(e) {
                    console.warn("Bluetooth scan parse error:", e);
                }
                root.scanning = false;
            }
        }
        onExited: (code, status) => {
            root.scanning = false;
        }
    }

    // Action process (connect, disconnect, pair, remove, power)
    Process {
        id: actionProcess
        stdout: SplitParser {
            onRead: data => {
                try {
                    const res = JSON.parse(data.trim());
                    if (res.error) {
                        root.lastError = res.error;
                    }
                } catch(e) {}
            }
        }
        onExited: (code, status) => {
            root.connectingMac = "";
            root.recheck();
        }
    }
}
