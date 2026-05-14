# 31 - Operations

## Goal
Manage non-clinical facility operations such as electrical, plumbing, water, power backup, HVAC/air-conditioning, safety checks, and general maintenance.

## Backend Routes To Align With
- `/api/v1/maintenance-requests`
- `/api/v1/assets`
- `/api/v1/asset-service-logs`
- `/api/v1/housekeeping`
- `/api/v1/facilities`
- `/api/v1/rooms`

## Implementation Scope
1. Operations dashboard.
2. Maintenance request list.
3. Issue categories such as electrical, plumbing, water, power backup, HVAC, safety, building, and general maintenance.
4. Request triage, assignment, status update, and completion.
5. Asset/service-log visibility where supported.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Operations staff can manage maintenance without entering unrelated modules.
- Electrical/plumbing/water/power/HVAC issues are clearly categorized.
- Requests are assigned, tracked, and auditable.

## Rule References
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
- `frontend/app-planner/app-rules/localization_i18n.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
