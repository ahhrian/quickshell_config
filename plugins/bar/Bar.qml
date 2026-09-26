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
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 15
                }

                // Middle Modules
                RowLayout {
                    id: middle_layout

                    anchors.centerIn: parent
                    spacing: 10

                    ClockWidget {
                        Layout.fillWidth: true
                    }

                    Workspaces {
                        screen: modelData
                        Layout.fillWidth: true
                    }

                    PowerWidget {
                        // Layout.rightMargin: 14
                    }
                }
                
                // Right-Side Modules
                RowLayout {
                    id: right_layout

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 15

                    WifiWidget {
                        barWindow: barWindow
                    }

                    BluetoothWidget {
                        barWindow: barWindow
                    }

                    VolumeWidget {
                        barWindow: barWindow
                    }

                    NotificationWidget {
                        barWindow: barWindow
                        Layout.rightMargin: 14
                    }

                    // ClockWidget {
                    //     Layout.fillWidth: true
                    // }

                    // PowerWidget {
                    //     Layout.rightMargin: 14
                    // }
                }
            }

            NotificationToasts {
                screenModel: modelData
                topOffset: barWindow.implicitHeight + 8
            }
        }
    }
}