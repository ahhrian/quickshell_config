import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

import "../../../services"
import "../../../shared"

LeftExpandingPopup {
    id: root

    targetWidth: 350
    maximumHeight: 520
    targetHeight: Math.min(card.implicitHeight, maximumHeight)
    borderColor: BarColors.hoverAndBorder

    onAboutToOpen: {
        if (visible) {
            Audio.recheck();
        }
    }

    Item {
        id: card
        anchors.fill: parent

        implicitHeight: contentColumn.implicitHeight + 32

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // ==================== 1. HEADER ====================
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Master Volume Icon Badge
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: BarColors.surfaceBackground

                    Text {
                        anchors.centerIn: parent
                        text: Audio.icon
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: Audio.muted ? Theme.colors.red : Theme.colors.default_accent

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMute()
                    }
                }

                // Title and Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Volume Control"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: BarColors.primaryText
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (Audio.muted) return "Sound is muted";
                            for (let i = 0; i < Audio.sinks.length; i++) {
                                if (Audio.sinks[i].is_default && Audio.sinks[i].display_name && Audio.sinks[i].display_name !== "(null)") {
                                    return Audio.sinks[i].display_name;
                                }
                            }
                            return "Output Device";
                        }
                        font.pixelSize: 11
                        color: Audio.muted ? Theme.colors.red : BarColors.secondaryText
                        elide: Text.ElideRight
                    }
                }

                // Mute Toggle Button
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    color: muteBtnMouse.containsMouse ? BarColors.hoverAndBorder : BarColors.surfaceBackground
                    border.width: 1
                    border.color: Audio.muted ? Theme.colors.red : BarColors.hoverAndBorder

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: Audio.muted ? "volume_off" : "volume_up"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 17
                        color: Audio.muted ? Theme.colors.red : BarColors.primaryText
                    }

                    MouseArea {
                        id: muteBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMute()
                    }
                }
            }

            // ==================== 2. MASTER VOLUME SLIDER ====================
            Rectangle {
                id: sliderContainer
                Layout.fillWidth: true
                implicitHeight: 46
                radius: 12
                color: BarColors.surfaceBackground
                border.width: 1
                border.color: BarColors.hoverAndBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    // Left speaker icon (quick mute toggle)
                    Text {
                        text: Audio.icon
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: Audio.muted ? Theme.colors.red : Theme.colors.default_accent

                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Audio.toggleMute()
                        }
                    }

                    // Slider Track
                    Item {
                        id: track
                        Layout.fillWidth: true
                        implicitHeight: 24

                        Rectangle {
                            id: trackBg
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 6
                            radius: 3
                            color: BarColors.hoverAndBorder

                            // Filled Progress Track
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(0, Math.min(trackBg.width, trackBg.width * Audio.volume))
                                radius: 3
                                color: Audio.muted ? Theme.colors.red : Theme.colors.default_accent

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        // Slider Thumb
                        Rectangle {
                            id: thumb
                            width: 16
                            height: 16
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(track.width - width, (track.width * Audio.volume) - (width / 2)))
                            color: BarColors.primaryText
                            border.width: 2
                            border.color: Audio.muted ? Theme.colors.red : Theme.colors.default_accent

                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: sliderArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton

                            function updateVolume(mouseX) {
                                const frac = Math.max(0.0, Math.min(1.0, mouseX / track.width));
                                Audio.setVolume(frac);
                            }

                            onPressed: (mouse) => updateVolume(mouse.x)
                            onPositionChanged: (mouse) => {
                                if (mouse.buttons & Qt.LeftButton) {
                                    updateVolume(mouse.x);
                                }
                            }
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    Audio.setVolume(Audio.volume + 0.05);
                                } else if (wheel.angleDelta.y < 0) {
                                    Audio.setVolume(Audio.volume - 0.05);
                                }
                            }
                        }
                    }

                    // Percentage Text
                    Text {
                        text: Audio.muted ? "Muted" : (Audio.volumePercent + "%")
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Audio.muted ? Theme.colors.red : BarColors.primaryText
                        Layout.minimumWidth: 42
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // ==================== 3. SEPARATOR ====================
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: BarColors.hoverAndBorder
            }

            // ==================== 4. OUTPUT DEVICES SECTION ====================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "OUTPUT DEVICE"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: BarColors.secondaryText
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: refreshMouse.containsMouse ? BarColors.surfaceBackground : BarColors.transparent

                    Text {
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 15
                        color: BarColors.secondaryText
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.recheck()
                    }
                }
            }

            // Sinks List Container with scrolling
            Flickable {
                id: sinksFlickable
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(sinksColumn.implicitHeight, 280)
                implicitHeight: Layout.preferredHeight
                contentHeight: sinksColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    target: sinksFlickable
                    onWheel: (event) => {
                        sinksFlickable.contentY = Math.max(0, Math.min(sinksFlickable.contentHeight - sinksFlickable.height, sinksFlickable.contentY - event.angleDelta.y));
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    parent: sinksFlickable
                    anchors.top: sinksFlickable.top
                    anchors.bottom: sinksFlickable.bottom
                    anchors.right: sinksFlickable.right
                    anchors.rightMargin: 1
                    policy: sinksFlickable.contentHeight > sinksFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 1.5
                        color: BarColors.hoverAndBorder
                    }
                }

                ColumnLayout {
                    id: sinksColumn
                    width: sinksFlickable.width
                    spacing: 6

                    Repeater {
                        model: (Audio.sinks || []).filter(s => s && s.display_name && s.display_name !== "(null)" && s.display_name.toLowerCase() !== "null" && s.display_name.trim() !== "")

                        Rectangle {
                            id: sinkItem
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 52
                            radius: 12
                            color: itemMouseArea.containsMouse ? BarColors.surfaceBackground : (modelData.is_default ? BarColors.surfaceBackground : BarColors.transparent)
                            border.width: 1
                            border.color: modelData.is_default ? Theme.colors.default_accent: (itemMouseArea.containsMouse ? BarColors.hoverAndBorder : BarColors.transparent)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                // Device Icon Badge
                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: modelData.is_default ? BarColors.hoverAndBorder : BarColors.surfaceBackground

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon || "volume_up"
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 18
                                        color: modelData.is_default ? Theme.colors.default_accent: BarColors.primaryText
                                    }
                                }

                                // Device Name & Description
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.display_name || "Audio Device"
                                        font.pixelSize: 13
                                        font.weight: modelData.is_default ? Font.DemiBold : Font.Normal
                                        color: BarColors.primaryText
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.is_default ? "Active Output" : (modelData.description || "Output Device")
                                        font.pixelSize: 11
                                        color: modelData.is_default ? Theme.colors.default_accent: BarColors.secondaryText
                                        elide: Text.ElideRight
                                    }
                                }

                                // Selection Checkmark / Radio
                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: modelData.is_default ? Theme.colors.default_accent: BarColors.transparent
                                    border.width: modelData.is_default ? 0 : 1.5
                                    border.color: itemMouseArea.containsMouse ? BarColors.secondaryText : BarColors.hoverAndBorder

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: modelData.is_default
                                        text: "check"
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 15
                                        color: BarColors.textOnAccent
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            MouseArea {
                                id: itemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Audio.setDefaultSink(modelData.name);
                                }
                                onWheel: (wheel) => {
                                    sinksFlickable.contentY = Math.max(0, Math.min(sinksFlickable.contentHeight - sinksFlickable.height, sinksFlickable.contentY - wheel.angleDelta.y));
                                }
                            }
                        }
                    }

                    // Fallback if no sinks
                    Rectangle {
                        visible: !Audio.sinks || (Audio.sinks || []).filter(s => s && s.display_name && s.display_name !== "(null)" && s.display_name.toLowerCase() !== "null" && s.display_name.trim() !== "").length === 0
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 10
                        color: BarColors.surfaceBackground

                        Text {
                            anchors.centerIn: parent
                            text: "No output devices found"
                            font.pixelSize: 12
                            color: BarColors.secondaryText
                        }
                    }

                    // Helpful hint when only one sink is available
                    RowLayout {
                        visible: Audio.sinks && (Audio.sinks || []).filter(s => s && s.display_name && s.display_name !== "(null)" && s.display_name.toLowerCase() !== "null" && s.display_name.trim() !== "").length === 1
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 6

                        Text {
                            text: "info"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 14
                            color: BarColors.secondaryText
                        }

                        Text {
                            text: "Connect headphones, Bluetooth, or HDMI to switch"
                            font.pixelSize: 11
                            font.italic: true
                            color: BarColors.secondaryText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
