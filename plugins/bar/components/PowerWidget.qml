import QtQuick
import QtQuick.Layouts

import "../../../services"
import "../../../shared"
import "../widget_gui"

TrayDropdownWidget {
    id: root

    compactWidth: compactRow.implicitWidth + 22
    dropdown: powerDropdown
    hovered: mouseArea.containsMouse

    RowLayout {
        id: compactRow
        anchors.centerIn: parent
        spacing: 3

        Text {
            text: Power.icon
            color: Power.color
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16
        }

        Text {
            text: Power.battery
            color: Power.color
            font.family: "SF Pro Display"
            font.pixelSize: 16
        }
    }

    PowerGui {
        id: powerDropdown
        barWindow: root.barWindow
        anchorItem: root
        compactWidth: root.compactWidth
        compactIcon: Power.icon
        compactLabel: Power.battery
        compactIconColor: Power.color
        compactLabelColor: Power.color
        compactColor: root.pillColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleDropdown()
    }
}
