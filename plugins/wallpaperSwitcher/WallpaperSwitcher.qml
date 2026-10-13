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
    property color collapsedColor: BarColors.surfaceBackground
    property int highlightedIndex: 0
    property bool closing: false
    property real carouselShift: 0
    property int swipeDirection: 0
    property int queuedDirection: 0
    property bool carouselAnimating: false

    readonly property int targetWidth: 680
    readonly property int targetHeight: 382
    readonly property real carouselCardWidth: 198
    readonly property real carouselCardHeight: 220
    readonly property real carouselGap: 16
    readonly property real carouselStride: carouselCardWidth + carouselGap
    readonly property real carouselSideDrop: 14
    readonly property int carouselDuration: 250
    readonly property int animationDuration: 260
    readonly property int closeDuration: 170
    readonly property real animationOvershoot: 0.8
    readonly property int overshootPadding: 12
    readonly property string wallpaperDirectory: (Quickshell.env("HOME") || "/home/aryan")
                                                       + "/Pictures/Wallpapers/"
                                                       + Theme.currentTheme
    readonly property string themeDisplayName: displayNameForTheme(Theme.currentTheme)

    property real expansionProgress: 0
    readonly property real contentProgress: Math.max(0, Math.min(1, expansionProgress))
    readonly property real animatedWidth: collapsedWidth + (targetWidth - collapsedWidth) * expansionProgress
    readonly property real animatedHeight: 33 + (targetHeight - 33) * expansionProgress

    signal openRequested()
    signal closeFinished()

    function displayNameForTheme(themeId) {
        for (let i = 0; i < Theme.availableThemes.length; i++) {
            if (Theme.availableThemes[i].id === themeId)
                return Theme.availableThemes[i].name;
        }
        return themeId;
    }

    function wrappedIndex(index, count) {
        if (count <= 0)
            return -1;
        return ((index % count) + count) % count;
    }

    function resetCarousel() {
        carouselAnimation.stop();
        carouselShift = 0;
        swipeDirection = 0;
        queuedDirection = 0;
        carouselAnimating = false;
    }

    function slotVisible(relativePosition) {
        const count = wallpaperModel.count;
        if (count <= 0)
            return false;
        if (count === 1)
            return relativePosition === 0;
        if (count === 2) {
            if (carouselAnimating)
                return relativePosition === 0 || relativePosition === swipeDirection;
            return relativePosition === 0 || relativePosition === 1;
        }
        return true;
    }

    function initialiseHighlight() {
        resetCarousel();

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
        if (count <= 1)
            return;

        const direction = offset < 0 ? -1 : 1;
        if (carouselAnimating) {
            queuedDirection = direction;
            return;
        }

        swipeDirection = direction;
        queuedDirection = 0;
        carouselShift = 0;
        carouselAnimating = true;
        carouselAnimation.to = -direction * carouselStride;
        carouselAnimation.restart();
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
    color: BarColors.transparent
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

    onWallpaperDirectoryChanged: {
        resetCarousel();
        highlightedIndex = -1;
    }

    onVisibleChanged: {
        if (visible) {
            resetCarousel();
            expansionProgress = 0;
            initialiseHighlight();
        } else {
            resetCarousel();
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

    NumberAnimation {
        id: carouselAnimation
        target: root
        property: "carouselShift"
        duration: root.carouselDuration
        easing.type: Easing.OutQuart

        onFinished: {
            const completedDirection = root.swipeDirection;
            root.highlightedIndex = root.wrappedIndex(
                root.highlightedIndex + completedDirection,
                wallpaperModel.count
            );
            root.carouselShift = 0;
            root.swipeDirection = 0;
            root.carouselAnimating = false;

            const nextDirection = root.queuedDirection;
            root.queuedDirection = 0;
            if (nextDirection !== 0)
                Qt.callLater(() => root.moveHorizontal(nextDirection));
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
        Keys.onUpPressed: root.moveHorizontal(-1)
        Keys.onDownPressed: root.moveHorizontal(1)
        Keys.onReturnPressed: root.selectHighlighted()
        Keys.onEnterPressed: root.selectHighlighted()
        Keys.onEscapePressed: root.closePopup()

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (33 - height) / 2
            text: Time.time
            color: BarColors.primaryText
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

                Item {
                    id: wallpaperCarousel

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: wallpaperModel.count === 0
                        text: "No wallpapers found in " + root.wallpaperDirectory
                        color: Theme.colors.fg
                        opacity: 0.65
                        font.family: "SF Pro Display"
                        font.pixelSize: 13
                    }

                    Repeater {
                        model: 5

                        Rectangle {
                            id: wallpaperOption

                            required property int index
                            readonly property int relativePosition: index - 2
                            readonly property int wallpaperIndex: root.wrappedIndex(
                                root.highlightedIndex + relativePosition,
                                wallpaperModel.count
                            )
                            readonly property string wallpaperName: wallpaperIndex >= 0
                                ? wallpaperModel.get(wallpaperIndex, "fileName")
                                : ""
                            readonly property url wallpaperUrl: wallpaperIndex >= 0
                                ? wallpaperModel.get(wallpaperIndex, "fileUrl")
                                : ""
                            readonly property real screenPosition: relativePosition
                                + root.carouselShift / root.carouselStride
                            readonly property real centerWeight: Math.max(0, 1 - Math.abs(screenPosition))

                            width: root.carouselCardWidth
                            height: root.carouselCardHeight
                            x: wallpaperCarousel.width / 2 - width / 2
                                + screenPosition * root.carouselStride
                            y: Math.max(2, (wallpaperCarousel.height - height - root.carouselSideDrop) / 2)
                                + root.carouselSideDrop * Math.min(1, Math.abs(screenPosition))
                            z: 10 - Math.abs(screenPosition)
                            visible: root.slotVisible(relativePosition)
                            radius: 12
                            color: centerWeight > 0.5 ? Theme.colors.bg1 : BarColors.transparent
                            border.width: centerWeight > 0.5 ? 2 : 1
                            border.color: Qt.rgba(
                                Theme.colors.bg2.r * (1 - centerWeight)
                                    + Theme.colors.default_accent.r * centerWeight,
                                Theme.colors.bg2.g * (1 - centerWeight)
                                    + Theme.colors.default_accent.g * centerWeight,
                                Theme.colors.bg2.b * (1 - centerWeight)
                                    + Theme.colors.default_accent.b * centerWeight,
                                1
                            )

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 5
                                height: parent.height - 36
                                radius: 8
                                color: Theme.colors.bg2
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: wallpaperOption.wallpaperUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 420
                                    sourceSize.height: 260
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.bottomMargin: 6
                                text: wallpaperOption.wallpaperName.replace(/\.[^.]+$/, "")
                                color: Theme.colors.fg
                                font.family: "SF Pro Display"
                                font.pixelSize: 12
                                font.bold: wallpaperOption.centerWeight > 0.5
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.carouselAnimating
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    if (wallpaperOption.relativePosition < 0)
                                        root.moveHorizontal(-1);
                                    else if (wallpaperOption.relativePosition > 0)
                                        root.moveHorizontal(1);
                                    else
                                        root.selectHighlighted();
                                }
                            }
                        }
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
