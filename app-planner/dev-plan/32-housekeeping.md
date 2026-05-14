# 32 - Housekeeping

## Goal
Manage cleaning tasks, room/bed turnover, ward cleaning, schedules, laundry coordination, sanitation requests, and cleanliness readiness.

## Backend Routes To Align With
- `/api/v1/housekeeping`
- `/api/v1/housekeeping-tasks`
- `/api/v1/housekeeping-schedules`
- `/api/v1/maintenance-requests`
- `/api/v1/rooms`
- `/api/v1/beds`
- `/api/v1/wards`

## Implementation Scope
1. Housekeeping workspace dashboard.
2. Cleaning task list by room, ward, bed, priority, and status.
3. Schedule view.
4. Turnover workflow for bed/room readiness.
5. Maintenance escalation for broken or unsafe rooms.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Housekeeping users can manage cleaning and turnover from one module.
- Bed/room readiness supports inpatient flow.
- Cleaning status is visible without screen congestion.

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
