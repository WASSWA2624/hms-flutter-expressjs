# Implementation Prompt: Make HMS Patient Workflows Clear, Short, and Action-Oriented

You are working in the attached HMS codebase with these main folders:

* `app-planner`
* `backend`
* `frontend`

Inspect the codebase before editing. Implement a focused workflow-clarity improvement across the existing patient workflows. Do **not** rebuild the system. Preserve the current architecture, folder structure, naming conventions, coding style, state-management patterns, UI components, API patterns, permissions model, and localization approach.

No task-specific workflow screenshots were found in the archive. Use the existing Flutter UI patterns, backend modules, planner docs, and current screens as the source of truth. If any requirement remains unclear, verify it from the codebase and implement only what is supported.

## Problem to Solve

The current HMS patient workflow is confusing in several areas. Users cannot always tell:

* What action is required now.
* What has already been completed.
* The current patient/status/stage.
* The next action to take.
* Who is responsible for the next action.
* Whether the last action completed successfully.
* Whether queue/status/stage updates are actually reflected.

Improve the patient workflows so that every department screen is clear, short, obvious, and action-oriented.

The target is:

* One-step completion where possible.
* Maximum two to three steps for genuinely complex actions.
* No unnecessary queue stages.
* No duplicate assignment/payment/admission steps.
* No misleading “request-based” workflows except where clinically appropriate.

Only laboratory and radiology investigations should remain request/order-based because they naturally require investigation orders.

## Relevant Areas to Inspect

### Planner / Requirements

Inspect these files and update only if required to keep implementation documentation aligned:

* `app-planner/app-write-up.md`
* `app-planner/ipd-flow.md`
* `app-planner/opd-flow.md`
* `app-planner/prompt.md`
* `app-planner/dev-plan/11-patients.md`
* `app-planner/dev-plan/12-opd-flow.md`
* `app-planner/dev-plan/13-triage.md`
* `app-planner/dev-plan/14-clinical.md`
* `app-planner/dev-plan/15-nursing.md`
* `app-planner/dev-plan/16-inpatient.md`
* `app-planner/dev-plan/17-icu.md`
* `app-planner/dev-plan/18-theater.md`
* `app-planner/dev-plan/19-discharge.md`
* `app-planner/dev-plan/20-emergency.md`
* `app-planner/dev-plan/21-lab.md`
* `app-planner/dev-plan/22-radiology.md`
* `app-planner/dev-plan/26-physiotherapy.md`
* `app-planner/dev-plan/29-rooms-beds.md`
* `app-planner/dev-plan/34-notifications.md`
* `frontend/app-planner/app-rules/*.md`

Code is the final source of truth if planner docs are stale or incomplete.

### Frontend Areas

Inspect and modify only the files required under:

* `frontend/lib/features/patients/`
* `frontend/lib/features/opd/`
* `frontend/lib/features/emergency/`
* `frontend/lib/features/ipd/`
* `frontend/lib/features/rooms_beds/`
* `frontend/lib/features/icu/`
* `frontend/lib/features/nursing/`
* `frontend/lib/features/discharge/`
* `frontend/lib/features/clinical/`
* `frontend/lib/features/physiotherapy/`
* `frontend/lib/features/theater/`
* `frontend/lib/features/lab/`
* `frontend/lib/features/radiology/`
* `frontend/lib/features/communications/`
* `frontend/lib/shared/opd_actions/`
* `frontend/lib/shared/clinical_actions/`
* `frontend/lib/shared/actions/`
* `frontend/lib/shared/components/`
* `frontend/lib/shared/forms/`
* `frontend/lib/shared/layout/`
* `frontend/lib/shared/data/`
* `frontend/lib/core/network/api_endpoints.dart`
* `frontend/lib/core/permissions/`
* `frontend/lib/l10n/app_en.arb`
* Generated localization files, if this project commits them.

Use the existing Flutter/Riverpod feature-first structure:

