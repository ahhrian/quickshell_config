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
                        barWindow: barWindow
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
