import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    property int targetHeight: 282
    property int targetWidth: 280
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

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    function prevMonth() {
        if (viewMonth === 0) {
            viewMonth = 11;
            viewYear--;
        } else {
            viewMonth--;
        }
    }

    function nextMonth() {
        if (viewMonth === 11) {
            viewMonth = 0;
            viewYear++;
        } else {
            viewMonth++;
        }
    }

    function resetToToday() {
        const today = new Date();
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    onVisibleChanged: {
        if (visible) {
            resetToToday();
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

    readonly property var calendarCells: {
        const _ = Time.time;
        const today = new Date();
        const year = root.viewYear;
        const month = root.viewMonth;

        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const firstDow = (new Date(year, month, 1).getDay() + 6) % 7; // 0=Mon, ..., 6=Sun
        const prevMonthDays = new Date(year, month, 0).getDate();

        const cells = [];

        // Leading days from previous month
        for (let i = 0; i < firstDow; i++) {
            const d = prevMonthDays - firstDow + 1 + i;
            cells.push({
                day: d,
                isCurrentMonth: false,
                isToday: false,
                isWeekend: i >= 5
            });
        }

        // Days of current month
        for (let d = 1; d <= daysInMonth; d++) {
            const dow = (firstDow + d - 1) % 7;
            const isToday = (year === today.getFullYear() && month === today.getMonth() && d === today.getDate());
            cells.push({
                day: d,
                isCurrentMonth: true,
                isToday: isToday,
                isWeekend: dow >= 5
            });
        }

        // Trailing days from next month to complete the grid (multiple of 7)
        const totalNeeded = Math.ceil(cells.length / 7) * 7;
        const trailingCount = totalNeeded - cells.length;
        for (let i = 1; i <= trailingCount; i++) {
            const dow = (firstDow + daysInMonth + i - 1) % 7;
            cells.push({
                day: i,
                isCurrentMonth: false,
                isToday: false,
                isWeekend: dow >= 5
            });
        }

        return cells;
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

            // 1. Header with Month navigation (aligned with top bar in collapsed state)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignHCenter

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 4

                    // Previous month button
                    Rectangle {
                        id: prevBtn
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: prevMouse.containsMouse ? "#343434" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 18
                            color: prevMouse.containsMouse ? "#ffffff" : "#b0b0b0"
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevMonth()
                        }
                    }

                    // Month & Year title
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: root.monthNames[root.viewMonth]
                                font.family: "SF Pro Display"
                                font.pixelSize: 15
                                font.bold: true
                                color: "#f0f0f0"
                            }

                            Text {
                                text: root.viewYear
                                font.family: "SF Pro Display"
                                font.pixelSize: 15
                                color: "#909090"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetToToday()
                        }
                    }

                    // Next month button
                    Rectangle {
                        id: nextBtn
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: nextMouse.containsMouse ? "#343434" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 18
                            color: nextMouse.containsMouse ? "#ffffff" : "#b0b0b0"
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextMonth()
                        }
                    }
                }
            }

            // Expanded body (Calendar grid & footer)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.bottomMargin: 8

                opacity: Math.max(0, Math.min(1, root.expansionProgress))

                ColumnLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 4

                    // Days of week header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        spacing: 0

                        Repeater {
                            model: [
                                { name: "M", weekend: false },
                                { name: "T", weekend: false },
                                { name: "W", weekend: false },
                                { name: "T", weekend: false },
                                { name: "F", weekend: false },
                                { name: "S", weekend: true },
                                { name: "S", weekend: true }
                            ]

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    font.family: "SF Pro Display"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: modelData.weekend ? "#dd6b6b" : "#757575"
                                }
                            }
                        }
                    }

                    // Calendar month grid
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: {
                            const rows = Math.ceil(root.calendarCells.length / 7);
                            return rows * 28 + Math.max(0, rows - 1) * rowSpacing;
                        }
                        columns: 7
                        rowSpacing: 2
                        columnSpacing: 0

                        Repeater {
                            model: root.calendarCells

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28

                                Rectangle {
                                    id: cellBg
                                    anchors.centerIn: parent
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: modelData.isToday ? "#81c8be" : (cellMouse.containsMouse && modelData.isCurrentMonth ? "#343434" : "transparent")

                                    Behavior on color {
                                        ColorAnimation { duration: 120 }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.day
                                        font.family: "SF Pro Display"
                                        font.pixelSize: 12
                                        font.bold: modelData.isToday
                                        color: {
                                            if (modelData.isToday) return "#1a1a1a";
                                            if (!modelData.isCurrentMonth) return "#484848";
                                            if (modelData.isWeekend) return "#dd6b6b";
                                            return "#e0e0e0";
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    hoverEnabled: modelData.isCurrentMonth
                                    cursorShape: modelData.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#2e2e2e"
                    }

                    // Footer with today jump
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24

                        RowLayout {
                            anchors.fill: parent
                            spacing: 6

                            Rectangle {
                                Layout.preferredWidth: 6
                                Layout.preferredHeight: 6
                                radius: 3
                                color: "#81c8be"
                            }

                            Text {
                                text: Qt.formatDate(new Date(), "dddd, d MMMM")
                                font.family: "SF Pro Display"
                                font.pixelSize: 11
                                color: footerMouse.containsMouse ? "#ffffff" : "#909090"

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Today"
                                font.family: "SF Pro Display"
                                font.pixelSize: 11
                                font.bold: true
                                color: footerMouse.containsMouse ? "#81c8be" : "#707070"

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }
                            }
                        }

                        MouseArea {
                            id: footerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetToToday()
                        }
                    }
                }
            }
        }
    }
}