* `data`
* `domain`
* `presentation`

Widgets must not call APIs directly. Controllers manage presentation actions/state. Repositories own data coordination.

### Backend Areas

Inspect and modify only where required:

* `backend/src/modules/opd-flow/`
* `backend/src/modules/visit-queue/`
* `backend/src/modules/triage/`
* `backend/src/modules/patient/`
* `backend/src/modules/emergency-case/`
* `backend/src/modules/emergency-response/`
* `backend/src/modules/admission/`
* `backend/src/modules/bed-assignment/`
* `backend/src/modules/bed/`
* `backend/src/modules/room/`
* `backend/src/modules/icu-stay/`
* `backend/src/modules/icu-observation/`
* `backend/src/modules/nursing-note/`
* `backend/src/modules/discharge-summary/`
* `backend/src/modules/clinical-note/`
* `backend/src/modules/theatre-case/`
* `backend/src/modules/theatre-flow/`
* `backend/src/modules/lab-workspace/`
* `backend/src/modules/lab-order/`
* `backend/src/modules/lab-sample/`
* `backend/src/modules/lab-result/`
* `backend/src/modules/radiology-workspace/`
* `backend/src/modules/radiology-order/`
* `backend/src/modules/radiology-result/`
* `backend/src/modules/communications-workspace/`
* Relevant backend tests under `backend/src/tests/modules/`

Avoid backend changes unless the current API/state logic blocks the requested workflow clarity.

## Core UI/UX Requirements

Across all affected screens:

1. Show one clear primary action for the current state.
2. Show completed steps clearly.
3. Show current status/stage using existing badges/status components.
4. Show the next action and responsible role.
5. Show success/completion feedback after actions.
6. Keep secondary actions available but visually subordinate.
7. Do not show long confusing grids of disabled or irrelevant actions.
8. Do not duplicate workflow steps.
9. Do not use request-style wording unless the action is genuinely a lab/radiology order/request.
10. Keep tables scannable and action-oriented.
11. Preserve existing responsive layouts and accessibility patterns.
12. Use existing components such as `AppWorkspace`, `AppListTable`, `AppDialog`, `AppActionSection`, `AppPermissionActionItem`, info/status tiles, shared forms, empty/error/loading states, and shared search/filter controls.
13. Avoid hard-coded UI strings. Use localization patterns already present in the project.

## Specific Implementation Requirements

### OPD Flow

Focus strongly on OPD because it is currently the most confusing workflow.

Inspect:

