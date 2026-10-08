import QtQuick
import QtQuick.Layouts
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

    readonly property int targetWidth: 386
    readonly property real targetHeight: contentColumn.implicitHeight + 28
    readonly property int animationDuration: 260
    readonly property int closeDuration: 170
    readonly property real animationOvershoot: 0.8
    readonly property int overshootPadding: 12
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

    function moveHighlight(offset) {
        const count = Theme.availableThemes.length;
        if (count > 0)
            highlightedIndex = (highlightedIndex + offset + count) % count;
    }

    function selectHighlighted() {
        if (highlightedIndex < 0 || highlightedIndex >= Theme.availableThemes.length)
            return;
        const selectedTheme = Theme.availableThemes[highlightedIndex].id;
        Theme.setTheme(selectedTheme);
        Wallpaper.applyForTheme(selectedTheme);
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
    color: "transparent"
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

    onVisibleChanged: {
        if (visible) {
            highlightedIndex = themeIndex(Theme.currentTheme);
            expansionProgress = 0;
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: Theme.availableThemes

                        Rectangle {
                            id: themeOption
                            required property int index
                            required property var modelData
                            readonly property var themePalette: Theme.paletteFor(modelData.id)
                            readonly property bool selected: Theme.currentTheme === modelData.id
                            readonly property bool highlighted: root.highlightedIndex === index

                            Layout.fillWidth: true
                            Layout.preferredHeight: 88
                            radius: 12
                            color: selected ? Theme.colors.bg2 : (highlighted ? Theme.colors.bg1 : "transparent")
                            border.width: highlighted ? 2 : 1
                            border.color: highlighted ? Theme.colors.default_accent : Theme.colors.bg2

                            Column {
                                anchors.centerIn: parent
                                spacing: 9

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: themeOption.modelData.name
                                    color: Theme.colors.fg
                                    font.family: "SF Pro Display"
                                    font.pixelSize: 14
                                    font.bold: themeOption.selected || themeOption.highlighted
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4

                                    Repeater {
                                        model: [
                                            themeOption.themePalette.red,
                                            themeOption.themePalette.yellow,
                                            themeOption.themePalette.green,
                                            themeOption.themePalette.aqua,
                                            themeOption.themePalette.purple
                                        ]

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
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.highlightedIndex = themeOption.index
                                onClicked: {
                                    root.highlightedIndex = themeOption.index;
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
