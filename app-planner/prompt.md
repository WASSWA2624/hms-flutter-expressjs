# Refined prompt: Reusable OPD encounter start dialog

## Objective

Refactor the current OPD start workflow into one reusable, consistent OPD encounter creation/check-in dialog that can be opened from the OPD module, Patient Registry patient details, and any future patient-context workflow such as Emergency.

The goal is not to create separate forms per screen. The HMS app must have one canonical OPD encounter start experience with shared logic, shared validation, shared backend calls, shared duplicate-check behavior, and consistent action naming/icons across the app.

## Visual context from screenshots

The current UI shows:

- `/opd` page titled **OPD flow**.
- Top-right action currently labeled **Start walk-in**.
- Clicking it opens a modal titled **Start OPD walk-in**.
- The modal has three patient tabs:
  - **Existing patient**
  - **Appointment patient**
  - **New patient**
- Existing patient tab includes:
  - Required patient search field.
  - Routing section with arrival mode defaulting to **Walk In**.
  - Optional provider search.
  - Billing section with optional consultation fee, currency selector, notes, and **Payment required** toggle.
- Appointment patient tab includes:
  - Required appointment search field.
  - Helper text explaining that a scheduled appointment is selected to check the patient into OPD.
  - Optional provider, billing, notes, and payment toggle.
- New patient tab includes:
  - Required first name and last name.
  - Optional gender.
  - Routing and billing fields similar to existing patient flow.
- `/patients` page shows **Patient registry**.
- Opening a patient displays a patient detail modal with quick actions:
  - Appointment
  - OPD check-in
  - Triage
  - Billing
  - Admission
  - Patient report
- The **OPD check-in** quick action must open the same reusable OPD encounter dialog, not a separate form.

## Required naming update

Replace unclear or inconsistent labels such as **Start walk-in** and **OPD check-in** with one consistent action name:

**Start OPD encounter**

Use this label wherever the action creates or resumes an OPD encounter.

Recommended related labels:

- Dialog title: **Start OPD encounter**
- Primary submit button: **Start encounter**
- Duplicate active encounter action: **Open active encounter**
- Tooltip/help text: **Create or continue an OPD encounter for this patient**

Use one consistent icon across all locations, preferably a patient-plus, medical-plus, or encounter/clipboard-plus icon already available in the project icon system.

## Scope

Update only the necessary frontend/backend files after inspecting the actual codebase.

Expected surfaces to review and update:

- OPD page/header action where **Start walk-in** currently exists.
- Current OPD walk-in dialog/form implementation.
- Patient Registry patient details modal quick actions.
- Patient detail action currently labeled **OPD check-in**.
- Existing hooks/services/API wrappers used for:
  - OPD flow/encounter creation.
  - Patient search/lookup.
  - Appointment search/lookup.
  - Provider search/assignment.
  - Billing/consultation fee/invoice/payment-required state.
  - Active OPD encounter lookup.
- Existing i18n/translation files.
- Existing permission/access-control helpers.
- Relevant frontend and backend tests.

Do not rewrite unrelated OPD, patient registry, billing, triage, or emergency workflows.

## Core implementation requirements

### 1. Create one reusable OPD encounter launcher

Extract the existing OPD start dialog into a reusable component and hook.

Suggested names, adjusted to match existing project conventions:

- `StartOpdEncounterDialog`
- `StartOpdEncounterButton`
- `useStartOpdEncounter`
- `OpdEncounterStartForm`

The reusable dialog must accept patient or appointment context through props, for example:

- `open`
- `onOpenChange`
- `source`
- `initialPatientId`
- `initialPatient`
- `initialAppointmentId`
- `initialAppointment`
- `defaultArrivalMode`
- `defaultProviderId`
- `onSuccess`
- `onExistingActiveEncounter`

The dialog must support these launch contexts:

1. **From OPD page**
   - No patient preselected.
   - User can choose Existing patient, Appointment patient, or New patient.

2. **From patient details modal**
   - Patient is already known.
   - The dialog must prefill/select that patient.
   - The user should not need to search for the same patient again.
   - The dialog must detect whether this patient has an eligible appointment.

3. **Future emergency/patient-context screens**
   - The component should be reusable without duplicating form logic.
   - Do not implement unrelated emergency changes unless the existing code already exposes the action there.

### 2. Auto-select the correct patient mode

When the dialog opens with a patient context:

- If the patient has one eligible scheduled appointment that can be checked into OPD, select **Appointment patient** and prefill the appointment.
- If the patient has multiple eligible appointments, select **Appointment patient** and require staff to choose the correct appointment.
- If the patient has no eligible appointment, select **Existing patient** and prefill the patient.
- Never default to **New patient** when a patient record already exists.
- If an appointment context is passed directly, select **Appointment patient** and load both appointment and patient details from that appointment.

Eligibility must follow existing backend rules and statuses. Do not hard-code appointment status logic if the backend already provides a safer contract.

### 3. Prevent duplicate active OPD encounters

Before creating a new OPD encounter, the dialog must check whether the selected patient or appointment already has an active OPD encounter/flow.

Active means any non-terminal OPD encounter status, for example waiting vitals, queue, triage, doctor review, billing pending, in progress, or similar existing statuses. Use the project’s actual enum/status definitions.

