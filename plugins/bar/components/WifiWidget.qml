import QtQuick
import Quickshell
import Quickshell.Io

import "../../../services"
import "../../../shared"
import "../widget_gui"

TrayDropdownWidget {
    id: root

    dropdown: wifiDropdown
    hovered: mouseArea.containsMouse

    Text {
        id: iconText
        anchors.centerIn: parent
        text: Wifi.icon
        color: "#e8e8e8"
        font.family: "Material Symbols Rounded"
        font.pixelSize: 16
    }

    WifiGui {
        id: wifiDropdown
        barWindow: root.barWindow
        anchorItem: root
        compactIcon: Wifi.icon
        compactColor: root.pillColor
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
                root.toggleDropdown();
            }
        }
    }
}
