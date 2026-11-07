pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int maximumRecentApplications: 5
    property var recentApplicationIds: []

    function sanitiseApplicationIds(values) {
        if (!Array.isArray(values))
            return [];

        const sanitised = [];
        for (let i = 0; i < values.length; i++) {
            const applicationId = values[i];
            if (typeof applicationId !== "string"
                    || applicationId.length === 0
                    || sanitised.indexOf(applicationId) !== -1)
                continue;

            sanitised.push(applicationId);
            if (sanitised.length >= maximumRecentApplications)
                break;
        }
        return sanitised;
    }

    function loadRecentApplications() {
        const contents = recentApplicationsFile.text();
        if (!contents || contents.trim().length === 0)
            return;

        try {
            const state = JSON.parse(contents);
            recentApplicationIds = sanitiseApplicationIds(
                state && state.recentApplicationIds
                    ? state.recentApplicationIds
                    : []
            );
        } catch (error) {
            console.warn("Could not parse app launcher history:", error);
            recentApplicationIds = [];
        }
    }

    function saveRecentApplications() {
        recentApplicationsFile.setText(JSON.stringify({
            recentApplicationIds: recentApplicationIds
        }, null, 2));
    }

    function recordLaunch(entry) {
        if (!entry || !entry.id)
            return;

        const updatedIds = [entry.id];
        for (let i = 0; i < recentApplicationIds.length; i++) {
            const applicationId = recentApplicationIds[i];
            if (applicationId === entry.id)
                continue;

            updatedIds.push(applicationId);
            if (updatedIds.length >= maximumRecentApplications)
                break;
        }

        recentApplicationIds = updatedIds;
        saveRecentApplications();
    }

    Component.onCompleted: loadRecentApplications()

    FileView {
        id: recentApplicationsFile
        path: Quickshell.statePath("app-launcher-history.json")
        preload: true
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }
}
