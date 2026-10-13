pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

import "colors"

QtObject {
    id: themeManager

    // 1. Instantiate the available palettes
    property QtObject catpuccin: Catpuccin {}
    property QtObject everforest: Everforest {}
    property QtObject gruvbox: Gruvbox {}
    property FileView selectionFile: FileView {
        path: Quickshell.statePath("theme-selection.json")
        preload: true
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    readonly property var availableThemes: [
        { name: "Catppuccin", id: "catpuccin" },
        { name: "Everforest", id: "everforest" },
        { name: "Gruvbox", id: "gruvbox" }
    ]

    // 2. Define the active color palette. Catppuccin is used only when no
    // valid persisted selection exists yet.
    property QtObject colors: catpuccin
    property string currentTheme: "catpuccin"
    property bool selectionLoaded: false

    // 3. Helper function to switch themes dynamically
    function normaliseTheme(themeName) {
        if (themeName === "everforest" || themeName === "gruvbox")
            return themeName;
        return "catpuccin";
    }

    function paletteFor(themeName) {
        const normalised = normaliseTheme(themeName);
        if (normalised === "everforest")
            return everforest;
        if (normalised === "gruvbox")
            return gruvbox;
        return catpuccin;
    }

    function applyThemeSelection(themeName) {
        currentTheme = normaliseTheme(themeName);
        colors = paletteFor(currentTheme);
    }

    function saveThemeSelection() {
        selectionFile.setText(JSON.stringify({ theme: currentTheme }, null, 2));
    }

    function setTheme(themeName) {
        applyThemeSelection(themeName);
        saveThemeSelection();
    }

    function loadThemeSelection() {
        const contents = selectionFile.text();
        if (contents && contents.trim().length > 0) {
            try {
                const state = JSON.parse(contents);
                applyThemeSelection(state && state.theme ? state.theme : "catpuccin");
            } catch (error) {
                console.warn("Could not parse persisted theme selection:", error);
                applyThemeSelection("catpuccin");
            }
        } else {
            applyThemeSelection("catpuccin");
        }
        selectionLoaded = true;
    }

    Component.onCompleted: loadThemeSelection()
}
