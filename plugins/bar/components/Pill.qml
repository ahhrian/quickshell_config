import QtQuick
import QtQuick.Layouts

import "../../../shared"

Rectangle {
    id: root

    property string icon: ""
    property color iconColor: Theme.colors.fg
    property string label: ""
    property int maxLabelWidth: 400

    // Any children declared inside `Pill { ... }` will be inserted directly into `row`
    default property alias content: row.data

    implicitWidth: row.implicitWidth + 22
    implicitHeight: 33
    radius: height / 2

    color: Theme.colors.bg0

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