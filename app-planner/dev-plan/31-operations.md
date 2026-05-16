# 31 - Operations Module

## Goal
Manage non-clinical facility operations such as maintenance requests, electrical, plumbing, water, power backup, HVAC/air-conditioning, general assets, safety checks, service logs, and operational readiness.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for operations scope.
- Use `ipd-flow.md` indirectly where operations affects bed/room/ward readiness and patient movement.
- Use `01-policy.md` for simple modals, permissions, responsive UI, and partial refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/maintenance-requests`
- `/api/v1/assets`
- `/api/v1/asset-service-logs`
- `/api/v1/facilities`
- `/api/v1/rooms`
- `/api/v1/wards`
- `/api/v1/beds`
- `/api/v1/housekeeping-tasks`
- `/api/v1/housekeeping-schedules`

## Implementation Scope
1. Operations request queue for new, assigned, in progress, waiting parts/vendor, completed, rejected, and closed requests.
2. Asset/location detail with maintenance history and readiness where supported.
3. Modal actions for create request, assign technician/team, update status, add service log, request parts/vendor, mark completed, and close request.
4. Links to room/bed status when maintenance affects patient care space.
5. Reports for maintenance workload and readiness.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a simple maintenance queue with location, issue, priority, status, assignee, and next action. |
| Request creation | Use a short modal: location, category, issue, priority, photo/attachment where supported, notes. |
| Detail view | Show request timeline, assignments, service logs, affected location/asset, and closure notes. |
| Technicality | Keep engineering details secondary; default UI should be clear to non-technical staff. |
| Responsiveness | Mobile supports request creation/update; desktop supports queue plus detail panel. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: maintenance request list, asset/service-log card, operational status badge, request/approval modal, facility area selector, task assignment panel, and closeout confirmation modal.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: assets, maintenance requests, service logs, facility/room context, housekeeping handoff where relevant, notifications, reports, and audit events must stay synchronized.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- Maintenance requests affecting rooms/beds should update room/bed readiness only for the affected location.
- Completed repair should notify bed/room managers where relevant.
- Housekeeping requests should route to housekeeping instead of duplicating cleaning work.
- Operations should not redefine facility/room/asset structure; consume configured records.

## Access and State Rules
- Operations staff manage maintenance workflows.
- Department staff can request and track issues where permitted.
- After mutation, refresh only the request row, location readiness badge, asset status, and notification badge.

## Reports and Printing
Maintenance request summaries, service logs, asset service history, readiness reports, and vendor/parts notes must use generated report templates from `35-reports-audit.md`.

## Done Criteria
- Operations requests are easy to create and track.
- Room/bed readiness updates stay synchronized with IPD and facility modules.
- UI is simple for busy staff and detailed enough for operations users.
- Actions are permission-aware and modal-based.

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
