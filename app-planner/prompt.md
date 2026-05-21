
# HMS task: Stabilize OPD billing display, extract reusable OPD actions, improve patient detail actions, and fix OPD workflow updates

## Goal

Improve the existing HMS OPD workflow without rebuilding it from scratch.

The current project already includes:

- Flutter frontend using Riverpod, `AppWorkspace`, `AppListTable`, shared components, localization, and permission-aware actions.
- Express/Prisma backend with OPD flow, triage, billing, payment, patient, visit queue, appointments, audit logs, and realtime/WebSocket updates.
- Existing OPD encounter creation dialog.
- Existing OPD action dialogs inside the OPD page.
- Existing patient registry quick actions.
- Existing backend OPD consultation billing enrichment and `correct-stage` support.

Your task is to consolidate, fix, and complete the existing implementation.

Do not duplicate existing OPD encounter/start-flow work.

---

## Key verified codebase baseline

### Frontend

Important files:

- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
  - Large file currently containing OPD table logic and many OPD action dialogs.
  - Contains `FlowActionsDialog`, `RecordVitalsDialog`, `DoctorReviewDialog`, `AssignDoctorDialog`, `ConsultationPaymentDialog`, `CorrectStageDialog`, `ReferralDialog`, `FollowUpDialog`, `RoutingDecisionDialog`, `OpdDispositionDialog`, `PrintOpdSummaryDialog`, queue dialogs, and appointment dialogs.
  - Currently imports `frontend/lib/shared/opd_actions/opd_actions.dart`.
  - OPD table merges `state.triageQueue.items`, `state.flows.items`, `state.queueEntries.items`, and appointments.
  - Billing display currently has frontend-local helpers such as `_flowBillingLabel`, `_flowBillingState`, `_queueBillingLabel`, and `_queueBillingState`.

- `frontend/lib/shared/components/opd_encounter_dialog.dart`
  - Already contains reusable `OpdEncounterDialog`.
  - Already supports:
    - Existing patient
    - Appointment patient
    - New patient
    - Routing section
    - Billing section
    - Active OPD encounter detection
    - “Open active encounter” behavior
  - Do not recreate this dialog.

- `frontend/lib/shared/opd_actions/opd_action_context.dart`
  - Already contains `OpdActionContextPanel`.
  - It shows copy buttons and context facts.
  - Currently `frontend/lib/shared/opd_actions/opd_actions.dart` only exports this file.
  - Expand this shared OPD action area rather than creating unrelated action folders.

- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`
  - Currently imports `features/opd/presentation/pages/opd_workspace_page.dart` to reuse `FlowActionsDialog`.
  - This is page-to-page coupling and should be removed.
  - Patient detail already uses `AppWorkspacePatientContextHeader` with `fieldStyle: AppWorkspacePatientContextFieldStyle.inline`.
  - Quick actions already include OPD-related actions, but they should reuse shared OPD action components instead of importing the OPD page.

- `frontend/lib/shared/layout/app_workspace.dart`
  - `AppWorkspacePatientContextHeader` already supports:
    - `AppWorkspacePatientContextFieldStyle.tiles`
    - `AppWorkspacePatientContextFieldStyle.inline`
  - Keep compatibility with other modules.

### Backend

Important files:

- `backend/src/modules/opd-flow/services/opd-flow.service.js`
  - Already contains consultation billing enrichment helpers:
    - `resolveConsultationPaymentAmount`
    - `resolveConsultationFeeAmount`
    - `resolveConsultationPaymentStatus`
    - `enrichConsultationBillingForListItems`
  - `listOpdFlows` already calls `enrichConsultationBillingForListItems(items)`.
  - `getOpdFlowById` already resolves consultation invoice/payment details.
  - `payConsultation` already supports correction-like behavior when consultation is already paid.
  - `correctStage` already updates encounter status, visit queue status, appointment status, audit logs, and realtime events.

- `backend/src/modules/opd-flow/routes/opd-flow.routes.js`
  - Existing routes include:
    - `POST /api/v1/opd-flows/start`
    - `POST /api/v1/opd-flows/bootstrap`
    - `POST /api/v1/opd-flows/:id/pay-consultation`
    - `POST /api/v1/opd-flows/:id/record-vitals`
    - `POST /api/v1/opd-flows/:id/assign-doctor`
    - `POST /api/v1/opd-flows/:id/doctor-review`
    - `POST /api/v1/opd-flows/:id/disposition`
    - `POST /api/v1/opd-flows/:id/correct-stage`

- `backend/src/modules/triage/`
  - Triage routes proxy some OPD actions to OPD flow service.
  - Frontend currently uses triage endpoints for some actions.
  - Confirm which route is canonical per action before changing.

---

## Non-goals

Do not:

- Create a second OPD workspace.
- Create a second OPD encounter dialog.
- Duplicate OPD action dialogs inside Patient Registry.
- Hard-code user-facing strings.
- Hard-code USD or `$`.
- Replace existing `AppWorkspace`, `AppListTable`, `AppDialog`, `AppPermissionActionItem`, or localization patterns.
- Bypass permissions, tenant/facility scoping, audit logs, or realtime events.

---

## Visual and UX requirements to preserve

The coding agent does not have the screenshots, so implement these written visual requirements exactly.

### OPD page

- Page title: `OPD flow`.
- Top-right primary action: `Start OPD encounter`.
- OPD table columns include:
  - Patient
  - Visit type
  - Queue/status
  - Payer/billing
  - Wait time
- Payer/billing column must show stable billing labels and amounts, for example:
  - `Payment required | UGX 20,000`
  - `Paid | UGX 20,000`
  - `Completed | UGX 30,000`
  - `Not required`

### Start OPD encounter dialog

Reuse `OpdEncounterDialog`.

It must keep:

- Title: `Start OPD encounter`
- Existing patient mode
- Appointment patient mode
- New patient mode
- Patient search/select
- Appointment search/select
- New patient first name, last name, gender
- Routing section with arrival mode and provider
- Billing section with consultation fee, currency, notes, and payment-required toggle
- Active encounter panel
- `Open active encounter` instead of creating duplicates

### Patient detail modal

The patient detail header should be clean and lightweight.

Keep:

- Patient name
- MRN/patient number
- Age/sex
- Active/inactive status
- DOB
- Phone
- Facility
- Current visit

Use inline facts such as:

- `Date of birth: Feb 26, 1985`
- `Phone: +15550000003`
- `Facility: Demo General Hospital`
- `Visit: OPD - ENC0000012 - Open`

Avoid bordered cards for every small field.

Use existing `AppWorkspacePatientContextHeader` inline mode. If more styling is needed, extend it safely without breaking other modules.

### OPD action dialogs

When opening an OPD patient/encounter:

- Show the current/next required action first.
- Show other useful actions after it.
- Every OPD action dialog must show:
  - Copy patient ID
  - Copy encounter ID
  - Current stage
  - Next step
  - Payment state
  - Provider

Use or extend `OpdActionContextPanel`.

---

## Objective 1: Fix OPD billing/payment display

The OPD table must use one canonical backend-backed billing state.

Expected rules:

| Backend state | Display |
|---|---|
| Payment required and unpaid | `Payment required | <currency amount>` |
| Paid | `Paid | <currency amount>` |
| Completed and paid | `Completed | <currency amount>` |
| Billing not required | `Not required` |
| No amount exists in backend | Show status only; do not flicker |

Use backend currency. Do not default to USD unless backend/default tenant/facility currency truly resolves to USD.

### Implementation guidance

Backend should return a consistent consultation summary for list and detail responses:

- `require_payment`
- `is_paid`
- `consultation_fee`
- `paid_amount`
- `currency`
- `invoice_id`
- `payment_id`
- `payment_status`

If helpful, add explicit canonical fields such as:

- `billing_state`
- `billing_amount`
- `billing_currency`
- `billing_label_source`

But avoid unnecessary API churn if existing fields are enough.

Frontend should stop duplicating billing-state logic in multiple places.

Create or extend shared OPD billing helpers under `frontend/lib/shared/opd_actions/`, for example:

- `frontend/lib/shared/opd_actions/opd_billing_state.dart`
- `frontend/lib/shared/opd_actions/opd_billing_formatters.dart`

Then use the same helper in:

- OPD table
- `OpdActionContextPanel`
- Consultation billing dialog
- Patient Registry active OPD actions

---

## Objective 2: Stop OPD table blinking/flickering

Investigate these frontend areas:

- `OpdWorkspaceController._syncInterval`
- `OpdWorkspaceController._syncVisibleData`
- `OpdWorkspaceController._refreshVisiblePages`
- `_tableItems(...)` in `opd_workspace_page.dart`
- `AppListTable` row keys
- `_OpdTableItem.stableKey`
- `_OpdTableItem.categoryKey`
- Merging of `flows`, `triageQueue`, `queueEntries`, and appointments

Requirements:

- Do not clear billing/status cells during refresh.
- Do not temporarily replace a flow row with a queue row when the encounter exists.
- Do not alternate billing display between `flows`, `triageQueue`, and `queueEntries`.
- Use encounter/flow ID as primary row identity.
- Only merge records that represent the same encounter/flow.
- Batch refresh results and emit one state update after visible page data is loaded.
- Keep previous row values if a refresh response temporarily lacks optional billing amount fields.
- Wait time may update naturally; payment/status text must not blink.

`_refreshVisiblePages` should prefer `Future.wait`/batched result handling and emit a single coherent state update.

---

## Objective 3: Extract reusable OPD action components

Move OPD-specific action dialogs out of:

- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`

