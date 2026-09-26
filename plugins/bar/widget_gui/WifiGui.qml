import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import "../../../services"
import "../../../shared"

PopupWindow {
    id: root

    property var barWindow: null
    property var anchorItem: null

    anchor.window: barWindow
    anchor.rect.x: anchorItem ? Math.max(10, Math.min((barWindow ? barWindow.width : 1920) - implicitWidth - 10, anchorItem.mapToItem(null, 0, 0).x + anchorItem.width - implicitWidth)) : 500
    anchor.rect.y: barWindow ? barWindow.height + 6 : 46
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    implicitWidth: 380
    implicitHeight: Math.min(card.implicitHeight, 540)

    color: "transparent"
    visible: false
    grabFocus: true

    property string expandedSsid: ""
    property string passwordInput: ""
    property bool showPassword: false

    onVisibleChanged: {
        if (visible) {
            expandedSsid = "";
            passwordInput = "";
            showPassword = false;
            Wifi.recheck();
            Wifi.scanNetworks();
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Theme.colors.bg0
        radius: 16
        border.width: 1
        border.color: Theme.colors.bg2
        clip: true

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

                // Network Icon
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Wifi.enabled && Wifi.connected ? Theme.colors.bg1 : Theme.colors.bg1

                    Text {
                        anchors.centerIn: parent
                        text: Wifi.icon
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: Wifi.iconColor
                    }
                }

                // SSID & Subtitle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: !Wifi.enabled ? "Wi-Fi Disabled" : (Wifi.connected ? Wifi.ssid : "Not Connected")
                        font.family: "SF Pro Display"
                        font.bold: true
                        font.pixelSize: 16
                        color: Theme.colors.fg
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: {
                            if (!Wifi.enabled) return "Turn on to view available networks";
                            if (Wifi.connected) {
                                let sub = "Connected";
                                if (Wifi.speedMbps > 0) sub += " • " + Math.round(Wifi.speedMbps) + " Mbps";
                                else if (Wifi.signalStrength > 0) sub += " • " + Wifi.signalStrength + "%";
                                return sub;
                            }
                            return Wifi.scanning ? "Scanning for networks..." : "Select a network below";
                        }
                        font.family: "SF Pro Display"
                        font.pixelSize: 12
                        color: Theme.colors.fg
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
                    color: rescanMouse.containsMouse ? Theme.colors.bg2 : "transparent"
                    visible: Wifi.enabled

                    Text {
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Theme.colors.fg
                        opacity: Wifi.scanning ? 0.4 : 0.8
                    }

                    MouseArea {
                        id: rescanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wifi.scanNetworks()
                    }
                }

                // Toggle Switch (ON / OFF)
                Rectangle {
                    id: toggleSwitch
                    width: 46
                    height: 24
                    radius: 12
                    color: Wifi.enabled ? Theme.colors.secondary_accent : Theme.colors.bg2

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    Rectangle {
                        id: toggleThumb
                        width: 20
                        height: 20
                        radius: 10
                        color: "#ffffff"
                        y: 2
                        x: Wifi.enabled ? 24 : 2

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
                        onClicked: Wifi.toggleWifi()
                    }
                }
            }

            // ==================== 2. LINE SEPARATOR ====================
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.colors.bg2
            }

            // ==================== 3. NETWORKS CONTAINER ====================
            // Wi-Fi Disabled placeholder
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                visible: !Wifi.enabled

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "wifi_off"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 32
                        color: Theme.colors.bg4
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Wi-Fi is turned off"
                        font.family: "SF Pro Display"
                        font.pixelSize: 14
                        color: Theme.colors.fg
                        opacity: 0.7
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 100
                        height: 28
                        radius: 14
                        color: Theme.colors.secondary_accent

                        Text {
                            anchors.centerIn: parent
                            text: "Turn On"
                            font.family: "SF Pro Display"
                            font.bold: true
                            font.pixelSize: 12
                            color: Theme.colors.bg0
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wifi.toggleWifi()
                        }
                    }
                }
            }

            // Scrollable list when Wi-Fi is enabled
            Flickable {
                id: flickable
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(networksColumn.implicitHeight, 400)
                contentHeight: networksColumn.implicitHeight
                clip: true
                visible: Wifi.enabled
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: networksColumn
                    width: flickable.width
                    spacing: 12

                    // ---------- SECTION: KNOWN NETWORKS ----------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: Wifi.knownNetworks.length > 0

                        Text {
                            text: "KNOWN NETWORKS"
                            font.family: "SF Pro Display"
                            font.bold: true
                            font.pixelSize: 11
                            color: Theme.colors.bg4
                            Layout.leftMargin: 4
                        }

                        Repeater {
                            model: Wifi.knownNetworks

                            delegate: Rectangle {
                                id: knownPill
                                Layout.fillWidth: true
                                radius: 10
                                color: modelData.connected ? Theme.colors.bg1 : (knownMouse.containsMouse ? Theme.colors.bg1 : "transparent")
                                border.width: modelData.connected ? 1 : 0
                                border.color: Theme.colors.secondary_accent

                                readonly property bool isExpanded: (root.expandedSsid === modelData.ssid)

                                implicitHeight: isExpanded ? (expandedColumn.implicitHeight + 16) : 48

                                Behavior on implicitHeight {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }

                                ColumnLayout {
                                    id: expandedColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: knownPill.isExpanded ? parent.top : undefined
                                    anchors.verticalCenter: knownPill.isExpanded ? undefined : parent.verticalCenter
                                    anchors.topMargin: knownPill.isExpanded ? 8 : 0
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Main Row (Collapsed view)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 10

                                        Text {
                                            text: root.getSignalIcon(modelData.signal)
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 18
                                            color: modelData.connected ? Theme.colors.secondary_accent : Theme.colors.fg
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2

                                            Text {
                                                text: modelData.ssid
                                                font.family: "SF Pro Display"
                                                font.bold: modelData.connected
                                                font.pixelSize: 13
                                                color: Theme.colors.fg
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.connected ? "Connected" : (modelData.outOfRange ? "Not in range" : modelData.signal + "% signal")
                                                font.family: "SF Pro Display"
                                                font.pixelSize: 11
                                                color: modelData.connected ? Theme.colors.secondary_accent : Theme.colors.bg4
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Text {
                                            text: "lock"
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 14
                                            color: Theme.colors.bg4
                                            visible: modelData.secure
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    // Expanded Details & Action buttons
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        visible: knownPill.isExpanded

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: Theme.colors.bg2
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: "Security: " + (modelData.security || "WPA")
                                                font.family: "SF Pro Display"
                                                font.pixelSize: 11
                                                color: Theme.colors.bg4
                                                Layout.fillWidth: true
                                            }

                                            // Connect Button (if not connected and in range)
                                            Rectangle {
                                                width: 75
                                                height: 26
                                                radius: 6
                                                color: Theme.colors.secondary_accent
                                                visible: !modelData.connected && !modelData.outOfRange

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Wifi.connectingSsid === modelData.ssid ? "Connecting" : "Connect"
                                                    font.family: "SF Pro Display"
                                                    font.bold: true
                                                    font.pixelSize: 11
                                                    color: Theme.colors.bg0
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Wifi.connectToNetwork(modelData.ssid, "")
                                                }
                                            }

                                            // Disconnect Button (if currently connected)
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
                                                    color: "#ffffff"
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Wifi.disconnectNetwork(modelData.ssid)
                                                }
                                            }

                                            // Forget Button
                                            Rectangle {
                                                width: 65
                                                height: 26
                                                radius: 6
                                                color: Theme.colors.bg2

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Forget"
                                                    font.family: "SF Pro Display"
                                                    font.pixelSize: 11
                                                    color: Theme.colors.fg
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Wifi.forgetNetwork(modelData.ssid)
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: knownMouse
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: 48
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.expandedSsid = (root.expandedSsid === modelData.ssid ? "" : modelData.ssid);
                                    }
                                }
                            }
                        }
                    }

                    // ---------- SECTION: AVAILABLE NETWORKS ----------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Header with "Connect to Hidden" Button
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4

                            Text {
                                text: "AVAILABLE NETWORKS"
                                font.family: "SF Pro Display"
                                font.bold: true
                                font.pixelSize: 11
                                color: Theme.colors.bg4
                                Layout.fillWidth: true
                            }

                            // Hidden network button
                            Rectangle {
                                implicitWidth: hiddenRow.implicitWidth + 12
                                implicitHeight: 22
                                radius: 11
                                color: hiddenMouse.containsMouse ? Theme.colors.bg2 : Theme.colors.bg1

                                RowLayout {
                                    id: hiddenRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "add"
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 13
                                        color: Theme.colors.secondary_accent
                                    }
                                    Text {
                                        text: "Hidden..."
                                        font.family: "SF Pro Display"
                                        font.pixelSize: 11
                                        color: Theme.colors.fg
                                    }
                                }

                                MouseArea {
                                    id: hiddenMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Wifi.openHiddenNetworkDialog()
                                }
                            }
                        }

                        // Empty / Scanning state
                        Text {
                            text: Wifi.scanning ? "Scanning nearby Wi-Fi networks..." : "No other networks found."
                            font.family: "SF Pro Display"
                            font.pixelSize: 12
                            color: Theme.colors.bg4
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                            visible: Wifi.availableNetworks.length === 0
                        }

                        // Available Networks List
                        Repeater {
                            model: Wifi.availableNetworks

                            delegate: Rectangle {
                                id: availPill
                                Layout.fillWidth: true
                                radius: 10
                                color: availMouse.containsMouse || isExpanded ? Theme.colors.bg1 : "transparent"

                                readonly property bool isExpanded: (root.expandedSsid === modelData.ssid)

                                implicitHeight: isExpanded ? (availColumn.implicitHeight + 16) : 48

                                Behavior on implicitHeight {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }

                                ColumnLayout {
                                    id: availColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: availPill.isExpanded ? parent.top : undefined
                                    anchors.verticalCenter: availPill.isExpanded ? undefined : parent.verticalCenter
                                    anchors.topMargin: availPill.isExpanded ? 8 : 0
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Main Row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 10

                                        Text {
                                            text: root.getSignalIcon(modelData.signal)
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 18
                                            color: Theme.colors.fg
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2

                                            Text {
                                                text: modelData.ssid
                                                font.family: "SF Pro Display"
                                                font.pixelSize: 13
                                                color: Theme.colors.fg
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.signal + "% signal" + (modelData.secure ? " • Secured" : " • Open")
                                                font.family: "SF Pro Display"
                                                font.pixelSize: 11
                                                color: Theme.colors.bg4
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Text {
                                            text: "lock"
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 14
                                            color: Theme.colors.bg4
                                            visible: modelData.secure
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    // Expanded Connect Panel
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        visible: availPill.isExpanded

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 1
                                            color: Theme.colors.bg2
                                        }

                                        // Password input if secured
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 32
                                            radius: 6
                                            color: Theme.colors.bg0
                                            border.width: 1
                                            border.color: pwdInput.activeFocus ? Theme.colors.secondary_accent : Theme.colors.bg3
                                            visible: modelData.secure

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8

                                                TextInput {
                                                    id: pwdInput
                                                    Layout.fillWidth: true
                                                    font.family: "SF Pro Display"
                                                    font.pixelSize: 12
                                                    color: Theme.colors.fg
                                                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                                    text: root.passwordInput
                                                    onTextChanged: root.passwordInput = text
                                                    onAccepted: Wifi.connectToNetwork(modelData.ssid, root.passwordInput)

                                                    Text {
                                                        text: "Enter password"
                                                        font.family: "SF Pro Display"
                                                        font.pixelSize: 12
                                                        color: Theme.colors.bg4
                                                        visible: pwdInput.text === "" && !pwdInput.activeFocus
                                                    }
                                                }

                                                Text {
                                                    text: root.showPassword ? "visibility_off" : "visibility"
                                                    font.family: "Material Symbols Rounded"
                                                    font.pixelSize: 16
                                                    color: Theme.colors.bg4

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.showPassword = !root.showPassword
                                                    }
                                                }
                                            }
                                        }

                                        // Connect & Cancel buttons row
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: Wifi.connectingSsid === modelData.ssid ? "Connecting to " + modelData.ssid + "..." : (modelData.secure ? "Secured with " + modelData.security : "Open Network")
                                                font.family: "SF Pro Display"
                                                font.pixelSize: 11
                                                color: Theme.colors.bg4
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                width: 60
                                                height: 26
                                                radius: 6
                                                color: Theme.colors.bg2

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Cancel"
                                                    font.family: "SF Pro Display"
                                                    font.pixelSize: 11
                                                    color: Theme.colors.fg
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.expandedSsid = ""
                                                }
                                            }

                                            Rectangle {
                                                width: 75
                                                height: 26
                                                radius: 6
                                                color: Theme.colors.secondary_accent

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Wifi.connectingSsid === modelData.ssid ? "..." : "Connect"
                                                    font.family: "SF Pro Display"
                                                    font.bold: true
                                                    font.pixelSize: 11
                                                    color: Theme.colors.bg0
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        Wifi.connectToNetwork(modelData.ssid, root.passwordInput);
                                                    }
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
                                        root.passwordInput = "";
                                        root.expandedSsid = (root.expandedSsid === modelData.ssid ? "" : modelData.ssid);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function getSignalIcon(signal) {
        if (signal >= 70) return "android_wifi_4_bar";
        if (signal >= 40) return "android_wifi_3_bar";
        if (signal > 0) return "wifi_2_bar";
        return "android_wifi_4_bar_off";
    }
}
