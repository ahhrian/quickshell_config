import QtQuick

QtObject {
    id: root
    property var activePopup: null
    property var pendingPopup: null

    function toggle(popup) {
        pendingPopup = null;
        if (activePopup === popup) {
            popup.togglePopup();
        } else if (activePopup && activePopup.visible) {
            pendingPopup = popup;
            activePopup.closePopup();
        } else {
            activePopup = popup;
            popup.openPopup();
        }
    }

    function closed(popup) {
        if (activePopup !== popup)
            return;
        activePopup = null;
        // Let the bar release the previous slot before positioning the next popup.
        Qt.callLater(function() {
            if (root.activePopup || !root.pendingPopup)
                return;
            const next = root.pendingPopup;
            root.pendingPopup = null;
            root.activePopup = next;
            next.openPopup();
        });
    }
}
