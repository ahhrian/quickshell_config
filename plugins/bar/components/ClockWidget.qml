import Quickshell
import QtQuick
import QtQuick.Layouts

import "../../../services"
import "../../../shared"
import "../widget_gui"
import "../../themeSelector"

Item {
    id: root

    property var barWindow: null

    readonly property bool anyOpen: calendarPopup.visible || clockGuiPopup.visible || themeSwitcherPopup.visible
    readonly property int compactWidth: timeText.implicitWidth + 34
    property var pendingPopup: null

    function togglePopup(popup) {
        const current = calendarPopup.visible ? calendarPopup : (clockGuiPopup.visible ? clockGuiPopup : (themeSwitcherPopup.visible ? themeSwitcherPopup : null));
        pendingPopup = null;
        if (current === popup) {
            if (popup.closing)
                popup.openPopup();
            else
                popup.closePopup();
        } else if (current) {
            pendingPopup = popup;
            current.closePopup();
        } else {
            popup.openPopup();
        }
    }

    function finishClose() {
        const next = pendingPopup;
        pendingPopup = null;
        if (next)
            next.openPopup();
    }

    // Keep the popup anchor stationary; expansion belongs to the popup surface.
    implicitWidth: compactWidth
    implicitHeight: 33

    Layout.preferredWidth: implicitWidth
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: mouseArea.containsMouse ? "#3c3c3c" : "#343434"

        // Hand off immediately so the pill cannot ghost underneath the popup.
        visible: !root.anyOpen

        Behavior on color {
            ColorAnimation { duration: 75 }
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
        collapsedWidth: root.compactWidth
        collapsedColor: mouseArea.containsMouse ? "#3c3c3c" : "#343434"
        onCloseFinished: root.finishClose()
    }

    ClockGui {
        id: clockGuiPopup
        barWindow: root.barWindow
        anchorItem: root
        collapsedWidth: root.compactWidth
        collapsedColor: mouseArea.containsMouse ? "#3c3c3c" : "#343434"
        onCloseFinished: root.finishClose()
    }

    ThemeSwitcher {
        id: themeSwitcherPopup
        barWindow: root.barWindow
        anchorItem: root
        collapsedWidth: root.compactWidth
        collapsedColor: mouseArea.containsMouse ? "#3c3c3c" : "#343434"
        onOpenRequested: root.togglePopup(themeSwitcherPopup)
        onCloseFinished: root.finishClose()
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            root.togglePopup(mouse.button === Qt.RightButton ? calendarPopup : clockGuiPopup);
        }
    }
}
