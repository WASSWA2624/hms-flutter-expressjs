### Refined Prompt

You are provided with the following attached zip folders:

* `backend.zip`
* `frontend.zip`
* `app-planner.zip`

Review and update/refactor the attached codebase to implement the task below.

# Requirements

Inspect the relevant parts of the backend, frontend, and app-planner codebases before making any changes.

Treat the following files as the single product and flow source of truth:

* `app-planner\app-write-up.zip`
* `app-planner\opd-flow.zip`
* `app-planner\ipd-flow.zip`

Use the planner and rules files only for alignment and implementation guidance.

Respect all rules defined in:

* `backend\app-planner\app-rules`
* `frontend\app-planner\app-rules`

Before creating or modifying components, first check the existing shared components folder:

`frontend\lib\shared`

Reuse existing shared components wherever applicable instead of reinventing them.

The goal is maximum UI uniformity, code reusability, and component consistency across the entire implementation.

If a suitable shared component already exists, reuse it instead of creating a new one.

If any component is reused, or will be reused in multiple places throughout the module or app, convert it into a reusable shared component.

This should be treated as a major UI optimization, uniformity, and reusability refactor across the implementation, including but not limited to:

* Screens
* Modules
* Modals
* Forms
* UI sub-components
* Components
* Any other reusable UI or code patterns

Update or refactor only the files required to implement the task.

Create new files only where necessary.

Update the backend only if it is strictly necessary.

Preserve the original folder structure and place all created or modified files in their correct respective paths.

# Output Requirement

Return a single zip folder named:

`hms.zip`

The `hms.zip` folder must contain only:

* Files that were modified
* Files that were newly created

Do not include unchanged files.

# Deleted or Renamed Files

If any files are deleted or renamed, include an appropriate script that can safely delete or rename those files.

The script should preserve the intended folder paths and apply only the required delete or rename operations.

# Task: Nursing Module

## Goal

Implement and optimize the Nursing Module to support:

* Nursing observations
* Vital signs
* Medication administration
* Care tasks
* Handovers
* Ward activity
* Clinical escalation

This should work across:

* OPD
* IPD
* ICU
* Theater recovery
* Discharge workflows

## Source of Truth

Use the following files as the single product and flow source of truth:

* `app-write-up.md`
* `opd-flow.md`
* `ipd-flow.md`

Use:

* `app-write-up.md` for nursing responsibilities.
* `opd-flow.md` for triage handoff and outpatient nursing touchpoints.
* `ipd-flow.md` for nursing admission, ward handover, inpatient care loop, transfers, discharge readiness, and bed release coordination.
* `01-policy.md` for simple modal actions, role access, responsive UI, and partial state updates.

Backend and frontend planner files and rules are alignment references only.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract:

* `/api/v1/nursing-notes`
* `/api/v1/medication-administrations`
* `/api/v1/vital-signs`
* `/api/v1/handovers`
* `/api/v1/nurse-rosters`
* `/api/v1/care-plans`

If a listed route is absent, record it as a backend gap.

Do not create a frontend-only endpoint, fake status, or local-only workflow.

## Implementation Scope

Implement the following:

1. Nursing worklist by ward, unit, shift, patient, priority, care task, admission status, and discharge readiness.
2. Patient nursing detail with current location, diagnosis summary, care plan, vitals, medications due, tasks, handovers, and alerts.
3. Modal actions for:

   * Record vitals
   * Nursing note
   * Medication administration
   * Task completion
   * Handover
   * Escalation
   * Transfer acknowledgement
4. Ward admission checklist connected to IPD bed allocation and admission handover.
5. Shift-aware context so nurses can see what needs action now without browsing unrelated modules.

## UI and Workflow Contract

| Area              | Requirement                                                                                                                                               |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Main screen       | Use a clean patient/task board with tabs or filters for assigned ward, urgent, medication due, handover pending, transfer pending, and discharge pending. |
| Patient row       | Show patient, ward/room/bed, status, priority, due action, and last observation. Avoid dense clinical history in the list.                                |
| Routine actions   | Use modals for vitals, notes, MAR updates, handover notes, and task completion.                                                                           |
| High-risk actions | Require clear confirmation for medication administration, escalation, and transfer acknowledgement.                                                       |
| Mobile behavior   | Use a one-column list and focused modal forms. Keep touch targets practical.                                                                              |
| Desktop behavior  | Allow worklist and patient panel side by side using the shared responsive layout.                                                                         |

## Reusable Components and Sync Contract

Reuse the workspace layout and shared UI patterns from `10-workspace-ui.md` before adding module-specific widgets.

Reuse existing shared components for:

* Workspace layout
* Shared form fields
* Shared modal/dialog shell
* Responsive detail panels
* Status badges
* Search/filter/table/list controls
* Async state views
* Permission-gated action patterns

Use or create shared components for:

