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

    color: mouseArea.containsMouse || (notifDropdown && notifDropdown.visible) ? "#343434" : "#303030"

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Text {
        id: iconText
        anchors.centerIn: parent
        font.family: "Material Symbols Rounded"
        font.pixelSize: 16

        text: {
            if (Notifications.dnd) return "notifications_off";
            if (Notifications.count > 0) return "notifications_active";
            return "notifications";
        }

        // Bar icon stays white; accent/status colors live in the dropdown only
        color: "#e8e8e8"
        opacity: Notifications.dnd ? 0.45 : 1.0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    // // Unread indicator dot
    // Rectangle {
    //     id: badgeDot
    //     width: 6
    //     height: 6
    //     radius: 3
    //     anchors.top: parent.top
    //     anchors.right: parent.right
    //     anchors.topMargin: 6
    //     anchors.rightMargin: 6
    //     color: Theme.colors.default_accent
    //     visible: Notifications.count > 0 && !Notifications.dnd
    // }

    NotificationGui {
        id: notifDropdown
        barWindow: root.barWindow
        anchorItem: root
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Notifications.toggleDnd();
            } else {
                notifDropdown.visible = !notifDropdown.visible;
            }
        }
    }
}
