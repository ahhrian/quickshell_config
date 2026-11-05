pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

import "../shared"

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNodeAudio audio: sink ? sink.audio : null

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    readonly property real volume: audio ? audio.volume : 0.0
    readonly property int volumePercent: Math.round(volume * 100)
    readonly property bool muted: audio ? audio.muted : false

    readonly property string icon: getIcon()

    // Track every open volume popup rather than a single boolean because the
    // bar creates one VolumeGui instance per screen.
    property var volumeGuiOwners: []
    property double uiVolumeChangeDeadline: 0
    readonly property bool volumeGuiActive: volumeGuiOwners.length > 0

    // Output Sinks
    property var sinks: []
    property var allSinks: []
    property string defaultSinkName: ""

    readonly property string scriptPath: (Quickshell.env("HOME") || "/home/aryan") + "/.config/quickshell/services/scripts/audio_ctl.py"

    onSinkChanged: {
        root.recheck();
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() {
            root.recheck();
        }
    }

    Connections {
        target: typeof Bluetooth !== "undefined" ? Bluetooth : null
        function onConnectedChanged() { root.recheck(); }
        function onConnectedCountChanged() { root.recheck(); }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.recheck()
    }

    function getIcon() {
        if (muted) {
            return "volume_off";
        }
        if (volumePercent <= 0) {
            return "volume_mute";
        }
        if (volumePercent > 40) {
            return "volume_up";
        }
        return "volume_down";
    }

    function setVolume(newVolume) {
        if (audio) {
            markUiVolumeChange();
            audio.volume = Math.max(0.0, Math.min(1.0, newVolume));
        }
    }

    function toggleMute() {
        if (audio) {
            markUiVolumeChange();
            audio.muted = !audio.muted;
        }
    }

    function setVolumeGuiActive(owner, active) {
        const owners = volumeGuiOwners.slice();
        const index = owners.indexOf(owner);

        if (active && index === -1)
            owners.push(owner);
        else if (!active && index !== -1)
            owners.splice(index, 1);
        else
            return;

        volumeGuiOwners = owners;
    }

    function markUiVolumeChange() {
        // PipeWire may publish the result shortly after the QML assignment.
        uiVolumeChangeDeadline = Date.now() + 1000;
    }

    function volumeOsdSuppressed() {
        return volumeGuiActive || Date.now() < uiVolumeChangeDeadline;
    }

    function recheck() {
        if (!statusProcess.running) {
            statusProcess.running = true;
        }
    }

    function setDefaultSink(sinkName) {
        if (!sinkName) return;
        if (actionProcess.running) actionProcess.running = false;
        actionProcess.command = [root.scriptPath, "set-default", sinkName];
        actionProcess.running = true;
    }

    // Process for fetching sinks
    Process {
        id: statusProcess
        running: true
        command: [root.scriptPath, "status"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    if (parsed.default_sink !== undefined) {
                        root.defaultSinkName = parsed.default_sink;
                    }
                    if (parsed.sinks !== undefined) {
                        root.sinks = parsed.sinks;
                    }
                    if (parsed.all_sinks !== undefined) {
                        root.allSinks = parsed.all_sinks;
                    }
                } catch(e) {
                    console.warn("Audio status parse error:", e);
                }
            }
        }
    }

    // Process for setting default sink
    Process {
        id: actionProcess
        stdout: SplitParser {
            onRead: data => {
                // Action complete
            }
        }
        onExited: (code, status) => {
            root.recheck();
        }
    }
}