Into shared OPD action files, preferably under:

- `frontend/lib/shared/opd_actions/`
- `frontend/lib/shared/opd_actions/dialogs/`
- `frontend/lib/shared/opd_actions/opd_action_context.dart`
- `frontend/lib/shared/opd_actions/opd_action_panel.dart`
- `frontend/lib/shared/opd_actions/opd_actions.dart`

Extract/reuse:

- Main OPD action panel/dialog
- Consultation payment / billing management dialog
- Record/edit vitals dialog
- Assign/change doctor dialog
- Doctor review dialog
- Correct stage dialog
- Routing/move queue dialog
- Disposition dialog
- Diagnosis action
- Procedure action
- Lab request action
- Radiology request action
- Prescription action
- Referral dialog
- Follow-up dialog
- Print summary dialog
- OPD encounter context/copy-ID panel

After refactor:

- `opd_workspace_page.dart` should mostly compose shared OPD actions.
- Patient Registry must use shared OPD action dialogs.
- Remove `patient_registry_page.dart` dependency on `features/opd/presentation/pages/opd_workspace_page.dart`.
- Avoid circular imports.
- Update `frontend/lib/shared/opd_actions/opd_actions.dart` exports.

---

## Objective 4: Show useful OPD actions with next action first

The OPD action list must always put the current/next required workflow action first.

Required priority:

| Stage | First action |
|---|---|
| `WAITING_CONSULTATION_PAYMENT` | Pay/manage consultation billing |
| `WAITING_VITALS` | Record/edit vitals |
| `WAITING_DOCTOR_ASSIGNMENT` | Assign/change doctor |
| `WAITING_DOCTOR_REVIEW` | Doctor review |
| `WAITING_DISPOSITION` | Disposition |
| `LAB_REQUESTED` | Disposition / lab follow-up |
| `RADIOLOGY_REQUESTED` | Disposition / radiology follow-up |
| `LAB_AND_RADIOLOGY_REQUESTED` | Disposition / lab/radiology follow-up |
| `PHARMACY_REQUESTED` | Disposition / pharmacy follow-up |

After the first action, show other useful actions:

- Correct stage
- Assign/change doctor
- Record/edit vitals
- Manage consultation billing
- Doctor review
- Add diagnosis
- Request lab
- Request radiology
- Prescribe
- Add procedure
- Refer
- Follow up
- Admission/IPD
- ICU transfer/view where applicable
- Emergency transfer/view where applicable
- Print summary
- Patient report
- Copy patient ID
- Copy encounter ID

Do not hide update/edit actions only because the stage has progressed.