If an active OPD encounter exists:

- Do not create a duplicate encounter.
- Show a clear notice inside the dialog, for example:

  **This patient already has an active OPD encounter.**

  Include:
  - Encounter/flow ID if available.
  - Current queue/status.
  - Visit type.
  - Billing/payment state if available.
  - Started/checked-in time if available.

- Provide an action to open the existing encounter:
  - **Open active encounter**
- Provide a safe cancel/close option.
- Only allow creating another OPD encounter if the backend explicitly supports it and the current role has a clearly defined override permission. Otherwise block duplicates.

### 4. Reuse the same dialog from Patient Registry

In the patient detail modal quick actions:

- Replace the current **OPD check-in** action with the shared **Start OPD encounter** action.
- Use the same icon, label, styling, hover/focus behavior, disabled state, and permission behavior used in the OPD module.
- Pass the selected patient into the reusable dialog.
- After successful creation or after opening an existing encounter:
  - Refresh the patient detail modal.
  - Update the displayed active visit/encounter state.
  - Refresh OPD lists/cache where applicable.
  - Navigate/open the OPD encounter if this is the existing project behavior.

### 5. Keep form capabilities identical across launch points

The shared dialog must preserve the current capabilities visible in the OPD modal:

- Existing patient flow.
- Appointment patient flow.
- New patient flow.
- Arrival mode selection.
- Optional provider assignment.
- Optional consultation fee.
- Currency selector.
- Notes.
- Payment required toggle.
- Correct validation for required fields.
- Correct loading, error, empty, offline, and permission states.
- Correct success feedback.

Do not remove functionality from the OPD module while making the form reusable.

### 6. Improve wording without changing meaning

Update user-facing text so the flow is not wrongly limited to walk-ins.

Use:

- **Start OPD encounter** instead of **Start walk-in**.
- **Start OPD encounter** instead of **OPD check-in** where the action can create or resume an OPD encounter.
- **Start encounter** for the modal primary button.
- Keep **Walk In** only as an arrival mode option.

Update translation/i18n keys instead of hard-coding strings.

### 7. Backend-first behavior

Inspect the backend before changing frontend assumptions.

Use existing backend endpoints/contracts for:

- Creating OPD encounters/flows.
- Searching patients.
- Searching appointments.
- Loading appointment details.
- Loading active OPD encounter by patient/appointment.
- Creating a new patient when using the New patient tab.
- Billing/payment-required handling.

If the backend lacks a safe active encounter lookup, add the smallest backend contract needed, with tests. Do not fake duplicate detection only on the frontend.

Suggested backend behavior if missing:

- Endpoint/service method to return active OPD encounter by:
  - patient ID
  - appointment ID
  - facility/tenant context
- Response should include enough summary data for the dialog notice:
  - encounter ID
  - patient ID
  - appointment ID if linked
  - current status/stage
  - billing/payment state
  - provider if assigned
  - created/started time

### 8. Permissions and access control

Respect existing RBAC/ABAC/permission rules.

The shared action should:

- Hide or disable itself if the user cannot start OPD encounters.
- Show a clear no-permission message if the action is visible but blocked.
- Respect patient access restrictions.
- Respect appointment access restrictions.
- Respect billing permissions for consultation fee/payment-required fields.
- Respect facility/tenant scope.

Do not expose backend IDs or internal fields unnecessarily in the UI.

### 9. UX and accessibility

The dialog must remain consistent with the visual design shown in the screenshots:

- Modal overlay.
- Clear title and close button.
- Segmented patient mode tabs.
- Patient, Routing, and Billing sections.
- Sticky footer actions.
- Clear primary and secondary actions.
- Responsive layout for smaller screens.
- Keyboard navigation and focus trap.
- Visible focus states.
- Screen-reader labels for tabs, fields, toggle, and submit action.
- Non-color-only status messaging for duplicate active encounters and validation errors.

### 10. Tests

Add or update tests for:

- Opening the shared dialog from OPD page.
- Opening the shared dialog from patient detail quick actions.
- Patient context preselects Existing patient when no eligible appointment exists.
- Patient context preselects Appointment patient when eligible appointment exists.
- Multiple appointments require selection.
- Active OPD encounter blocks duplicate creation and shows **Open active encounter**.
- New patient flow still creates/registers patient then starts OPD encounter.
- Billing fields and payment-required toggle submit correctly.
- Permission-denied states.
- i18n keys are used.
- Responsive/accessibility behavior where existing test tools support it.

### 11. Acceptance criteria

Implementation is complete when:

- There is only one canonical OPD encounter start dialog/form.
- OPD page uses the reusable dialog.
- Patient detail modal uses the same reusable dialog.
- Action label/icon are consistent across the app.
- The dialog title no longer says walk-in for appointment/new patient flows.
- Patient detail quick action passes the selected patient into the dialog.
- The dialog detects active OPD encounters and prevents duplicates.
- Existing patient, appointment patient, and new patient flows still work.
- Backend contracts are reused or minimally extended where necessary.
- No unrelated module is rewritten.
- Tests pass.
- The final output lists every modified, created, and deleted file with exact paths.