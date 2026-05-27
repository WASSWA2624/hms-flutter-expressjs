# 10 - Localization readiness

## Goal
Configure generated localization and keep all user-facing starter text localizable.

## Applies app rules
- [`localization_i18n.md`](../app-rules/localization_i18n.md)
- [`date_time_formatting.md`](../app-rules/date_time_formatting.md)
- [`accessibility.md`](../app-rules/accessibility.md)
- [`error_handling.md`](../app-rules/error_handling.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Enable `flutter: generate: true` in `pubspec.yaml`.
3. Create root `l10n.yaml`.
4. Create `lib/l10n/app_en.arb` with starter labels, navigation labels, error labels, and accessibility labels.
5. Wire generated localization delegates into `MaterialApp.router`.
6. Create locale controller/provider if runtime locale switching is required.
7. Replace hard-coded user-facing strings in starter UI.

## Expected output
- Root `l10n.yaml`.
- English ARB file.
- Generated localization configuration.
- Localized starter UI.

## Acceptance criteria
- `flutter gen-l10n` succeeds.
- User-facing starter text is localizable.
- Accessibility labels are included for icon-only controls.
