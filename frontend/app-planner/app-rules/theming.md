# Theme System

## Scope
Defines the visual system used by every screen and component.

## Mandatory rules
- Use Material 3 as the default design foundation.
- Light theme is the default app theme.
- Support dark theme and system theme mode.
- Use a clean blue-based light theme and a clean dark theme.
- Do not hard-code colors in feature widgets.
- Do not hard-code repeated spacing, radius, elevation, or typography values in feature widgets.
- Store theme mode as a non-sensitive preference when persistence is implemented.
- Theme changes must update the app reactively.
- Shared components must read colors, typography, shape, and spacing from the active theme or app design tokens.

## Color standard
| Theme | Baseline |
|---|---|
| Light | Use `ColorScheme.fromSeed(seedColor: Color(0xFF1565C0), brightness: Brightness.light)`. |
| Dark | Use `ColorScheme.fromSeed(seedColor: Color(0xFF90CAF9), brightness: Brightness.dark)`. |
| Error | Use Material error roles from the active `ColorScheme`. |
| Status colors | Define success, warning, and info through a theme extension only when required. |

## Design tokens
| Token group | Required examples |
|---|---|
| Spacing | `xs=4`, `sm=8`, `md=12`, `lg=16`, `xl=24`, `xxl=32` |
| Radius | `xs=4`, `sm=8`, `md=10`, `lg=12`, `xl=16` |
| Page padding | mobile `16`, tablet `24`, desktop `32` |
| Button height | compact `36-40`, standard `40-48` |
| Icon size | default `20-24`, large only when the layout requires it |
| Max widths | reuse values from `responsive_adaptive_design.md` |

## Shape and density rules
- Avoid overly rounded components; prefer moderate radii between `8` and `12` for most cards, fields, and buttons.
- Avoid excessive padding; compact desktop controls should remain visually balanced.
- Use consistent elevation and borders. Do not mix unrelated card, button, and dialog styles.
- Keep navigation items readable without making icons or row heights unnecessarily large.

## Typography rules
- Use theme text styles instead of raw `TextStyle` duplication.
- Keep headings consistent by screen purpose.
- Keep body text readable at scaled font sizes.
- Use locale-aware text direction where needed.

## Acceptance checklist
- Switching light, dark, and system modes works without restarting.
- Shared UI looks consistent on all supported platforms.
- New feature screens can be built without raw colors or repeated spacing constants.
- Icons, buttons, cards, dialogs, and navigation items look professional rather than oversized or overly rounded.

## Related rules
- [`reusable_components.md`](./reusable_components.md)
- [`responsive_adaptive_design.md`](./responsive_adaptive_design.md)
- [`localization_i18n.md`](./localization_i18n.md)
- [`accessibility.md`](./accessibility.md)
