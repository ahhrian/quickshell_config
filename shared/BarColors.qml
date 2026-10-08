pragma Singleton

import QtQuick

QtObject {
    // No-fill state.
    readonly property color transparent: "transparent"

    // Three background states used throughout the bar and its popups.
    readonly property color deepBackground: "#202020"
    readonly property color surfaceBackground: "#303030"
    readonly property color hoverAndBorder: "#3d3d3d"

    // Three text roles: normal content, de-emphasized content, and text on accents.
    readonly property color primaryText: "#e8e8e8"
    readonly property color secondaryText: "#909090"
    readonly property color textOnAccent: deepBackground

    // Icons that remain visible while representing a muted state.
    readonly property color mutedIcon: Qt.rgba(primaryText.r, primaryText.g, primaryText.b, 0.4)
}
