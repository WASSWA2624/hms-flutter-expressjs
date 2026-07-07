# Fix OPD Request Lab flow

## Problem
In **OPD → Request lab**, users can browse and select lab tests/panels, but submission fails. The dialog also shows the wrong patient identifier.

## Observed behavior (see screenshot)
- After selecting items and clicking **Request lab**, a red error banner appears:
  - `Enter a valid Lab Requests.0.lab Test Id.`
  - `Enter a valid Lab Requests.1.lab Test Id.`
- Selected tests display correctly in the table (names, types, prices).
- **Patient ID** shows an internal UUID (e.g. `4e73222f-7b32-4a31-a1c1-9c1b59889479`) instead of the human-friendly ID (e.g. `PAT0000001`).
- **Encounter ID** displays correctly (e.g. `ENC0000003`).

## Expected behavior
1. **Request lab** submits successfully and creates the lab order.
2. **Patient ID** in the dialog shows the human-friendly ID (`human_friendly_id`), consistent with how Encounter ID is shown.
3. API payloads use backend-accepted identifiers (friendly IDs like `LBT…` / `STD_LAB_TEST:…`, not internal UUIDs).
4. Validation errors, if any remain, are user-friendly — not raw field-path messages.

## Likely root causes
1. **Lab test IDs** — `ClinicalLabOrderActionDialog` submits `option.apiId` (`publicId ?? id`). If catalog search results lack `human_friendly_id`, the payload falls back to internal UUIDs, which fail `labTestIdentifierSchema` in `backend/src/modules/opd-flow/schemas/opd-flow.schema.js`.
2. **Patient ID display** — `opd_flow_actions_dialog.dart` passes `flow.patientId ?? flow.patientIdentifier` into `ClinicalRequestPatientContext`. `patientId` is the internal UUID; `patientIdentifier` is the human-friendly ID. The precedence is reversed.

## Key files
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart` — lab order dialog wiring, patient context
- `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart` — selection table & submit payload
- `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_request_catalog_dialog.dart` — catalog search & selection
- `frontend/lib/features/clinical/data/dtos/clinical_dtos.dart` — `ClinicalCatalogOptionDto` (`id` vs `publicId`)
- `frontend/lib/features/opd/data/dtos/opd_dtos.dart` — `patientId` vs `patientIdentifier` mapping
- `backend/src/modules/opd-flow/schemas/opd-flow.schema.js` — `labTestIdentifierSchema` / `labPanelIdentifierSchema`

## Implementation guidance
1. Ensure submitted `lab_test_id` / `lab_panel_id` values are `apiId` (human-friendly), not internal UUIDs. Fix at the DTO mapping layer and/or catalog search response handling if `human_friendly_id` is missing.
2. Change patient context to prefer `flow.patientIdentifier` over `flow.patientId`. Apply the same fix to other clinical request dialogs in `opd_flow_actions_dialog.dart` (lab, radiology, prescription, etc.) where the same pattern exists.
3. Align with how working flows handle IDs (e.g. nursing/IPD lab order tests using `LAB000001`-style IDs).
4. Add or update unit/widget tests covering:
   - Lab order submit sends friendly IDs, not UUIDs
   - Patient context displays human-friendly patient ID
5. Keep UI responsive across mobile, tablet, and desktop.

## Acceptance criteria
- [ ] Select one or more lab tests/panels → **Request lab** succeeds with no validation errors.
- [ ] Patient ID in the dialog shows the human-friendly ID (e.g. `PAT0000001`), not a UUID.
- [ ] Lab order appears in the patient's clinical/lab workflow after submission.
- [ ] Existing tests pass; new tests cover the regression.
