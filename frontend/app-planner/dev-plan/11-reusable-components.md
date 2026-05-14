# 11 - Reusable components

## Goal
Build the minimal shared UI component library without creating unnecessary wrappers.

## Applies app rules
- [`reusable_components.md`](../app-rules/reusable_components.md)
- [`forms.md`](../app-rules/forms.md)
- [`theming.md`](../app-rules/theming.md)
- [`accessibility.md`](../app-rules/accessibility.md)
- [`responsive_adaptive_design.md`](../app-rules/responsive_adaptive_design.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create shared wrappers only where repeated styling or behavior exists.
3. Implement minimal starter components: `AppButton`, `AppIconButton`, `AppTextField`, `AppDialog`, `AsyncStateScaffold`, and layout helpers.
4. Add form/select/radio/checkbox/switch/date components only when the starter demonstrates or requires those controls.
5. Base components on Flutter built-in widgets.
6. Support loading, disabled, error, focus, hover, and accessibility states where relevant.
7. Add widget tests for important components.

## Expected output
- Shared component files.
- Component tests.
- Optional small showcase only if useful for validation.

## Acceptance criteria
- No duplicate component solves the same responsibility.
- Components are localized and theme-aware.
- Components work with touch, mouse, keyboard, and screen readers.
