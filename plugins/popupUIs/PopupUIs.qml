import QtQuick
import Quickshell

Scope {
    Variants {
        model: Quickshell.screens

        Scope {
            required property var modelData

            NotificationToasts {
                screenModel: modelData
                topOffset: 53
            }

            LevelOsd {
                screenModel: modelData
            }
        }
    }
}
