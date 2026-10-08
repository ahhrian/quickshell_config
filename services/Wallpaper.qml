pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

import "../shared"

Singleton {
    id: root

    readonly property string wallpaperRoot: (Quickshell.env("HOME") || "/home/aryan")
                                               + "/Pictures/Wallpapers"
    readonly property var imageFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]

    property var history: ({})
    property bool historyLoaded: false
    property string pendingTheme: ""

    function normaliseTheme(themeName) {
        return themeName === "everforest" ? "everforest" : "catpuccin";
    }

    function pathFromUrl(url) {
        return decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
    }

    function wallpaperForTheme(themeName) {
        const theme = normaliseTheme(themeName);
        return history[theme] || "";
    }

    function modelForTheme(themeName) {
        return normaliseTheme(themeName) === "everforest" ? everforestWallpapers : catpuccinWallpapers;
    }

    function firstWallpaperForTheme(themeName) {
        const model = modelForTheme(themeName);
        if (model.count === 0)
            return "";
        return pathFromUrl(model.get(0, "fileUrl"));
    }

    function saveHistory() {
        historyFile.setText(JSON.stringify(history, null, 2));
    }

    function rememberWallpaper(themeName, wallpaperPath) {
        if (!wallpaperPath || wallpaperPath.length === 0)
            return;

        const theme = normaliseTheme(themeName);
        const updated = {};
        for (const key in history)
            updated[key] = history[key];
        updated[theme] = wallpaperPath;
        history = updated;
        saveHistory();
    }

    function applyWallpaper(wallpaperPath) {
        if (!wallpaperPath || wallpaperPath.length === 0)
            return;

        wallpaperProcess.exec([
            "awww", "img", wallpaperPath,
            "--transition-type", "wipe",
            "--transition-fps", "60"
        ]);
    }

    function selectWallpaper(themeName, wallpaperPath) {
        rememberWallpaper(themeName, wallpaperPath);
        applyWallpaper(wallpaperPath);
    }

    function applyForTheme(themeName) {
        const theme = normaliseTheme(themeName);
        if (!historyLoaded) {
            pendingTheme = theme;
            return;
        }

        let wallpaperPath = wallpaperForTheme(theme);
        if (wallpaperPath.length === 0) {
            wallpaperPath = firstWallpaperForTheme(theme);
            if (wallpaperPath.length === 0) {
                pendingTheme = theme;
                return;
            }
            rememberWallpaper(theme, wallpaperPath);
        }

        pendingTheme = "";
        applyWallpaper(wallpaperPath);
    }

    function loadHistory() {
        const contents = historyFile.text();
        if (contents && contents.trim().length > 0) {
            try {
                const parsed = JSON.parse(contents);
                history = parsed && typeof parsed === "object" ? parsed : ({});
            } catch (error) {
                console.warn("Could not parse wallpaper history:", error);
                history = ({});
            }
        }

        historyLoaded = true;
        if (pendingTheme.length > 0)
            applyForTheme(pendingTheme);
    }

    Component.onCompleted: loadHistory()

    FileView {
        id: historyFile
        path: Quickshell.statePath("wallpaper-history.json")
        preload: true
        blockLoading: true
        atomicWrites: true
        printErrors: false

    }

    FolderListModel {
        id: catpuccinWallpapers
        folder: "file://" + root.wallpaperRoot + "/catpuccin"
        nameFilters: root.imageFilters
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name

        onCountChanged: {
            if (root.pendingTheme === "catpuccin" && count > 0)
                root.applyForTheme("catpuccin");
        }
    }

    FolderListModel {
        id: everforestWallpapers
        folder: "file://" + root.wallpaperRoot + "/everforest"
        nameFilters: root.imageFilters
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name

        onCountChanged: {
            if (root.pendingTheme === "everforest" && count > 0)
                root.applyForTheme("everforest");
        }
    }

    Process {
        id: wallpaperProcess
    }
}
