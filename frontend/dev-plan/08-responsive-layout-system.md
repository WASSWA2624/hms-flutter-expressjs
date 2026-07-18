# 08 - Responsive Layout System
Build one adaptive layout system for mobile, tablet, desktop, and web.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`layouts.mdc`](../.cursor/layouts.mdc), [`platform_guidelines.mdc`](../.cursor/platform_guidelines.mdc), [`multi_platform_input.mdc`](../.cursor/multi_platform_input.mdc), and [`performance.mdc`](../.cursor/performance.mdc).

## Implementation
1. Implement canonical breakpoints in `lib/core/responsive/app_breakpoints.dart`.
2. Implement `ResponsivePage` for padding, scrolling, and maximum width.
3. Implement `ResponsiveAppShell` for mobile, tablet, and desktop.
4. Add `AppMenuBar` and collapsible `SideNavigation` for desktop/web.
5. Desktop navigation should use `20-24px` icons, balanced padding, and moderate radius.
6. Add breakpoint and shell smoke tests.
7. Separate duplicate screen implementations must not be created.

## Acceptance Criteria
- Core screens must work at `320px`.
- Large desktop layouts must remain readable.
- Desktop must provide a menu bar and expanded/collapsed side navigation.
