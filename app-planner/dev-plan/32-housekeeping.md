# 32 - Housekeeping Module

## Goal
Manage cleaning tasks, schedules, bed turnover, ward cleaning, sanitation readiness, laundry coordination where supported, housekeeping requests, and cleanliness status.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for housekeeping scope.
- Use `ipd-flow.md` for discharge-triggered bed cleaning, bed release, and room readiness.
- Use `01-policy.md` for simple modal actions, role access, responsive UI, and partial state refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/housekeeping-tasks`
- `/api/v1/housekeeping-schedules`
- `/api/v1/maintenance-requests`
- `/api/v1/rooms`
- `/api/v1/beds`
- `/api/v1/wards`

## Implementation Scope
1. Housekeeping task board for pending, assigned, in progress, inspection pending, completed, failed/rework, and cancelled tasks.
2. Cleaning schedule and ward/room/bed readiness view.
3. Modal actions for create task, assign staff/team, start cleaning, complete cleaning, fail inspection, request rework, and mark room/bed ready.
4. Bed turnover workflow triggered by discharge or transfer where supported.
5. Housekeeping reports for tasks, turnaround time, and readiness.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a simple task board with location, task type, priority, status, assignee, and next action. |
| Bed turnover | Show discharged/dirty beds separately from routine cleaning tasks. |
| Actions | Use modals for start, complete, inspect, rework, assign, and ready actions. |
| Responsiveness | Mobile must support quick task updates from staff; desktop supports board plus detail panel. |
| Simplicity | Avoid technical facility data in the task list. Show location and action clearly. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: housekeeping task list, room/bed context card, cleaning schedule form, task assignment modal, readiness badge, sanitation checklist, and turnover confirmation modal.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: housekeeping tasks, schedules, room/bed readiness, ward/bed availability, discharge turnover, maintenance handoff, notifications, reports, and audit events must stay synchronized.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- Discharge patient exit should create/update housekeeping cleaning task and set bed to cleaning/dirty where backend supports it.
- Cleaning completion should update bed/room readiness and notify bed manager/IPD.
- Maintenance issues found during cleaning should create/route a maintenance request without losing cleaning context.
- Room/bed records must be consumed from existing configuration.

## Access and State Rules
- Housekeeping staff update assigned tasks.
- Bed managers/nurses can view readiness where permitted.
- After mutation, refresh only the task row, bed/room status, ward readiness summary, and notification badge.

## Reports and Printing
Cleaning schedules, completed task summaries, bed turnover reports, inspection notes, and readiness summaries must use generated report templates from `35-reports-audit.md`.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppPaginatedListTable<HousekeepingTask>` with task/reference, location, room/bed, trigger/source, priority, assignee, due time, status, and next action. Use `AppSearchBar` for location, room/bed, assignee, status, priority, and date filters. |
| Detail/display | Use task detail with cleaning checklist, bed/room readiness, source admission/discharge/maintenance link, notes, and activity history. |
| CRUD/UI actions | Use `AppDialog` for create task, assign, start, complete, fail/return, mark room/bed ready, add note, and print housekeeping summary. |
| RBAC/ABAC | Gate with operations/housekeeping roles, ward/location scope, bed-management links, and backend authorization. |
| Partial refresh | After housekeeping mutation update only task row, room/bed readiness badge, IPD/discharge bed-release state, ward count, and notification badge. |

Implementation must reuse `AppWorkspace`, `AppListTable`/`AppPaginatedListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


## Done Criteria
- Bed turnover after discharge is quick and traceable.
- Housekeeping tasks are simple to assign and complete.
- Bed/room readiness stays synchronized with IPD and rooms/beds module.
- UI is responsive, clean, and permission-aware.

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
