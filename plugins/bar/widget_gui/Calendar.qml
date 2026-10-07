import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

import "../../../services"
import "../../../shared"

PopupWindow {
    id: root

    property var barWindow: null
    property var anchorItem: null

    anchor.window: barWindow
    // Coordinate mapping is not reactive to the bar layout moving the clock.
    // Resolve its current position immediately before the popup is placed.
    anchor.onAnchoring: {
        if (anchorItem && barWindow) {
            const position = anchorItem.mapToItem(barWindow.contentItem, 0, 0);
            anchor.rect.x = Math.round(position.x + (anchorItem.width - implicitWidth) / 2);
            anchor.rect.y = Math.round(position.y);
        } else {
            anchor.rect.x = Math.round(((barWindow ? barWindow.width : 1920) - implicitWidth) / 2);
            anchor.rect.y = 6;
        }
    }
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    // Leave room for the spring-like overshoot without clipping the card.
    implicitWidth: targetWidth + 2 * overshootPadding
    implicitHeight: targetHeight + overshootPadding

    color: "transparent"
    visible: false
    // Manage dismissal ourselves so the native window survives the exit animation.
    grabFocus: false

    property int targetHeight: 88
    property int targetWidth: 240
    property real collapsedWidth: targetWidth
    property int animationDuration: 260
    property int closeDuration: 170
    property bool closing: false
    property color collapsedColor: "#343434"
    signal closeFinished()
    property real animationOvershoot: 0.8
    readonly property int overshootPadding: 12
    property real expansionProgress: 0
    readonly property real animatedWidth: collapsedWidth + (targetWidth - collapsedWidth) * expansionProgress
    readonly property real animatedHeight: 33 + (targetHeight - 33) * expansionProgress
    readonly property real contentProgress: Math.max(0, Math.min(1, expansionProgress))

    function openPopup() {
        if (visible) {
            closeAnimation.stop();
            closing = false;
            focusGrab.active = true;
            openAnimation.restart();
        } else {
            visible = true;
        }
    }

    function closePopup() {
        if (!visible || closing)
            return;
        openAnimation.stop();
        closing = true;
        focusGrab.active = false;
        closeAnimation.restart();
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: root.closePopup()
    }

    onVisibleChanged: {
        if (visible) {
            expansionProgress = 0;
        } else {
            openAnimation.stop();
            closeAnimation.stop();
            focusGrab.active = false;
            expansionProgress = 0;
            closing = false;
        }
    }

    // Start when the native popup is shown, rather than racing a fixed timer.
    onBackingWindowVisibleChanged: {
        if (backingWindowVisible && visible && !closing) {
            focusGrab.active = true;
            openAnimation.restart();
        }
    }

    NumberAnimation {
        id: openAnimation
        target: root
        property: "expansionProgress"
        to: 1
        duration: root.animationDuration
        easing.type: Easing.OutBack
        easing.overshoot: root.animationOvershoot
    }

    NumberAnimation {
        id: closeAnimation
        target: root
        property: "expansionProgress"
        to: 0
        duration: root.closeDuration
        easing.type: Easing.InOutCubic
        onFinished: {
            root.visible = false;
            root.closeFinished();
        }
    }

    readonly property var weekDays: {
        // Time.time reference ensures midnight/daily reactive refresh
        const _ = Time.time;
        const now = new Date();
        // 0=Mon, ..., 6=Sun
        const dayOfWeek = (now.getDay() + 6) % 7;
        const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dayOfWeek);
        const dayNamesShort = ["M", "T", "W", "T", "F", "S", "S"];
        const dayNamesFull = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
        const result = [];

        for (let i = 0; i < 7; i++) {
            const d = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i);
            const isToday = (i === dayOfWeek);
            const isWeekend = (i >= 5);
            result.push({
                dayName: isToday ? dayNamesFull[i] : dayNamesShort[i],
                dateNum: d.getDate(),
                isToday: isToday,
                isWeekend: isWeekend
            });
        }
        return result;
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.animatedWidth
        height: root.animatedHeight
        radius: 18
        color: root.closing ? Qt.rgba(
            (32 / 255) * root.contentProgress + root.collapsedColor.r * (1 - root.contentProgress),
            (32 / 255) * root.contentProgress + root.collapsedColor.g * (1 - root.contentProgress),
            (32 / 255) * root.contentProgress + root.collapsedColor.b * (1 - root.contentProgress), 1) : "#202020"
        border.width: 1
        border.color: Qt.rgba(56 / 255, 56 / 255, 56 / 255, root.closing ? root.contentProgress : 1)
        clip: true
        focus: true
        Keys.onEscapePressed: root.closePopup()

        // Match the bar clock at the end of the shrink, before handing it back.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (33 - height) / 2
            text: Time.time
            color: "#e8e8e8"
            font.family: "SF Pro Display"
            font.pixelSize: 16
            font.bold: true
            opacity: root.closing ? 1 - root.contentProgress : 0
        }

        ColumnLayout {
            opacity: root.closing ? root.contentProgress : 1
            enabled: !root.closing
            // Lay out once at the final size. The animated card clips/reveals
            // this content without squeezing rows or moving text each frame.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.targetWidth
            height: root.targetHeight
            spacing: 0

            // 1. Time header section (aligned with the bar)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignHCenter

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    text: Time.time
                    color: "#f0f0f0"
                    font.family: "SF Pro Display"
                    font.pixelSize: 22
                    font.bold: true
                }
            }

            // 2. Week strip section
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.bottomMargin: 8

                opacity: Math.max(0, Math.min(1, root.expansionProgress))

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Repeater {
                        model: root.weekDays

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.dayName
                                    font.family: "SF Pro Display"
                                    font.pixelSize: modelData.isToday ? 11 : 10
                                    font.bold: modelData.isToday
                                    color: modelData.isToday ? "#f0f0f0" : (modelData.isWeekend ? "#dd6b6b" : "#757575")
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.dateNum
                                    font.family: "SF Pro Display"
                                    font.pixelSize: modelData.isToday ? 15 : 13
                                    font.bold: modelData.isToday
                                    color: modelData.isToday ? "#81c8be" : (modelData.isWeekend ? "#c55858" : "#b0b0b0")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
