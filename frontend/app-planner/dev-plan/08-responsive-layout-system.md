# 08 - Responsive layout system

## Goal
Create centralized breakpoints, layout helpers, page constraints, and adaptive shell behavior.

## Applies app rules
- [`responsive_adaptive_design.md`](../app-rules/responsive_adaptive_design.md)
- [`platform_guidelines.md`](../app-rules/platform_guidelines.md)
- [`multi_platform_input.md`](../app-rules/multi_platform_input.md)
- [`performance.md`](../app-rules/performance.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Implement `lib/core/responsive/app_breakpoints.dart` using the canonical breakpoints.
3. Implement `ResponsivePage` for padding, scrolling, and max-width constraints.
4. Implement `ResponsiveAppShell` for mobile, tablet, and desktop layouts.
5. Implement `AppMenuBar` for desktop/web shell actions.
6. Implement `SideNavigation` with expanded and collapsed states.
7. Keep desktop navigation compact: icons around `20-24px`, balanced padding, and moderate radius.
8. Add breakpoint tests and shell smoke tests.

## Expected output
- Breakpoint utilities.
- Responsive page wrapper.
- Desktop menu bar.
- Collapsible side navigation.
- Shell tests.

## Acceptance criteria
- Core screens work at `320px` width.
- Large desktop layouts remain readable.
- Desktop layout includes menu bar, side navigation, and collapsible navigation behavior.
- No separate duplicate screen implementations are created.
