import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

import "../../../shared"

Pill {
    id: root

    property var screen: null
    readonly property string screenName: screen?.name ?? ""

    // Width derives dynamically from layout plus padding for the left-most and right-most workspace pills.
    // Height is not overridden, allowing it to naturally follow the overall module size from Pill.qml (same as ClockWidget, PowerWidget, etc.).
    implicitWidth: layout.implicitWidth + 16
    Layout.preferredWidth: implicitWidth

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    // Refresh trigger for dynamic workspace reactivity
    property int refreshCounter: 0

    // Track urgent windows and workspaces
    property var urgentAddresses: new Set()
    property var urgentWorkspaces: new Set()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            root.refreshCounter++;
            const evName = event?.name ?? "";
            if (evName === "urgent") {
                const addr = (event.data || "").trim();
                if (addr) {
                    root.urgentAddresses.add(addr);
                    const tops = Hyprland.toplevels?.values ?? [];
                    const win = tops.find(t => t.address === addr || (t.address && addr.includes(t.address)));
                    if (win && win.workspace?.id) {
                        root.urgentWorkspaces.add(win.workspace.id);
                    }
                }
                Hyprland.refreshWorkspaces();
                Hyprland.refreshToplevels();
            }
        }
        function onFocusedWorkspaceChanged() {
            root.refreshCounter++;
            const focId = Hyprland.focusedWorkspace?.id;
            if (focId) {
                root.urgentWorkspaces.delete(focId);
                const tops = Hyprland.toplevels?.values ?? [];
                for (const t of tops) {
                    if (t.workspace?.id === focId && t.address) {
                        root.urgentAddresses.delete(t.address);
                    }
                }
            }
        }
        function onFocusedMonitorChanged() {
            root.refreshCounter++;
        }
    }

    // Dynamically computed list of workspace IDs for this screen
    readonly property var workspaceIds: {
        const _trigger = refreshCounter;
        const screensCount = Quickshell.screens?.length ?? 1;
        const focusedWs = Hyprland.focusedWorkspace?.id;
        const focusedMon = Hyprland.focusedMonitor?.name;
        const wss = Hyprland.workspaces?.values ?? [];
        const tops = Hyprland.toplevels?.values ?? [];

        return computeWorkspaceIds(screen, screensCount);
    }

    function computeWorkspaceIds(screenObj, numScreens) {
        const currentScreenName = screenObj?.name ?? "";
        const isBuiltin = currentScreenName.startsWith("eDP");
        const isExternal = (numScreens > 1) && !isBuiltin;

        // Base range:
        // External monitor (when >1 screen): Workspaces 6..10
        // Laptop / single monitor: Workspaces 1..5
        const baseStart = isExternal ? 6 : 1;
        const baseCount = 5;
        const baseEnd = baseStart + baseCount - 1;

        const wsSet = new Set();
        for (let i = 0; i < baseCount; i++) {
            wsSet.add(baseStart + i);
        }

        const activeIds = [];

        // Check active workspaces registered in Hyprland
        const wss = Hyprland.workspaces?.values ?? [];
        for (const w of wss) {
            if (!w || !w.id || w.id <= 0) continue;

            let belongsToThis = false;
            if (numScreens <= 1) {
                belongsToThis = true;
            } else if (w.monitor && w.monitor.name) {
                belongsToThis = (w.monitor.name === currentScreenName);
            } else {
                belongsToThis = isExternal ? (w.id >= 6) : (w.id <= 5);
            }

            if (belongsToThis) {
                activeIds.push(w.id);
            }
        }

        // Check active toplevel windows
        const toplevels = Hyprland.toplevels?.values ?? [];
        for (const top of toplevels) {
            const wid = top.workspace?.id;
            if (!wid || wid <= 0) continue;

            let belongsToThis = false;
            if (numScreens <= 1) {
                belongsToThis = true;
            } else {
                const winMonName = top.monitor?.name || top.workspace?.monitor?.name;
                if (winMonName) {
                    belongsToThis = (winMonName === currentScreenName);
                } else {
                    belongsToThis = isExternal ? (wid >= 6) : (wid <= 5);
                }
            }

            if (belongsToThis) {
                activeIds.push(wid);
            }
        }

        // Check currently focused workspace
        const focusedWs = Hyprland.focusedWorkspace?.id;
        if (focusedWs && focusedWs > 0) {
            const focusedMon = Hyprland.focusedMonitor?.name;
            if (numScreens <= 1 || focusedMon === currentScreenName) {
                activeIds.push(focusedWs);
            }
        }

        // Add active workspaces beyond baseEnd
        let maxActive = baseEnd;
        for (const id of activeIds) {
            if (id > maxActive) {
                maxActive = id;
            }
            wsSet.add(id);
        }

        // If maxActive is within contiguous range (up to baseEnd + 10), fill in-between
        if (maxActive > baseEnd && maxActive <= baseEnd + 10) {
            for (let i = baseEnd + 1; i <= maxActive; i++) {
                wsSet.add(i);
            }
        }

        const arr = Array.from(wsSet);
        arr.sort((a, b) => a - b);
        return arr;
    }

    // Watch and load workspaceIcons.jsonc
    FileView {
        id: iconConfigFile
        path: Qt.resolvedUrl("../workspaceIcons.jsonc")
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
    }

    // Parsed window-rewrite rules from workspaceIcons.jsonc
    readonly property var rewriteMap: {
        const raw = iconConfigFile.text();
        if (!raw) return {};
        try {
            const clean = raw.replace(/\/\/.*$/gm, "").replace(/\/\*[\s\S]*?\*\//g, "").replace(/,\s*([\]}])/g, "$1");
            const parsed = JSON.parse(clean);
            return parsed["window-rewrite"] || {};
        } catch (e) {
            console.warn("Failed to parse workspaceIcons.jsonc:", e);
            return {};
        }
    }

    // Lookup function to find a Nerd Font icon in rewriteMap for a given window
    function findNerdFontIcon(w) {
        if (!w || !rewriteMap) return "";
        const rawClass = w.wayland?.appId || w.lastIpcObject?.class || w.lastIpcObject?.initialClass || "";
        const title = w.lastIpcObject?.title || w.title || "";
        const initialTitle = w.lastIpcObject?.initialTitle || "";

        const testStrings = [rawClass, title, initialTitle].filter(s => s && s.length > 0);
        if (testStrings.length === 0) return "";

        // 1. Exact match on class (case-insensitive)
        const lowerRaw = rawClass.toLowerCase();
        for (const key of Object.keys(rewriteMap)) {
            if (key.toLowerCase() === lowerRaw) {
                return rewriteMap[key];
            }
        }

        // 2. Regex / substring match on class, title, initialTitle
        for (const key of Object.keys(rewriteMap)) {
            try {
                const re = new RegExp(key, "i");
                for (const str of testStrings) {
                    if (re.test(str)) {
                        return rewriteMap[key];
                    }
                }
            } catch (e) {
                const lk = key.toLowerCase();
                for (const str of testStrings) {
                    if (str.toLowerCase().includes(lk)) {
                        return rewriteMap[key];
                    }
                }
            }
        }

        return "";
    }

    // Fallback function to resolve natural app icon from system desktop entries or theme
    function resolveNaturalAppIcon(w) {
        const rawId = w.wayland?.appId || w.lastIpcObject?.class || w.lastIpcObject?.initialClass || "";
        if (!rawId) return "";

        // 1. Quickshell heuristic desktop entry lookup (matches StartupWMClass / desktop files)
        const entry = DesktopEntries.heuristicLookup(rawId) || DesktopEntries.heuristicLookup(rawId.toLowerCase());
        if (entry && entry.icon) {
            const p = Quickshell.iconPath(entry.icon, true);
            if (p) return p;
        }

        // 2. Direct icon name lookup (raw and lowercase)
        const id = rawId.toLowerCase();
        const pDirect = Quickshell.iconPath(rawId, true) || Quickshell.iconPath(id, true);
        if (pDirect) return pDirect;

        // 3. Known aliases where window class != icon name
        if (id.includes("code")) {
            const pCode = Quickshell.iconPath("com.visualstudio.code", true) || Quickshell.iconPath("vscode", true);
            if (pCode) return pCode;
        }
        if (id.includes("telegram")) {
            const pTg = Quickshell.iconPath("telegram", true) || Quickshell.iconPath("telegram-desktop", true) || Quickshell.iconPath("org.telegram.desktop", true);
            if (pTg) return pTg;
        }
        if (id.includes("thunar") || id.includes("nautilus") || id.includes("dolphin") || id.includes("nemo")) {
            const pFm = Quickshell.iconPath("system-file-manager", true) || Quickshell.iconPath("org.gnome.Nautilus", true) || Quickshell.iconPath("Thunar", true);
            if (pFm) return pFm;
        }

        // 4. Reverse-DNS segment extraction (e.g. org.telegram.desktop -> telegram)
        const parts = id.split(".");
        for (let i = parts.length - 1; i >= 0; i--) {
            const part = parts[i];
            if (part && part !== "desktop" && part !== "org" && part !== "com") {
                const pPart = Quickshell.iconPath(part, true);
                if (pPart) return pPart;
            }
        }

        // 5. Fallback generic app icon
        return Quickshell.iconPath("application-x-executable", true)
            || Quickshell.iconPath("system-run", true)
            || "";
    }

    // Layout for individual Workspace Pills
    RowLayout {
        id: layout
        Layout.alignment: Qt.AlignCenter
        spacing: 5

        readonly property color unfocused_color: Theme.colors.bg2
        readonly property color focused_color: Theme.colors.default_accent
        readonly property int animDuration: 450
        readonly property var animEasing: Easing.OutCubic
        readonly property int focused_extra_width: 18

        Repeater {
            model: root.workspaceIds

            delegate: Pill {
                id: wsPill
                required property int modelData

                readonly property int wsId: modelData
                readonly property bool isFocused: Hyprland.focusedWorkspace?.id === wsId

                // Urgent state for unfocused workspaces
                readonly property bool isUrgent: {
                    const _ = root.refreshCounter;
                    if (isFocused) return false;

                    // 1. Direct workspace urgency from Hyprland
                    const wsObj = Hyprland.workspaces?.values?.find(w => w.id === wsId);
                    if (wsObj?.urgent) return true;

                    // 2. Window/toplevel urgency
                    for (const w of workspaceApps) {
                        if (w?.urgent) return true;
                        if (w?.address && root.urgentAddresses.has(w.address)) return true;
                    }

                    // 3. Tracked urgent workspace IDs from raw Hyprland events
                    if (root.urgentWorkspaces.has(wsId)) return true;

                    return false;
                }

                // Width expansion with smooth shrink/grow transition
                Layout.preferredWidth: implicitWidth + (isFocused ? layout.focused_extra_width : 0)

                // Dynamically size individual workspace pills relative to overall module height
                implicitHeight: root.implicitHeight - 8
                Layout.preferredHeight: implicitHeight
                Layout.alignment: Qt.AlignVCenter

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: layout.animDuration
                        easing.type: layout.animEasing
                    }
                }

                // Apps open on this workspace
                readonly property var workspaceApps: {
                    const toplevels = Hyprland.toplevels?.values ?? [];
                    return toplevels.filter(w => w.workspace?.id === wsId);
                }

                readonly property bool isOccupied: workspaceApps.length > 0

                // Resolve open apps: Nerd Font icon from workspaceIcons.jsonc or fallback to natural app icon
                readonly property var openApps: {
                    const _ = root.rewriteMap; // Bind reactivity to config file changes
                    const list = [];
                    for (const w of workspaceApps) {
                        const nerd = root.findNerdFontIcon(w);
                        if (nerd) {
                            list.push({ isNerdFont: true, icon: nerd });
                        } else {
                            const nat = root.resolveNaturalAppIcon(w);
                            if (nat) {
                                list.push({ isNerdFont: false, icon: nat });
                            }
                        }
                    }
                    return list;
                }

                color: isFocused ? layout.focused_color : layout.unfocused_color

                Behavior on color {
                    ColorAnimation {
                        duration: layout.animDuration
                        easing.type: layout.animEasing
                    }
                }

                // Workspace content: Workspace ID + List of Open App Icons
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 5

                    Text {
                        text: wsPill.wsId.toString()
                        color: wsPill.isFocused ? Theme.colors.bg0 : (wsPill.isUrgent ? Theme.colors.red : Theme.colors.fg)
                        font.family: "SF Pro Display"
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: wsPill.openApps.length > 0 ? 3 : 5

                        Behavior on color {
                            ColorAnimation {
                                duration: layout.animDuration
                                easing.type: layout.animEasing
                            }
                        }
                    }

                    // App icons for occupied workspaces
                    Repeater {
                        model: wsPill.openApps

                        delegate: Item {
                            id: appItem
                            required property var modelData

                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: modelData.isNerdFont ? nerdText.implicitWidth : iconImg.implicitWidth
                            implicitHeight: modelData.isNerdFont ? nerdText.implicitHeight : iconImg.implicitHeight

                            Text {
                                id: nerdText
                                anchors.centerIn: parent
                                visible: modelData.isNerdFont
                                text: modelData.isNerdFont ? modelData.icon : ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: wsPill.isFocused ? Theme.colors.bg0 : (wsPill.isUrgent ? Theme.colors.red : Theme.colors.fg)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: layout.animDuration
                                        easing.type: layout.animEasing
                                    }
                                }
                            }

                            IconImage {
                                id: iconImg
                                anchors.centerIn: parent
                                visible: !modelData.isNerdFont
                                implicitWidth: 16
                                implicitHeight: 16
                                source: modelData.isNerdFont ? "" : modelData.icon
                            }

                            Rectangle {
                                anchors.top: iconImg.top
                                anchors.right: iconImg.right
                                anchors.topMargin: -2
                                anchors.rightMargin: -2
                                width: 6
                                height: 6
                                radius: 3
                                color: Theme.colors.red
                                visible: !modelData.isNerdFont && wsPill.isUrgent
                            }
                        }
                    }

                    // Fallback circle when workspace is empty or has no apps open
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        width: 5
                        height: 5
                        radius: 2.5
                        visible: wsPill.openApps.length === 0
                        color: wsPill.isFocused ? Theme.colors.bg0 : (wsPill.isUrgent ? Theme.colors.red : Theme.colors.fg)

                        Behavior on color {
                            ColorAnimation {
                                duration: layout.animDuration
                                easing.type: layout.animEasing
                            }
                        }
                    }
                }

                MouseArea {
                    parent: wsPill
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsPill.wsId} })`)
                }
            }
        }
    }
}