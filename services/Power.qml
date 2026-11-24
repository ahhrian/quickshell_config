pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Services.UPower

import "../shared"

Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property int percentage: device ? Math.round(device.percentage * 100) : 0
    readonly property string battery: device ? percentage + "%" : "N.A"
    readonly property bool pluggedIn: !UPower.onBattery
    readonly property bool activelyCharging: device ? (
        device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.PendingCharge
    ) : false
    readonly property bool isCharging: activelyCharging || (device ? (
        pluggedIn && device.state === UPowerDeviceState.FullyCharged
    ) : false)
    readonly property string icon: iconName()
    readonly property color color: getColor()
    readonly property string estimateText: formatEstimate()

    readonly property color red_indicator: Theme.colors.red
    readonly property color yellow_indicator: Theme.colors.yellow
    readonly property color default_color: BarColors.primaryText

    readonly property int activePowerProfile: PowerProfiles.profile
    readonly property string powerProfileId: profileId(activePowerProfile)
    readonly property var powerModes: [
        {
            id: "power-saver",
            label: "Efficiency",
            description: "Longest battery life",
            icon: "energy_savings_leaf",
            available: true
        },
        {
            id: "balanced",
            label: "Balanced",
            description: "Everyday performance",
            icon: "balance",
            available: true
        },
        {
            id: "performance",
            label: "Performance",
            description: "Maximum speed",
            icon: "speed",
            available: PowerProfiles.hasPerformanceProfile
        }
    ]

    property bool chargeLimitSupported: false
    property string chargeLimitMode: "unsupported"
    property int chargeLimit: 100
    property var chargeLimitPresets: []
    property string chargeLimitDetail: "Checking charge-limit support…"
    property string activeChargeType: ""
    property bool chargeLimitBusy: false
    property string chargeLimitError: ""

    readonly property string scriptPath: (Quickshell.env("HOME") || "/home/aryan")
                                         + "/.config/quickshell/services/scripts/power_ctl.py"

    function iconName() {
        if (!device)
            return "battery_unknown";

        const charge = percentage;
        if (isCharging) {
            if (charge >= 95 || device.state === UPowerDeviceState.FullyCharged)
                return "battery_charging_full";
            if (charge >= 85)
                return "battery_charging_90";
            if (charge >= 70)
                return "battery_charging_80";
            if (charge >= 55)
                return "battery_charging_60";
            if (charge >= 40)
                return "battery_charging_50";
            if (charge >= 25)
                return "battery_charging_30";
            return "battery_charging_20";
        }

        const level = Math.floor((charge - 1) / 15) + 1;
        if (charge > 90)
            return "battery_full";
        if (charge < 15)
            return "battery_alert";
        return "battery_" + level + "_bar";
    }

    function getColor() {
        if (device) {
            if (percentage < 15)
                return red_indicator;
            if (percentage <= 30)
                return yellow_indicator;
        }
        return default_color;
    }

    function profileId(profile) {
        if (profile === PowerProfile.PowerSaver)
            return "power-saver";
        if (profile === PowerProfile.Performance)
            return "performance";
        return "balanced";
    }

    function setPowerProfile(profile) {
        if (profile === "power-saver")
            PowerProfiles.profile = PowerProfile.PowerSaver;
        else if (profile === "balanced")
            PowerProfiles.profile = PowerProfile.Balanced;
        else if (profile === "performance" && PowerProfiles.hasPerformanceProfile)
            PowerProfiles.profile = PowerProfile.Performance;
    }

    function estimateSeconds() {
        if (!device)
            return -1;

        const rate = Math.abs(device.changeRate || 0);
        if (activelyCharging) {
            const target = chargeLimitSupported ? chargeLimit : 100;
            if (percentage >= target)
                return 0;

            if (target >= 100 && device.timeToFull > 0)
                return device.timeToFull;
            if (device.energyCapacity > 0 && rate > 0)
                return device.energyCapacity * ((target - percentage) / 100) / rate * 3600;
            if (device.timeToFull > 0 && percentage < 100)
                return device.timeToFull * ((target - percentage) / (100 - percentage));
            return -1;
        }

        if (!pluggedIn || device.state === UPowerDeviceState.Discharging
                || device.state === UPowerDeviceState.PendingDischarge) {
            if (device.timeToEmpty > 0)
                return device.timeToEmpty;
            if (device.energy > 0 && rate > 0)
                return device.energy / rate * 3600;
        }
        return -1;
    }

    function formatDuration(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "Estimating…";
        if (seconds < 60)
            return "Less than a minute";

        const totalMinutes = Math.max(1, Math.round(seconds / 60));
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        if (hours <= 0)
            return minutes + " min";
        if (minutes === 0)
            return hours + " h";
        return hours + " h " + minutes + " min";
    }

    function formatEstimate() {
        if (!device)
            return "Battery information unavailable";

        const target = chargeLimitSupported ? chargeLimit : 100;
        if (activelyCharging) {
            if (percentage >= target)
                return target < 100 ? "At the " + target + "% charge limit" : "Fully charged";
            return formatDuration(estimateSeconds()) + " to " + target + "%";
        }
        if (pluggedIn) {
            if (target < 100 && percentage >= target)
                return "At the " + target + "% charge limit";
            if (device.state === UPowerDeviceState.FullyCharged)
                return "Fully charged";
            return "Plugged in";
        }
        return formatDuration(estimateSeconds()) + " remaining";
    }

    function applyChargeStatus(parsed) {
        if (parsed.error) {
            chargeLimitError = parsed.error;
            return;
        }

        chargeLimitSupported = !!parsed.supported;
        chargeLimitMode = parsed.mode || "unsupported";
        chargeLimit = parsed.current_limit === undefined ? 100 : parsed.current_limit;
        chargeLimitPresets = parsed.presets || [];
        chargeLimitDetail = parsed.detail || "";
        activeChargeType = parsed.active_type || "";
        chargeLimitError = "";
    }

    function recheckChargeLimit() {
        if (!chargeStatusProcess.running)
            chargeStatusProcess.running = true;
    }

    function setChargeLimit(limit) {
        if (!chargeLimitSupported || chargeLimitBusy)
            return;
        if (chargeLimitPresets.indexOf(limit) === -1)
            return;

        chargeLimitError = "";
        chargeLimitBusy = true;
        chargeActionReceivedOutput = false;
        chargeActionProcess.command = ["pkexec", "/usr/bin/python3", root.scriptPath,
                                       "set-limit", String(limit)];
        chargeActionProcess.running = true;
    }

    property bool chargeActionReceivedOutput: false

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.recheckChargeLimit()
    }

    Process {
        id: chargeStatusProcess
        command: ["/usr/bin/python3", root.scriptPath, "status"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.applyChargeStatus(JSON.parse(data.trim()));
                } catch (error) {
                    root.chargeLimitError = "Could not read the battery charge limit.";
                    console.warn("Power charge-limit status parse error:", error);
                }
            }
        }
    }

    Process {
        id: chargeActionProcess
        stdout: SplitParser {
            onRead: data => {
                root.chargeActionReceivedOutput = true;
                try {
                    root.applyChargeStatus(JSON.parse(data.trim()));
                } catch (error) {
                    root.chargeLimitError = "Could not apply the battery charge limit.";
                    console.warn("Power charge-limit action parse error:", error);
                }
            }
        }
        onExited: (code, status) => {
            root.chargeLimitBusy = false;
            if (code !== 0 && !root.chargeActionReceivedOutput)
                root.chargeLimitError = "Authentication was cancelled or the charge limit could not be changed.";
            root.recheckChargeLimit();
        }
    }
}
