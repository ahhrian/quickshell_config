# Popup UIs Plugin

`PopupUIs.qml` owns transient, non-modal overlays that are independent of the top bar. It creates one set of overlays for every `Quickshell.screens` entry.

## Notification toasts

`NotificationToasts.qml` preserves the original upper-right notification placement and behavior. It listens to `Notifications.toastRequested`, displays at most five cards, and does not reserve screen space.

## Hardware level OSD

`LevelOsd.qml` displays volume and brightness changes near the lower center of the focused monitor. Repeated changes update the existing card and restart its dismissal timer.

- Volume and mute values come from `Audio`'s native PipeWire state.
- Calls through `Audio.setVolume()` and `Audio.toggleMute()` are marked as UI-originated and suppressed.
- Volume changes are also suppressed while any `VolumeGui` is open.
- Brightness comes from the `Brightness` service's discovered `brightnessctl` backlight device.
- The card does not accept focus or reserve compositor space.

The OSD opens with `Easing.OutBack`, closes with `Easing.InOutCubic`, and disappears after 1.35 seconds without another change.
