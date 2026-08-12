# Patient registry duplicate merge review

## Context

The Patient registry (`PatientRegistryPage`) already exposes a **Duplicate review** toolbar action when `overview.duplicates` is non-empty. It opens `PatientDuplicateReviewDialog` with scored pairs (primary vs secondary), match reasons, **Review merge**, **Dismiss**, and a follow-on **Merge preview** that ends in **Merge patients**.

Today, **Review merge** only loads a transfer-count preview, and **Merge patients** runs a whole-record merge (`previewPatientMerge` / `mergePatients`) without letting the user choose per-field values. Dismiss already persists the pair under `extension_json.duplicate_review.dismissed_pair_keys` and stays in scope.

This prompt upgrades the **Review merge → merge** path into a field-level merge workspace. Registration-time similarity (`showPatientRegistrationSimilarityDialog` / `showAppSimilarityReviewDialog`) is out of scope unless a shared field-row primitive is reused.

Follow [dialogs.mdc](/.cursor/dialogs.mdc), [forms.mdc](/.cursor/forms.mdc), [theming.mdc](/.cursor/theming.mdc), [localization.mdc](/.cursor/localization.mdc), [responsiveness.mdc](/.cursor/responsiveness.mdc), and [prompt.mdc](/.cursor/prompt.mdc). Do not restate those files.

### Terms

- **Duplicate pair:** one `PatientDuplicateCandidate` with primary and secondary patients, confidence score, classification, and match reasons.
- **Merge workspace:** the field-level comparison UI opened from **Review merge** (replaces or extends today’s transfer-count-only merge preview).
- **Field lane:** one comparable attribute row (name, DOB, gender, phone, email, identifier, etc.) shown as proposed/primary vs secondary with similarity status.
- **Keep left / Keep right:** resolve the surviving patient profile by committing the values currently on the left lane or the right lane after the user has arranged fields.
- **Auto-merge:** one action that fills each field with the better value (prefer non-empty, exact-match, or higher field score) and still transfers linked clinical/billing history so nothing is orphaned on the secondary.
- **Linked history:** encounters, admissions, orders, invoices, payments, documents, contacts, identifiers, and other patient-owned rows already moved by `mergePatients`.

## Requirements

1. **Keep the existing entry path.** The Duplicate review button below the registry tabs still opens `PatientDuplicateReviewDialog` with the overview queue. Preserve **Dismiss** behavior (pair dismissed on both patients, card removed, snackbar, overview refresh). Gate merge/dismiss with the existing duplicate-review / write atoms.

2. **Show field-level comparison in the merge workspace.** After **Review merge**, present every comparable identity/demographics/contact/identifier field side by side for that pair—not only the compact summary cards. Include match/similar/conflict status and score when the API already provides `fieldComparisons` (or equivalent). Empty values must be visible as empty, not omitted silently.

3. **Support arranging values between sides.** The user can move a field value from left to right or right to left (drag-and-drop on pointer platforms; provide an equivalent keyboard/button control so the same outcome works without drag). After arranging, the user can commit with **Keep left** or **Keep right**, meaning the chosen side’s field set becomes the surviving patient profile for the merge.

4. **Provide Auto-merge.** Add a **Merge** / **Auto-merge** action that builds one effective patient by choosing the best value per field automatically, then runs the existing history transfer so linked clinical and billing data from the secondary is retained on the survivor. Do not drop secondary history when identity fields come from the other side.

5. **Confirm before destructive commit.** Keep an explicit confirm step (footer primary action) after Keep left / Keep right / Auto-merge selection. On success: snackbar, close dialog, refresh registry overview/list, and select the surviving patient. On failure: keep the workspace open and show the failure banner.

6. **Polish the UI.** Use shared dialog, section, banner, badge, and button primitives. Layout must be scannable: pair header (score + classification + match reasons), field lanes, then actions. Maximize by default per dialogs rules. Match supported themes; no one-off colors or unthemed chrome.

7. **Cover UI states.** Implement loading (preview fetch), empty (no duplicates left), error (preview/merge/dismiss failure), busy/disabled actions while saving, success snackbars, and validation if a side cannot be resolved (missing primary/secondary). Unauthorized merge/dismiss controls must not render.

## Constraints

- Extend `PatientDuplicateReviewDialog` / patient merge APIs; do not invent a second duplicate-review entry point on the registry.
- Reuse `previewPatientMerge`, `mergePatients`, and dismiss endpoints where possible. If per-field survivor values require a payload extension, keep it additive and backward compatible; do not break whole-record merge callers.
- Prefer extending shared similarity/field-row components over a one-off visual system.
- Do not change registration-time duplicate blocking rules in this prompt.
- No unrelated registry refactors, seed changes, or docs outside l10n keys needed for new labels.

## Acceptance Criteria

1. With at least one overview duplicate and duplicate-review permission, Duplicate review opens the dialog showing the pair summary; without permission the toolbar action is absent.
2. **Review merge** opens a field-level merge workspace listing comparable fields side by side with status/score when available.
3. Moving a field value left↔right (drag or equivalent control) updates the pending survivor set; **Keep left** / **Keep right** commits that side’s arranged values as the merge profile (after confirm).
4. **Auto-merge** produces one survivor profile without orphaning secondary linked history, then merges successfully end-to-end.
5. **Dismiss** still removes the pair from the queue and persists dismissed pair keys; it does not merge.
6. Success closes or clears the resolved pair, refreshes registry data, and surfaces a snackbar; failures keep context and show an error banner.
7. Unauthorized users never see Review merge, Dismiss, Keep left/right, or Auto-merge controls.
8. UI passes representative desktop/narrow viewports and light/dark (or supported) themes without clipped primary actions.

## Verification

- Widget/controller tests for dialog actions: preview open, dismiss removes card, keep-left/keep-right/auto-merge call paths, unauthorized controls absent.
- Backend tests if merge payload gains survivor field overrides; existing merge/dismiss tests still pass.
- Manual check on `/patients`: open Duplicate review → Review merge → arrange fields → Keep left/right and Auto-merge; confirm Dismiss still hides the pair after refresh.

## Relevant Files

- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` (`PatientDuplicateReviewDialog`, merge preview panel)
- `frontend/lib/features/patients/presentation/controllers/patient_registry_controller.dart`
- `frontend/lib/features/patients/domain/repositories/patient_repository.dart`
- `frontend/lib/features/patients/data/repositories/patient_repository_impl.dart`
- `frontend/lib/shared/components/app_similarity.dart` (reuse field-row / review primitives where fit)
- `backend/src/modules/patient/services/patient-workspace.service.js` (`previewPatientMerge`, `mergePatients`, `dismissDuplicateCandidate`)
- `backend/src/modules/patient/routes/patient.routes.js`
- `frontend/test/features/patients/presentation/patient_registry_page_test.dart`
