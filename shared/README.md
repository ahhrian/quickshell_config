# Shared Design System

`shared/` owns the reusable visual tokens for the shell. It intentionally separates permanent monochrome shell chrome from switchable semantic themes.

Both public objects are QML singletons registered in `shared/qmldir`:

```text
singleton Theme 1.0 Theme.qml
singleton BarColors 1.0 BarColors.qml
```

Import them with the relative shared module and access them directly:

```qml
import "../../shared"

Rectangle { color: BarColors.surfaceBackground }
Text { color: Theme.colors.default_accent }
```

## Color ownership

Use this decision rule before choosing a token:

| Question | Palette |
| --- | --- |
| Is this ordinary bar/popup chrome, neutral text, a neutral border, or a hover surface? | `BarColors` |
| Should this color visibly change when the selected theme changes? | `Theme.colors` |
| Is this a semantic alert, active accent, theme preview, or highlighted date? | Usually `Theme.colors` |

Do not use `Theme.colors.bg*` merely because a component needs a dark background. Neutral shell surfaces must remain visually consistent across Catppuccin, Everforest, and Gruvbox.

Current ownership by area:

| Area | Primary palette | Allowed secondary use |
| --- | --- | --- |
| Compact bar widgets and workspace shells | `BarColors` | `Theme.colors` for urgency and the focused-workspace accent. |
| Wi-Fi, Bluetooth, volume, calendar, and clock popups | `BarColors` | Semantic active, warning, and current-date accents from `Theme.colors`. |
| App launcher and logout manager | `BarColors` | No theme-dependent surface colors. |
| Theme selector | `Theme.colors` | `BarColors.transparent` and clock-handoff text. The selector must preview the active/candidate palettes. |
| Wallpaper switcher | `Theme.colors` | `BarColors.transparent` and clock-handoff text. Its chrome intentionally follows the selected theme. |
| Services | Neither for data | May expose semantic `Theme.colors` or neutral `BarColors` values for consumers. |

## `BarColors.qml`

`BarColors` is the small black-and-white palette shared by the bar, its dropdowns, and the clock-anchored plugins.

| Token | Current value | Role |
| --- | --- | --- |
| `transparent` | `transparent` | No-fill state and invisible borders. |
| `deepBackground` | `#101010` | Deep popup cards and the outer workspace container. |
| `surfaceBackground` | `#202020` | Compact pills, controls, fields, and secondary surfaces. |
| `hoverAndBorder` | `#3d3d3d` | Hover/selection fills, outlines, dividers, tracks, and disabled controls. |
| `primaryText` | `#e8e8e8` | Main labels and active monochrome icons. |
| `secondaryText` | `#909090` | Metadata, placeholders, inactive labels, and subdued icons. |
| `textOnAccent` | aliases `deepBackground` | Dark text placed over a bright theme accent. |
| `mutedIcon` | 40% `primaryText` | Icons that must remain visible while representing a muted state. |

The palette is intentionally small. Avoid adding marginally different gray values for individual components. Prefer one of the existing roles unless a genuinely distinct state cannot be represented.

## `Theme.qml`

`Theme` instantiates every available semantic palette and exposes the selected one through `Theme.colors`.

Public API:

| Member | Purpose |
| --- | --- |
| `availableThemes` | Array of `{name, id}` records used by `ThemeSwitcher`. |
| `currentTheme` | Current ID; restored from persistent state, initially `catpuccin`. |
| `colors` | The active palette object. |
| `paletteFor(id)` | Returns a palette for previews without changing the active theme. |
| `setTheme(id)` | Selects a registered theme or falls back to Catppuccin. |

Available IDs are:

- `catpuccin` — the spelling is retained throughout paths and state for compatibility.
- `everforest`.
- `gruvbox`.

Theme choice is stored in `Quickshell.statePath("theme-selection.json")` and restored whenever Quickshell starts or reloads. Restoring it changes only the in-process `Theme.colors` palette; external application configuration remains the responsibility of `apply-theme.sh` when the user actively selects a theme. Wallpaper history is persisted separately by `services/Wallpaper.qml`.

## Palette interface

Every file in `shared/colors/` must provide the same properties so components can switch palettes without branching:

| Token | Meaning |
| --- | --- |
| `bg0` … `bg4` | Progressively elevated or muted theme-aware surfaces. |
| `fg` | Theme-aware primary foreground. |
| `red`, `orange`, `yellow`, `green`, `aqua`, `blue`, `purple` | Named semantic colors and preview swatches. |
| `default_accent` | Primary selection and focus accent. |
| `secondary_accent` | Secondary active-state accent. |
| `tertiary_accent` | Additional accent when two are insufficient. |

Current accent aliases:

| Palette | `default_accent` | `secondary_accent` | `tertiary_accent` |
| --- | --- | --- | --- |
| Catppuccin Frappé | Purple | Aqua | Blue |
| Everforest | Aqua | Yellow | Blue |
| Gruvbox | Yellow | Green | Blue |

Use named semantic aliases in ordinary components. Direct named swatches are appropriate for warnings (`red`, `yellow`) and for the theme selector's palette previews.

## Typical usage

```qml
Rectangle {
    color: hovered ? BarColors.hoverAndBorder : BarColors.surfaceBackground
    border.color: BarColors.hoverAndBorder

    Text {
        color: BarColors.primaryText
    }
}
```

```qml
Rectangle {
    color: isSelected ? Theme.colors.default_accent : BarColors.transparent

    Text {
        color: isSelected ? BarColors.textOnAccent : BarColors.secondaryText
    }
}
```

## Typography and iconography

- Primary UI typeface: `SF Pro Display`.
- Symbol font: `Material Symbols Rounded`.
- Workspace and launcher application icons: `DesktopEntries` plus `Quickshell.iconPath()`.
- Icon theme: supplied at process startup through `QS_ICON_THEME` by `launch.sh`, derived from the GTK theme selected by `nwg-look`.

If a desktop entry specifies an absolute icon file, that file takes precedence over themed lookup. If the selected pack lacks an icon, its inherited fallback theme may supply one.

## Motion design

Shared motion conventions are part of the design system even though the animation code currently lives in popup components:

- One `expansionProgress` controls width and height together.
- Opening uses `260 ms`, `Easing.OutBack`, overshoot `0.8`.
- Closing uses `170 ms`, `Easing.InOutCubic`.
- Static final-size content is clipped and faded by the expanding card.
- Hover color transitions are normally 75–180 ms.
- Selection is usually communicated by fill alone; avoid redundant bright borders unless a component needs a distinct keyboard-focus ring, such as the theme/wallpaper selectors.

## Adding a theme

1. Add `shared/colors/<ThemeName>.qml` with the full palette interface above.
2. Instantiate it in `Theme.qml`.
3. Add a record to `availableThemes`.
4. Update `paletteFor()` and `setTheme()` normalization.
5. Add the matching wallpaper directory under `~/Pictures/Wallpapers/`.
6. Update `Wallpaper.normaliseTheme()`, its folder model, and the switcher display name logic.
7. Test both neutral shell chrome and all semantic accent states.