Respect permissions using the existing `AccessRequirement`, `AppPermissionActionItem`, and `AppAccessActionGate` patterns.

---

## Objective 5: Allow updating already completed action data

The OPD workflow must support safe updates.

Examples:

- Paid consultation with wrong/missing amount:
  - Show `Manage consultation billing` or `Update consultation billing`.
  - Create audit-safe correction/payment adjustment.
  - Update invoice/payment/OPD consultation summary consistently.
  - Preserve payment history.
  - Emit realtime updates.

- Existing vitals:
  - Show `Edit vitals`.
  - Load existing values.
  - Update existing vital records where possible.
  - Do not create duplicate measurements for the same encounter/vital type unless clinically intended.

- Existing provider:
  - Show `Change doctor`.
  - Update provider safely.

- Existing doctor review/orders:
  - Allow add/update where backend contracts already support it.
  - If backend support is missing, add the smallest safe endpoint.

For financial data, never silently overwrite history. Use correction/payment/adjustment records according to the existing billing model.

---

## Objective 6: Fix Correct stage

Frontend currently has both OPD and triage correct-stage repository methods. Verify the correct canonical route for the action.

Preferred OPD action route:

- `POST /api/v1/opd-flows/:id/correct-stage`

unless the triage route is intentionally required for a triage-only context.

Requirements:

- Allow selecting any valid OPD workflow stage except the current one.
- Do not default to the current stage as the submit value.
- Show current stage and target stage clearly.
- Require a reason when:
  - Moving backwards
  - Skipping stages
  - Moving to terminal stage
- Submit exact backend enum values from `WORKFLOW_STAGE_VALUES`.
- Backend must update:
  - Encounter status
  - Visit queue status
  - Appointment status where linked
  - Audit logs
  - Realtime OPD events
- Frontend must refresh:
  - OPD table
  - Selected OPD detail
  - Patient Registry selected detail/current visit where applicable

Show clear success/failure feedback.

---

## Objective 7: Use one reusable OPD context/reference component

Extend `OpdActionContextPanel` if needed.

It must show:

- Copy patient ID
- Copy encounter ID
- Current stage
- Next step
- Payment state
- Provider

Use it in every OPD action dialog, including:

- Main OPD action dialog
- Pay/manage consultation billing dialog
- Record/edit vitals dialog
- Assign/change doctor dialog
- Doctor review dialog
- Correct stage dialog
- Diagnosis/procedure/lab/radiology/prescription dialogs
- Referral/follow-up dialogs
- Print summary dialog
- Queue/move/start consultation dialogs where encounter context exists

Use localization keys. Do not hard-code labels.

---

## Objective 8: Improve Patient Registry detail modal

Patient Registry should act as a command center for a selected patient.

Requirements:

- Keep the existing inline patient header style.
- Preserve patient name, MRN, age/sex, active status, DOB, phone, facility, and visit.
- Avoid heavy bordered field cards.
- Keep icons only if they improve readability.
- Do not break other modules using `AppWorkspacePatientContextHeader`.

Quick actions should include:

- Appointment
- Start OPD encounter
- View active OPD encounter
- Record/edit vitals
- Triage
- Assign/change doctor
- Doctor review
- Billing/manage billing
- Admission/IPD
- ICU
- Emergency
- Lab request
- Radiology request
- Prescription
- Patient report
- Print summary
- Copy patient ID
- Copy active encounter ID where available

Actions should either open shared OPD dialogs or navigate to the correct module filtered to the patient/encounter.

---

## Objective 9: Realtime/database reflection

After every OPD action:

- Persist to database.
- Return updated OPD flow detail/summary.
- Emit realtime events.
- Update Riverpod state immediately.
- Refresh affected views:
  - OPD table
  - Selected OPD action dialog
  - Patient detail modal
  - Billing workspace if billing changed
  - Triage/Nursing/Clinical views if affected

Do not require manual refresh to see corrected billing/status/stage values.

---

## Objective 10: Localization

Do not hard-code new user-facing strings.

Update:

- `frontend/lib/l10n/app_en.arb`

Regenerate committed localization files if this project commits generated files.

