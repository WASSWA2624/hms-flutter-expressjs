You are working on the HMS project. Review the full codebase, especially:

- `app-planner`
- `backend`
- `frontend`

Focus on improving the OPD, patient registration, and triage flow so that the outpatient journey is simple, obvious, robust, and fully synchronized between frontend and backend.

Important context from the current project:

- Backend is Node.js/Express/Prisma using a Route → Controller → Service → Repository → Prisma structure.
- Frontend is Flutter with Riverpod/GoRouter and feature-first architecture.
- Existing OPD flow logic is already implemented through `opd-flow`, `patients`, `triage`, `visit-queue`, `encounter`, `vital-sign`, and related modules.
- Do not create a duplicate OPD module, patient registry, triage module, dashboard, or route unless absolutely necessary.
- Use and improve the existing architecture.

Main goal:

Make the OPD flow from patient arrival to registration, triage, consultation, service routing, and disposition as simple as possible. A staff member should always see one clear next action. Avoid duplicate or nearly duplicate actions. If a task can be completed in one dialog or one backend action, merge it into one complete action.

Canonical OPD journey:

1. Patient arrives at the hospital.
2. Staff searches for an existing patient, selects an appointment, or quickly registers a new patient.
3. Staff starts/checks in the OPD visit from one unified dialog.
4. The system creates or reuses the correct active OPD/emergency encounter.
5. The patient moves through payment, vitals/triage, doctor assignment, consultation, investigations/services, pharmacy/admission/referral/discharge as required.
6. Every stage shows one obvious next action.
7. The frontend and backend remain fully synchronized after every action.

Backend requirements:

Review and improve these modules as needed:

- `backend/src/modules/opd-flow`
- `backend/src/modules/patient`
- `backend/src/modules/triage`
- `backend/src/modules/triage-assessment`
- `backend/src/modules/vital-sign`
- `backend/src/modules/visit-queue`
- `backend/src/modules/encounter`
- `backend/src/modules/appointment`
- `backend/src/modules/billing`
- related Prisma models and shared services only where necessary

Use `opd-flow` as the main source of truth for outpatient flow orchestration.

Preserve and harden these existing backend endpoints:

- `POST /api/v1/opd-flows/start`
- `POST /api/v1/opd-flows/bootstrap`
- `POST /api/v1/opd-flows/:id/pay-consultation`
- `POST /api/v1/opd-flows/:id/record-vitals`
- `POST /api/v1/opd-flows/:id/assign-doctor`
- `POST /api/v1/opd-flows/:id/doctor-review`
- `POST /api/v1/opd-flows/:id/disposition`
- `POST /api/v1/opd-flows/:id/correct-stage`
- `GET /api/v1/triage`
- `POST /api/v1/triage/:id/record-vitals`
- `POST /api/v1/triage/:id/assign-provider`
- `POST /api/v1/triage/:id/route`

Backend behavior must include:

- Prevent duplicate active OPD/emergency encounters for the same patient.
- Reuse an active open encounter when `reuse_open_encounter` is true.
- Return the existing active flow instead of creating duplicates.
- Keep emergency cases moving even when consultation payment is pending.
- Keep OPD encounter state, visit queue state, triage assessment, vital signs, billing state, alerts, and provider assignment synchronized.
- Make all mutations duplicate-submit safe where practical.
- Validate all request payloads with existing validation patterns.
- Preserve audit logging, permission checks, tenant/facility isolation, and realtime/socket updates.
- Never rely on frontend-only state for critical flow decisions.

Frontend requirements:

Review and improve these files first:

- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
- `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
- `frontend/lib/features/opd/data/repositories/opd_repository_impl.dart`
- `frontend/lib/features/opd/domain/entities/opd_entities.dart`
- `frontend/lib/features/opd/domain/repositories/opd_repository.dart`
- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`
- `frontend/lib/features/patients/presentation/controllers/patient_registry_controller.dart`
- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/shared/components/app_triage_components.dart`
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_action_context.dart`
- `frontend/lib/shared/opd_actions/opd_billing_state.dart`

Frontend simplification requirements:

1. Use one unified OPD start/check-in dialog.

Improve `OpdEncounterDialog` so it can handle:

- existing patient check-in
- new patient quick registration
- appointment check-in
- walk-in visit
- emergency visit
- provider selection
- consultation billing requirement
- optional immediate payment
- notes
- reuse of active OPD/emergency encounter

If payment can be captured during OPD start, submit it through the existing backend-supported OPD start payload instead of forcing a separate billing action.

