import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import "../../../services"
import "../../../shared"

LeftExpandingPopup {
    id: root

    targetWidth: 380
    maximumHeight: 540
    targetHeight: Math.min(card.implicitHeight, maximumHeight)
    borderColor: BarColors.hoverAndBorder

    property string expandedMac: ""

    onAboutToOpen: {
        if (visible) {
            expandedMac = "";
            Bluetooth.recheck();
            Bluetooth.scanDevices();
        }
    }

    function getDeviceMaterialIcon(iconType) {
        switch (iconType) {
            case "headphones": return "headphones";
            case "speaker": return "speaker";
            case "keyboard": return "keyboard";
            case "mouse": return "mouse";
            case "smartphone": return "smartphone";
            case "computer": return "computer";
            default: return "bluetooth";
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
            spacing: 12

            // ==================== 1. HEADER ====================
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Bluetooth Status Icon
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: BarColors.surfaceBackground

                    Text {
                        anchors.centerIn: parent
                        text: Bluetooth.icon
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: Bluetooth.iconColor
                    }
                }

                // Status & Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: {
                            if (!Bluetooth.enabled) return "Bluetooth Disabled";
                            if (Bluetooth.connected) {
                                return Bluetooth.connectedDeviceName || (Bluetooth.connectedCount + " Device" + (Bluetooth.connectedCount > 1 ? "s" : "") + " Connected");
                            }
                            return "Not Connected";
                        }
                        font.family: "SF Pro Display"
                        font.bold: true
                        font.pixelSize: 16
                        color: BarColors.primaryText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: {
                            if (!Bluetooth.enabled) return "Turn on to view devices";
                            if (Bluetooth.connected) {
                                let sub = "Connected";
                                if (Bluetooth.connectedCount > 1) sub += " • " + Bluetooth.connectedCount + " active";
                                return sub;
                            }
                            return Bluetooth.scanning ? "Scanning for devices..." : "Select a device below";
                        }
                        font.family: "SF Pro Display"
                        font.pixelSize: 12
                        color: BarColors.primaryText
                        opacity: 0.65
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Rescan Button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: rescanMouse.containsMouse ? BarColors.hoverAndBorder : BarColors.transparent
                    visible: Bluetooth.enabled

                    Text {
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: BarColors.primaryText
                        opacity: Bluetooth.scanning ? 0.4 : 0.8
                    }

                    MouseArea {
                        id: rescanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bluetooth.scanDevices()
                    }
                }

                // Toggle Switch (ON / OFF)
                Rectangle {
                    id: toggleSwitch
                    width: 46
                    height: 24
                    radius: 12
                    color: Bluetooth.enabled ? Theme.colors.default_accent : BarColors.hoverAndBorder

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    Rectangle {
                        id: toggleThumb
                        width: 20
                        height: 20
                        radius: 10
                        color: BarColors.primaryText
                        y: 2
                        x: Bluetooth.enabled ? 24 : 2

                        Behavior on x {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bluetooth.togglePower(!Bluetooth.enabled)
                    }
                }
            }

            // ==================== 2. LINE SEPARATOR ====================
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: BarColors.hoverAndBorder
            }

            // ==================== 3. DISABLED PLACEHOLDER ====================
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                visible: !Bluetooth.enabled

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "bluetooth_disabled"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 32
                        color: BarColors.secondaryText
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Bluetooth is turned off"
                        font.family: "SF Pro Display"
                        font.pixelSize: 14
                        color: BarColors.primaryText
                        opacity: 0.7
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 100
                        height: 28
                        radius: 14
                        color: Theme.colors.default_accent

                        Text {
                            anchors.centerIn: parent
                            text: "Turn On"
                            font.family: "SF Pro Display"
                            font.bold: true
                            font.pixelSize: 12
                            color: BarColors.textOnAccent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Bluetooth.togglePower(true)
                        }
                    }
                }
            }

            // ==================== 4. DEVICE LIST CONTAINER ====================
            Flickable {
                id: flickable
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(devicesColumn.implicitHeight, 400)
                contentHeight: devicesColumn.implicitHeight
                clip: true
                visible: Bluetooth.enabled
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    target: flickable
                    onWheel: (event) => {
                        flickable.contentY = Math.max(0, Math.min(flickable.contentHeight - flickable.height, flickable.contentY - event.angleDelta.y));
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    parent: flickable
                    anchors.top: flickable.top
                    anchors.bottom: flickable.bottom
                    anchors.right: flickable.right
                    anchors.rightMargin: 1
                    policy: flickable.contentHeight > flickable.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 1.5
                        color: BarColors.hoverAndBorder
                    }
                }

                ColumnLayout {
                    id: devicesColumn
                    width: flickable.width
                    spacing: 14

                    // ---------- SECTION: PAIRED DEVICES ----------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: Bluetooth.pairedDevices.length > 0

                        Text {
                            text: "PAIRED DEVICES (" + Bluetooth.pairedDevices.length + ")"
                            font.family: "SF Pro Display"
                            font.bold: true
                            font.pixelSize: 11
                            color: BarColors.secondaryText
                            Layout.leftMargin: 4
                        }

                        Repeater {
                            model: Bluetooth.pairedDevices

                            delegate: Rectangle {
                                id: pairedCard
                                Layout.fillWidth: true
                                radius: 10
                                color: modelData.connected ? BarColors.surfaceBackground : (pairedMouse.containsMouse ? BarColors.surfaceBackground : BarColors.transparent)
                                border.width: modelData.connected ? 1 : 0
                                border.color: Theme.colors.default_accent

                                readonly property bool isExpanded: (root.expandedMac === modelData.mac)

                                implicitHeight: isExpanded ? (expandedColumn.implicitHeight + 16) : 48

                                Behavior on implicitHeight {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }

                                ColumnLayout {
                                    id: expandedColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: pairedCard.isExpanded ? parent.top : undefined
                                    anchors.verticalCenter: pairedCard.isExpanded ? undefined : parent.verticalCenter
                                    anchors.topMargin: pairedCard.isExpanded ? 8 : 0
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Main Row (Collapsed)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 10

                                        Text {
                                            text: root.getDeviceMaterialIcon(modelData.icon)
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 20
                                            color: modelData.connected ? Theme.colors.default_accent : BarColors.primaryText
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2

                                            Text {
                                                text: modelData.name || modelData.mac
                                                font.family: "SF Pro Display"
                                                font.bold: modelData.connected
                                                font.pixelSize: 13
                                                color: BarColors.primaryText
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: {
                                                    if (modelData.connected) {
                                                        let s = "Connected";
                                                        if (modelData.battery !== null && modelData.battery !== undefined) {
                                                            s += " • " + modelData.battery + "% battery";
                                                        }
                                                        return s;
                                                    }
                                                    return "Paired";
                                                }
                                                font.family: "SF Pro Display"
                                                font.pixelSize: 11
                                                color: modelData.connected ? Theme.colors.default_accent : BarColors.secondaryText
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        // Status or battery icon
                                        Text {
                                            text: modelData.connected ? "check_circle" : "chevron_right"
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 16
                                            color: modelData.connected ? Theme.colors.default_accent : BarColors.secondaryText
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    // Expanded Controls
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        visible: pairedCard.isExpanded

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: BarColors.hoverAndBorder
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: modelData.mac
                                                font.family: "SF Pro Display"
                                                font.pixelSize: 11
                                                color: BarColors.secondaryText
                                                Layout.fillWidth: true
                                            }

                                            // Connect Button (if not connected)
                                            Rectangle {
                                                width: 80
                                                height: 26
                                                radius: 6
                                                color: Theme.colors.default_accent
                                                visible: !modelData.connected

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Bluetooth.connectingMac === modelData.mac ? "Connecting" : "Connect"
                                                    font.family: "SF Pro Display"
                                                    font.bold: true
                                                    font.pixelSize: 11
                                                    color: BarColors.textOnAccent
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Bluetooth.connectDevice(modelData.mac)
                                                }
                                            }

                                            // Disconnect Button (if connected)
                                            Rectangle {
                                                width: 85
                                                height: 26
                                                radius: 6
                                                color: Theme.colors.red
                                                visible: modelData.connected

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Disconnect"
                                                    font.family: "SF Pro Display"
                                                    font.bold: true
                                                    font.pixelSize: 11
                                                    color: BarColors.primaryText
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Bluetooth.disconnectDevice(modelData.mac)
                                                }
                                            }

                                            // Forget Button
                                            Rectangle {
                                                width: 65
                                                height: 26
                                                radius: 6
                                                color: BarColors.hoverAndBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Forget"
                                                    font.family: "SF Pro Display"
                                                    font.pixelSize: 11
                                                    color: BarColors.primaryText
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Bluetooth.forgetDevice(modelData.mac)
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: pairedMouse
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: 48
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.expandedMac = (root.expandedMac === modelData.mac ? "" : modelData.mac);
                                    }
                                    onWheel: (wheel) => {
                                        flickable.contentY = Math.max(0, Math.min(flickable.contentHeight - flickable.height, flickable.contentY - wheel.angleDelta.y));
                                    }
                                }
                            }
                        }
                    }

                    // ---------- SECTION: AVAILABLE DEVICES ----------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "AVAILABLE DEVICES" + (Bluetooth.availableDevices.length > 0 ? " (" + Bluetooth.availableDevices.length + ")" : "")
                                font.family: "SF Pro Display"
                                font.bold: true
                                font.pixelSize: 11
                                color: BarColors.secondaryText
                                Layout.leftMargin: 4
                                Layout.fillWidth: true
                            }

                            // Small scan indicator
                            Text {
                                text: Bluetooth.scanning ? "Scanning..." : ""
                                font.family: "SF Pro Display"
                                font.pixelSize: 11
                                color: Theme.colors.default_accent
                                visible: Bluetooth.scanning
                            }
                        }

                        // Empty State / Scanning info
                        Rectangle {
                            Layout.fillWidth: true
                            height: 60
                            radius: 10
                            color: BarColors.surfaceBackground
                            visible: Bluetooth.availableDevices.length === 0

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    text: Bluetooth.scanning ? "search" : "devices_other"
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 20
                                    color: BarColors.secondaryText
                                }

                                Text {
                                    text: Bluetooth.scanning ? "Scanning for nearby devices..." : "No nearby devices found. Tap refresh to scan."
                                    font.family: "SF Pro Display"
                                    font.pixelSize: 12
                                    color: BarColors.primaryText
                                    opacity: 0.6
                                }
                            }
                        }

                        // List of available devices
                        Repeater {
                            model: Bluetooth.availableDevices

                            delegate: Rectangle {
                                id: availCard
                                Layout.fillWidth: true
                                radius: 10
                                color: availMouse.containsMouse ? BarColors.surfaceBackground : BarColors.transparent

                                readonly property bool isExpanded: (root.expandedMac === modelData.mac)

                                implicitHeight: isExpanded ? (availExpandedColumn.implicitHeight + 16) : 48

                                Behavior on implicitHeight {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }

                                ColumnLayout {
                                    id: availExpandedColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: availCard.isExpanded ? parent.top : undefined
                                    anchors.verticalCenter: availCard.isExpanded ? undefined : parent.verticalCenter
                                    anchors.topMargin: availCard.isExpanded ? 8 : 0
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Main Row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 10

                                        Text {
                                            text: root.getDeviceMaterialIcon(modelData.icon)
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 20
                                            color: BarColors.primaryText
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2

                                            Text {
                                                text: modelData.name || modelData.mac
                                                font.family: "SF Pro Display"
                                                font.pixelSize: 13
                                                color: BarColors.primaryText
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: "Ready to pair"
                                                font.family: "SF Pro Display"
                                                font.pixelSize: 11
                                                color: BarColors.secondaryText
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Text {
                                            text: "chevron_right"
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 16
                                            color: BarColors.secondaryText
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    // Expanded Controls
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        visible: availCard.isExpanded

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: BarColors.hoverAndBorder
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: modelData.mac
                                                font.family: "SF Pro Display"
                                                font.pixelSize: 11
                                                color: BarColors.secondaryText
                                                Layout.fillWidth: true
                                            }

                                            Rectangle {
                                                width: 95
                                                height: 26
                                                radius: 6
                                                color: Theme.colors.default_accent

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Bluetooth.connectingMac === modelData.mac ? "Pairing..." : "Pair & Connect"
                                                    font.family: "SF Pro Display"
                                                    font.bold: true
                                                    font.pixelSize: 11
                                                    color: BarColors.textOnAccent
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Bluetooth.pairDevice(modelData.mac)
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: availMouse
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: 48
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.expandedMac = (root.expandedMac === modelData.mac ? "" : modelData.mac);
                                    }
                                    onWheel: (wheel) => {
                                        flickable.contentY = Math.max(0, Math.min(flickable.contentHeight - flickable.height, flickable.contentY - wheel.angleDelta.y));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
