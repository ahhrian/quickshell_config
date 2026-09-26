import QtQuick
import Quickshell
import Quickshell.Io

import "../../../services"
import "../../../shared"
import "../widget_gui"

Rectangle {
    id: root

    property var barWindow: null

    implicitWidth: 33
    implicitHeight: 33
    radius: height / 2

    color: mouseArea.containsMouse || (wifiDropdown && wifiDropdown.visible) ? Theme.colors.bg1 : Theme.colors.bg0

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Text {
        id: iconText
        anchors.centerIn: parent
        text: Wifi.icon
        color: Wifi.iconColor
        font.family: "Material Symbols Rounded"
        font.pixelSize: 16

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    WifiGui {
        id: wifiDropdown
        barWindow: root.barWindow
        anchorItem: root
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Wifi.openHiddenNetworkDialog();
            } else {
                wifiDropdown.visible = !wifiDropdown.visible;
            }
        }
    }
}