2. Collapse duplicate patient quick actions.

In the patient registry/detail workflow, OPD-related actions should be simplified into:

- `Start / Check in OPD` when the patient has no active OPD/emergency flow
- `Continue OPD flow` when the patient already has an active flow
- optional non-flow actions such as print/report/copy ID where appropriate

Remove or merge duplicate buttons such as separate triage, record vitals, assign doctor, doctor review, and billing buttons when they all lead to the same OPD flow process.

No dialog should show success without performing a real backend mutation. Remove or fix any no-op action paths.

3. Make OPD workspace stage-driven.

In the OPD workspace:

- Keep one combined OPD table/workspace.
- Continue deduplicating appointments, visit queues, triage cases, and active flows.
- Each row should expose one clear primary action based on the current OPD stage.
- Avoid showing multiple buttons that complete the same task.
- Use clear stage labels, next-action labels, and status indicators.

Recommended stage-to-action mapping:

- `WAITING_CONSULTATION_PAYMENT` → collect/record consultation payment
- `WAITING_VITALS` → record triage/vitals
- `WAITING_DOCTOR_ASSIGNMENT` → assign provider or route from triage
- `WAITING_DOCTOR_REVIEW` → open doctor consultation/review
- `LAB_REQUESTED` / `RADIOLOGY_REQUESTED` / `LAB_AND_RADIOLOGY_REQUESTED` → show service status and next clinical action
- `PHARMACY_REQUESTED` → continue pharmacy/dispensing path
- `WAITING_DISPOSITION` → complete visit, admit, refer, discharge, or follow up
- `ADMITTED` / `DISCHARGED` → read-only summary/report actions

4. Simplify triage.

Triage should be completed through one clear dialog where possible.

The triage/vitals dialog should support:

- vital signs
- triage level/priority
- chief complaint
- pain score
- emergency/risk flags
- route decision
- provider assignment where appropriate
- notes

Avoid separate actions for vitals, triage, route, and provider assignment when the same staff member can complete them together.

5. Preserve design consistency.

Use existing shared UI patterns:

- `AppWorkspace`
- `AppListTable`
- `AppDialog`
- existing shared OPD action components
- existing patient context/action panels
- existing theme, spacing, typography, loading, empty, and error states

No screenshot-specific UI requirements are available from the archive beyond app logos/icons. Preserve the current HMS visual style and improve clarity using the existing component system.

Robustness requirements:

- Every action must show proper loading, disabled, success, and error states.
- Prevent double-submit issues.
- Surface backend validation errors clearly.
- Do not leave the UI in a stale state after successful mutations.
- Use targeted refreshes for OPD rows, patient detail, queue state, and triage state where possible.
- Preserve permission/RBAC/ABAC checks.
- Do not expose PHI beyond existing authorized screens.
- Do not introduce fake frontend-only states that are not backed by API data.

Testing requirements:

Add or update tests where practical.

Backend tests should cover:

- starting OPD for an existing patient
- quick-registering a new patient and starting OPD
- appointment check-in
- emergency OPD start
- optional immediate payment during OPD start
- active encounter reuse
- duplicate active encounter prevention
- consultation payment gate
- vitals/triage recording
- triage routing
- doctor assignment
- disposition

Frontend tests should cover:

- OPD start dialog modes
- active encounter reuse notice
- pay-now payload submission
- patient quick action simplification
- no no-op success actions
- stage-based OPD primary actions
- triage/vitals dialog submission
- error and loading states

Validation before final response:

Run the relevant backend and frontend checks, for example:

- backend lint/tests
- frontend format/analyze/tests

If unrelated pre-existing failures exist, document them clearly and explain why they are unrelated.

Implementation constraints:

- Modify only necessary files.
- Do not rewrite unrelated modules.
- Do not create duplicate routes, duplicate screens, or duplicate patient/OPD registries.
- Prefer refactoring and consolidating existing logic over adding new parallel logic.
- Preserve current architecture and naming conventions.
- Keep changes secure, maintainable, scalable, and production-ready.

Final response format:

Return only:

1. Summary of what changed.
2. Modified files with exact repository paths.
3. New files with exact repository paths, if any.
4. Deleted files with exact repository paths, if any.
5. Safe deletion script, only if files were deleted.
6. Tests/checks run and their results.
7. Any known limitations or follow-up recommendations.

The final implementation should make the OPD and triage workflow feel like one smooth, obvious hospital process instead of many separate repeated actions.