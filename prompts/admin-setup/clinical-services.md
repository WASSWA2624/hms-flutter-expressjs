# Implement "Create lab panel" with similarity checks

## Goal

Lab **test** creation with similarity checks is already implemented. Extend the
same experience to lab **panels**. A panel is a named, coded catalog entry that
is composed by combining several existing lab tests, so the create flow must let
the admin pick the member tests and must guard against creating a panel that
duplicates or closely resembles one that already exists.

## Current state (what to build on / fix)

- Test create/edit lives in `LabCatalogItemMutationDialog`
  (`frontend/lib/shared/facility_catalog/clinical_catalog_admin_dialogs.dart`).
  For tests it runs `_guardAgainstDuplicates(...)` before save, opens
  `showLabCatalogSimilarityDialog(...)` (always, including a 0% / no-match
  result), and sends `confirm_similar: true` when the user proceeds past matches
  or an exact clash. Reuse this exact pattern for panels.
- In the same dialog, the `_isPanel` branch currently only collects
  name / code / category / description. It has **no member-test picker**, its
  `_payload()` **omits `panel_items`**, and it **skips** the similarity guard
  (`if (!_isPanel) { ... }`). These are the gaps to close.
- A reusable `_PanelTestPicker` widget already exists in
  `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart` (currently wired
  with `enabled: false`). Prefer promoting/reusing it over building a new one.
- Backend `createLabPanel` (`backend/src/modules/lab-panel/services/lab-panel.service.js`)
  accepts `panel_items` and resolves each `lab_test_id`, but performs **no**
  duplicate/similarity check and does not honor `confirm_similar`. Contrast with
  `lab-test.service.js`, which uses `@lib/lab/lab-test-similarity` and rejects
  exact/near matches with a 409 unless `confirm_similar === true`.

## Requirements

### Frontend (`LabCatalogItemMutationDialog`, panel branch)

1. Add a member-test picker to the create-panel form so the admin can add/remove
   several lab tests. Reuse `_PanelTestPicker`; require at least one test before
   Save is allowed and show a clear localized validation message otherwise.
2. Include the selected tests in the create payload as `panel_items`
   (list of `{ lab_test_id, sort_order, ... }`) matching the backend
   `normalizeLabPanelItems` contract used by `updateLabPanel`.
3. Run a similarity/duplicate check on Save before submitting, mirroring the test
   flow: scan by name + code + category, always open the similarity dialog
   (including 0% / no matches), support Cancel / Use this / Create anyway, and
   send `confirm_similar: true` when the user proceeds past matches or an exact
   clash. Also consider **test-composition overlap** (a panel whose member tests
   substantially match an existing panel) as a similarity signal.
4. Keep name/code duplicate field errors in sync with backend 409 responses,
   as the test branch already does.

### Backend (`lab-panel.service.js` + `@lib/lab`)

5. Add panel similarity/duplicate detection analogous to `lab-test-similarity.js`
   (composite score over name/code/category, plus member-test overlap). Put it in
   a focused lib module under `backend/src/lib/lab/`.
6. In `createLabPanel` (and `updateLabPanel`), reject exact or near-duplicate
   panels with a 409 similar to the lab-test service unless `confirm_similar`
   is set; strip `confirm_similar` from the persisted payload.
7. Update the panel schema/validation (`lab-panel.schema.js`) to accept
   `confirm_similar` and enforce `panel_items` on create.

### Cross-cutting (mandatory checks — see `.cursor/mandatories.mdc`)

- **Loading feedback:** use `AppButton.isLoading` for the Save/similarity scan and
  the same "checking similarity" banner pattern as tests; show localized copy.
- **Responsive UI:** the test picker + selected-tests list must work from `xs`
  through `xxl` without overflow.
- **Access control:** creating panels stays gated by `canMutateLabCatalog`
  (lab:write or tenant/facility/system admin) on both stacks.
- **Realtime UI:** on successful create, patch the Lab catalog list so the acting
  user sees the new panel immediately (no blanket invalidate).
- **Migrations:** only if a schema/DB change is actually needed.
- **l10n:** add any new strings to `app_en.arb` (and generated localizations);
  reuse existing lab keys where possible.

### Tests

- Backend: add unit tests for the new panel similarity lib and service 409 /
  `confirm_similar` behavior (mirror `lab-test-similarity.test.js` and
  `lab-test.service.test.js`).
- Frontend: extend
  `frontend/test/shared/facility_catalog/lab_catalog_item_mutation_dialog_test.dart`
  to cover the panel picker, `panel_items` payload, and the similarity flow.

## Deliverables

- Working create-panel flow with member-test selection and similarity checks on
  both stacks, matching the test experience.
- Passing new/updated tests.
- Update `screens/admin-setup/clinical-services.md` to document the new
  create-panel form (test picker) and its similarity review step.
