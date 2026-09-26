pragma Singleton
import QtQuick

import "colors"

QtObject {
    id: themeManager

    // 1. Instantiate the available palettes
    property QtObject catpuccin: Catpuccin {}
    //property QtObject gruvbox: Gruvbox {} 

    // 2. Define the active color palette (defaults to catpuccin)
    property QtObject colors: catpuccin

    // 3. Helper function to switch themes dynamically
    // function setTheme(themeName) {
    //     if (themeName === "gruvbox") {
    //         colors = gruvbox;
    //     } else {
    //         colors = catpuccin;
    //     }
    // }
}