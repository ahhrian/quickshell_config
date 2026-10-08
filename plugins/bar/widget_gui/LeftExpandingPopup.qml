import QtQuick
import Quickshell
import Quickshell.Hyprland

import "../../../shared"

PopupWindow {
    id: root

    property var barWindow: null
    property var anchorItem: null
    property real targetWidth: 380
    property real targetHeight: 300
    property real maximumHeight: 540
    property real compactSize: 33
    property string compactIcon: ""
    property color compactIconColor: BarColors.primaryText
    property color compactColor: BarColors.surfaceBackground
    property color borderColor: BarColors.hoverAndBorder
    property int animationDuration: 260
    property int closeDuration: 170
    property real animationOvershoot: 0.8
    property bool closing: false
    property bool opening: false
    property real expansionProgress: 0
    property real expandedHeight: targetHeight
    readonly property real contentProgress: Math.max(0, Math.min(1, expansionProgress))
    readonly property real animatedWidth: compactSize + (targetWidth - compactSize) * expansionProgress
    readonly property real animatedHeight: compactSize + (expandedHeight - compactSize) * expansionProgress
    readonly property int overshootPadding: 20
    default property alias popupContent: contentHost.data

    signal aboutToOpen()
    signal closeFinished()

    // Only the card moves. The native surface and its top-right anchor stay fixed.
    implicitWidth: targetWidth + overshootPadding
    implicitHeight: maximumHeight + overshootPadding
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

    function openPopup() {
        if (visible) {
            closeAnimation.stop();
            closing = false;
            opening = true;
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
        resizeAnimation.stop();
        opening = false;
        closing = true;
        focusGrab.active = false;
        closeAnimation.restart();
    }

    function togglePopup() {
        if (visible && !closing)
            closePopup();
        else
            openPopup();
    }

    function acquireKeyboardFocus() {
        // The focus grab routes keyboard input to this window; item focus then
        // routes it to the card's Keys handlers.
        card.forceActiveFocus();
    }

    onVisibleChanged: {
        if (visible) {
            opening = true;
            expansionProgress = 0;
            aboutToOpen();
            expandedHeight = targetHeight;
        } else {
            openAnimation.stop();
            closeAnimation.stop();
            resizeAnimation.stop();
            focusGrab.active = false;
            expansionProgress = 0;
            opening = false;
            closing = false;
            closeFinished();
        }
    }

    onBackingWindowVisibleChanged: {
        if (backingWindowVisible && visible && !closing) {
            expandedHeight = targetHeight;
            focusGrab.active = true;
            openAnimation.restart();
        }
    }

    // Scan results can change the natural height. Defer that resize until the
    // opening finishes, preserving a fixed diagonal trajectory during the reveal.
    onTargetHeightChanged: {
        if (!opening && !closing)
            expandedHeight = targetHeight;
    }

    Behavior on expandedHeight {
        enabled: root.visible && !root.opening && !root.closing
        NumberAnimation { id: resizeAnimation; duration: 160; easing.type: Easing.OutCubic }
    }

    // Explicit data keeps these implementation objects out of popupContent.
    data: [
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
        },
        NumberAnimation {
            id: openAnimation
            target: root
            property: "expansionProgress"
            to: 1
            duration: root.animationDuration
            easing.type: Easing.OutBack
            easing.overshoot: root.animationOvershoot
            onFinished: {
                root.opening = false;
                root.expandedHeight = root.targetHeight;
            }
        },
        NumberAnimation {
            id: closeAnimation
            target: root
            property: "expansionProgress"
            to: 0
            duration: root.closeDuration
            easing.type: Easing.InOutCubic
            onFinished: root.visible = false
        },
        Rectangle {
            id: card
            anchors.top: parent.top
            anchors.right: parent.right
            width: root.animatedWidth
            height: root.animatedHeight
            radius: 16.5
            color: Qt.rgba(
                BarColors.surfaceBackground.r * root.contentProgress + root.compactColor.r * (1 - root.contentProgress),
                BarColors.surfaceBackground.g * root.contentProgress + root.compactColor.g * (1 - root.contentProgress),
                BarColors.surfaceBackground.b * root.contentProgress + root.compactColor.b * (1 - root.contentProgress), 1)
            border.width: 1
            border.color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.contentProgress)
            clip: true
            focus: true
            Keys.onEscapePressed: root.closePopup()

            Item {
                width: root.compactSize
                height: root.compactSize
                anchors.top: parent.top
                anchors.right: parent.right
                opacity: 1 - root.contentProgress
                Text {
                    anchors.centerIn: parent
                    text: root.compactIcon
                    color: root.compactIconColor
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                }
            }

            Item {
                id: contentHost
                anchors.top: parent.top
                anchors.right: parent.right
                width: root.targetWidth
                height: root.expandedHeight
                opacity: root.contentProgress
                enabled: !root.closing
            }
        }
    ]
}
