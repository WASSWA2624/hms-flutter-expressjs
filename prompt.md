# Register New Patient Dialog — Form Layout & Disabled-Field UX

## Context

On the **Register new patient** modal (`/patients` → **Register patient**), form fields visually overlap vertically when the dialog is maximized or at typical desktop widths. The **Identifier value** field is correctly disabled until **Identifier type** is chosen, but gives no feedback on hover—users cannot tell why it is inactive.

**Primary file:** `frontend/lib/shared/patient_actions/register_new_patient_dialog.dart` (`RegisterNewPatientForm`, shared by the registry dialog and OPD intake).

---

## Requirements

### 1. Fix vertical field spacing

- Add consistent vertical spacing between all input rows so labels, inputs, and validation messages no longer overlap.
- Use existing form layout primitives and theme tokens (`AppFormSection`, `AppResponsiveFieldRow` with `AppResponsiveFieldRowGap.form`, `theme.appTokens.formGap*`)—do not introduce ad-hoc pixel values.
- Preserve responsive behavior: two-column rows on wide viewports, stacked fields with appropriate gap on narrow viewports.
- Verify at dialog default size, maximized state, and the OPD walk-in embed (`RegisterNewPatientForm` in `opd_encounter_dialog.dart`).

### 2. Explain disabled Identifier value on hover

- When **Identifier value** is disabled because no **Identifier type** is selected, show a tooltip on hover explaining the prerequisite (e.g. *“Select an identifier type first.”*).
- Apply the same pattern only when the field is disabled for this reason—not when the whole form is saving or checking duplicates.
- Add the user-visible string to `frontend/lib/l10n/app_en.arb`; no hardcoded labels.
- Prefer reusing shared component behavior (e.g. optional `tooltip` on `AppTextField`) if that keeps other forms consistent.

---

## Acceptance criteria

- [ ] No overlapping fields in the Register new patient dialog at 1000×800 and maximized.
- [ ] Spacing matches other modal forms in the app (design-system density).
- [ ] Hovering the disabled Identifier value field shows a localized reason tooltip.
- [ ] Identifier value enables normally once a type is selected; existing disable-until-type behavior is unchanged.
- [ ] Widget test in `frontend/test/features/patients/presentation/patient_registry_page_test.dart` updated or extended for the tooltip/disabled state.

---

## Quality gate

From `frontend/`:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test test/features/patients/presentation/patient_registry_page_test.dart
```
