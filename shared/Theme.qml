pragma Singleton
import QtQuick

import "colors"

QtObject {
    id: themeManager

    // 1. Instantiate the available palettes
    property QtObject catpuccin: Catpuccin {}
    property QtObject everforest: Everforest {}
    //property QtObject gruvbox: Gruvbox {} 

    readonly property var availableThemes: [
        { name: "Catppuccin", id: "catpuccin" },
        { name: "Everforest", id: "everforest" }
    ]

    // 2. Define the active color palette (defaults to catpuccin)
    property QtObject colors: catpuccin
    property string currentTheme: "catpuccin"

    // 3. Helper function to switch themes dynamically
    function paletteFor(themeName) {
        return themeName === "everforest" ? everforest : catpuccin;
    }

    function setTheme(themeName) {
        currentTheme = themeName === "everforest" ? "everforest" : "catpuccin";
        colors = paletteFor(currentTheme);
    }
}
