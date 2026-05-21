# HMS task: Improve OPD billing display, reusable OPD actions, patient detail actions, and stage/action workflows

## Project context

The HMS project contains:

- `frontend`: Flutter app using Riverpod, shared widgets, localization, and workspace-style screens.
- `backend`: Express/Prisma API with OPD flow, billing, patient, appointment, visit queue, and realtime/WebSocket logic.
- `app-planner`: architecture and implementation rules.

Relevant frontend files to inspect first:

- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
- `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
- `frontend/lib/features/opd/domain/entities/opd_entities.dart`
- `frontend/lib/features/opd/data/dtos/opd_dtos.dart`
- `frontend/lib/features/opd/data/repositories/opd_repository_impl.dart`
- `frontend/lib/features/opd/domain/repositories/opd_repository.dart`
- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`
- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/shared/actions/`
- `frontend/lib/shared/clinical_actions/`
- `frontend/lib/shared/layout/app_workspace.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/l10n/app_en.arb`

Relevant backend files to inspect first:

- `backend/src/modules/opd-flow/routes/opd-flow.routes.js`
- `backend/src/modules/opd-flow/controllers/opd-flow.controller.js`
- `backend/src/modules/opd-flow/services/opd-flow.service.js`
- `backend/src/modules/opd-flow/repositories/opd-flow.repository.js`
- `backend/src/modules/opd-flow/schemas/opd-flow.schema.js`
- `backend/src/modules/patient/services/patient.service.js`
- `backend/src/modules/patient/services/patient-workspace.service.js`
- `backend/src/modules/billing/`
- `backend/src/modules/payment/`
- Realtime/WebSocket helpers used by OPD and billing.

## Important current state

Some earlier OPD encounter work already exists:

- `OpdEncounterDialog` is already in `frontend/lib/shared/components/opd_encounter_dialog.dart`.
- The label **Start OPD encounter** already appears in OPD and patient quick actions.
- The dialog can show an **Active OPD encounter found** notice with encounter ID, stage, visit type, provider, billing state, amount, and arrival time.
- The patient detail modal already has a **Start OPD encounter** quick action.

Do not duplicate this work. Reuse and improve it.

## Visual requirements from screenshots

The coding agent will not have screenshots, so preserve these visual/UX details in code:

1. OPD page:
   - Page title: **OPD flow**.
   - Top-right primary action: **Start OPD encounter**.
   - OPD table columns include patient, visit type, queue/status, payer/billing, and wait time.
   - Billing values such as **Paid**, **Payment required**, **Completed**, and amounts are shown in the payer/billing column.

2. Start OPD encounter dialog:
   - Title: **Start OPD encounter**.
   - Three patient modes:
     - Existing patient
     - Appointment patient
     - New patient
   - Existing patient mode searches/selects an existing patient.
   - Appointment patient mode searches/selects a scheduled appointment.
   - New patient mode captures first name, last name, gender, routing, billing, and notes.
   - Routing section includes arrival mode and provider.
   - Billing section includes consultation fee, currency, notes, and payment-required toggle.
   - If an active encounter exists, show a clear active encounter panel and offer **Open active encounter** instead of creating a duplicate.

3. Patient detail modal:
   - Current header shows patient name, MRN, age/sex, status, DOB, phone, facility, and visit.
   - The current field cards have too many borders and look heavy.
   - Redesign the details to be cleaner, preferably inline rows such as:
     - `Date of birth: Feb 26, 1985`
     - `Phone: +15550000003`
     - `Facility: Demo General Hospital`
     - `Visit: OPD - ENC0000012 - Open`
   - Icons may remain, but avoid bordered cards for every small field.

4. OPD action dialogs:
   - Clicking an OPD patient opens an action dialog.
   - The current/next needed action must appear first.
   - Example: if the patient is waiting for vitals, **Record vitals** must be first.
   - If waiting for payment, **Pay consultation** or **Manage consultation billing** must be first.
   - Every OPD action dialog must show copy buttons:
     - **Copy patient ID**
     - **Copy encounter ID**

## Main objectives

### 1. Fix OPD table billing/payment display

The OPD table currently shows inconsistent billing values:

- Some rows show **Paid** but no amount.
- Some rows show amounts that blink/flicker.
- Some paid/required/completed values do not reflect the latest database state.

Fix this so the OPD table always uses one canonical backend-backed billing state.

Expected display rules:

- If payment is required and unpaid:
  - Show `Payment required`
  - Show the consultation fee amount when available.
  - Example: `Payment required | UGX 20,000`

- If paid:
  - Show `Paid`
  - Show the paid amount when available.
  - Example: `Paid | UGX 20,000`

- If completed and paid:
  - Show `Completed | UGX 30,000` or the project’s equivalent canonical label.

- If billing is not required:
  - Show `Not required`.

- If the backend truly has no amount:
  - Show the status without amount, but do not blink or alternate between amount/no amount.

Use the actual currency from the backend. Do not hard-code `$` or USD when the encounter uses UGX.

### 2. Stop table blinking/flickering

Investigate and fix the blinking table values.

Likely areas to inspect:

- `OpdWorkspaceController._syncInterval`
- `OpdWorkspaceController._refreshVisiblePages`
- Multiple `_emit(...)` calls during one refresh cycle.
- OPD table item merging in `_tableItems(...)`.
- Row keys in `AppListTable`.
- The OPD row `categoryKey`, which currently deduplicates by patient identifiers.

Requirements:

- Do not clear table cells while refreshing.
- Do not temporarily show stale/unknown billing during refresh.
- Prefer batching OPD refresh data and emitting once after all visible OPD pages are loaded.
- Keep stable row identity using encounter/flow ID first, not patient ID.
- Only merge records that represent the same encounter/flow.
- Do not let the same row alternate between `flows`, `triageQueue`, and `queueEntries` if that changes billing labels.
- Keep the table visually stable during realtime updates.
- Wait time may update naturally, but payment/status text must not blink.

### 3. Make OPD action dialogs reusable and shared

Many OPD action dialogs are currently defined inside `opd_workspace_page.dart`.

Move reusable action dialogs into an appropriate shared folder, for example:

- `frontend/lib/shared/opd_actions/`
- `frontend/lib/shared/opd_actions/dialogs/`
- `frontend/lib/shared/opd_actions/opd_action_context.dart`
- `frontend/lib/shared/opd_actions/opd_action_panel.dart`
- `frontend/lib/shared/opd_actions/opd_actions.dart`

Use existing shared folders where appropriate:

- `shared/actions`
- `shared/clinical_actions`
- `shared/components`

Move or extract these OPD-specific dialogs/actions where appropriate:

- Consultation payment / billing management
- Record/edit vitals
- Assign doctor
- Doctor review
- Correct stage
- Routing/move queue
- Disposition
- Diagnosis
- Procedure
- Lab request
- Radiology request
- Prescription
- Referral
- Follow-up
- Print summary
- OPD action panel/grid
- OPD encounter context/copy-ID panel

After refactor:

- `opd_workspace_page.dart` should mostly compose shared dialogs/actions.
- Patient Registry should reuse the same shared dialogs/actions.
- Do not maintain duplicate OPD action forms in Patient Registry and OPD.

### 4. Show all useful OPD actions, with the next action first

When a user opens an OPD encounter, show a comprehensive set of actions.

The first action must be the current/next workflow action:

- `WAITING_CONSULTATION_PAYMENT` → Pay/manage consultation billing
- `WAITING_VITALS` → Record vitals
- `WAITING_DOCTOR_ASSIGNMENT` → Assign doctor
- `WAITING_DOCTOR_REVIEW` → Doctor review
- `WAITING_DISPOSITION` → Disposition
- Lab/radiology/pharmacy-related stages → relevant follow-up/disposition actions

After the first action, show other useful actions:

- Correct stage
- Assign doctor
- Record/edit vitals
- Manage billing
- Doctor review
- Add diagnosis
- Request lab
- Request radiology
- Prescribe
- Add procedure
- Refer
- Follow up
- Admission/IPD
- ICU transfer/view
- Emergency view/transfer where applicable
- Print summary
- Patient report
- Copy patient ID
- Copy encounter ID

Do not hide actions only because a stage has already progressed. If the action is an update/edit action, allow it to open in update mode.

Respect permissions. If the user lacks permission, either hide or disable according to the existing project pattern, but avoid stage-based hiding that prevents legitimate updates.

### 5. Allow updating already completed action data

The OPD workflow should not be one-way only.

If data already exists, the action should become an update/manage action instead of disappearing or failing.

Examples:

- If consultation was paid but amount is wrong or missing:
  - Show **Manage consultation billing** or **Update consultation billing**.
  - Allow an audit-safe correction/update.
  - Update the database and refresh the OPD table immediately.

- If vitals already exist:
  - Show **Edit vitals**.
  - Load existing values.
  - Save updates through the existing vital-sign update flow or a proper backend endpoint.

- If doctor is already assigned:
  - Show **Change doctor** or allow Assign doctor to update provider.

- If doctor review exists:
  - Allow adding/updating notes/orders where medically appropriate.

- If diagnosis/procedure/lab/radiology/prescription/referral/follow-up exists:
  - Support add-new and update-existing where backend contracts already exist.
  - If backend support is missing, add the smallest safe endpoint needed.

For financial data, do not silently overwrite payment history. Use an audit-safe approach:

- Update invoice/payment/OPD consultation summary consistently.
- Preserve audit logs.
- Use billing adjustments or correction records if the existing billing model requires them.
- Emit realtime updates after correction.

### 6. Fix “Correct stage”

The **Correct stage** action currently appears not to work reliably.

Requirements:

- Correct stage must allow selecting any valid OPD workflow stage except the current one.
- The current stage should not be the default selectable submit value unless the form clearly requires a different choice.
- Show the current stage and target stage clearly.
- Require a reason when moving backwards, skipping stages, or moving to a terminal stage.
- Submit the exact backend enum expected by `opd-flow.service.js`.
- Backend must:
  - Update encounter status correctly.
  - Update visit queue status correctly.
  - Update appointment status correctly where linked.
  - Emit realtime OPD updates.
  - Write audit logs.
- Frontend must:
  - Refresh OPD table.
  - Refresh selected flow details.
  - Refresh patient detail current visit where applicable.
  - Show clear success/failure feedback.

Do not bypass permissions or audit logging.

### 7. Copy patient ID and encounter ID everywhere

Create one reusable context/reference component for OPD actions.

It should display:

- Copy patient ID
- Copy encounter ID
- Current stage
- Next step
- Payment state
- Provider

Use it in:

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

Use localization keys instead of hard-coded labels.

### 8. Improve patient detail modal

The Patient Registry detail modal should become a command center for the selected patient.

Update the header:

- Keep patient name, MRN, age/sex, and active status prominent.
- Replace the heavy bordered field cards with cleaner inline patient facts.
- Example layout:
  - `Date of birth: Feb 26, 1985`
  - `Phone: +15550000003`
  - `Facility: Demo General Hospital`
  - `Visit: OPD - ENC0000012 - Open`
- Keep icons if they improve readability.
- Avoid excessive borders around every small field.
- Do not break other modules using `AppWorkspacePatientContextHeader`; add an optional style/variant if needed.

Expand quick actions:

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

Actions should either open a reusable dialog or navigate to the correct module filtered to that patient/encounter.

### 9. Cross-module consistency

The same action should look and behave the same everywhere:

- OPD module
- Patient Registry
- Emergency module if applicable
- Clinical/Nursing/Billing screens where the same action is exposed

Examples:

- **Start OPD encounter** should use the same label, icon, permission requirement, tooltip, and dialog.
- **Record vitals** should use the same form.
- **Assign doctor** should use the same provider picker.
- **Manage consultation billing** should use the same billing correction/payment form.

Avoid redefining similar dialogs per screen.

### 10. Realtime/database reflection

After every action update:

- Persist to the database.
- Return the updated OPD flow detail/summary from backend.
- Emit realtime events for affected workspaces.
- Update frontend Riverpod state without waiting for manual refresh.
- Refresh affected views:
  - OPD table
  - selected OPD action dialog
  - Patient detail modal
  - Billing workspace if affected
  - Triage/Nursing/Clinical views if affected

Do not make the user press refresh to see corrected billing/status/stage values.

### 11. Backend requirements

Before adding new endpoints, inspect existing contracts.

Existing OPD endpoints include:

- `POST /api/v1/opd-flows/start`
- `POST /api/v1/opd-flows/bootstrap`
- `POST /api/v1/opd-flows/:id/pay-consultation`
- `POST /api/v1/opd-flows/:id/record-vitals`
- `POST /api/v1/opd-flows/:id/assign-doctor`
- `POST /api/v1/opd-flows/:id/doctor-review`
- `POST /api/v1/opd-flows/:id/disposition`
- `POST /api/v1/opd-flows/:id/correct-stage`

If needed, add minimal backend support for:

- Updating consultation billing/payment summary safely.
- Returning canonical OPD billing state and amount in list endpoints.
- Updating existing OPD action records.
- Loading active OPD context for Patient Registry actions.
- Returning patient current active encounter details.

Backend must preserve:

- tenant/facility scoping
- permissions
- validation
- audit logs
- realtime events
- consistent response format

### 12. Localization

Do not hard-code new user-facing strings.

Update:

- `frontend/lib/l10n/app_en.arb`
- generated localization files if the project requires committed generated files.

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

Existing stale keys such as `opdStartWalkInAction` may remain only if renaming causes unnecessary churn, but values must be correct. Prefer clearer key names if safe.

### 13. Tests

Add/update tests in the existing test structure.

Frontend tests:

- `test/features/opd/presentation/opd_workspace_controller_test.dart`
- `test/features/opd/presentation/start_walk_in_dialog_test.dart`
- `test/features/opd/data/dtos/opd_dtos_test.dart`
- `test/features/patients/presentation/patient_registry_page_test.dart`
- `test/shared/components/app_list_table_test.dart`
- `test/shared/layout/app_workspace_test.dart`
- `test/l10n/hard_coded_ui_text_test.dart`

Backend tests:

- `backend/src/tests/modules/opd-flow/services/opd-flow.service.test.js`
- `backend/src/tests/modules/opd-flow/routes/opd-flow.routes.test.js`
- `backend/src/tests/modules/opd-flow/controllers/opd-flow.controller.test.js`
- Billing/payment tests if billing correction is changed.

Test cases:

- Paid OPD row displays amount.
- Payment-required OPD row displays fee.
- Paid row without direct paid amount resolves amount from invoice/payment if available.
- OPD table does not blank or flicker billing values during refresh.
- Correct stage updates backend and frontend state.
- Correct stage rejects current-stage submit with a clear validation message.
- Existing paid consultation can be managed/corrected safely.
- Existing vitals can be edited.
- Patient detail quick action opens reusable OPD action dialogs.
- Current/next OPD action is first in the action list.
- Copy patient ID and copy encounter ID buttons exist in all OPD action dialogs.
- Patient detail header uses the cleaner inline layout.
- Realtime refresh updates OPD and patient detail state.

### 14. Acceptance criteria

The task is complete when:

- OPD billing/payment labels and amounts are accurate and stable.
- No OPD table billing/status text blinks or alternates during background refresh.
- `Paid` rows show the paid amount whenever the backend has it.
- OPD action dialogs are reusable shared components, not duplicated inside pages.
- OPD action list shows the next required action first.
- All useful OPD actions remain accessible for an active encounter.
- Existing data can be updated safely instead of being blocked by workflow progression.
- Correct stage works end-to-end.
- Every OPD action dialog has copy patient ID and copy encounter ID actions.
- Patient detail modal has a cleaner header and more comprehensive quick actions.
- Updates persist to the database and reflect immediately across OPD, Patient Registry, Billing, and related modules.
- Permissions, tenant/facility scoping, localization, accessibility, and audit logging are preserved.
- Tests pass.

## Output requirements

Modify only necessary files.

For the final response, list:

- Modified files with exact paths
- New files with exact paths
- Deleted files with exact paths, if any
- A brief summary of what changed
- Tests run and their results
- Any remaining limitations or follow-up notes

If any file is deleted, include a safe deletion script.