# Multi-Platform Input

## Scope
Defines touch, mouse, keyboard, focus, hover, and shortcut behavior across platforms.

## Mandatory rules
- Support touch-first interaction on mobile and pointer/keyboard interaction on web and desktop.
- Keep visible focus states for keyboard navigation.
- Use hover states where they improve desktop/web clarity.
- Do not make actions available only through hover.
- Use platform-appropriate text input keyboard types and actions.
- Keep form submission accessible from keyboard where practical.
- Respect safe areas and keyboard insets on mobile.

## Implementation standard
- Shared components should handle focus, hover, enabled/disabled, and pressed states consistently.
- Shortcut keys may be added at the shell level for app-specific workflows, but must not conflict with browser/system shortcuts.

## Acceptance checklist
- Forms work with keyboard only.
- Menus, dialogs, and dropdowns can be dismissed predictably.
- Touch targets are practical on mobile.

## Related rules
- [`accessibility.md`](./accessibility.md)
- [`reusable_components.md`](./reusable_components.md)
- [`responsive_adaptive_design.md`](./responsive_adaptive_design.md)
- [`platform_guidelines.md`](./platform_guidelines.md)