* `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
* `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
* `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
* `frontend/lib/shared/opd_actions/opd_action_context.dart`
* `frontend/lib/shared/opd_actions/opd_billing_state.dart`
* `backend/src/modules/opd-flow/services/opd-flow.service.js`
* `backend/src/modules/opd-flow/controllers/`
* `backend/src/modules/opd-flow/routes/`
* `backend/src/modules/opd-flow/schemas/`
* `backend/src/tests/modules/opd-flow/`

Required OPD behavior:

* The OPD workspace must clearly show:

  * patient identity/context,
  * OPD stage,
  * billing/payment status,
  * assigned provider,
  * next required action,
  * responsible role,
  * completed actions.
* `FlowActionsDialog` must become stage-aware and concise:

  * Show the current state/context first.
  * Show one primary “Next required action”.
  * Show only relevant secondary actions.
  * Remove or avoid the confusing pattern where all actions are always displayed regardless of current stage.
  * Avoid disabled placeholder action grids that do not help the user complete the workflow.
* If consultation payment is required, make payment the obvious next step.
* If vitals are required, make “Record vitals” the obvious next step.
* If a doctor/provider is already assigned, do not show doctor assignment as the required next step.
* If a doctor/provider is missing, show assignment as the required next step.
* After vitals are recorded, the backend must not blindly move the flow to `WAITING_DOCTOR_ASSIGNMENT` when a provider is already assigned. It must advance to the correct next stage, normally doctor review.
* If a doctor was assigned during registration/check-in/start flow, do not create another unnecessary doctor-assignment step later.
* Doctor review should lead to the correct next state:

  * lab requested,
  * radiology requested,
  * lab and radiology requested,
  * pharmacy required,
  * waiting disposition,
  * admitted,
  * discharged.
* OPD disposition should be direct and action-oriented:

  * Use “Admit patient”, “Send to pharmacy”, or “Discharge patient” style wording where supported.
  * Do not present OPD admission as merely “request admission” if the current backend already performs direct admission.
* Ensure OPD queue/stage changes refresh the UI correctly after successful actions.

### Emergency Flow

Inspect:

* `frontend/lib/features/emergency/`
* `backend/src/modules/emergency-case/`
* `backend/src/modules/emergency-response/`
* Ambulance/dispatch/trip modules where used.

Improve clarity for:

* quick arrival,
* triage,
* priority update,
* emergency response,
* ambulance dispatch/status,
* handoff.

Each emergency case must show the current emergency status, required action, owner role, and completion result. Keep emergency actions direct and fast.

### General Patient Flow

Inspect:

* `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`
* related patient controllers/repositories/models.

Improve patient registry actions so users can quickly start the correct workflow without duplicate steps:

* OPD/walk-in/check-in,
* emergency arrival,
* IPD/admission,
* patient detail/context actions.

Do not create duplicate patients, duplicate encounters, or duplicate unnecessary queues.

### IPD, Room Assignment, ICU, Nursing, and Discharge

Inspect:

* `frontend/lib/features/ipd/`
* `frontend/lib/features/rooms_beds/`
* `frontend/lib/features/icu/`
* `frontend/lib/features/nursing/`
* `frontend/lib/features/discharge/`
* corresponding backend modules.

Required behavior:

* IPD admission and bed assignment should be direct and obvious.
* Room/bed state must clearly show whether a bed is available, occupied, reserved, blocked, or out of service, based on existing backend states.
* Avoid unnecessary “request” wording for actions that can be completed directly.
* Transfer, release bed, discharge planning, discharge completion, nursing notes, medication administration, ICU observations, ICU transfer-out, and escalation actions should show:

  * current state,
  * next action,
  * owner role,
  * completion result.
* Do not break bed assignment consistency between IPD, ICU, rooms/beds, and discharge.

### Clinical Workflow

Inspect:

* `frontend/lib/features/clinical/`
* `frontend/lib/shared/clinical_actions/`
* `backend/src/modules/clinical-note/`
* related admission/disposition modules.

Required behavior:

* Clinical screens must show what the clinician needs to do next.
* Lab and radiology may remain order/request-based.
* Admission should be direct where the backend supports it.
* Avoid misleading “request admission” wording if the action actually admits or marks the patient admitted.
* Preserve existing clinical note, diagnosis, procedure, prescription, referral, follow-up, disposition, lab, and radiology action patterns.

### Physiotherapy

Inspect:

* `frontend/lib/features/physiotherapy/`
* corresponding backend/workspace APIs if present.

Improve clarity for:

* referral acceptance,
* assessment,
* session scheduling,
* attendance,
* progress note,
* plan update,
* follow-up,
* episode closure.

The screen must clearly distinguish pending, active, missed, follow-up due, and completed physiotherapy work.

### Theater

Inspect:

* `frontend/lib/features/theater/`
* `backend/src/modules/theatre-case/`
* `backend/src/modules/theatre-flow/`

Improve clarity for:

* case scheduling,
* stage updates,
* anesthesia record,
* observations,
* checklist,
* resources,
* post-op note,
* finalization/reopening.

Theater stages must clearly show what is pending, what is completed, and the next required owner/action.

### Laboratory

Inspect:

* `frontend/lib/features/lab/`
* `backend/src/modules/lab-workspace/`
* `backend/src/modules/lab-order/`
* `backend/src/modules/lab-sample/`
* `backend/src/modules/lab-result/`

Lab should remain request/order-based.

Improve clarity for:

* order status,
* sample collection,
* sample receiving,
* rejection,
* result entry/release,
* reversal,
* QC logs.

Show the next lab action and responsible role without removing the order-based workflow.

### Radiology

Inspect:

* `frontend/lib/features/radiology/`
* `backend/src/modules/radiology-workspace/`
* `backend/src/modules/radiology-order/`
* `backend/src/modules/radiology-result/`

Radiology should remain request/order-based.

Improve clarity for:

* order creation,
* assignment,
* start,
* completion,
* cancellation,
* study creation,
* draft result,
* finalization,
* addendum,
* PACS sync.

Show the next radiology action and responsible role without removing the order-based workflow.

### Communication Notes

Inspect:

* `frontend/lib/features/communications/`
* `backend/src/modules/communications-workspace/`

Improve clarity for:

* conversations,
* messages,
* notifications,
* delivery status,
* read/unread state,
* archive/unarchive actions.

Communication notes should clearly show whether communication is pending, sent, delivered, read, archived, or requiring action.

## Backend Requirements

Make minimal backend changes only when needed to support correct workflow behavior.

At minimum, verify and fix OPD stage progression:

* If provider is already assigned, OPD must not require a second doctor-assignment step.
* After vitals, if provider exists, advance to doctor review.
* If provider is missing, advance to doctor assignment.
* Ensure `next_step`, stage/status, audit/realtime events, and API responses remain consistent.
* Update backend tests for OPD stage behavior.

Do not invent new APIs if existing routes already support the needed action. If a required action cannot be safely implemented with current backend support, leave unsupported behavior unchanged and document the verified limitation in the smallest appropriate place.

## Frontend Requirements

* Preserve Riverpod controller/repository patterns.
* Do not call APIs directly from widgets.
* Keep permission checks intact.
* Use existing shared UI components.
* Keep responsive layout behavior.
* Keep table filters/search/sort/pagination behavior.
* Update localization strings properly.
* Do not introduce hard-coded user-facing text.
* Do not create broad duplicate workflow components if existing shared action/dialog components can be improved.
* Ensure successful actions refresh local state or invalidate/reload the correct providers so the visible patient status updates immediately.

## Scope Limits

Do not:

* rewrite the whole HMS,
* redesign unrelated modules,
* change unrelated APIs,
* remove useful existing features,
* introduce a new design system,
* rename folders unnecessarily,
* delete files unless deletion is required for this task,
* change authentication, authorization, or permissions behavior except where required to preserve existing action visibility,
* fake backend behavior on the frontend,
* leave dead code, unused imports, or linter errors.

Modify only the files required for the requested workflow improvements.

## Testing and Verification

Run and fix issues from the relevant checks.

Frontend:

* `cd frontend`
* `flutter analyze`
* `flutter test`
* Run targeted tests for modified areas, especially:

  * OPD controller/action tests,
  * patient registry tests,
  * clinical workspace tests,
  * rooms/beds tests,
  * theater tests,
  * communications tests,
  * shared OPD action tests,
  * localization/hard-coded UI text tests.
* Run `flutter test integration_test/startup_navigation_smoke_test.dart` if feasible.

Backend:

* `cd backend`
* `npm run lint`
* `npm run test:backend`
* Run targeted OPD/backend workflow tests.
* If backend routes/schemas/OpenAPI behavior changed, also run:

  * `npm run openapi:validate`

All linter, analyzer, and test issues introduced by this work must be cleared.

## Required Output

Return a zipped archive containing only the files and folders that were created or updated.

Requirements for the archive:

* Preserve correct relative paths from the project root.
* Do not include the full repository.
* Do not include unchanged files.
* Include updated frontend, backend, and `app-planner` files only where actually changed.
* If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those delete/rename operations.
* The `.ps1` scripts must use correct relative paths and must not delete unrelated files.
* Do not include unsafe broad delete commands.
