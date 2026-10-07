import QtQuick
import Quickshell
import Quickshell.Io

import "../../../services"
import "../../../shared"
import "../widget_gui"

TrayDropdownWidget {
    id: root

    dropdown: btDropdown
    hovered: mouseArea.containsMouse

    Text {
        id: iconText
        anchors.centerIn: parent
        text: Bluetooth.icon
        color: "#e8e8e8"
        font.family: "Material Symbols Rounded"
        font.pixelSize: 16
    }

    BluetoothGui {
        id: btDropdown
        barWindow: root.barWindow
        anchorItem: root
        compactIcon: Bluetooth.icon
        compactColor: root.pillColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.toggleDropdown();
        }
    }
}
