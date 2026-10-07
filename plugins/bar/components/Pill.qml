import QtQuick
import QtQuick.Layouts

import "../../../shared"

Rectangle {
    id: root

    property string icon: ""
    property color iconColor: "#ffffff"
    property string label: ""
    property int maxLabelWidth: 400
    // Extra horizontal padding on top of the base 22px — used by ClockWidget to make it wider
    property int extraPadding: 0

    // Any children declared inside `Pill { ... }` will be inserted directly into `row`
    default property alias content: row.data

    implicitWidth: row.implicitWidth + 22 + extraPadding
    implicitHeight: 33
    radius: height / 2

    color: "#1a1a1a"

    // Native border support for the focused-workspace accent ring
    property color borderColor: "transparent"
    property int borderWidth: 0
    border.color: borderColor
    border.width: borderWidth

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Text {
            text: root.icon
            color: root.iconColor
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16
            visible: root.icon !== ""
        }
        Text {
            text: root.label
            color: root.iconColor
            font.family: "SF Pro Display"
            font.pixelSize: 16
            elide: Text.ElideRight
            Layout.maximumWidth: root.maxLabelWidth
            visible: root.label !== ""
        }
    }
}