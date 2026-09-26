pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import "../shared"

Singleton {
    id: root

    property bool dnd: false
    property var timeMap: ({})
    property int timePulse: 0

    // Reactive timer to refresh relative timestamps every 15 seconds
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: {
            root.timePulse++;
        }
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true

        onNotification: (n) => {
            n.tracked = true;
            root.timeMap[n.id] = Date.now();
            root.timeMapChanged();
            root.timePulse++;

            if (!root.dnd) {
                root.toastRequested(n);
            }
        }
    }

    readonly property var trackedNotifications: server.trackedNotifications
    readonly property var list: (server.trackedNotifications && server.trackedNotifications.values) ? server.trackedNotifications.values : []
    readonly property int count: list.length

    signal toastRequested(var notification)

    function toggleDnd() {
        dnd = !dnd;
    }

    function clearAll() {
        if (!server.trackedNotifications || !server.trackedNotifications.values) return;
        const items = server.trackedNotifications.values;
        for (let i = items.length - 1; i >= 0; i--) {
            const item = items[i];
            if (item && typeof item.dismiss === "function") {
                item.dismiss();
            }
        }
        timeMap = ({});
        timePulse++;
    }

    function dismiss(n) {
        if (n && typeof n.dismiss === "function") {
            n.dismiss();
        }
    }

    function getById(id) {
        if (!server.trackedNotifications || !server.trackedNotifications.values) return null;
        const items = server.trackedNotifications.values;
        for (let i = 0; i < items.length; i++) {
            if (items[i] && items[i].id === id) return items[i];
        }
        return null;
    }

    function getTimeAgo(id) {
        // Reference timePulse so this binding updates periodically
        timePulse;
        const ts = timeMap[id];
        if (!ts) return "Just now";
        const diffSeconds = Math.max(0, Math.floor((Date.now() - ts) / 1000));
        if (diffSeconds < 10) return "Just now";
        if (diffSeconds < 60) return diffSeconds + "s ago";
        const diffMinutes = Math.floor(diffSeconds / 60);
        if (diffMinutes < 60) return diffMinutes + "m ago";
        const diffHours = Math.floor(diffMinutes / 60);
        if (diffHours < 24) return diffHours + "h ago";
        return Math.floor(diffHours / 24) + "d ago";
    }
}
