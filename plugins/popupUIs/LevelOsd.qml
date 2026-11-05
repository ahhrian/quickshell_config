import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../../services"
import "../../shared"

PanelWindow {
    id: root

    property var screenModel: null
    property string osdKind: "volume"
    property string osdIcon: "volume_up"
    property string osdLabel: "Volume"
    property real osdLevel: 0
    property real revealProgress: 0
    property bool audioReady: false

    readonly property real contentProgress: Math.max(0, Math.min(1, revealProgress))

    screen: screenModel

    anchors {
        bottom: true
    }

    margins {
        bottom: 105
    }

    implicitWidth: 310
    implicitHeight: 82
    color: BarColors.transparent
    visible: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    function belongsToFocusedMonitor() {
        const focused = Hyprland.focusedMonitor;
        const ownMonitor = screenModel ? Hyprland.monitorFor(screenModel) : null;

        if (focused && ownMonitor)
            return focused.id === ownMonitor.id;

        const screens = Quickshell.screens ?? [];
        return screens.length === 0 || screens[0] === screenModel;
    }

    function showLevel(kind, iconName, label, level) {
        if (!belongsToFocusedMonitor())
            return;

        osdKind = kind;
        osdIcon = iconName;
        osdLabel = label;
        osdLevel = Math.max(0, Math.min(1, level));

        dismissTimer.restart();
        closeAnimation.stop();

        if (!visible) {
            revealProgress = 0;
            visible = true;
        } else {
            openAnimation.restart();
        }
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function() {
                if (root.visible)
                    openAnimation.restart();
            });
        } else {
            openAnimation.stop();
            closeAnimation.stop();
            revealProgress = 0;
        }
    }

    Connections {
        target: Audio

        function onVolumeChanged() {
            if (!root.audioReady || Audio.volumeOsdSuppressed())
                return;

            root.showLevel("volume",
                           Audio.icon,
                           Audio.muted ? "Muted" : "Volume",
                           Audio.muted ? 0 : Audio.volume);
        }

        function onMutedChanged() {
            if (!root.audioReady || Audio.volumeOsdSuppressed())
                return;

            root.showLevel("volume",
                           Audio.icon,
                           Audio.muted ? "Muted" : "Volume",
                           Audio.muted ? 0 : Audio.volume);
        }
    }

    Connections {
        target: Brightness

        function onBrightnessAdjusted(level) {
            root.showLevel("brightness", Brightness.icon, "Brightness", level);
        }
    }

    // Avoid treating PipeWire's initial sink discovery as a user adjustment.
    Timer {
        interval: 1200
        running: true
        repeat: false
        onTriggered: root.audioReady = true
    }

    Timer {
        id: dismissTimer
        interval: 1350
        repeat: false
        onTriggered: closeAnimation.restart()
    }

    NumberAnimation {
        id: openAnimation
        target: root
        property: "revealProgress"
        to: 1
        duration: 230
        easing.type: Easing.OutBack
        easing.overshoot: 0.55
    }

    NumberAnimation {
        id: closeAnimation
        target: root
        property: "revealProgress"
        to: 0
        duration: 170
        easing.type: Easing.InOutCubic
        onFinished: root.visible = false
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        width: 290
        height: 66
        y: 12 * (1 - root.contentProgress)
        scale: 0.94 + 0.06 * root.contentProgress
        opacity: root.contentProgress
        radius: height / 2
        color: BarColors.surfaceBackground
        border.width: 1
        border.color: BarColors.hoverAndBorder

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 18
            spacing: 13

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: BarColors.hoverAndBorder

                Text {
                    anchors.centerIn: parent
                    text: root.osdIcon
                    color: BarColors.primaryText
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 22
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.osdLabel
                        color: BarColors.primaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.osdLabel === "Muted"
                              ? "Muted"
                              : Math.round(root.osdLevel * 100) + "%"
                        color: BarColors.secondaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: BarColors.hoverAndBorder

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * root.osdLevel
                        radius: parent.radius
                        color: Theme.colors.default_accent

                        Behavior on width {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
