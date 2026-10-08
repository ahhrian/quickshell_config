import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../shared"
import "components"

Scope {
    id: root

    property var clockWidgets: []

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

    Variants {
        model: Quickshell.screens

        Scope {
            required property var modelData

            PanelWindow {
                id: barWindow
                screen: modelData

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
                    implicitWidth: wifiWidget.width + bluetoothWidget.width + volumeWidget.width + powerWidget.width + 15
                    implicitHeight: 33

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
                    }
                }
            }

            NotificationToasts {
                screenModel: modelData
                topOffset: barWindow.implicitHeight + 8
            }
        }
    }
}
