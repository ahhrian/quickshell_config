import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

import "../../../services"
import "../../../shared"

PopupWindow {
    id: root

    property var barWindow: null
    property var anchorItem: null

    anchor.window: barWindow
    anchor.rect.x: anchorItem ? Math.max(10, Math.min((barWindow ? barWindow.width : 1920) - implicitWidth - 10, anchorItem.mapToItem(null, 0, 0).x + anchorItem.width - implicitWidth)) : 500
    anchor.rect.y: barWindow ? barWindow.height + 6 : 46
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    implicitWidth: 380
    implicitHeight: Math.min(card.implicitHeight, 560)

    color: "transparent"
    visible: false
    grabFocus: true

    property bool isClearingAll: false

    function clearAllWithDomino() {
        if (isClearingAll || Notifications.count === 0) return;
        isClearingAll = true;

        const count = Notifications.count;
        // Total duration: 45ms stagger per item + 200ms slide duration + 40ms safety buffer
        const totalDuration = Math.max(250, (count - 1) * 45 + 240);

        dominoCleanupTimer.interval = totalDuration;
        dominoCleanupTimer.start();
    }

    Timer {
        id: dominoCleanupTimer
        repeat: false
        onTriggered: {
            Notifications.clearAll();
            root.isClearingAll = false;
        }
    }

    onVisibleChanged: {
        if (!visible && isClearingAll) {
            dominoCleanupTimer.stop();
            Notifications.clearAll();
            isClearingAll = false;
        }
    }

    Rectangle {
        id: card
        width: 380
        implicitHeight: mainCol.implicitHeight + 24
        radius: 16
        color: Theme.colors.bg0
        border.color: Theme.colors.bg2
        border.width: 1
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: mainCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            // 1. Top Row: Do Not Disturb
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 10

                Text {
                    text: "Do not disturb"
                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.colors.fg
                }

                Item { Layout.fillWidth: true }

                // Animated Toggle Switch
                Rectangle {
                    id: dndToggle
                    width: 44
                    height: 24
                    radius: 12
                    color: Notifications.dnd ? Theme.colors.default_accent : Theme.colors.bg2

                    Behavior on color {
                        ColorAnimation { duration: 180 }
                    }

                    Rectangle {
                        id: dndThumb
                        width: 20
                        height: 20
                        radius: 10
                        color: "#ffffff"
                        y: 2
                        x: Notifications.dnd ? 22 : 2

                        Behavior on x {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.toggleDnd()
                    }
                }
            }

            // 2. Second Row: Notifications Header & Clear All Button
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 8

                Text {
                    text: "Notifications"
                    font.family: "SF Pro Display"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Theme.colors.fg
                }

                // Notification count pill
                Rectangle {
                    visible: Notifications.count > 0
                    opacity: root.isClearingAll ? 0.3 : 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                    implicitWidth: countText.implicitWidth + 12
                    implicitHeight: 18
                    radius: 9
                    color: Theme.colors.bg2

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: Notifications.count
                        font.family: "SF Pro Display"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Theme.colors.fg
                        opacity: 0.8
                    }
                }

                Item { Layout.fillWidth: true }

                // Clear All Button Pill
                Rectangle {
                    implicitWidth: clearText.implicitWidth + 20
                    implicitHeight: 28
                    radius: 8
                    color: (clearMouse.containsMouse && Notifications.count > 0 && !root.isClearingAll) ? Theme.colors.bg2 : Theme.colors.bg1
                    border.color: Theme.colors.bg2
                    border.width: 1
                    opacity: (Notifications.count > 0 && !root.isClearingAll) ? 1.0 : 0.45

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "Clear All"
                        font.family: "SF Pro Display"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.colors.fg
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (Notifications.count > 0 && !root.isClearingAll) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: Notifications.count > 0 && !root.isClearingAll
                        onClicked: root.clearAllWithDomino()
                    }
                }
            }

            // 3. Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.colors.bg2
                opacity: 0.7
            }

            // 4. Content Area
            // Empty State (No Notifications)
            ColumnLayout {
                visible: Notifications.count === 0 && !root.isClearingAll
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                Layout.alignment: Qt.AlignCenter
                spacing: 10

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 48
                    color: Theme.colors.fg
                    opacity: 0.3
                    text: "notifications"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    font.family: "SF Pro Display"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.colors.fg
                    opacity: 0.5
                    text: "No Notifications"
                }
            }

            // Populated State (List of Notifications)
            ListView {
                id: notifList
                visible: Notifications.count > 0 || root.isClearingAll
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 420)
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds

                model: Notifications.trackedNotifications

                delegate: Rectangle {
                    id: notifCard
                    width: notifList.width
                    implicitHeight: cardContent.implicitHeight + 20
                    radius: 12
                    color: cardHover.containsMouse ? Theme.colors.bg2 : Theme.colors.bg1
                    border.color: Theme.colors.bg2
                    border.width: 1

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Component.onCompleted: {
                        notifCard.x = 0;
                        notifCard.opacity = 1.0;
                    }

                    SequentialAnimation {
                        id: dominoAnim

                        PauseAnimation {
                            duration: Math.max(0, index * 45)
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: notifCard
                                property: "x"
                                to: notifList.width + 40
                                duration: 200
                                easing.type: Easing.InQuad
                            }
                            NumberAnimation {
                                target: notifCard
                                property: "opacity"
                                to: 0.0
                                duration: 200
                                easing.type: Easing.InQuad
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onIsClearingAllChanged() {
                            if (root.isClearingAll) {
                                dominoAnim.start();
                            } else {
                                notifCard.x = 0;
                                notifCard.opacity = 1.0;
                            }
                        }
                    }

                    ParallelAnimation {
                        id: singleDismissAnim
                        NumberAnimation {
                            target: notifCard
                            property: "x"
                            to: notifList.width + 40
                            duration: 180
                            easing.type: Easing.InQuad
                        }
                        NumberAnimation {
                            target: notifCard
                            property: "opacity"
                            to: 0.0
                            duration: 180
                            easing.type: Easing.InQuad
                        }
                        onFinished: {
                            if (modelData) {
                                Notifications.dismiss(modelData);
                            }
                        }
                    }

                    ColumnLayout {
                        id: cardContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 6

                        // Header row: App Icon, App Name, bullet, relative time, close button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // App Icon
                            IconImage {
                                id: appIconImg
                                implicitWidth: 16
                                implicitHeight: 16
                                source: {
                                    if (!modelData || !modelData.appIcon) return "";
                                    let icon = modelData.appIcon;
                                    if (icon.startsWith("/")) return "file://" + icon;
                                    return icon;
                                }
                                visible: source !== "" && status !== Image.Error
                            }

                            // Fallback icon if no app icon or failed to load
                            Text {
                                visible: !appIconImg.visible
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 16
                                color: Theme.colors.fg
                                opacity: 0.6
                                text: "notifications"
                            }

                            Text {
                                text: (modelData && modelData.appName) ? modelData.appName : "System"
                                font.family: "SF Pro Display"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: Theme.colors.fg
                                opacity: 0.75
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "•"
                                font.pixelSize: 11
                                color: Theme.colors.fg
                                opacity: 0.4
                            }

                            Text {
                                text: modelData ? Notifications.getTimeAgo(modelData.id) : "Just now"
                                font.family: "SF Pro Display"
                                font.pixelSize: 11
                                color: Theme.colors.fg
                                opacity: 0.55
                            }

                            Item { Layout.fillWidth: true }

                            // Close Button
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: closeMouse.containsMouse ? Theme.colors.bg3 : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 14
                                    color: closeMouse.containsMouse ? Theme.colors.red : Theme.colors.fg
                                    opacity: closeMouse.containsMouse ? 1.0 : 0.5
                                    text: "close"
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.isClearingAll
                                    onClicked: {
                                        singleDismissAnim.start();
                                    }
                                }
                            }
                        }

                        // Summary / Title
                        Text {
                            Layout.fillWidth: true
                            text: (modelData && modelData.summary) ? modelData.summary : ""
                            font.family: "SF Pro Display"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.colors.fg
                            wrapMode: Text.Wrap
                            visible: text.length > 0
                        }

                        // Body
                        Text {
                            Layout.fillWidth: true
                            text: (modelData && modelData.body) ? modelData.body : ""
                            font.family: "SF Pro Display"
                            font.pixelSize: 12
                            color: Theme.colors.fg
                            opacity: 0.8
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }

                        // Actions Row (if any)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: modelData && modelData.actions && modelData.actions.length > 0

                            Repeater {
                                model: (modelData && modelData.actions) ? modelData.actions : []

                                Rectangle {
                                    implicitHeight: 24
                                    implicitWidth: actionLabel.implicitWidth + 16
                                    radius: 6
                                    color: actionMouse.containsMouse ? Theme.colors.bg3 : Theme.colors.bg2

                                    Text {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        text: modelData.text ? modelData.text : ""
                                        font.family: "SF Pro Display"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Theme.colors.fg
                                    }

                                    MouseArea {
                                        id: actionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !root.isClearingAll
                                        onClicked: {
                                            if (modelData && typeof modelData.invoke === "function") {
                                                modelData.invoke();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: cardHover
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        enabled: !root.isClearingAll
                    }
                }
            }
        }
    }
}