Prefer clear labels:

- `Start OPD encounter`
- `Open active encounter`
- `Manage consultation billing`
- `Update consultation billing`
- `Record vitals`
- `Edit vitals`
- `Assign doctor`
- `Change doctor`
- `Correct stage`
- `Copy patient ID`
- `Copy encounter ID`

Existing stale key names may remain only if renaming would create unnecessary churn, but visible values must be correct.

---

## Objective 11: Tests

Add or update tests in the existing test structure.

Frontend tests:

- `frontend/test/features/opd/presentation/opd_workspace_controller_test.dart`
- `frontend/test/features/opd/presentation/start_walk_in_dialog_test.dart`
- `frontend/test/features/opd/data/dtos/opd_dtos_test.dart`
- `frontend/test/features/patients/presentation/patient_registry_page_test.dart`
- `frontend/test/shared/components/app_list_table_test.dart`
- `frontend/test/shared/layout/app_workspace_test.dart`
- `frontend/test/l10n/hard_coded_ui_text_test.dart`

Backend tests:

- `backend/src/tests/modules/opd-flow/services/opd-flow.service.test.js`
- `backend/src/tests/modules/opd-flow/routes/opd-flow.routes.test.js`
- `backend/src/tests/modules/opd-flow/controllers/opd-flow.controller.test.js`
- Billing/payment tests if billing correction behavior changes.

Required test cases:

- Paid OPD row displays paid amount.
- Payment-required OPD row displays consultation fee.
- Paid row without direct paid amount resolves amount from invoice/payment if available.
- OPD table does not blank or flicker billing values during refresh.
- Correct stage rejects current-stage submit.
- Correct stage updates backend and frontend state.
- Existing paid consultation can be managed/corrected safely.
- Existing vitals can be edited.
- Patient detail quick action opens shared OPD action dialog.
- Patient Registry no longer imports `opd_workspace_page.dart` only to access OPD dialogs.
- Current/next OPD action appears first.
- Copy patient ID and copy encounter ID exist in OPD action dialogs.
- Patient detail header uses cleaner inline layout.
- Realtime refresh updates OPD and patient detail state.

Run targeted tests first, then broader suites where practical:

Frontend:

```bash
cd frontend
flutter test test/features/opd/presentation/opd_workspace_controller_test.dart
flutter test test/features/opd/presentation/start_walk_in_dialog_test.dart
flutter test test/features/patients/presentation/patient_registry_page_test.dart
flutter test test/l10n/hard_coded_ui_text_test.dart
````

Backend:

```bash
cd backend
npm run test:backend -- src/tests/modules/opd-flow/services/opd-flow.service.test.js
npm run test:backend -- src/tests/modules/opd-flow/routes/opd-flow.routes.test.js
npm run test:backend -- src/tests/modules/opd-flow/controllers/opd-flow.controller.test.js
```

---

## Acceptance criteria

The task is complete when:

* OPD billing/payment labels and amounts are accurate and stable.
* `Paid` rows show paid amount whenever backend has it or can resolve it.
* `Payment required` rows show fee amount whenever available.
* Billing/status text no longer blinks or alternates during background refresh.
* OPD action dialogs are reusable shared components.
* `opd_workspace_page.dart` is reduced to workspace composition/table wiring.
* Patient Registry reuses shared OPD action dialogs and no longer depends on OPD page dialogs.
* OPD action list shows the next required action first.
* Useful update/manage actions remain accessible after workflow progression.
* Existing action data can be updated safely.
* Correct stage works end-to-end.
* Every OPD action dialog has copy patient ID and copy encounter ID.
* Patient detail modal has cleaner inline facts and comprehensive quick actions.
* Updates persist and reflect immediately across OPD, Patient Registry, Billing, and related modules.
* Permissions, tenant/facility scoping, localization, accessibility, audit logging, and realtime events are preserved.
* Tests pass.

---

## Final response requirements

In your final response, list:

* Modified files with exact paths
* New files with exact paths
* Deleted files with exact paths, if any
* Brief summary of what changed
* Tests run and results
* Remaining limitations or follow-up notes

