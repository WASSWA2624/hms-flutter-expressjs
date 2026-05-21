You are working on the HOSSPI Hospital Management System. Review the attached `app-planner.zip`, `backend.zip`, `frontend.zip`, and the provided OPD screenshots before making changes.

Fix the OPD flow bugs and simplify the OPD action dialogs while keeping the backend and frontend fully synchronized.

## Current problem

On the OPD screen, the same patient can currently end up with more than one active OPD encounter. For example, the screenshots show `Nia Demo-Charlie` appearing multiple times, including a paid consultation flow and another new walk-in flow waiting for consultation payment. This should not happen.

A patient must not be allowed to start a new OPD encounter while another OPD/emergency encounter for that patient is still open. The previous encounter must be closed first.

## Backend requirements

Work in the existing OPD flow backend structure, especially:

* `backend/src/modules/opd-flow/services/opd-flow.service.js`
* `backend/src/modules/opd-flow/controllers/opd-flow.controller.js`
* `backend/src/modules/opd-flow/repositories/opd-flow.repository.js`
* `backend/src/modules/opd-flow/routes/opd-flow.routes.js`
* `backend/src/modules/opd-flow/schemas/opd-flow.schema.js`

Implement backend protection so duplicate active OPD encounters cannot be created for the same patient.

Apply this protection to OPD flow creation paths, including:

* existing patient walk-in
* appointment patient
* queue-based start
* any other `startOpdFlow` path that creates an OPD/emergency encounter

Keep the existing appointment and visit-queue duplicate checks, but add the missing patient-level active encounter guard.

The backend must be the source of truth. Do not rely only on frontend filtering or disabling.

When a patient already has an open OPD/emergency encounter, do not create another encounter. Return the existing backend validation/error pattern used by the project so the frontend can show the failure clearly.

Ensure consultation payment data stays consistent in the OPD flow response:

* consultation fee
* currency
* consultation invoice ID
* payment status
* encounter ID
* patient ID

## Frontend requirements

Work in the existing OPD frontend structure, especially:

* `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
* `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
* `frontend/lib/features/opd/domain/entities/opd_entities.dart`
* `frontend/lib/features/opd/data/dtos/opd_dtos.dart`
* `frontend/lib/features/opd/data/repositories/opd_repository_impl.dart`

### 1. Prevent duplicate visible OPD rows

The combined OPD table should not show duplicate actionable rows for the same active patient/encounter when the same patient appears through flows, triage queue, visit queue, or appointments.

Show one clear actionable row that represents the patient’s current OPD state and next step.

### 2. Start walk-in duplicate handling

When starting a walk-in for an existing patient, the frontend must respect the backend duplicate-encounter guard.

If the backend says the patient already has an active encounter, show the error instead of creating another row.

### 3. Pay consultation dialog

In `ConsultationPaymentDialog`, pre-fill the amount and currency from the selected OPD flow’s allocated consultation fee/currency.

The user should not need to manually re-enter an amount that is already allocated to the patient.

Expected behavior:

* amount is pre-filled from the OPD flow
* currency is pre-filled from the OPD flow
* payment method remains selectable
* transaction reference and notes can remain optional
* submitting payment should use the existing OPD pay-consultation API

### 4. Simplify OPD flow action dialog

The OPD patient/flow dialog is currently too congested and places the useful actions too far down.

Refactor `FlowActionsDialog` so it is focused on advancing the OPD flow.

Do not place the main action buttons at the bottom after large detail sections. Put the action buttons near the top of the dialog.

Replace the separate grouped action sections such as:

* Reception and queue
* Triage
* Doctor consultation
* Printing

with one compact responsive action grid using the existing shared action/button patterns.

The action grid should use multiple columns where space allows, so buttons consume less vertical space.

Prioritize the current next step. For example:

* if the patient is waiting for consultation payment, `Pay consultation` should be immediately visible
* if the patient is waiting for vitals, `Record vitals` should be immediately visible
* if the patient is waiting for doctor review, doctor review actions should be immediately visible

If the current stage can be skipped or corrected using the existing flow, expose that action clearly instead of burying it.

### 5. Remove unnecessary OPD dialog clutter

The OPD flow dialog should not be dominated by details that do not help the user advance the OPD workflow.

De-emphasize or remove from the main dialog area:

* large active-flow summary blocks
* repeated arrival mode/stage/queue/wait-time panels
* vitals summary counts
* clinical notes counts
* procedures counts
* service counts
* other patient-detail style information

Those details can remain accessible elsewhere, but the OPD dialog itself should be mainly for managing the OPD flow and moving the patient to the next step.

### 6. Copy patient and encounter IDs

Add copy actions in OPD flow/action dialogs where patient and encounter context exists.

The user should be able to copy:

* patient ID
* encounter ID

Use the existing Flutter clipboard approach and shared button style.

### 7. Keep backend and frontend synchronized

After OPD actions complete, the frontend state should refresh/update so the OPD table reflects the backend state correctly.

This includes:

* starting walk-in
* paying consultation
* recording vitals
* assigning doctor
* doctor review
* correcting stage
* printing summary flow if it affects state

## Constraints

Do not add unrelated features.

Do not invent new OPD workflow stages.

Do not change the overall architecture.

Use the existing backend layering:

`route → controller → service → repository → Prisma`

Use the existing frontend patterns:

* Riverpod controller
* OPD repository
* OPD DTO/entity mapping
* shared dialog/action components
* existing permission gates

## Expected result

After the fix:

* a patient cannot have multiple active OPD encounters
* duplicate OPD rows are no longer shown for the same active patient/encounter
* the pay-consultation dialog opens with the allocated amount already filled in
* OPD action dialogs are simpler and action-first
* patient ID and encounter ID can be copied from OPD flow dialogs
* backend and frontend stay consistent after each OPD action
