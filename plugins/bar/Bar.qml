import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../shared"
import "../lockScreen"
import "components"

Scope {
    id: root

    // Process-wide secure session lock. Its own IPC handler is intentionally
    // outside the per-screen Variants so there is exactly one lock owner.
    LockScreen {}

    property var clockWidgets: []

    function refreshMonitorState() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
    }

    // Fullscreen can remain active across DPMS/suspend, without another
    // fullscreen event when the layer surfaces are mapped on wake.
    IpcHandler {
        target: "bar"

        function refresh(): void { root.refreshMonitorState(); }
        function status(): string {
            return JSON.stringify(root.clockWidgets.map(widget => ({
                screen: widget.barWindow.screen.name,
                fullscreen: widget.barWindow.workspaceFullscreen,
                visible: widget.barWindow.visible
            })));
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["fullscreen", "workspace", "workspacev2", "focusedmon",
                 "activespecial", "activespecialv2", "moveworkspace", "moveworkspacev2",
                 "monitoradded", "monitoraddedv2", "monitorremoved"].indexOf(event.name) !== -1)
                monitorRefresh.restart();
        }
    }

    Timer {
        id: monitorRefresh
        interval: 50
        onTriggered: root.refreshMonitorState()
    }

    Component.onCompleted: refreshMonitorState()

    function registerClockWidget(widget) {
        if (clockWidgets.indexOf(widget) === -1)
            clockWidgets = clockWidgets.concat([widget]);
    }

    function unregisterClockWidget(widget) {
        const remaining = [];
        for (let i = 0; i < clockWidgets.length; i++) {
            if (clockWidgets[i] !== widget)
                remaining.push(clockWidgets[i]);
        }
        clockWidgets = remaining;
    }

    function focusedClockWidget() {
        const focusedMonitor = Hyprland.focusedMonitor;
        if (focusedMonitor) {
            for (let i = 0; i < clockWidgets.length; i++) {
                const widget = clockWidgets[i];
                if (!widget || !widget.barWindow || !widget.barWindow.screen)
                    continue;

                const widgetMonitor = Hyprland.monitorFor(widget.barWindow.screen);
                if (widgetMonitor && widgetMonitor.id === focusedMonitor.id)
                    return widget;
            }
        }

        // Hyprland may briefly have no focused monitor while outputs are being
        // reconfigured. Keep IPC useful by falling back to the first live bar.
        return clockWidgets.length > 0 ? clockWidgets[0] : null;
    }

    function routeSwitcher(kind, action) {
        const target = focusedClockWidget();
        if (!target)
            return;

        // A switcher previously opened on another output must not remain there
        // when focus has moved to a different monitor.
        for (let i = 0; i < clockWidgets.length; i++) {
            const widget = clockWidgets[i];
            if (widget && widget !== target)
                widget.closeIpcSwitchers();
        }

        target.handleIpcSwitcher(kind, action);
    }

    IpcHandler {
        target: "themeSwitcher"

        function toggle(): void { root.routeSwitcher("theme", "toggle"); }
        function open(): void { root.routeSwitcher("theme", "open"); }
        function close(): void { root.routeSwitcher("theme", "close"); }
    }

    IpcHandler {
        target: "wallpaperSwitcher"

        function toggle(): void { root.routeSwitcher("wallpaper", "toggle"); }
        function open(): void { root.routeSwitcher("wallpaper", "open"); }
        function close(): void { root.routeSwitcher("wallpaper", "close"); }
    }

    IpcHandler {
        target: "appLauncher"

        function toggle(): void { root.routeSwitcher("app", "toggle"); }
        function open(): void { root.routeSwitcher("app", "open"); }
        function close(): void { root.routeSwitcher("app", "close"); }
    }

    IpcHandler {
        target: "logoutManager"

        function toggle(): void { root.routeSwitcher("logout", "toggle"); }
        function open(): void { root.routeSwitcher("logout", "open"); }
        function close(): void { root.routeSwitcher("logout", "close"); }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            required property var modelData

            PanelWindow {
                id: barWindow
                screen: modelData

                readonly property var monitor: {
                    const monitors = Hyprland.monitors.values;
                    return monitors.find(m => m.name === barWindow.screen?.name) ?? null;
                }
                readonly property bool workspaceFullscreen: {
                    if (!monitor)
                        return false;
                    // A special workspace covers the normal workspace while open.
                    const specialName = monitor.lastIpcObject?.specialWorkspace?.name ?? "";
                    const workspace = specialName.length > 0
                        ? Hyprland.workspaces.values.find(w => w.name === specialName)
                        : monitor.activeWorkspace;
                    return workspace?.hasFullscreen ?? false;
                }

                visible: !workspaceFullscreen
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell-bar"

                onWorkspaceFullscreenChanged: {
                    if (!workspaceFullscreen)
                        return;
                    if (clockWidget)
                        clockWidget.closeIpcSwitchers();
                    if (rightDropdownController) {
                        rightDropdownController.pendingPopup = null;
                        if (rightDropdownController.activePopup)
                            rightDropdownController.activePopup.closePopup();
                    }
                }

                anchors {
                    top: true;
                    right: true;
                    left: true;
                }

                implicitHeight: 45

                color: BarColors.transparent

                DropdownController { id: rightDropdownController }

                // Left-side Modules
                RowLayout {
                    id: left_layout

                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 15

                    Workspaces {
                        screen: modelData
                    }
                }

                // Middle Modules
                RowLayout {
                    id: middle_layout

                    anchors.centerIn: parent
                    spacing: 6

                    ClockWidget {
                        id: clockWidget
                        barWindow: barWindow

                        Component.onCompleted: root.registerClockWidget(clockWidget)
                        Component.onDestruction: root.unregisterClockWidget(clockWidget)
                    }

                    // NotificationWidget {
                    //     barWindow: barWindow
                    // }
                }

                // Right-Side Modules
                Item {
                    id: right_layout

                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: mediaWidget.width + wifiWidget.width + bluetoothWidget.width + volumeWidget.width + powerWidget.width + 20
                    implicitHeight: 33

                    MediaWidget {
                        id: mediaWidget
                        anchors.right: wifiWidget.left
                        anchors.rightMargin: 5
                        barWindow: barWindow
                    }

                    WifiWidget {
                        id: wifiWidget
                        anchors.right: bluetoothWidget.left
                        anchors.rightMargin: 5
                        barWindow: barWindow
                        dropdownController: rightDropdownController
                    }

                    BluetoothWidget {
                        id: bluetoothWidget
                        anchors.right: volumeWidget.left
                        anchors.rightMargin: 5
                        barWindow: barWindow
                        dropdownController: rightDropdownController
                    }

                    VolumeWidget {
                        id: volumeWidget
                        anchors.right: powerWidget.left
                        anchors.rightMargin: 5
                        barWindow: barWindow
                        dropdownController: rightDropdownController
                    }

                    PowerWidget {
                        id: powerWidget
                        anchors.right: parent.right
                        barWindow: barWindow
                        dropdownController: rightDropdownController
                    }
                }
            }

        }
    }
}