* Patient context header
* Nursing observation form
* Vitals form
* Medication administration form
* Care task checklist
* Handover modal
* Roster/assignment list
* Ward activity panel

Keep the following shared:

* Common form layout
* Field behavior
* Validation-error display
* Server-error mapping
* Loading state
* Disabled state
* Duplicate-submit protection

Keep module-specific validation and submit mapping in feature controllers/repositories.

Modal actions should remain focused and return users to the same worklist/detail context after success.

After successful actions, refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.

Backend/frontend sync is required for:

* Nursing notes
* Vitals
* Medication administrations
* Care tasks
* Handovers
* Ward queues
* Doctor updates
* Pharmacy stock effects
* IPD admission state

Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules

* IPD nursing admission must start only after the admission/bed workflow provides a patient location or authorized holding area.
* Medication administration should update MAR status, patient task list, and notification badges only for the affected patient.
* Transfer handovers must update source and destination nursing queues.
* Discharge nursing checklist must feed discharge status without closing the admission by itself.
* ICU and theater handovers must remain visible to permitted nurses without duplicating care episodes.

## Access and State Rules

* Nurses can act only within their assigned facility, ward/unit, role, and entitlement scope.
* Doctors can view nursing notes where permitted, but should not receive nursing-only action buttons unless allowed.
* After a mutation, update only the patient row, task badge, MAR line, handover item, and detail panel.
* Offline or failed saves must keep unsaved form data visible until staff retry or discard.

## Reports and Printing

Nursing notes, handover summaries, observation charts, medication administration summaries, and discharge nursing checklists must use generated report templates from:

`35-reports-audit.md`

Do not print UI screens.

## Concrete Implementation Contract

| Slice              | Required implementation                                                                                                                                                                                                                             |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Worklist/list data | Use `AppWorkspace` + `AppPaginatedListTable<NursingWorkItem>` with patient, ward/bed, admission, task type, priority, due time, responsible nurse, and status. Use `AppSearchBar` for patient, ward, bed, task, status, priority, and date filters. |
| Detail/display     | Use shared inpatient patient context with observations, medication administration, nursing notes, care tasks, handover notes, and ward activity.                                                                                                    |
| CRUD/UI actions    | Use `AppDialog` for observation, medication administration, task update, nursing note, handover, escalation, and print handover/task summary.                                                                                                       |
| RBAC/ABAC          | Gate with clinical permissions, nursing/ward manager roles where represented, ward/unit scope, and active inpatient module entitlement.                                                                                                             |
| Partial refresh    | After nursing mutation, update only affected task row, medication/observation section, ward board badge, handover/activity entry, and notification count.                                                                                           |

Implementation must reuse the following before adding feature-local UI:

* `AppWorkspace`
* `AppListTable`
* `AppPaginatedListTable`
* `AppSearchBar`
* `AppListTableSearch`
* `AppDialog`
* Shared form fields
* `AppStateView`
* `AsyncStateScaffold`
* Access gates

Do not reload the full workspace after modal actions.

## Done Criteria

* Nurses can complete routine ward work quickly from the nursing workspace.
* Nursing actions are synchronized with IPD, ICU, theater, and discharge status.
* MAR, vitals, notes, tasks, and handovers are easy to update and audit.
* UI is uncluttered, responsive, and permission-aware.

## Rule References

### Product and Flow References

* `app-planner/app-write-up.md`
* `app-planner/opd-flow.md`
* `app-planner/ipd-flow.md`
* `app-planner/dev-plan/01-policy.md`
* `app-planner/dev-plan/10-workspace-ui.md`

### Frontend Rules

* `frontend/app-planner/app-rules/architecture.md`
* `frontend/app-planner/app-rules/project_structure.md`
* `frontend/app-planner/app-rules/navigation.md`
* `frontend/app-planner/app-rules/reusable_components.md`
* `frontend/app-planner/app-rules/responsive_adaptive_design.md`
* `frontend/app-planner/app-rules/state_management.md`
* `frontend/app-planner/app-rules/network_api.md`
* `frontend/app-planner/app-rules/permissions.md`
* `frontend/app-planner/app-rules/forms.md`
* `frontend/app-planner/app-rules/search_filtering.md`
* `frontend/app-planner/app-rules/pagination_data_tables.md`
* `frontend/app-planner/app-rules/localization_i18n.md`
* `frontend/app-planner/app-rules/performance.md`
* `frontend/app-planner/app-rules/accessibility.md`

### Backend Rules

* `backend/app-planner/app-rules/api.md`
* `backend/app-planner/app-rules/api-versioning.md`
* `backend/app-planner/app-rules/response-format.md`
* `backend/app-planner/app-rules/auth-security.md`
* `backend/app-planner/app-rules/validation.md`
* `backend/app-planner/app-rules/module-creation.md`

Respect these documents when implementing this step.

Do not edit backend or frontend planner files unless a future task explicitly allows it.
