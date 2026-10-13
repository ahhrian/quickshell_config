import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

import "../../services"
import "../../shared"

Scope {
    id: root

    property bool lockRequested: false
    property bool pamConfigured: false
    property string inputText: ""
    property string pendingPassword: ""
    property string statusMessage: ""
    property bool authenticating: false
    property bool unlockPending: false
    property real visualOpacity: 0
    property int focusRequestSerial: 0

    readonly property int fadeInDuration: 260
    readonly property int fadeOutDuration: 200

    readonly property string wallpaperPath: {
        const remembered = Wallpaper.wallpaperForTheme(Theme.currentTheme);
        return remembered.length > 0
               ? remembered
               : Wallpaper.firstWallpaperForTheme(Theme.currentTheme);
    }
    readonly property url wallpaperUrl: wallpaperPath.length > 0
                                            ? "file://" + wallpaperPath
                                            : ""

    function requestFocus() {
        focusRequestSerial++;
    }

    // Read the three authoritative values at the point of use. A derived QML
    // property previously remained stuck at true after the native session-lock
    // object unlocked, preventing every later lock request.
    function isLockActive() {
        return lockRequested || sessionLock.locked || sessionLock.secure;
    }

    function resetUnlockedState() {
        fadeInAnimation.stop();
        fadeOutAnimation.stop();
        lockRequested = false;
        unlockPending = false;
        visualOpacity = 0;
        resetAuthenticationState();
    }

    function lock() {
        if (!pamConfigured) {
            console.error("Lock screen refused to lock: /etc/pam.d/quickshell-lock is missing");
            return;
        }

        // IPC is intentionally idempotent. A repeated request only restores
        // focus and can never release the compositor's session lock.
        if (isLockActive()) {
            requestFocus();
            return;
        }

        fadeInAnimation.stop();
        fadeOutAnimation.stop();
        unlockPending = false;
        visualOpacity = 0;
        resetAuthenticationState();
        lockRequested = true;
        sessionLock.locked = true;
        Qt.callLater(function() { root.requestFocus(); });
    }

    function authenticate() {
        if (!lockRequested || authenticating || unlockPending || inputText.length === 0)
            return;

        pendingPassword = inputText;
        inputText = "";
        statusMessage = "Checking…";
        authenticating = true;

        if (!pam.start()) {
            handleAuthenticationFailure(PamResult.Error);
            return;
        }

        // Match Omarchy's proven conversation flow. Depending on timing, PAM
        // may expose responseRequired before or alongside pamMessage.
        Qt.callLater(root.respondToPasswordPrompt);
    }

    function respondToPasswordPrompt() {
        if (!authenticating || !pam.active || !pam.responseRequired)
            return;
        pam.respond(pendingPassword);
    }

    function handleAuthenticationFailure(result) {
        if (!lockRequested || !authenticating)
            return;

        authenticating = false;
        inputText = "";
        pendingPassword = "";
        statusMessage = result === PamResult.MaxTries
                        ? "Too many attempts — try again shortly"
                        : (result === PamResult.Error
                           ? "Authentication is unavailable"
                           : "Incorrect password");
        requestFocus();
    }

    function resetAuthenticationState() {
        if (pam.active)
            pam.abort();
        inputText = "";
        pendingPassword = "";
        statusMessage = "";
        authenticating = false;
    }

    function finishUnlock() {
        if (!isLockActive() || unlockPending)
            return;

        // Keep the compositor lock held while its contents fade to the solid
        // surface color. The lock is released only after the fade completes.
        unlockPending = true;
        authenticating = false;
        pendingPassword = "";
        statusMessage = "";
        fadeInAnimation.stop();
        fadeOutAnimation.restart();
    }

    function releaseSessionLock() {
        if (!isLockActive() && !unlockPending)
            return;

        // Clear the QML-owned request before releasing the compositor lock.
        // onLockStateChanged performs a second idempotent reset once the native
        // object confirms that it has unlocked.
        lockRequested = false;
        unlockPending = false;
        resetAuthenticationState();
        sessionLock.locked = false;
        visualOpacity = 0;
        console.info("Lock screen released after successful authentication");
    }

    function clearInput() {
        if (authenticating)
            return;
        inputText = "";
        statusMessage = "";
        requestFocus();
    }

    function emergencyUnlock() {
        if (!isLockActive())
            return;

        // TEMPORARY SECURITY BYPASS: remove this function and its IPC handler
        // once normal PAM unlocking has been confirmed reliable.
        console.warn("Emergency lock-screen unlock requested; bypassing PAM");
        fadeInAnimation.stop();
        fadeOutAnimation.stop();
        lockRequested = false;
        sessionLock.locked = false;
        resetUnlockedState();
    }

    IpcHandler {
        target: "lockScreen"

        function lock(): void { root.lock(); }
        function open(): void { root.lock(); }
        function toggle(): void { root.lock(); }
        function status(): string {
            return JSON.stringify({
                locked: root.isLockActive(),
                requested: root.lockRequested,
                sessionLocked: sessionLock.locked,
                secure: sessionLock.secure,
                pamConfigured: root.pamConfigured,
                authenticating: root.authenticating,
                unlockPending: root.unlockPending
            });
        }
    }

    NumberAnimation {
        id: fadeInAnimation

        target: root
        property: "visualOpacity"
        from: 0
        to: 1
        duration: root.fadeInDuration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOutAnimation

        target: root
        property: "visualOpacity"
        to: 0
        duration: root.fadeOutDuration
        easing.type: Easing.InOutCubic
        onFinished: {
            if (root.unlockPending)
                root.releaseSessionLock();
        }
    }

    // TEMPORARY: this deliberately bypasses authentication so a broken PAM
    // flow cannot strand the graphical session. Delete the entire handler
    // together with emergencyUnlock() once the normal unlock path is fixed.
    IpcHandler {
        target: "lockScreenEmergency"

        function unlock(): void { root.emergencyUnlock(); }
    }

    PamContext {
        id: pam

        // Use a root-owned, password-only PAM service. The repository copy is
        // a template installed by plugins/lockScreen/install-pam.sh.
        config: "quickshell-lock"
        user: Quickshell.env("USER") || Quickshell.env("LOGNAME")

        onResponseRequiredChanged: root.respondToPasswordPrompt()
        onPamMessage: root.respondToPasswordPrompt()

        onCompleted: function(result) {
            console.info("Lock screen PAM result:", PamResult.toString(result));
            if (!root.lockRequested)
                return;
            if (result === PamResult.Success)
                root.finishUnlock();
            else
                root.handleAuthenticationFailure(result);
        }

        onError: function(error) {
            console.warn("Lock screen PAM error:", PamError.toString(error));
            root.handleAuthenticationFailure(PamResult.Error);
        }
    }

    FileView {
        id: pamPolicyFile

        path: "/etc/pam.d/quickshell-lock"
        preload: true
        blockLoading: true
        printErrors: false
        watchChanges: true
        onLoaded: root.pamConfigured = true
        onLoadFailed: root.pamConfigured = false
        onFileChanged: reload()
    }

    WlSessionLock {
        id: sessionLock

        locked: false

        onSecureStateChanged: {
            if (secure) {
                root.requestFocus();
                if (!root.unlockPending) {
                    fadeOutAnimation.stop();
                    root.visualOpacity = 0;
                    fadeInAnimation.restart();
                }
            }
        }

        onLockStateChanged: {
            if (!locked) {
                // Always reset every QML-side lifecycle flag. Conditional
                // cleanup left stale state behind after successful unlocks.
                root.resetUnlockedState();
            } else {
                root.requestFocus();
            }
        }

        WlSessionLockSurface {
            id: lockSurface

            color: BarColors.deepBackground

            readonly property date currentDate: {
                // Time.time is the minute-resolution change dependency.
                const tick = Time.time;
                return new Date();
            }

            onVisibleChanged: {
                if (visible)
                    Qt.callLater(function() { passwordInput.forceActiveFocus(); });
            }

            Connections {
                target: root

                function onFocusRequestSerialChanged() {
                    Qt.callLater(function() { passwordInput.forceActiveFocus(); });
                }
            }

            Rectangle {
                anchors.fill: parent
                color: BarColors.deepBackground
                opacity: root.visualOpacity
                enabled: !root.unlockPending

                Image {
                    id: wallpaperImage

                    anchors.fill: parent
                    anchors.margins: -32
                    source: root.wallpaperUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: root.wallpaperUrl.toString().length > 0

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 0.72
                        blurMax: 64
                        autoPaddingEnabled: false
                    }
                }

                // A solid lock surface plus this overlay guarantees that no
                // client windows can show through even if no wallpaper loads.
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.48)
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: passwordInput.forceActiveFocus()
                }

                Column {
                    anchors.top: parent.top
                    anchors.topMargin: Math.max(64, parent.height * 0.1)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Time.time
                        color: BarColors.primaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: Math.max(76, Math.min(126, lockSurface.width * 0.09))
                        font.weight: Font.Light
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(lockSurface.currentDate, "dddd, d MMMM")
                        color: BarColors.primaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: Math.max(19, Math.min(25, lockSurface.width * 0.018))
                        font.weight: Font.Medium
                    }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(parent.height * 0.7)
                    spacing: 10

                    Rectangle {
                        width: Math.min(380, Math.max(280, lockSurface.width - 48))
                        height: 56
                        radius: height / 2
                        color: Qt.rgba(
                            BarColors.deepBackground.r,
                            BarColors.deepBackground.g,
                            BarColors.deepBackground.b,
                            0.82)
                        border.width: passwordInput.activeFocus ? 2 : 1
                        border.color: passwordInput.activeFocus
                                      ? BarColors.primaryText
                                      : BarColors.hoverAndBorder

                        Behavior on border.color {
                            ColorAnimation { duration: 100 }
                        }

                        Text {
                            id: lockIcon

                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.authenticating ? "progress_activity" : "lock"
                            color: BarColors.secondaryText
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                                running: root.authenticating
                            }
                        }

                        Text {
                            anchors.left: lockIcon.right
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Enter password"
                            visible: passwordInput.text.length === 0
                            color: BarColors.secondaryText
                            font.family: "SF Pro Display"
                            font.pixelSize: 15
                        }

                        TextInput {
                            id: passwordInput

                            anchors.left: lockIcon.right
                            anchors.leftMargin: 12
                            anchors.right: submitIcon.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.inputText
                            color: BarColors.primaryText
                            selectionColor: BarColors.hoverAndBorder
                            selectedTextColor: BarColors.primaryText
                            font.family: "SF Pro Display"
                            font.pixelSize: 17
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            enabled: !root.authenticating
                            focus: true
                            clip: true
                            inputMethodHints: Qt.ImhHiddenText
                                              | Qt.ImhSensitiveData
                                              | Qt.ImhNoPredictiveText

                            onTextChanged: {
                                if (root.inputText !== text)
                                    root.inputText = text;
                            }
                            Keys.onPressed: event => {
                                const emergencyModifiers = Qt.ControlModifier
                                                           | Qt.AltModifier
                                                           | Qt.ShiftModifier;
                                if (event.key === Qt.Key_F12
                                        && (event.modifiers & emergencyModifiers) === emergencyModifiers) {
                                    event.accepted = true;
                                    root.emergencyUnlock();
                                }
                            }
                            Keys.onReturnPressed: root.authenticate()
                            Keys.onEnterPressed: root.authenticate()
                            Keys.onEscapePressed: root.clearInput()
                        }

                        Text {
                            id: submitIcon

                            anchors.right: parent.right
                            anchors.rightMargin: 17
                            anchors.verticalCenter: parent.verticalCenter
                            text: "arrow_forward"
                            color: root.inputText.length > 0 && !root.authenticating
                                   ? BarColors.primaryText
                                   : BarColors.mutedIcon
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 21
                        }

                        MouseArea {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 54
                            enabled: root.inputText.length > 0 && !root.authenticating
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.authenticate()
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.statusMessage
                        color: root.statusMessage === "Checking…"
                               ? BarColors.secondaryText
                               : BarColors.primaryText
                        font.family: "SF Pro Display"
                        font.pixelSize: 13
                        visible: text.length > 0
                    }
                }
            }
        }
    }
}
