# Fix Clinical Services edit dialog titles

Make Admin Setup → Clinical Services Edit dialogs use entity-correct titles.

## Context

`/admin/setup?section=clinical-services` (`FacilityCatalogConfigPanel`): Radiology, Lab, Diagnoses. Edit/row-select already open mutation dialogs and save via update APIs. Wrong titles: Radiology **Edit**; Lab test **Configure Lab Test**; Lab panel **Create Lab Panel**; Diagnoses **Diagnosis details**. Lab already branches on `LabCatalogItemType`. Follow `prompts/.cursor/prompt.mdc`. See `screens/admin-setup-clinical-services.md`.

## Requirements

1. Radiology edit title: **Edit Radiology procedure**.
2. Lab edit title: **Edit Lab Test** for tests; **Edit Lab Panel** for panels.
3. Diagnoses edit title: **Edit diagnosis**.
4. Leave create titles and row **Edit** label unchanged.
5. Add/reuse l10n; do not retarget `clinicalDiagnosisFormTitle` if encounter UI needs **Diagnosis details**.
6. Reuse existing dialogs, validation, auth, save, and list refresh; no API/schema changes.
7. Keep current permission, loading, empty, error, success, and validation feedback.

## Constraints

Title copy in Clinical Services mutation dialogs only. No unrelated refactors.

## Acceptance Criteria

- AC1 (1): Radiology Edit → **Edit Radiology procedure**.
- AC2 (2): Lab test → **Edit Lab Test**; panel → **Edit Lab Panel**.
- AC3 (3): Diagnosis Edit → **Edit diagnosis**, not **Diagnosis details**.
- AC4 (4–6): Create flows, save, and list sync unchanged.
- AC5 (7): Authorized Edit remains; unauthorized UI stays absent.

## Verification

Manual checks per tab (test vs panel), light/dark, mobile/desktop. Confirm create + save. Prefer widget tests for title by mode/kind.

## Relevant Files

- `frontend/lib/shared/facility_catalog/clinical_catalog_admin_dialogs.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/l10n/app_en.arb`
- `screens/admin-setup-clinical-services.md`
