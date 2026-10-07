import QtQuick
import QtQuick.Layouts

import "../../../services"
import "../../../shared"
import "../widget_gui"

Rectangle {
    id: root

    property var barWindow: null

    implicitWidth: 33
    implicitHeight: 33
    radius: height / 2

    color: mouseArea.containsMouse || (volumeDropdown && volumeDropdown.visible) ? "#343434" : "#303030"

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    readonly property real currentVolume: Audio.volume
    property real animatedVolume: currentVolume

    Behavior on animatedVolume {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    onAnimatedVolumeChanged: canvas.requestPaint()

    Connections {
        target: Audio
        function onMutedChanged() { canvas.requestPaint(); }
        function onVolumeChanged() { canvas.requestPaint(); }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const w = width;
            const h = height;
            const cx = w / 2;
            const cy = h / 2;
            const strokeWidth = 2.5;
            const radius = (Math.min(w, h) - strokeWidth) / 2 - 1.0;

            // Full 360 degree background track ring along the edge of the circular pill
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.strokeStyle = "#3d3d3d";
            ctx.lineWidth = strokeWidth;
            ctx.stroke();

            // Filled progress ring starting from top-middle and sweeping symmetrically in both directions
            const fraction = Math.max(0.0, Math.min(1.0, root.animatedVolume));
            if (fraction > 0) {
                ctx.beginPath();
                if (fraction >= 0.999) {
                    ctx.arc(cx, cy, radius, 0, Math.PI * 2, false);
                } else {
                    const topAngle = -Math.PI / 2; // Top-middle (12 o'clock)
                    const halfSweep = fraction * Math.PI; // At 50%, halfSweep is 90 deg -> 180 deg semicircle
                    ctx.arc(cx, cy, radius, topAngle - halfSweep, topAngle + halfSweep, false);
                }
                ctx.strokeStyle = Audio.muted ? "rgba(232,232,232,0.4)" : "#e8e8e8";
                ctx.lineWidth = strokeWidth;
                ctx.lineCap = "round";
                ctx.stroke();
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: Audio.icon
        color: Audio.muted ? "#909090" : "#e8e8e8"
        font.family: "Material Symbols Rounded"
        font.pixelSize: 16

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    VolumeGui {
        id: volumeDropdown
        barWindow: root.barWindow
        anchorItem: root
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Audio.toggleMute();
            } else {
                volumeDropdown.visible = !volumeDropdown.visible;
            }
        }

        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                Audio.setVolume(Audio.volume + 0.05);
            } else if (wheel.angleDelta.y < 0) {
                Audio.setVolume(Audio.volume - 0.05);
            }
        }
    }
}
