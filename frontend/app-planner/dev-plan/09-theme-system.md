# 09 - Theme system

## Goal
Implement a professional Material theme system with light, dark, and system theme mode.

## Applies app rules
- [`theming.md`](../app-rules/theming.md)
- [`assets_branding.md`](../app-rules/assets_branding.md)
- [`accessibility.md`](../app-rules/accessibility.md)
- [`localization_i18n.md`](../app-rules/localization_i18n.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create `AppTheme.light` using a clean blue Material 3 seed color.
3. Create `AppTheme.dark` using a clean dark Material 3 scheme.
4. Create `AppThemeTokens` for spacing, radius, sizing, and optional status colors.
5. Implement `themeModeControllerProvider` and persistence only for non-sensitive preference storage.
6. Keep buttons, icons, fields, cards, dialogs, and navigation visually balanced; avoid excessive padding and overly rounded shapes.
7. Remove raw repeated colors, spacing, and shapes from starter UI.
8. Add theme smoke tests.

## Expected output
- Light and dark themes.
- Theme token extension.
- Theme mode provider/controller.
- Theme-aware starter UI.

## Acceptance criteria
- Light theme is default.
- System and dark mode work.
- Shared components read from theme tokens.
