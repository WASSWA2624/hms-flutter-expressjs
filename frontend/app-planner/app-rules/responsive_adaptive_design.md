# Responsive and Adaptive Design

## Scope
Defines how the app must behave across mobile, tablet, web, and desktop screen sizes.

## Breakpoints
| Token | Width range | Target layout |
|---|---:|---|
| `xs` | `< 360` | extra-small mobile, one column, compact spacing |
| `sm` | `360-599` | mobile, one column |
| `md` | `600-839` | large mobile / small tablet, one or two columns |
| `lg` | `840-1199` | tablet / small desktop, navigation rail or compact shell |
| `xl` | `1200-1599` | desktop, menu bar, side navigation, centered readable content |
| `xxl` | `>= 1600` | large desktop, max-width layouts, avoid over-stretching |

## Mandatory rules
- Use centralized responsive utilities based on `LayoutBuilder`, `MediaQuery.sizeOf(context)`, or both.
- Do not create duplicate screens for each size unless the interaction model truly changes.
- Scale from one-column to multi-column layouts.
- Use readable max widths on large screens instead of stretching forms and text across the full window.
- Avoid fixed widths except for intentional min/max constraints.
- Make scroll behavior explicit for small screens and content-heavy pages.
- Keep touch targets practical on mobile and pointer targets comfortable on desktop/web.
- Keep icons and buttons balanced: normal action icons should usually be `20-24px`; avoid oversized icons, excessive padding, and overly rounded shapes.

## Navigation behavior
| Width | Required behavior |
|---|---|
| `< 600` | Mobile app bar plus bottom navigation or drawer where appropriate. |
| `600-1199` | Navigation rail or compact side navigation. |
| `>= 1200` | Desktop/web shell with menu bar and side navigation. |
| `>= 1200` with limited width | Side navigation may start collapsed. |

## Desktop shell standard
- Include a top menu bar for desktop/web layouts when multiple app-level actions or sections exist.
- Include side navigation for primary destinations.
- Side navigation must support expanded and collapsed states.
- Recommended collapsed side-nav width: `64-80`.
- Recommended expanded side-nav width: `220-280`.
- Persist collapsed state only as a non-sensitive preference.
- Keep destination icons compact and labels readable.

## Layout width standards
| Content type | Recommended max width |
|---|---:|
| Authentication forms | `420-520` |
| General forms | `560-720` |
| Reading/detail pages | `840-1040` |
| Dashboards | `1200-1440` |
| Data-heavy pages | `1440` with horizontal handling when needed |

## Acceptance checklist
- Core screens are usable at `320px` width.
- Layouts remain readable at `>=1600px` width.
- Desktop layouts include menu bar, side navigation, and collapsible navigation behavior.
- No important content is clipped at supported breakpoints.
- Forms, lists, dialogs, and navigation adapt without duplicate business logic.

## Related rules
- [`reusable_components.md`](./reusable_components.md)
- [`theming.md`](./theming.md)
- [`platform_guidelines.md`](./platform_guidelines.md)
- [`multi_platform_input.md`](./multi_platform_input.md)
- [`accessibility.md`](./accessibility.md)
