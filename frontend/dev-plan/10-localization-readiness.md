# 10 - Localization Readiness
Make starter text, errors, navigation, and accessibility labels localizable.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`localization_i18n.mdc`](../.cursor/localization_i18n.mdc), [`date_time_formatting.mdc`](../.cursor/date_time_formatting.mdc), [`accessibility.mdc`](../.cursor/accessibility.mdc), and [`error_handling.mdc`](../.cursor/error_handling.mdc).

## Implementation
1. Enable `flutter: generate: true` in `pubspec.yaml`.
2. Create root `l10n.yaml`.
3. Add starter, navigation, error, and accessibility labels to `lib/l10n/app_en.arb`.
4. Wire generated delegates into `MaterialApp.router`.
5. Add a locale controller/provider only when runtime switching is required.
6. Hard-coded user-facing starter strings must be replaced.

## Acceptance Criteria
- `flutter gen-l10n` must succeed.
- All user-facing starter text must be localizable.
- Icon-only controls must have localized accessibility labels.
- Generated localization configuration and localized starter UI must work together.
