# Shared Theming & Design System (`shared/`)

The `shared/` directory encapsulates the global design system, color tokens, and theme management for the entire desktop configuration.

---

## 1. Theme Manager Architecture (`Theme.qml`)

Theme tokens are made available globally via a registered singleton:

- **`shared/qmldir`**:
  ```
  singleton Theme 1.0 Theme.qml
  ```
- **`Theme.qml`**:
  Exposes the active color palette through the `colors` property:
  ```qml
  pragma Singleton
  import QtQuick
  import "colors"

  QtObject {
      id: themeManager

      property QtObject catpuccin: Catpuccin {}
      property QtObject colors: catpuccin
  }
  ```

---

## 2. Palette Definitions (`colors/Catpuccin.qml`)

The active palette is **Catppuccin Frappé**:

```qml
QtObject {
    id: catpuccin

    readonly property color bg0:    "#232634" // Primary container & pill background
    readonly property color bg1:    "#303446" // Hovered pills, active rows
    readonly property color bg2:    "#414559" // Dividers, borders, switch off-tracks
    readonly property color bg3:    "#51576d" // Elevated borders, input outlines
    readonly property color bg4:    "#626880" // Muted text, disabled glyphs

    readonly property color fg:     "#c6d0f5" // Primary text
    readonly property color red:    "#e78284" // Mute state, alerts, disconnect actions
    readonly property color orange: "#ef9f76" // Secondary alerts
    readonly property color yellow: "#e5c890" // Medium battery warning
    readonly property color green:  "#a6d189" // Success state
    readonly property color aqua:   "#81c8be" // Primary text & widget accent
    readonly property color blue:   "#8caaee" // Secondary accent
    readonly property color purple: "#ca9ee6" // Container accent

    readonly property color container_accent: purple
    readonly property color text_accent:      aqua
    readonly property color alt_accent:       blue
}
```

---

## 3. Theming Rules for Components

1. **Avoid Hardcoded Hex Values**: Always use `Theme.colors.<token>`.
2. **Standard Backgrounds**:
   - Bar pills: `Theme.colors.bg0`
   - Hover highlights: `Theme.colors.bg1`
   - Borders: `Theme.colors.bg2`
3. **Accent Roles**:
   - `Theme.colors.text_accent` is the primary indicator color (volume progress ring, active Wi-Fi, toggle switch active state).
   - `Theme.colors.red` is reserved for muting, critical battery levels ($<15\%$), and destructive actions (disconnecting).
   - `Theme.colors.bg4` is used for disconnected icons and secondary metadata text.
4. **Typography**:
   - Text elements use `font.family: "SF Pro Display"` (with system sans-serif fallback).
   - Icons use `font.family: "Material Symbols Rounded"`.
