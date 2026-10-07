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

    color: mouseArea.containsMouse || (btDropdown && btDropdown.visible) ? "#2a2a2a" : "#1a1a1a"

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Text {
        id: iconText
        anchors.centerIn: parent
        text: Bluetooth.icon
        color: "#ffffff"
        font.family: "Material Symbols Rounded"
        font.pixelSize: 16
    }

    BluetoothGui {
        id: btDropdown
        barWindow: root.barWindow
        anchorItem: root
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            btDropdown.visible = !btDropdown.visible;
        }
    }
}
