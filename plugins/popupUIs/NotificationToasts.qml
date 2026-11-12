import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

import "../../services"
import "../../shared"

PanelWindow {
    id: toastWindow

    property var screenModel: null
    property int topOffset: 48
    property int toastDuration: 5000 // milliseconds
    property int slideInDuration: 360
    property int slideOutDuration: 300
    property int slideOvershoot: 24

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
    // Keep the transparent host surface mapped so the compositor does not
    // animate the window itself when the first toast appears.
    visible: true

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
            NumberAnimation {
                property: "x"
                from: toastList.width + toastWindow.slideOvershoot
                to: 0
                duration: toastWindow.slideInDuration
                easing.type: Easing.OutCubic
            }
        }

        // This handles forced removals when the five-toast limit is reached.
        // Normal dismissals finish their slide before touching the model.
        remove: Transition {
            NumberAnimation {
                property: "x"
                to: toastList.width + toastWindow.slideOvershoot
                duration: toastWindow.slideOutDuration
                easing.type: Easing.InCubic
            }
        }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
        }

        delegate: Rectangle {
            id: toastCard
            property bool dismissing: false

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
                if (dismissing)
                    return;

                dismissing = true;
                dismissAnimation.restart();
            }

            function removeFromModel() {
                for (let i = 0; i < toastModel.count; i++) {
                    if (toastModel.get(i).notifId === model.notifId) {
                        toastModel.remove(i);
                        break;
                    }
                }
            }

            NumberAnimation {
                id: dismissAnimation
                target: toastCard
                property: "x"
                to: toastList.width + toastWindow.slideOvershoot
                duration: toastWindow.slideOutDuration
                easing.type: Easing.InCubic
                onFinished: toastCard.removeFromModel()
            }

            // Auto-dismiss timer (pauses if mouse is hovering)
            Timer {
                id: dismissTimer
                interval: toastWindow.toastDuration
                running: !cardHover.containsMouse && !toastCard.dismissing
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

            // Keep the countdown inside the flat section of the rounded bottom
            // edge so it reads as part of the card rather than a separate line.
            Item {
                id: countdownTrack
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottomMargin: toastCard.border.width
                anchors.leftMargin: toastCard.radius
                anchors.rightMargin: toastCard.radius
                height: 2
                clip: true

                Rectangle {
                    id: countdownBar
                    property real remaining: 1

                    anchors.left: parent.left
                    width: countdownTrack.width * remaining
                    height: parent.height
                    radius: height / 2
                    color: Theme.colors.default_accent
                    opacity: 0.45

                    NumberAnimation on remaining {
                        from: 1
                        to: 0
                        duration: toastWindow.toastDuration
                        running: true
                        paused: cardHover.containsMouse
                    }
                }
            }
        }
    }
}
