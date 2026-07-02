# Register New Patient — Form UX Refinement

## Objective

Polish the **Register new patient** dialog so the form is clean, well-spaced, and consistent across Android, iOS, web, and desktop. Fix layout issues (especially the phone field), tighten field requirements, and improve identifier and facility behaviour — without changing registration scope (create patient master record only).

**Primary target:** `frontend/lib/shared/patient_actions/register_new_patient_dialog.dart` (`RegisterNewPatientForm` + `RegisterNewPatientDialog`)

**Also used by:** `patient_registry_page.dart`, `opd_encounter_dialog.dart` — keep behaviour aligned.

---

## Problems (from current UI)

- Phone field shows error/overlap; inputs feel cramped with inconsistent vertical spacing.
- Gender is optional in the UI but should be required for registration.
- Identifier value stays editable when no identifier type is selected.
- Identifier type labels use raw API codes (e.g. `Mrn`) instead of full name + capitalized abbreviation.
- Facility field is shown even when the user has no meaningful choice.

---

## Field rules

| Field | Requirement | Notes |
| ----- | ----------- | ----- |
| First name | **Required** | Keep current validation. |
| Last name | Optional | Confirm backend accepts empty/null (`optionalNameBodySchema` in `patient.schema.js`). |
| Date of birth | Optional | Keep optional. |
| Gender | **Required** | Options: Male, Female, Other, Unknown. Use `AppGenderField` with `isRequired: true`. |
| Facility | Contextual | See **Facility behaviour** below. |
| Phone | Optional | Fix layout/spacing; resolve error-state overlap. |
| Email | Optional | No change. |
| Identifier type | Optional | If unset, **disable** identifier value and clear its value. |
| Identifier value | Conditional | Enabled only when identifier type is selected. |
| Notes | Optional | No change. |
| Patient is active | Default checked | No change. |

Captured fields are sufficient — focus on presentation and validation, not new data points.

---

## Layout and responsiveness

- Use existing form primitives (`AppFormShell`, `AppResponsiveFieldRow`, `PatientPhoneField`, etc.) and design-system spacing tokens.
- Ensure consistent gaps between rows; no overlapping borders, labels, or error text (phone field is the main offender).
- Form must read well on narrow mobile, tablet, and wide desktop breakpoints inside the maximized `AppDialog`.
- Prefer full-width rows for compound fields (phone) when side-by-side layout causes crowding.

---

## Identifier type labels

Replace `AppDisplay.apiLabel(value)` for dropdown options with localized labels in **full name + abbreviation** format, abbreviation in capitals, e.g.:

- Medical Record Number (MRN)
- National ID (NATIONAL_ID)
- Passport (PASSPORT)
- Insurance (INSURANCE)
- Driver License (DRIVER_LICENSE)
- Birth Certificate (BIRTH_CERTIFICATE)
- Other (OTHER)

Store/send the existing API enum value on submit; only change display labels (add i18n keys in `app_en.arb`).

---

## Facility behaviour

| User context | UI |
| ------------ | -- |
| Super admin or tenant admin with **multiple** facilities | Show facility dropdown; user must choose. |
| Any other role, or only **one** facility in reference data | Pre-select the user's current/logged-in facility; **hide** the facility field. |
| Single facility available | Set `facility_id` in payload internally; do not render the field. |

Wire pre-selection via `PatientReferenceData` / caller context (registry page, OPD dialog) — do not hardcode facility logic only in the widget if session context lives higher up.

---

## Backend alignment

- **Last name:** already optional — no schema change expected; verify create path accepts omission.
- **Gender:** currently optional in `createPatientSchema`. Either:
  1. Add frontend required validation only (recommended minimum), or
  2. Make `gender` required in `createPatientSchema` if product policy demands server-side enforcement.

Document which approach is taken in the PR.

---

## Out of scope

- New registration fields or downstream workflows (OPD, emergency, IPD).
- Edit-patient flows (`PatientFormDialog`).
- Non-English locales beyond new `app_en.arb` keys.

---

## Acceptance criteria

- [ ] Phone field and all rows have clear spacing; no overlapping inputs or error states at common breakpoints.
- [ ] Gender is required with Male / Female / Other / Unknown options.
- [ ] Identifier value is disabled until identifier type is selected; clearing type clears value.
- [ ] Identifier dropdown shows full name + capitalized abbreviation labels.
- [ ] Facility hidden and auto-set when user has no real choice; shown only when admin-level multi-facility selection applies.
- [ ] Last name remains optional and saves successfully without a value.
- [ ] `flutter analyze` and `flutter test test/features/patients/` pass.

---

## Quality gate

From `frontend/`:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test test/features/patients/
```
