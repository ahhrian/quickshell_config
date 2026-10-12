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
    property var pendingAction: null
    property bool closing: false

    readonly property int targetWidth: 520
    readonly property int targetHeight: 136
    readonly property int animationDuration: 260
    readonly property int closeDuration: 170
    readonly property real animationOvershoot: 0.8
    readonly property int overshootPadding: 12
    readonly property var actions: [
        {
            id: "suspend",
            label: "Suspend",
            icon: "bedtime",
            command: ["systemctl", "suspend"]
        },
        {
            id: "logout",
            label: "Logout",
            icon: "logout",
            command: ["hyprctl", "dispatch", "exit"]
        },
        {
            id: "restart",
            label: "Restart",
            icon: "restart_alt",
            command: ["systemctl", "reboot"]
        },
        {
            id: "shutdown",
            label: "Shutdown",
            icon: "power_settings_new",
            command: ["systemctl", "poweroff"]
        }
    ]

    property real expansionProgress: 0
    readonly property real contentProgress: Math.max(0, Math.min(1, expansionProgress))
    readonly property real animatedWidth: collapsedWidth
                                          + (targetWidth - collapsedWidth) * expansionProgress
    readonly property real animatedHeight: 33 + (targetHeight - 33) * expansionProgress

    signal openRequested()
    signal closeFinished()

    function moveHighlight(offset) {
        const count = actions.length;
        if (count > 0)
            highlightedIndex = (highlightedIndex + offset + count) % count;
    }

    function selectHighlighted() {
        if (highlightedIndex < 0 || highlightedIndex >= actions.length)
            return;

        pendingAction = actions[highlightedIndex];
        closePopup();
    }

    function executeAction(action) {
        if (!action || !action.command)
            return;

        actionProcess.command = action.command;
        actionProcess.running = true;
    }

    function openPopup() {
        if (visible) {
            closeAnimation.stop();
            closing = false;
            pendingAction = null;
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

    Process {
        id: actionProcess
    }

    onVisibleChanged: {
        if (visible) {
            highlightedIndex = 0;
            pendingAction = null;
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
            const action = root.pendingAction;
            root.pendingAction = null;
            root.visible = false;
            root.closeFinished();
            if (action)
                Qt.callLater(function() { root.executeAction(action); });
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
            BarColors.deepBackground.r * root.contentProgress
                + root.collapsedColor.r * (1 - root.contentProgress),
            BarColors.deepBackground.g * root.contentProgress
                + root.collapsedColor.g * (1 - root.contentProgress),
            BarColors.deepBackground.b * root.contentProgress
                + root.collapsedColor.b * (1 - root.contentProgress), 1)
            : BarColors.deepBackground
        border.width: 1
        border.color: Qt.rgba(
            BarColors.hoverAndBorder.r,
            BarColors.hoverAndBorder.g,
            BarColors.hoverAndBorder.b,
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

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: actionOption

                        required property int index
                        required property var modelData
                        readonly property bool highlighted: root.highlightedIndex === index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: highlighted
                               ? BarColors.hoverAndBorder
                               : (optionMouse.containsMouse
                                  ? BarColors.surfaceBackground
                                  : BarColors.transparent)

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: actionOption.modelData.icon
                                color: BarColors.primaryText
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 31
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: actionOption.modelData.label
                                color: BarColors.primaryText
                                font.family: "SF Pro Display"
                                font.pixelSize: 13
                                font.bold: actionOption.highlighted
                            }
                        }

                        MouseArea {
                            id: optionMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.highlightedIndex = actionOption.index
                            onClicked: {
                                root.highlightedIndex = actionOption.index;
                                root.selectHighlighted();
                            }
                        }
                    }
                }
            }
        }
    }
}
