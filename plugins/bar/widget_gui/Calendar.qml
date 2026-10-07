import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../../services"
import "../../../shared"

PopupWindow {
    id: root

    property var barWindow: null
    property var anchorItem: null

    anchor.window: barWindow
    anchor.rect.x: anchorItem ? Math.round(anchorItem.mapToItem(null, 0, 0).x + (anchorItem.width - implicitWidth) / 2) : Math.round((barWindow ? barWindow.width - implicitWidth : 1920) / 2)
    anchor.rect.y: anchorItem ? Math.round(anchorItem.mapToItem(null, 0, 0).y) : 6
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    implicitWidth: 240
    implicitHeight: 88

    color: "transparent"
    visible: false
    grabFocus: true

    property int targetHeight: 88
    property int targetWidth: 240
    property real collapsedWidth: targetWidth
    property int animationDuration: 100
    property real expansionProgress: 0
    readonly property real animatedWidth: collapsedWidth + (targetWidth - collapsedWidth) * expansionProgress
    readonly property real animatedHeight: 33 + (targetHeight - 33) * expansionProgress

    onVisibleChanged: {
        if (visible) {
            expansionProgress = 0;
            openTimer.restart();
        } else {
            openTimer.stop();
            openAnimation.stop();
            expansionProgress = 0;
        }
    }

    Timer {
        id: openTimer
        interval: 16
        repeat: false
        onTriggered: openAnimation.start()
    }

    NumberAnimation {
        id: openAnimation
        target: root
        property: "expansionProgress"
        from: 0
        to: 1
        duration: root.animationDuration
        easing.type: Easing.OutCubic
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
        color: "#202020"
        border.width: 1
        border.color: "#383838"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
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

                opacity: Math.max(0, Math.min(1, (root.animatedHeight - 45) / 35))

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
