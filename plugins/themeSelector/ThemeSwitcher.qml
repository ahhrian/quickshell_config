import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

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
    readonly property real targetHeight: contentColumn.implicitHeight + 28
    readonly property real carouselCardWidth: 196
    readonly property real carouselCardHeight: 92
    readonly property real carouselGap: 18
    readonly property real carouselStride: carouselCardWidth + carouselGap
    readonly property real carouselSideDrop: 10
    readonly property int carouselDuration: 240
    readonly property int animationDuration: 260
    readonly property int closeDuration: 170
    readonly property real animationOvershoot: 0.8
    readonly property int overshootPadding: 12
    readonly property string applyThemeScript: (Quickshell.env("HOME") || "/home/aryan")
                                                + "/.config/quickshell/plugins/themeSelector/apply-theme.sh"
    property real expansionProgress: 0
    readonly property real contentProgress: Math.max(0, Math.min(1, expansionProgress))
    readonly property real animatedWidth: collapsedWidth + (targetWidth - collapsedWidth) * expansionProgress
    readonly property real animatedHeight: 33 + (targetHeight - 33) * expansionProgress

    signal openRequested()
    signal closeFinished()

    function themeIndex(themeId) {
        for (let i = 0; i < Theme.availableThemes.length; i++) {
            if (Theme.availableThemes[i].id === themeId)
                return i;
        }
        return 0;
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
        const count = Theme.availableThemes.length;
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

    function moveHighlight(offset) {
        const count = Theme.availableThemes.length;
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
        if (highlightedIndex < 0 || highlightedIndex >= Theme.availableThemes.length)
            return;

        const selectedTheme = Theme.availableThemes[highlightedIndex].id;
        let wallpaperPath = Wallpaper.wallpaperForTheme(selectedTheme);
        if (wallpaperPath.length === 0) {
            wallpaperPath = Wallpaper.firstWallpaperForTheme(selectedTheme);
            if (wallpaperPath.length > 0)
                Wallpaper.rememberWallpaper(selectedTheme, wallpaperPath);
        }

        Theme.setTheme(selectedTheme);
        themeApplyProcess.exec([
            "bash",
            root.applyThemeScript,
            selectedTheme,
            wallpaperPath
        ]);
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
        // The focus grab routes keyboard input to this window; item focus then
        // routes it to the card's Keys handlers.
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
        // Do not include the bar: Hyprland could otherwise choose it instead
        // of this popup as the keyboard-focused surface.
        windows: [root]
        onCleared: root.closePopup()
        onActiveChanged: {
            if (active)
                Qt.callLater(root.acquireKeyboardFocus);
        }
    }

    Process {
        id: themeApplyProcess

        onExited: (code, status) => {
            if (code !== 0)
                console.warn("Theme settings script exited with code", code);
        }
    }

    onVisibleChanged: {
        if (visible) {
            resetCarousel();
            highlightedIndex = themeIndex(Theme.currentTheme);
            expansionProgress = 0;
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
                Theme.availableThemes.length
            );
            root.carouselShift = 0;
            root.swipeDirection = 0;
            root.carouselAnimating = false;

            const nextDirection = root.queuedDirection;
            root.queuedDirection = 0;
            if (nextDirection !== 0)
                Qt.callLater(() => root.moveHighlight(nextDirection));
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

        Keys.onLeftPressed: root.moveHighlight(-1)
        Keys.onRightPressed: root.moveHighlight(1)
        Keys.onUpPressed: root.moveHighlight(-1)
        Keys.onDownPressed: root.moveHighlight(1)
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
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 10

                Text {
                    text: "Choose a theme"
                    color: Theme.colors.fg
                    font.family: "SF Pro Display"
                    font.pixelSize: 16
                    font.bold: true
                }

                Item {
                    id: carouselViewport

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.carouselCardHeight + root.carouselSideDrop + 4
                    clip: true

                    Repeater {
                        model: 5

                        Rectangle {
                            id: themeOption

                            required property int index
                            readonly property int relativePosition: index - 2
                            readonly property int themeModelIndex: root.wrappedIndex(
                                root.highlightedIndex + relativePosition,
                                Theme.availableThemes.length
                            )
                            readonly property var themeData: themeModelIndex >= 0
                                ? Theme.availableThemes[themeModelIndex]
                                : null
                            readonly property var themePalette: themeData
                                ? Theme.paletteFor(themeData.id)
                                : null
                            readonly property real screenPosition: relativePosition
                                + root.carouselShift / root.carouselStride
                            readonly property real centerWeight: Math.max(0, 1 - Math.abs(screenPosition))
                            readonly property bool selected: themeData
                                && Theme.currentTheme === themeData.id

                            width: root.carouselCardWidth
                            height: root.carouselCardHeight
                            x: carouselViewport.width / 2 - width / 2
                                + screenPosition * root.carouselStride
                            y: 2 + root.carouselSideDrop * Math.min(1, Math.abs(screenPosition))
                            z: 10 - Math.abs(screenPosition)
                            visible: root.slotVisible(relativePosition)
                            radius: 12
                            color: centerWeight > 0.5
                                ? Theme.colors.bg1
                                : (selected ? Theme.colors.bg2 : BarColors.transparent)
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

                            Column {
                                anchors.centerIn: parent
                                spacing: 9

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: themeOption.themeData ? themeOption.themeData.name : ""
                                    color: Theme.colors.fg
                                    font.family: "SF Pro Display"
                                    font.pixelSize: 14
                                    font.bold: themeOption.selected || themeOption.centerWeight > 0.5
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4

                                    Repeater {
                                        model: themeOption.themePalette ? [
                                            themeOption.themePalette.red,
                                            themeOption.themePalette.yellow,
                                            themeOption.themePalette.green,
                                            themeOption.themePalette.aqua,
                                            themeOption.themePalette.purple
                                        ] : []

                                        Rectangle {
                                            required property color modelData
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: modelData
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.carouselAnimating
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    if (themeOption.relativePosition < 0)
                                        root.moveHighlight(-1);
                                    else if (themeOption.relativePosition > 0)
                                        root.moveHighlight(1);
                                    else
                                        root.selectHighlighted();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
