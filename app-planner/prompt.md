# HMS OPD Screen + Active Encounter Workflow Refactor

You are working in the HMS/HOSSPI codebase from `hms.zip`.

Project structure:
- `frontend/` — Flutter app using Riverpod, Dio, GoRouter, shared UI components.
- `backend/` — Node.js/Express/Prisma/MySQL backend.
- `app-planner/` — planning/reference docs only unless a documented update is needed.

No OPD-specific screenshots were included in the archive, so use the current OPD UI and the written requirements below as the source of truth.

## Main goal

Refactor and test the OPD workflow so that OPD records, appointments, queues, triage, active encounters, and patient-module OPD actions behave consistently, persist correctly to the database, and use the shared clinical/action/printing components already available in the codebase.

Important existing frontend areas:
- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
- `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/lib/shared/clinical_actions/clinical_order_action_dialogs.dart`
- `frontend/lib/shared/printing/`
- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`

Important backend areas:
- `backend/src/modules/opd-flow/`
- `backend/src/lib/opd-active-encounter.js`
- related patient, appointment, queue, billing, lab, pharmacy, referral, follow-up, and provider/doctor modules.

---

## 1. Preserve working OPD summary cards

The OPD button/cards are currently working and should not regress:

- All OPD records
- Queue
- Triage
- Active flows
- Any existing arrivals/appointments summary card
- Refresh
- Start OPD Encounter

When these cards are clicked, the OPD table must continue updating correctly.

Do not redesign these cards unless required for consistency. Keep their current filtering behavior.

---

## 2. Fix provider search in “Start OPD Encounter”

In `OpdEncounterDialog`, the provider search currently shows duplicate providers and displays internal IDs.

Observed issue:
- A provider such as `Jordan / Jordani Demo Demo` appears more than once.
- Internal UID/HFID/UUID/staff-profile identifiers are visible in the provider search result.

Required behavior:
- Each provider must appear only once.
- Provider results must show human-readable details only:
  - provider display name
  - role/position/title
  - practitioner type
  - facility/department when useful
- Do not display internal IDs, UUIDs, human-friendly IDs, `staff_profile_id`, `providerUserId`, or raw API IDs in visible UI labels/subtitles.
- Do not use internal IDs as fallback display text. If the name is missing, show a safe fallback like `Unknown provider`.
- Deduplicate providers across:
  - provider list API results
  - provider schedules
  - any fallback schedule-based provider options
- Prefer the canonical provider/doctor record over a schedule fallback when both point to the same person.

Also check the backend provider/doctor response if duplicates originate from the API. Fix uniqueness at the correct layer, not only visually.

Acceptance test:
- Searching for `Jordan` or `Jordani Demo` shows the provider once.
- No internal ID is visible in the provider dropdown.

---

## 3. Change active encounter behavior

Current bad behavior:
- When an existing patient already has an active OPD encounter, the dialog shows/open action like “Open Active Encounter”.
- Clicking it takes the user back to the OPD screen and does not clearly update or open the active encounter.
- Provider, billing, routing, and related changes are not reliably persisted.

Required behavior:
- If the selected patient already has a running active OPD encounter, do not create a new encounter.
- Replace the “Open Active Encounter” action with a clearer action:
  - `Update Encounter`
  - or `Update Active Encounter`
- Submitting this action must update the existing active encounter, not start a duplicate encounter.
- Persist changed values to the database, including where applicable:
  - assigned provider/doctor
  - routing/stage/queue context
  - appointment linkage
  - billing/consultation fee/payment requirement/payment state
  - notes/reason/visit context
  - payer/payment method where supported
- Update the UI immediately after success:
  - selected active encounter state
  - OPD table row
  - summary counts
  - action dialog/context panel
- Do not fake success with frontend-only state changes.

After updating an active encounter:
- Either open the unified OPD action dialog for that active encounter, or keep the user in a clearly updated active encounter state.
- Do not simply close/pop back to the OPD list without showing what happened.

Backend requirement:
- Add or update an OPD endpoint/service method if needed for active encounter context updates.
- Keep duplicate active encounter prevention at backend/service/database level.
- Reuse the existing active encounter instead of creating another one.

---

## 4. Remove redundant modal-close “Cancel” buttons in OPD dialogs

In OPD start/action shell dialogs, remove `Cancel` buttons whose only purpose is closing the dialog.

Required behavior:
- Use the existing dialog header close button.
- Pressing `Esc` must close the OPD dialog when no save/submission is in progress.
- Do not remove real business actions such as “Cancel appointment”. Only remove redundant modal-close cancel buttons.
- Prevent double-submit while saving.

Apply this to:
- Start OPD Encounter dialog
- OPD action shell/dialogs where the secondary cancel button only closes the modal

Do not globally remove valid cancel actions from unrelated workflows.

---

## 5. Unify OPD row click dialogs

Current bad behavior:
- Appointment patients, queue patients, triage patients, and active flow patients open different dialogs.
- Appointment patients get a different dialog from active OPD patients.
- This confuses users.

Required behavior:
- All OPD patient rows must open the same unified OPD patient/action dialog.
- This applies to:
  - appointment rows
  - queue rows
  - triage rows
  - active flow rows
  - all OPD records
- Do not create separate confusing dialogs for appointment vs queue vs active flow patients.
- If an action is not currently available, keep it visible but disabled with a clear reason.
- If an action is already completed, keep it visible and mark it as done/completed.
- Do not hide actions merely because the patient is in a different OPD state.

The unified dialog must show consistent actions such as:
- Update encounter
- Update consultation/billing
- Record/update vitals
- Assign/change provider
- Start/update consultation
- Add diagnosis
- Request lab
- Request radiology
- Prescribe
- Add procedure
- Refer
- Follow up
- Correct stage
- Disposition
- Print

Appointment-specific actions such as queue/check-in/reschedule/cancel appointment may remain, but they must be presented inside the same unified dialog pattern.

Queue-specific actions such as prioritize/move queue/start consultation may remain, but they must also be presented inside the same unified dialog pattern.

Security note:
- Preserve permission checks.
- For authorized users, do not hide actions just because the current state makes them inactive; show disabled/done status instead.

---

## 6. Use shared clinical/action components

Do not create duplicate custom dialogs where shared components already exist.

Diagnosis:
- Use the shared diagnosis/catalog dialog already defined in the shared clinical components.
- It must expose the predefined diagnosis fields/options.
- It must save/update against the active OPD encounter.

Lab:
- Use the shared lab request/order component.
- Lab requests must attach to the active encounter and persist to the backend.

Radiology:
- Use the shared radiology order component where available.

Prescription:
- Verify prescribing works end-to-end.
- Preserve shared prescription/drug selection behavior.

Procedure:
- Ensure procedure creation/update works and is persisted.

Referral:
- Ensure referral works and persists.

Follow-up:
- Ensure follow-up works and persists.

Print:
- Use the shared printing components under `frontend/lib/shared/printing/`.
- Do not implement a one-off print layout for OPD.
- Printing should reflect current encounter data.

Catalog search behavior:
- If the user searches for a diagnosis/lab/procedure/radiology/drug item and it does not exist, provide an appropriate “add new” path where the module supports it.
- Persist newly added catalog items through the backend, not temporary frontend-only state.

---

## 7. Patient module must use the same OPD action model

In the Patients module, patient detail/quick actions must be consistent with OPD.

Required behavior:
- Opening a patient from the patient registry must expose the same OPD action set/pattern used in the OPD workspace.
- Do not show a different OPD dialog under Patients.
- If the patient has an active OPD encounter:
  - show/update that active encounter
  - do not create a duplicate encounter
- If no OPD encounter exists:
  - allow OPD check-in/start encounter
  - keep downstream actions visible but disabled until an encounter exists
- Completed actions should be marked done.
- Users should be able to revisit/update previous OPD actions where clinically valid.

---

## 8. Realtime UI/database consistency

Every OPD action mutation must update both database and UI.

After each mutation, refresh or patch:
- active encounter details
- selected flow
- table row
- summary card counts
- related appointment/queue/triage state
- patient registry active encounter status where relevant

No stale UI should remain after:
- updating encounter provider/routing/billing
- paying/updating consultation billing
- recording vitals
- assigning provider
- doctor review
- adding diagnosis
- requesting lab/radiology
- prescribing
- adding procedure
- referral
- follow-up
- correcting stage
- disposition
- printing/logging print event where applicable

Prefer targeted refresh/patching rather than full unnecessary workspace reloads.

---

## 9. Backend requirements

Implement backend changes cleanly through the existing architecture.

Requirements:
- Prevent duplicate active OPD encounters for the same patient.
- Reuse/update running active encounters when requested.
- Add an explicit update-active-encounter/context endpoint if existing endpoints are insufficient.
- Ensure appointment-linked and queue-linked encounters remain correctly linked.
- Ensure billing/provider/stage updates are transactional where needed.
- Write audit/timeline/activity entries for meaningful OPD changes.
- Ensure API responses return enough updated data for the frontend to refresh accurately.
- Do not expose internal IDs unnecessarily in provider-facing display fields.

---

## 10. Testing requirements

Perform full backend, frontend, and end-to-end testing. Modify/reset local test data as needed.

Backend:
- Run existing backend tests.
- Add/update tests for:
  - provider uniqueness
  - no duplicate active OPD encounter creation
  - updating an active encounter instead of opening/duplicating it
  - billing/consultation update persistence
  - provider assignment update persistence
  - OPD action mutations
  - appointment/queue/triage/flow state consistency

Frontend:
- Add/update tests for:
  - provider dropdown deduplication
  - no internal IDs visible in provider search
  - active encounter shows `Update Encounter`
  - active encounter update persists and refreshes UI
  - appointment/queue/triage/active rows open the same unified OPD dialog
  - inactive actions remain visible but disabled
  - completed actions are marked done
  - Esc closes OPD dialogs
  - redundant modal-close Cancel buttons are removed

Manual E2E:
- Start app and backend locally.
- Login with seeded/demo users if available.
- Test:
  - existing patient without active encounter
  - existing patient with active encounter
  - appointment patient
  - queue patient
  - triage patient
  - active flow patient
  - provider search
  - billing update
  - diagnosis/lab/prescription/procedure/referral/follow-up
  - patient registry OPD actions
  - print workflow

Use the project’s existing scripts where applicable, for example:
- Backend: `npm install`, `npm run test:backend`, `npm run test:backend:unit`, `npm run test:backend:integration`, `npm run validate`
- Frontend: `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test`
- Run browser/manual testing with the existing Flutter web configuration.

Install missing test tools/dependencies only when necessary and keep changes minimal.

---

## 11. Acceptance criteria

The work is complete only when:

1. OPD summary cards still filter the table correctly.
2. Provider search shows each provider once.
3. Provider search never exposes internal UID/UUID/HFID/staff-profile IDs.
4. Existing patient prefill still works.
5. Appointment patient prefill still works.
6. Patients with active encounters show `Update Encounter`, not `Open Active Encounter`.
7. Updating an active encounter persists provider/routing/billing changes to the database.
8. Updating an active encounter does not create a duplicate OPD encounter.
9. Appointment, queue, triage, active flow, and all OPD rows open one consistent OPD action dialog.
10. The Patients module uses the same OPD action model.
11. Actions are visible consistently; inactive actions are disabled, completed actions are marked done.
12. Diagnosis, lab, radiology, prescription, procedure, referral, follow-up, correct stage, billing, and print actions work end-to-end.
13. Shared clinical and print components are used instead of duplicate one-off dialogs.
14. Redundant modal-close Cancel buttons are removed from OPD shell dialogs.
15. Esc closes OPD dialogs safely.
16. Backend and frontend tests pass.
17. Manual E2E testing confirms database and UI stay synchronized.