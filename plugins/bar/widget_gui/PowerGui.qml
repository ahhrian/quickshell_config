import QtQuick
import QtQuick.Layouts

import "../../../services"
import "../../../shared"

LeftExpandingPopup {
    id: root

    targetWidth: 400
    maximumHeight: 520
    targetHeight: Math.min(card.implicitHeight, maximumHeight)
    borderColor: BarColors.hoverAndBorder

    onAboutToOpen: Power.recheckChargeLimit()

    Item {
        id: card
        anchors.fill: parent
        implicitHeight: contentColumn.implicitHeight + 32

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: BarColors.surfaceBackground

                    Text {
                        anchors.centerIn: parent
                        text: Power.icon
                        color: Power.color
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 24

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: Power.isCharging ? "Charging" : (Power.pluggedIn ? "External power" : "On battery")
                        color: BarColors.primaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Power.estimateText
                        color: BarColors.secondaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: Power.battery
                    color: Power.color
                    font.family: "SF Pro Display"
                    font.pixelSize: 22
                    font.bold: true

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 7
                radius: height / 2
                color: BarColors.hoverAndBorder

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Power.percentage / 100))
                    height: parent.height
                    radius: parent.radius
                    color: Power.color

                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: BarColors.hoverAndBorder
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "POWER MODE"
                    color: BarColors.secondaryText
                    font.family: "SF Pro Display"
                    font.pixelSize: 11
                    font.bold: true
                }

                Text {
                    text: Power.powerProfileId === "power-saver" ? "Efficiency"
                          : (Power.powerProfileId === "performance" ? "Performance" : "Balanced")
                    color: Theme.colors.default_accent
                    font.family: "SF Pro Display"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: Power.powerModes

                    delegate: Rectangle {
                        id: modeButton

                        required property var modelData
                        readonly property bool selected: Power.powerProfileId === modelData.id
                        readonly property bool available: modelData.available

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 82
                        radius: 11
                        opacity: available ? 1 : 0.45
                        color: selected ? Theme.colors.default_accent
                                        : (modeMouse.containsMouse && available
                                           ? BarColors.hoverAndBorder
                                           : BarColors.surfaceBackground)
                        border.width: selected ? 0 : 1
                        border.color: BarColors.hoverAndBorder

                        Behavior on color { ColorAnimation { duration: 150 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 12
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modeButton.modelData.icon
                                color: modeButton.selected ? BarColors.textOnAccent : BarColors.primaryText
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 21
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modeButton.modelData.label
                                color: modeButton.selected ? BarColors.textOnAccent : BarColors.primaryText
                                font.family: "SF Pro Display"
                                font.pixelSize: 12
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modeButton.available ? modeButton.modelData.description : "Unavailable"
                                color: modeButton.selected ? BarColors.textOnAccent : BarColors.secondaryText
                                font.family: "SF Pro Display"
                                font.pixelSize: 9
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: modeMouse
                            anchors.fill: parent
                            enabled: modeButton.available
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Power.setPowerProfile(modeButton.modelData.id)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: BarColors.hoverAndBorder
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "CHARGE LIMIT"
                    color: BarColors.secondaryText
                    font.family: "SF Pro Display"
                    font.pixelSize: 11
                    font.bold: true
                }

                Rectangle {
                    visible: Power.chargeLimitSupported
                    implicitWidth: limitStatus.implicitWidth + 14
                    implicitHeight: 22
                    radius: height / 2
                    color: BarColors.surfaceBackground
                    border.width: 1
                    border.color: BarColors.hoverAndBorder

                    Text {
                        id: limitStatus
                        anchors.centerIn: parent
                        text: Power.chargeLimit < 100 ? Power.chargeLimit + "% max" : "No limit"
                        color: Power.chargeLimit < 100 ? Theme.colors.default_accent : BarColors.secondaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: Power.chargeLimitDetail
                color: BarColors.secondaryText
                font.family: "SF Pro Display"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                visible: Power.chargeLimitSupported

                Repeater {
                    model: Power.chargeLimitPresets

                    delegate: Rectangle {
                        id: limitButton

                        required property var modelData
                        readonly property int limitValue: Number(modelData)
                        readonly property bool selected: Power.chargeLimit === limitValue

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 34
                        radius: 9
                        color: selected ? Theme.colors.default_accent
                                        : (limitMouse.containsMouse
                                           ? BarColors.hoverAndBorder
                                           : BarColors.surfaceBackground)
                        border.width: selected ? 0 : 1
                        border.color: BarColors.hoverAndBorder
                        opacity: Power.chargeLimitBusy ? 0.55 : 1

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: limitButton.limitValue >= 100 ? "Off" : limitButton.limitValue + "%"
                            color: limitButton.selected ? BarColors.textOnAccent : BarColors.primaryText
                            font.family: "SF Pro Display"
                            font.pixelSize: 12
                            font.bold: limitButton.selected
                        }

                        MouseArea {
                            id: limitMouse
                            anchors.fill: parent
                            enabled: !Power.chargeLimitBusy
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Power.setChargeLimit(limitButton.limitValue)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                visible: Power.chargeLimitSupported

                Text {
                    text: Power.chargeLimitBusy ? "progress_activity" : "admin_panel_settings"
                    color: Power.chargeLimitBusy ? Theme.colors.default_accent : BarColors.secondaryText
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 14

                    RotationAnimation on rotation {
                        running: Power.chargeLimitBusy
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Power.chargeLimitBusy
                          ? "Applying charge limit…"
                          : "Changing the firmware setting requires authentication."
                    color: BarColors.secondaryText
                    font.family: "SF Pro Display"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: chargeError.implicitHeight + 16
                radius: 9
                color: BarColors.surfaceBackground
                border.width: 1
                border.color: Theme.colors.red
                visible: Power.chargeLimitError !== ""

                Text {
                    id: chargeError
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    text: Power.chargeLimitError
                    color: Theme.colors.red
                    font.family: "SF Pro Display"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
