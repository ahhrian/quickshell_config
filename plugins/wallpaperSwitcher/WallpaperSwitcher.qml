import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland

import "../../services"
import "../../shared"

PopupWindow {
    id: root

    property var barWindow: null
    property var anchorItem: null
    property real collapsedWidth: targetWidth
    property color collapsedColor: "#343434"
    property int highlightedIndex: 0
    property bool closing: false

    readonly property int targetWidth: 680
    readonly property int targetHeight: 382
    readonly property int animationDuration: 260
    readonly property int closeDuration: 170
    readonly property real animationOvershoot: 0.8
    readonly property int overshootPadding: 12
    readonly property int columnCount: 3
    readonly property string wallpaperDirectory: (Quickshell.env("HOME") || "/home/aryan")
                                                       + "/Pictures/Wallpapers/"
                                                       + (Theme.currentTheme === "everforest" ? "everforest" : "catpuccin")
    readonly property string themeDisplayName: Theme.currentTheme === "everforest" ? "Everforest" : "Catppuccin"

    property real expansionProgress: 0
    readonly property real contentProgress: Math.max(0, Math.min(1, expansionProgress))
    readonly property real animatedWidth: collapsedWidth + (targetWidth - collapsedWidth) * expansionProgress
    readonly property real animatedHeight: 33 + (targetHeight - 33) * expansionProgress

    signal openRequested()
    signal closeFinished()

    function initialiseHighlight() {
        if (wallpaperModel.count === 0) {
            highlightedIndex = -1;
            return;
        }

        const rememberedPath = Wallpaper.wallpaperForTheme(Theme.currentTheme);
        if (rememberedPath.length > 0) {
            for (let i = 0; i < wallpaperModel.count; i++) {
                const candidateUrl = wallpaperModel.get(i, "fileUrl").toString();
                const candidatePath = decodeURIComponent(candidateUrl.replace(/^file:\/\//, ""));
                if (candidatePath === rememberedPath) {
                    highlightedIndex = i;
                    return;
                }
            }
        }

        highlightedIndex = 0;
    }

    function moveHorizontal(offset) {
        const count = wallpaperModel.count;
        if (count === 0)
            return;
        highlightedIndex = (Math.max(0, highlightedIndex) + offset + count) % count;
    }

    function moveVertical(direction) {
        const count = wallpaperModel.count;
        if (count === 0)
            return;

        const current = Math.max(0, highlightedIndex);
        const next = current + direction * columnCount;
        if (next >= 0 && next < count)
            highlightedIndex = next;
    }

    function selectHighlighted() {
        if (highlightedIndex < 0 || highlightedIndex >= wallpaperModel.count)
            return;

        const wallpaperUrl = wallpaperModel.get(highlightedIndex, "fileUrl").toString();
        const wallpaperPath = decodeURIComponent(wallpaperUrl.replace(/^file:\/\//, ""));
        Wallpaper.selectWallpaper(Theme.currentTheme, wallpaperPath);
        closePopup();
    }

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

    function acquireKeyboardFocus() {
        card.forceActiveFocus();
    }

    function requestOpen() {
        if (visible)
            openPopup();
        else
            openRequested();
    }

    onHighlightedIndexChanged: {
        if (highlightedIndex >= 0)
            Qt.callLater(function() { wallpaperGrid.positionViewAtIndex(highlightedIndex, GridView.Contain); });
    }

    anchor.window: barWindow
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY
    anchor.onAnchoring: {
        if (anchorItem && barWindow) {
            const position = anchorItem.mapToItem(barWindow.contentItem, 0, 0);
            anchor.rect.x = Math.round(position.x + (anchorItem.width - implicitWidth) / 2);
            anchor.rect.y = Math.round(position.y);
        }
    }

    implicitWidth: targetWidth + 2 * overshootPadding
    implicitHeight: targetHeight + overshootPadding
    color: "transparent"
    visible: false
    grabFocus: false

    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        onCleared: root.closePopup()
        onActiveChanged: {
            if (active)
                Qt.callLater(root.acquireKeyboardFocus);
        }
    }

    FolderListModel {
        id: wallpaperModel
        folder: "file://" + root.wallpaperDirectory
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name

        onCountChanged: {
            if (root.visible)
                root.initialiseHighlight();
        }
    }

    onWallpaperDirectoryChanged: highlightedIndex = -1

    onVisibleChanged: {
        if (visible) {
            expansionProgress = 0;
            initialiseHighlight();
        } else {
            openAnimation.stop();
            closeAnimation.stop();
            focusGrab.active = false;
            expansionProgress = 0;
            closing = false;
        }
    }

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

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.animatedWidth
        height: root.animatedHeight
        radius: 18
        color: root.closing ? Qt.rgba(
            Theme.colors.bg0.r * root.contentProgress + root.collapsedColor.r * (1 - root.contentProgress),
            Theme.colors.bg0.g * root.contentProgress + root.collapsedColor.g * (1 - root.contentProgress),
            Theme.colors.bg0.b * root.contentProgress + root.collapsedColor.b * (1 - root.contentProgress), 1) : Theme.colors.bg0
        border.width: 1
        border.color: Qt.rgba(Theme.colors.bg2.r, Theme.colors.bg2.g, Theme.colors.bg2.b,
                              root.closing ? root.contentProgress : 1)
        clip: true
        focus: true

        Keys.onLeftPressed: root.moveHorizontal(-1)
        Keys.onRightPressed: root.moveHorizontal(1)
        Keys.onUpPressed: root.moveVertical(-1)
        Keys.onDownPressed: root.moveVertical(1)
        Keys.onReturnPressed: root.selectHighlighted()
        Keys.onEnterPressed: root.selectHighlighted()
        Keys.onEscapePressed: root.closePopup()

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

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.targetWidth
            height: root.targetHeight
            opacity: root.contentProgress
            enabled: !root.closing

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 9

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Choose a wallpaper"
                        color: Theme.colors.fg
                        font.family: "SF Pro Display"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.themeDisplayName
                        color: Theme.colors.default_accent
                        font.family: "SF Pro Display"
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                GridView {
                    id: wallpaperGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: wallpaperModel
                    cellWidth: width / root.columnCount
                    cellHeight: 142
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: root.highlightedIndex
                    highlightFollowsCurrentItem: true

                    delegate: Item {
                        id: wallpaperDelegate
                        required property int index
                        required property string fileName
                        required property url fileUrl

                        width: wallpaperGrid.cellWidth
                        height: wallpaperGrid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 12
                            color: wallpaperDelegate.index === root.highlightedIndex ? Theme.colors.bg1 : "transparent"
                            border.width: wallpaperDelegate.index === root.highlightedIndex ? 2 : 1
                            border.color: wallpaperDelegate.index === root.highlightedIndex
                                              ? Theme.colors.default_accent : Theme.colors.bg2

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 5
                                height: 101
                                radius: 8
                                color: Theme.colors.bg2
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: wallpaperDelegate.fileUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 420
                                    sourceSize.height: 210
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.bottomMargin: 5
                                text: wallpaperDelegate.fileName.replace(/\.[^.]+$/, "")
                                color: Theme.colors.fg
                                font.family: "SF Pro Display"
                                font.pixelSize: 12
                                font.bold: wallpaperDelegate.index === root.highlightedIndex
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.highlightedIndex = wallpaperDelegate.index
                                onClicked: {
                                    root.highlightedIndex = wallpaperDelegate.index;
                                    root.selectHighlighted();
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: wallpaperModel.count === 0
                        text: "No wallpapers found in " + root.wallpaperDirectory
                        color: Theme.colors.fg
                        opacity: 0.65
                        font.family: "SF Pro Display"
                        font.pixelSize: 13
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Arrow keys to navigate  •  Enter to apply  •  Esc to close"
                    color: Theme.colors.fg
                    opacity: 0.55
                    font.family: "SF Pro Display"
                    font.pixelSize: 11
                }
            }
        }
    }
}
