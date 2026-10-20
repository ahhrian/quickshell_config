import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets

import "../../../shared"
import "../widget_gui"

Pill {
    id: root

    property var barWindow: null

    // Prefer a player that is actively playing. If everything is paused,
    // retain the first player that still exposes track metadata.
    readonly property var activePlayer: {
        const players = Mpris.players?.values ?? [];
        let metadataPlayer = null;

        for (const player of players) {
            if (!player)
                continue;

            if (player.isPlaying)
                return player;

            if (!metadataPlayer
                    && (player.trackTitle || player.trackArtist || player.trackArtUrl)) {
                metadataPlayer = player;
            }
        }

        return metadataPlayer ?? (players.length > 0 ? players[0] : null);
    }

    readonly property string mediaTitle: activePlayer?.trackTitle
                                               || activePlayer?.identity
                                               || "Nothing playing"
    readonly property string mediaArtist: activePlayer
                                               ? (activePlayer.trackArtist
                                                  || activePlayer.trackAlbumArtist
                                                  || "Unknown artist")
                                               : ""
    readonly property string artworkUrl: activePlayer?.trackArtUrl ?? ""
    readonly property bool canTogglePlayback: activePlayer?.canTogglePlaying ?? false

    opacity: mediaPopup.visible ? 0 : 1
    color: mediaHover.hovered && canTogglePlayback
           ? BarColors.hoverAndBorder
           : BarColors.surfaceBackground

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    ClippingRectangle {
        Layout.preferredWidth: 25
        Layout.preferredHeight: 25
        Layout.alignment: Qt.AlignVCenter
        radius: 6
        color: BarColors.deepBackground

        Image {
            id: artwork
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
            visible: artwork.status !== Image.Ready
            text: "music_note"
            color: BarColors.primaryText
            font.family: "Material Symbols Rounded"
            font.pixelSize: 17
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignVCenter
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
        visible: root.activePlayer !== null
        text: root.activePlayer?.isPlaying ? "pause" : "play_arrow"
        color: root.canTogglePlayback
               ? BarColors.primaryText
               : BarColors.mutedIcon
        font.family: "Material Symbols Rounded"
        font.pixelSize: 18
        Layout.alignment: Qt.AlignVCenter
    }

    HoverHandler {
        id: mediaHover
        parent: root
        cursorShape: root.canTogglePlayback ? Qt.PointingHandCursor : Qt.ArrowCursor
        onHoveredChanged: root.updatePreviewHover()
    }

    TapHandler {
        parent: root
        enabled: root.canTogglePlayback && !mediaPopup.visible
        acceptedButtons: Qt.LeftButton
        onTapped: root.activePlayer.togglePlaying()
    }

    MediaGui {
        id: mediaPopup
        barWindow: root.barWindow
        anchorItem: root
        player: root.activePlayer
        mediaTitle: root.mediaTitle
        mediaArtist: root.mediaArtist
        artworkUrl: root.artworkUrl
        compactWidth: root.width
        compactColor: root.color
    }

    Timer {
        id: previewOpenTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (mediaHover.hovered && !mediaPopup.visible)
                mediaPopup.openPopup();
        }
    }

    Timer {
        id: previewCloseTimer
        interval: 240
        repeat: false
        onTriggered: {
            if (!mediaHover.hovered && !mediaPopup.hovered)
                mediaPopup.closePopup();
        }
    }

    Connections {
        target: mediaPopup

        function onHoveredChanged() {
            root.updatePreviewHover();
        }

        function onVisibleChanged() {
            root.updatePreviewHover();
        }
    }

    function updatePreviewHover() {
        const overWidget = mediaHover.hovered;
        const overPopup = mediaPopup.hovered;

        if (overWidget || overPopup) {
            previewCloseTimer.stop();

            if (mediaPopup.visible && mediaPopup.closing)
                mediaPopup.openPopup();

            if (overWidget && !mediaPopup.visible && !previewOpenTimer.running)
                previewOpenTimer.start();
        } else {
            previewOpenTimer.stop();

            if (mediaPopup.visible && !mediaPopup.closing)
                previewCloseTimer.restart();
        }
    }
}
