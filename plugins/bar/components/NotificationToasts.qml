import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

import "../../../services"
import "../../../shared"

PanelWindow {
    id: toastWindow

    property var screenModel: null
    property int topOffset: 48

    screen: screenModel

    anchors {
        top: true
        right: true
    }

    margins {
        top: topOffset
        right: 14
    }

    color: BarColors.transparent
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    implicitWidth: 350
    implicitHeight: Math.max(1, toastList.contentHeight)
    visible: toastModel.count > 0

    ListModel {
        id: toastModel
    }

    Connections {
        target: Notifications

        function onToastRequested(n) {
            // Maximum of 5 notification toasts can appear at once.
            // If we have 5, remove the earliest received (index 0) to shift others upwards.
            while (toastModel.count >= 5) {
                toastModel.remove(0);
            }

            // Introduce the new notification below them
            toastModel.append({
                notifId: n.id,
                appName: n.appName ? n.appName : "System",
                appIcon: n.appIcon ? n.appIcon : "",
                summary: n.summary ? n.summary : "",
                body: n.body ? n.body : ""
            });
        }
    }

    ListView {
        id: toastList
        anchors.fill: parent
        spacing: 8
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        model: toastModel

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { property: "x"; from: 60; to: 0; duration: 180; easing.type: Easing.OutCubic }
        }

        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { property: "x"; to: 60; duration: 150; easing.type: Easing.OutCubic }
        }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
        }

        delegate: Rectangle {
            id: toastCard
            width: toastList.width
            implicitHeight: cardCol.implicitHeight + 20
            radius: 12
            color: cardHover.containsMouse ? Theme.colors.bg1 : Theme.colors.bg0
            border.color: Theme.colors.bg2
            border.width: 1
            clip: true

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            function dismissThis() {
                for (let i = 0; i < toastModel.count; i++) {
                    if (toastModel.get(i).notifId === model.notifId) {
                        toastModel.remove(i);
                        break;
                    }
                }
            }

            // 2-second auto-dismiss timer (pauses if mouse is hovering)
            Timer {
                id: dismissTimer
                interval: 2000
                running: !cardHover.containsMouse
                onTriggered: toastCard.dismissThis()
            }

            MouseArea {
                id: cardHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const raw = Notifications.getById(model.notifId);
                    if (raw && raw.actions && raw.actions.length > 0) {
                        raw.actions[0].invoke();
                    }
                    toastCard.dismissThis();
                }
            }

            ColumnLayout {
                id: cardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 6

                // Header Row: App icon, app name, bullet, "Just now", close button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // App Icon
                    IconImage {
                        id: appIconImg
                        implicitWidth: 16
                        implicitHeight: 16
                        source: {
                            if (!model.appIcon) return "";
                            let icon = model.appIcon;
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
                        text: model.appName ? model.appName : "System"
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
                        text: "Just now"
                        font.family: "SF Pro Display"
                        font.pixelSize: 11
                        color: Theme.colors.fg
                        opacity: 0.55
                    }

                    Item { Layout.fillWidth: true }

                    // Manual close button
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: closeHover.containsMouse ? Theme.colors.bg3 : BarColors.transparent

                        Text {
                            anchors.centerIn: parent
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 14
                            color: closeHover.containsMouse ? Theme.colors.red : Theme.colors.fg
                            opacity: closeHover.containsMouse ? 1.0 : 0.5
                            text: "close"
                        }

                        MouseArea {
                            id: closeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                toastCard.dismissThis();
                            }
                        }
                    }
                }

                // Summary
                Text {
                    Layout.fillWidth: true
                    text: model.summary ? model.summary : ""
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
                    text: model.body ? model.body : ""
                    font.family: "SF Pro Display"
                    font.pixelSize: 12
                    color: Theme.colors.fg
                    opacity: 0.8
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Subtle 2-second countdown progress bar
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                height: 2
                radius: 1
                color: Theme.colors.default_accent
                opacity: 0.45

                NumberAnimation on width {
                    from: toastCard.width
                    to: 0
                    duration: 2000
                    running: true
                    paused: cardHover.containsMouse
                }
            }
        }
    }
}
