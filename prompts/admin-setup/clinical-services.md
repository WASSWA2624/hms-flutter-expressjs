# Clinical Services — Lab test create/edit robustness

Raise lab-test create/edit under Clinical Services to radiology save-guard and form-polish parity. Panels out of scope.

## Context

`/admin/setup?section=clinical-services` Lab tab. Surfaces: `LabCatalogItemMutationDialog`, `LabTestDefinitionForm`. Map: `screens/admin-setup/clinical-services.md`. Mirror radiology similarity UX. Enforce `.cursor/mandatories.mdc`.

## Requirements

1. Before create/update, run similarity on tenant plus standard catalog; show field-level percent; exact name/code conflicts block with field errors; near-matches open Cancel, Use existing, Proceed; no-match create needs no-similar confirm; proceed sends `confirm_similar`; clearing name/code resets acceptance.
2. Save shows `AppButton.isLoading` during similarity and save; Cancel stays available during scan.
3. Polish `LabTestDefinitionForm`: even category and code columns; finished unit-option list; spaced range cards; Add reference range above cards with count; sections Test identity, Result configuration, Reference ranges.
4. Block duplicate ranges by label, gender, and age band; validate age, normal, and critical min/max; incomplete filled ranges fail; empty optional ranges pass.
5. Searchable selects for category, specimen, units, range labels; reuse `AppDialog` and `AppSelectField`; share form with configure.
6. Require name and result kind; validate optional fields when set; gate mutate via `canMutateLabCatalog`; sync UI after save; localize new copy.

## Constraints

- No panel create/edit or desk chrome redesign.
- Reuse similarity helpers and form components; no new dialog chrome.
- Unauthorized mutate controls must not render.

## Acceptance Criteria

- Exact conflicts block; near-matches need confirm; `confirm_similar` only after proceed.
- Requirement 3 layout holds; Add range top; duplicates cannot save.
- Catalog selects; `xs`–`xxl` usable; Save loading; l10n complete.
- Tests cover similarity flows, duplicate-range validation, and absent unauthorized mutate UI.

## Relevant Files

- `frontend/lib/shared/lab_catalog/`
- `frontend/lib/shared/facility_catalog/clinical_catalog_admin_dialogs.dart`
- `backend/src/lib/lab/lab-test-similarity.js`
- `backend/src/modules/lab-test/`
- `screens/admin-setup/clinical-services.md`
