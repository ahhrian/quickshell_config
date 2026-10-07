import Quickshell
import QtQuick
import QtQuick.Layouts

import "../../../services"
import "../../../shared"
import "../widget_gui"

Item {
    id: root

    property var barWindow: null

    readonly property bool anyOpen: calendarPopup.visible || clockGuiPopup.visible
    readonly property int compactWidth: timeText.implicitWidth + 34

    implicitWidth: calendarPopup.visible ? 240 : (clockGuiPopup.visible ? 280 : compactWidth)
    implicitHeight: 33

    Layout.preferredWidth: implicitWidth
    Layout.alignment: Qt.AlignVCenter

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: mouseArea.containsMouse ? "#3c3c3c" : "#343434"

        opacity: root.anyOpen ? 0.0 : 1.0

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        Text {
            id: timeText
            anchors.centerIn: parent
            text: Time.time
            color: "#e8e8e8"
            font.family: "SF Pro Display"
            font.bold: true
            font.pixelSize: 16
        }
    }

    Calendar {
        id: calendarPopup
        barWindow: root.barWindow
        anchorItem: root
    }

    ClockGui {
        id: clockGuiPopup
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
                clockGuiPopup.visible = false;
                calendarPopup.visible = !calendarPopup.visible;
            } else {
                calendarPopup.visible = false;
                clockGuiPopup.visible = !clockGuiPopup.visible;
            }
        }
    }
}