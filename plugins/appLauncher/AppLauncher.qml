import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

import "../../services"
import "../../shared"

PopupWindow {
    id: root

    property var barWindow: null
    property var anchorItem: null
    property real collapsedWidth: targetWidth
    property color collapsedColor: BarColors.surfaceBackground
    property int highlightedIndex: -1
    property string query: ""
    property bool closing: false

    readonly property int targetWidth: 430
    readonly property int rowHeight: 46
    readonly property int rowSpacing: 6
    readonly property int visibleRowCount: 5
    readonly property int listHeight: rowHeight * visibleRowCount
                                      + rowSpacing * (visibleRowCount - 1)
    readonly property int targetHeight: 334
    readonly property int animationDuration: 260
    readonly property int closeDuration: 170
    readonly property real animationOvershoot: 0.8
    readonly property int overshootPadding: 12

    property real expansionProgress: 0
    readonly property real contentProgress: Math.max(0, Math.min(1, expansionProgress))
    readonly property real animatedWidth: collapsedWidth
                                          + (targetWidth - collapsedWidth) * expansionProgress
    readonly property real animatedHeight: 33 + (targetHeight - 33) * expansionProgress

    readonly property var filteredApplications: {
        const needle = query.trim().toLocaleLowerCase();
        const applications = DesktopEntries.applications.values;
        const matches = [];

        for (let i = 0; i < applications.length; i++) {
            const entry = applications[i];
            if (!entry || !entry.name)
                continue;

            if (needle.length === 0 || entry.name.toLocaleLowerCase().includes(needle))
                matches.push(entry);
        }

        matches.sort(function(a, b) {
            return a.name.localeCompare(b.name, undefined, { sensitivity: "base" });
        });
        return matches;
    }

    signal openRequested()
    signal closeFinished()

    function resetHighlight() {
        highlightedIndex = applicationModel.values.length > 0 ? 0 : -1;
        Qt.callLater(function() {
            if (highlightedIndex >= 0)
                applicationList.positionViewAtIndex(highlightedIndex, ListView.Beginning);
        });
    }

    function moveHighlight(offset) {
        const count = applicationModel.values.length;
        if (count === 0) {
            highlightedIndex = -1;
            return;
        }

        highlightedIndex = Math.max(0, Math.min(count - 1, highlightedIndex + offset));
    }

    function launchHighlighted() {
        if (highlightedIndex < 0 || highlightedIndex >= applicationModel.values.length)
            return;

        const entry = applicationModel.values[highlightedIndex];
        if (!entry)
            return;

        entry.execute();
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
        searchInput.forceActiveFocus();
    }

    function requestOpen() {
        if (visible)
            openPopup();
        else
            openRequested();
    }

    onHighlightedIndexChanged: {
        if (highlightedIndex >= 0) {
            Qt.callLater(function() {
                applicationList.positionViewAtIndex(highlightedIndex, ListView.Contain);
            });
        }
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

    ScriptModel {
        id: applicationModel
        values: root.filteredApplications
        onValuesChanged: root.resetHighlight()
    }

    onVisibleChanged: {
        if (visible) {
            query = "";
            expansionProgress = 0;
            resetHighlight();
        } else {
            openAnimation.stop();
            closeAnimation.stop();
            focusGrab.active = false;
            expansionProgress = 0;
            closing = false;
            query = "";
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
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 11
                    color: BarColors.surfaceBackground
                    // border.width: 1
                    // border.color: searchInput.activeFocus
                    //               ? BarColors.primaryText
                    //               : BarColors.hoverAndBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 9

                        Text {
                            text: "search"
                            color: BarColors.secondaryText
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 19
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            TextInput {
                                id: searchInput

                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: BarColors.primaryText
                                selectionColor: BarColors.hoverAndBorder
                                selectedTextColor: BarColors.primaryText
                                font.family: "SF Pro Display"
                                font.pixelSize: 14
                                text: root.query
                                selectByMouse: true
                                clip: true

                                onTextEdited: root.query = text

                                Keys.onUpPressed: root.moveHighlight(-1)
                                Keys.onDownPressed: root.moveHighlight(1)
                                Keys.onReturnPressed: root.launchHighlighted()
                                Keys.onEnterPressed: root.launchHighlighted()
                                Keys.onEscapePressed: root.closePopup()
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Search applications..."
                                color: BarColors.secondaryText
                                font.family: "SF Pro Display"
                                font.pixelSize: 14
                                visible: searchInput.text.length === 0
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.listHeight

                    ListView {
                        id: applicationList

                        anchors.fill: parent
                        model: applicationModel
                        spacing: root.rowSpacing
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: root.highlightedIndex

                        delegate: Rectangle {
                            id: applicationRow

                            required property int index
                            required property var modelData

                            readonly property bool highlighted: root.highlightedIndex === index

                            width: applicationList.width
                            height: root.rowHeight
                            radius: 10
                            color: highlighted
                                   ? BarColors.hoverAndBorder
                                   : (rowMouse.containsMouse
                                      ? BarColors.surfaceBackground
                                      : BarColors.transparent)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 11

                                IconImage {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    Layout.alignment: Qt.AlignVCenter
                                    source: applicationRow.modelData.icon
                                            ? Quickshell.iconPath(applicationRow.modelData.icon, true)
                                            : Quickshell.iconPath("application-x-executable", true)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: applicationRow.modelData.name
                                    color: BarColors.primaryText
                                    font.family: "SF Pro Display"
                                    font.pixelSize: 14
                                    font.bold: applicationRow.highlighted
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: rowMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.highlightedIndex = applicationRow.index
                                onClicked: {
                                    root.highlightedIndex = applicationRow.index;
                                    root.launchHighlighted();
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: applicationList.count > root.visibleRowCount
                                    ? ScrollBar.AsNeeded
                                    : ScrollBar.AlwaysOff
                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: 1.5
                                color: BarColors.hoverAndBorder
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.query.length > 0
                              ? "No matching applications"
                              : "No applications found"
                        color: BarColors.secondaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: 14
                        visible: applicationList.count === 0
                    }
                }
            }
        }
    }
}
