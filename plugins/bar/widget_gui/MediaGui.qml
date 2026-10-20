import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import "../../../shared"

PopupWindow {
    id: root

    property var barWindow: null
    property var anchorItem: null
    property var player: null
    property string mediaTitle: "Nothing playing"
    property string mediaArtist: ""
    property string artworkUrl: ""
    property color compactColor: BarColors.surfaceBackground
    property real compactWidth: 260
    property real compactHeight: 33
    property real targetWidth: 370
    property real targetHeight: 270
    property real expansionProgress: 0
    property bool opening: false
    property bool closing: false

    readonly property int overshootPadding: 22
    readonly property real contentProgress: Math.max(0, Math.min(1, expansionProgress))
    readonly property real animatedWidth: compactWidth
                                                  + (targetWidth - compactWidth) * expansionProgress
    readonly property real animatedHeight: compactHeight
                                                   + (targetHeight - compactHeight) * expansionProgress
    readonly property bool hovered: popupHover.hovered
    readonly property bool hasDuration: (player?.lengthSupported ?? false) && player.length > 0
    readonly property real currentPosition: player?.positionSupported
                                                    ? Math.max(0, player.position)
                                                    : 0
    readonly property real totalDuration: hasDuration ? player.length : 0
    readonly property real playbackProgress: totalDuration > 0
                                                     ? Math.max(0, Math.min(1, currentPosition / totalDuration))
                                                     : 0

    signal closeFinished()

    implicitWidth: targetWidth + overshootPadding
    implicitHeight: targetHeight + overshootPadding
    color: BarColors.transparent
    visible: false
    grabFocus: false
    mask: Region { item: card }

    anchor.window: barWindow
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY
    anchor.onAnchoring: {
        if (anchorItem && barWindow) {
            const position = anchorItem.mapToItem(barWindow.contentItem, 0, 0);
            anchor.rect.x = Math.round(position.x + anchorItem.width - implicitWidth);
            anchor.rect.y = Math.round(position.y);
        }
    }

    function formatTime(value) {
        if (!isFinite(value) || value < 0)
            return "--:--";

        const seconds = Math.floor(value);
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const remainder = seconds % 60;
        const paddedSeconds = remainder < 10 ? "0" + remainder : remainder.toString();

        if (hours > 0) {
            const paddedMinutes = minutes < 10 ? "0" + minutes : minutes.toString();
            return hours + ":" + paddedMinutes + ":" + paddedSeconds;
        }

        return minutes + ":" + paddedSeconds;
    }

    function openPopup() {
        closeAnimation.stop();
        closing = false;
        opening = true;

        if (!visible) {
            expansionProgress = 0;
            visible = true;
        } else {
            openAnimation.restart();
        }
    }

    function closePopup() {
        if (!visible || closing)
            return;

        openAnimation.stop();
        opening = false;
        closing = true;
        closeAnimation.restart();
    }

    onVisibleChanged: {
        if (!visible) {
            openAnimation.stop();
            closeAnimation.stop();
            expansionProgress = 0;
            opening = false;
            closing = false;
            closeFinished();
        }
    }

    onBackingWindowVisibleChanged: {
        if (backingWindowVisible && visible && !closing)
            openAnimation.restart();
    }

    // Quickshell deliberately avoids continuously notifying position changes.
    // Only request frame-by-frame updates while the expanded player is visible.
    FrameAnimation {
        running: root.visible
                 && (root.player?.isPlaying ?? false)
                 && (root.player?.positionSupported ?? false)
        onTriggered: {
            if (root.player)
                root.player.positionChanged();
        }
    }

    NumberAnimation {
        id: openAnimation
        target: root
        property: "expansionProgress"
        to: 1
        duration: 320
        easing.type: Easing.OutBack
        easing.overshoot: 0.75
        onFinished: root.opening = false
    }

    NumberAnimation {
        id: closeAnimation
        target: root
        property: "expansionProgress"
        to: 0
        duration: 210
        easing.type: Easing.InOutCubic
        onFinished: root.visible = false
    }

    ClippingRectangle {
        id: card
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.animatedWidth
        height: root.animatedHeight
        radius: 16.5 + 5.5 * root.contentProgress
        color: root.compactColor
        border.width: 1
        border.color: Qt.rgba(BarColors.primaryText.r,
                              BarColors.primaryText.g,
                              BarColors.primaryText.b,
                              0.12 + 0.16 * root.contentProgress)

        Image {
            id: backgroundArtwork
            anchors.fill: parent
            source: root.artworkUrl
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 740
            sourceSize.height: 540
            visible: status === Image.Ready
            opacity: root.contentProgress
        }

        Rectangle {
            anchors.fill: parent
            visible: backgroundArtwork.status !== Image.Ready
            color: BarColors.deepBackground
            opacity: root.contentProgress

            Text {
                anchors.centerIn: parent
                text: "music_note"
                color: Qt.rgba(BarColors.primaryText.r,
                               BarColors.primaryText.g,
                               BarColors.primaryText.b, 0.14)
                font.family: "Material Symbols Rounded"
                font.pixelSize: 112
            }
        }

        Rectangle {
            anchors.fill: parent
            opacity: root.contentProgress
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#26000000" }
                GradientStop { position: 0.48; color: "#72000000" }
                GradientStop { position: 1.0; color: "#e6000000" }
            }
        }

        // A duplicate of the compact pill content makes the transition begin
        // at the exact size and visual state of the bar widget.
        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            width: root.compactWidth
            height: root.compactHeight
            opacity: 1 - root.contentProgress

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 11
                anchors.rightMargin: 11
                spacing: 3

                ClippingRectangle {
                    Layout.preferredWidth: 25
                    Layout.preferredHeight: 25
                    radius: 6
                    color: BarColors.deepBackground

                    Image {
                        id: compactArtwork
                        anchors.fill: parent
                        source: root.artworkUrl
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 96
                        sourceSize.height: 96
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: compactArtwork.status !== Image.Ready
                        text: "music_note"
                        color: BarColors.primaryText
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 17
                    }
                }

                RowLayout {
                    spacing: 4

                    Text {
                        text: root.mediaTitle
                        color: BarColors.primaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        Layout.maximumWidth: 145
                    }

                    Text {
                        visible: root.mediaArtist !== ""
                        text: "·"
                        color: BarColors.secondaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: 14
                    }

                    Text {
                        visible: root.mediaArtist !== ""
                        text: root.mediaArtist
                        color: BarColors.secondaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        Layout.maximumWidth: 95
                    }
                }

                Text {
                    visible: root.player !== null
                    text: root.player?.isPlaying ? "pause" : "play_arrow"
                    color: root.player?.canTogglePlaying
                           ? BarColors.primaryText
                           : BarColors.mutedIcon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                }
            }
        }

        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            width: root.targetWidth
            height: root.targetHeight
            opacity: root.contentProgress
            enabled: root.contentProgress > 0.85 && !root.closing

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 7

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: root.mediaTitle
                    color: "white"
                    font.family: "SF Pro Display"
                    font.pixelSize: 23
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.mediaArtist !== ""
                    text: root.mediaArtist
                    color: "#d9ffffff"
                    font.family: "SF Pro Display"
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    Layout.topMargin: 8

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 5
                        radius: 2.5
                        color: "#4dffffff"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * root.playbackProgress
                            radius: parent.radius
                            color: "white"
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.player?.positionSupported
                              ? root.formatTime(root.currentPosition)
                              : "--:--"
                        color: "#b3ffffff"
                        font.family: "SF Pro Display"
                        font.pixelSize: 11
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.hasDuration
                              ? root.formatTime(root.totalDuration)
                              : "--:--"
                        color: "#b3ffffff"
                        font.family: "SF Pro Display"
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    spacing: 22

                    Rectangle {
                        implicitWidth: 38
                        implicitHeight: 38
                        radius: 19
                        color: previousMouse.containsMouse ? "#3dffffff" : "#1fffffff"
                        opacity: root.player?.canGoPrevious ? 1 : 0.38

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            color: "white"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 24
                        }

                        MouseArea {
                            id: previousMouse
                            anchors.fill: parent
                            enabled: root.player?.canGoPrevious ?? false
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.player.previous()
                        }
                    }

                    Rectangle {
                        implicitWidth: 46
                        implicitHeight: 46
                        radius: 23
                        color: playMouse.containsMouse ? "#e6ffffff" : "white"
                        opacity: root.player?.canTogglePlaying ? 1 : 0.38

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.player?.isPlaying ? "pause" : "play_arrow"
                            color: "#e6000000"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 29
                        }

                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            enabled: root.player?.canTogglePlaying ?? false
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.player.togglePlaying()
                        }
                    }

                    Rectangle {
                        implicitWidth: 38
                        implicitHeight: 38
                        radius: 19
                        color: nextMouse.containsMouse ? "#3dffffff" : "#1fffffff"
                        opacity: root.player?.canGoNext ? 1 : 0.38

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "skip_next"
                            color: "white"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 24
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            enabled: root.player?.canGoNext ?? false
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.player.next()
                        }
                    }
                }
            }
        }
    }

    HoverHandler {
        id: popupHover
        parent: card
    }
}
