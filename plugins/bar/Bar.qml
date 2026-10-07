import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../shared"
import "components"

Scope {
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

                color: "transparent"

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

                    WifiWidget {
                        barWindow: barWindow
                    }

                    BluetoothWidget {
                        barWindow: barWindow
                    }

                    ClockWidget {}

                    VolumeWidget {
                        barWindow: barWindow
                    }

                    NotificationWidget {
                        barWindow: barWindow
                    }
                }

                // Right-Side Modules
                RowLayout {
                    id: right_layout

                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 15

                    PowerWidget {}
                }
            }

            NotificationToasts {
                screenModel: modelData
                topOffset: barWindow.implicitHeight + 8
            }
        }
    }
}