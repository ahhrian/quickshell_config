pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string deviceName: ""
    property int rawBrightness: 0
    property int maximumBrightness: 1
    property bool initialized: false

    readonly property string brightnessPath: deviceName.length > 0
                                                    ? "/sys/class/backlight/" + deviceName + "/brightness"
                                                    : "/dev/null"
    readonly property real level: maximumBrightness > 0
                                          ? Math.max(0, Math.min(1, rawBrightness / maximumBrightness))
                                          : 0
    readonly property int percent: Math.round(level * 100)
    readonly property string icon: percent >= 67
                                           ? "brightness_high"
                                           : (percent >= 34 ? "brightness_medium" : "brightness_low")

    signal brightnessAdjusted(real level)

    function applyDiscovery(output) {
        const lines = output.trim().split("\n");
        let selected = null;

        for (const line of lines) {
            const fields = line.trim().split(",");
            if (fields.length < 5)
                continue;

            if (!selected || fields[1] === "backlight")
                selected = fields;
            if (fields[1] === "backlight")
                break;
        }

        if (!selected)
            return;

        const current = parseInt(selected[2], 10);
        const maximum = parseInt(selected[4], 10);
        if (!isFinite(current) || !isFinite(maximum) || maximum <= 0)
            return;

        deviceName = selected[0];
        maximumBrightness = maximum;
        rawBrightness = current;
        initialized = true;
    }

    function consumeBrightness(contents) {
        const nextValue = parseInt(contents.trim(), 10);
        if (!isFinite(nextValue))
            return;

        const shouldNotify = initialized && nextValue !== rawBrightness;
        rawBrightness = nextValue;

        if (!initialized) {
            initialized = true;
            return;
        }

        if (shouldNotify)
            brightnessAdjusted(level);
    }

    Process {
        id: discoveryProcess
        running: true
        command: ["brightnessctl", "-m"]

        stdout: StdioCollector {
            onStreamFinished: root.applyDiscovery(text)
        }
    }

    FileView {
        id: brightnessFile
        path: root.brightnessPath
        preload: true
        blockLoading: true
        printErrors: false
        watchChanges: true

        onLoaded: root.consumeBrightness(text())
        onTextChanged: root.consumeBrightness(text())
        onFileChanged: reload()
    }

    // QFileSystemWatcher normally reports sysfs changes immediately. This
    // inexpensive fallback read covers drivers that do not emit file events.
    Timer {
        interval: 500
        running: root.deviceName.length > 0
        repeat: true
        onTriggered: brightnessFile.reload()
    }
}
