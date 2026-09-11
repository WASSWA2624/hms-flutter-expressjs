# 23 — Replace the Country Selector Globally

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 7, Step 23
**Depends on:** 22
**Applies to:** development and production

## Context

`frontend/lib/shared/components/app_country_field.dart` already wraps a searchable select backed by `appCountryCatalogEntries` in `app_phone_field.dart`, but it is used in only a few places while other screens, including Edit Facility, keep their own country inputs. One selector and one dataset must serve the whole application.

## Requirements

1. Audit every country input in the application (free-text fields, bespoke dropdowns, hardcoded lists) and record each usage site.
2. Confirm the shared country catalog is complete for every supported country, with ISO code, display name, dialing code, and flag, and correct any gap or duplicate.
3. Make `AppCountryField` the single country selector: searchable by name and ISO code, keyboard navigable, mobile friendly, localized, themed, and consistent in appearance and behavior.
4. Replace every audited usage site with the shared selector, including Edit Facility, preserving each stored value format or migrating it deliberately.
5. Define the stored value explicitly (ISO code or display name) and keep it consistent across the frontend and the API contract; migrate existing records if the format changes.
6. Keep the selector consistent with the phone field so a country selection and a dialing code never disagree on the same form.
7. Handle empty, required, disabled, invalid, and unknown-stored-value states explicitly.
8. Add widget tests for search, keyboard selection, required validation, and unknown-value handling, plus a test asserting no screen renders a bespoke country input.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Do not add a third-party country package if the existing catalog suffices; if one is added, justify it and pin the version.
- Do not leave a duplicate country list anywhere in the codebase.
- Follow `prompts/.cursor/forms.mdc`, `localization.mdc`, `theming.mdc`, and `responsiveness.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1, R4)** Every audited country input uses the shared selector, and the usage list is recorded in the pull request description.
- [ ] **AC2 (R2)** The dataset covers every supported country with no duplicates or missing fields.
- [ ] **AC3 (R3)** Search, keyboard navigation, and touch selection work at mobile, tablet, and desktop widths in both themes.
- [ ] **AC4 (R5)** Stored values are consistent across screens and the API, with existing records migrated if the format changed.
- [ ] **AC5 (R6)** Country and dialing code stay consistent on forms containing both.
- [ ] **AC6 (R7)** All field states render correctly, including an unknown stored value.
- [ ] **AC7 (R8)** New tests pass, including the no-bespoke-input assertion.
- [ ] **AC8 (R9)** The selector behaves identically in development and production.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- `npm run test:backend` if the stored value contract changes.
- Manual: exercise the selector on Edit Facility and at least three other usage sites in both environments.

## Rollout — Development and Production

- Behavior must be identical under both Flutter define files.
- Config: mirror any locale or catalog define in `frontend/env/development.json.example` and `frontend/env/production.json.example`.
- Schema/data: if the stored value format changes, apply the migration with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host, and run the idempotent value backfill in development and then production.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-android.py`, plus `python deploy/deploy-backend.py` when the contract changes, then re-verify the usage sites in production.

## Relevant Files

- `frontend/lib/shared/components/app_country_field.dart`, `app_phone_field.dart`, `app_select_field.dart`, `components.dart`
- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/patients/`, `frontend/lib/features/hr/`, `frontend/lib/features/settings/`
- `frontend/lib/l10n/app_en.arb`
