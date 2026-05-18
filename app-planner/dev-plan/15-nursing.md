# 15 - Nursing Module

## Goal
Support nursing observations, vital signs, medication administration, care tasks, handovers, ward activity, and clinical escalation across OPD, IPD, ICU, theater recovery, and discharge workflows.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for nursing responsibilities.
- Use `opd-flow.md` for triage handoff and outpatient nursing touchpoints.
- Use `ipd-flow.md` for nursing admission, ward handover, inpatient care loop, transfers, discharge readiness, and bed release coordination.
- Use `01-policy.md` for simple modal actions, role access, responsive UI, and partial state updates.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/nursing-notes`
- `/api/v1/medication-administrations`
- `/api/v1/vital-signs`
- `/api/v1/handovers`
- `/api/v1/nurse-rosters`
- `/api/v1/care-plans`

## Implementation Scope
1. Nursing worklist by ward, unit, shift, patient, priority, care task, admission status, and discharge readiness.
2. Patient nursing detail with current location, diagnosis summary, care plan, vitals, medications due, tasks, handovers, and alerts.
3. Modal actions for record vitals, nursing note, medication administration, task completion, handover, escalation, and transfer acknowledgement.
4. Ward admission checklist connected to IPD bed allocation and admission handover.
5. Shift-aware context so nurses see what needs action now without browsing unrelated modules.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a clean patient/task board with tabs or filters for assigned ward, urgent, medication due, handover pending, transfer pending, discharge pending. |
| Patient row | Show patient, ward/room/bed, status, priority, due action, and last observation. Avoid dense clinical history in the list. |
| Routine actions | Use modals for vitals, notes, MAR updates, handover notes, and task completion. |
| High-risk actions | Require clear confirmation for medication administration, escalation, and transfer acknowledgement. |
| Mobile behavior | One-column list and focused modal forms. Keep touch targets practical. |
| Desktop behavior | Allow worklist and patient panel side by side using shared responsive layout. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: patient context header, nursing observation form, vitals form, medication administration form, care task checklist, handover modal, roster/assignment list, and ward activity panel.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: nursing notes, vitals, medication administrations, care tasks, handovers, ward queues, doctor updates, pharmacy stock effects, and IPD admission state must update together.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- IPD nursing admission must start only after admission/bed workflow provides a patient location or authorized holding area.
- Medication administration should update MAR status, patient task list, and notification badges only for the affected patient.
- Transfer handovers must update source and destination nursing queues.
- Discharge nursing checklist must feed discharge status without closing the admission by itself.
- ICU and theater handovers must remain visible to permitted nurses without duplicating care episodes.

## Access and State Rules
- Nurses can act only within assigned facility, ward/unit, role, and entitlement scope.
- Doctors can view nursing notes where permitted but should not receive nursing-only action buttons unless allowed.
- After a mutation, update only the patient row, task badge, MAR line, handover item, and detail panel.
- Offline or failed saves must keep unsaved form data visible until staff retry or discard.

## Reports and Printing
Nursing notes, handover summaries, observation charts, medication administration summaries, and discharge nursing checklists must use generated report templates from `35-reports-audit.md`. Do not print UI screens.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppPaginatedListTable<NursingWorkItem>` with patient, ward/bed, admission, task type, priority, due time, responsible nurse, and status. Use `AppSearchBar` for patient, ward, bed, task, status, priority, and date filters. |
| Detail/display | Use shared inpatient patient context with observations, medication administration, nursing notes, care tasks, handover notes, and ward activity. |
| CRUD/UI actions | Use `AppDialog` for observation, medication administration, task update, nursing note, handover, escalation, and print handover/task summary. |
| RBAC/ABAC | Gate with clinical permissions, nursing/ward manager roles where represented, ward/unit scope, and active inpatient module entitlement. |
| Partial refresh | After nursing mutation update only affected task row, medication/observation section, ward board badge, handover/activity entry, and notification count. |

Implementation must reuse `AppWorkspace`, `AppListTable`/`AppPaginatedListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


## Done Criteria
- Nurses can complete routine ward work quickly from the nursing workspace.
- Nursing actions are synchronized with IPD, ICU, theater, and discharge status.
- MAR, vitals, notes, tasks, and handovers are easy to update and audit.
- UI is uncluttered, responsive, and permission-aware.

## Rule References

### Product and flow references
- `app-planner/app-write-up.md`
- `app-planner/opd-flow.md`
- `app-planner/ipd-flow.md`
- `app-planner/dev-plan/01-policy.md`
- `app-planner/dev-plan/10-workspace-ui.md`

### Frontend rules
- `frontend/app-planner/app-rules/architecture.md`
- `frontend/app-planner/app-rules/project_structure.md`
- `frontend/app-planner/app-rules/navigation.md`
- `frontend/app-planner/app-rules/reusable_components.md`
- `frontend/app-planner/app-rules/responsive_adaptive_design.md`
- `frontend/app-planner/app-rules/state_management.md`
- `frontend/app-planner/app-rules/network_api.md`
- `frontend/app-planner/app-rules/permissions.md`
- `frontend/app-planner/app-rules/forms.md`
- `frontend/app-planner/app-rules/search_filtering.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`
- `frontend/app-planner/app-rules/localization_i18n.md`
- `frontend/app-planner/app-rules/performance.md`
- `frontend/app-planner/app-rules/accessibility.md`

### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
