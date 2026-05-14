# 29 - Rooms, Wards, and Beds

## Goal
Manage physical spaces and occupancy readiness for clinical, inpatient, ICU, theater, housekeeping, and operations workflows.

## Backend Routes To Align With
- `/api/v1/rooms`
- `/api/v1/wards`
- `/api/v1/beds`
- `/api/v1/bed-assignments`
- `/api/v1/facilities`
- `/api/v1/departments`
- `/api/v1/units`

## Implementation Scope
1. Room/ward/bed admin lists.
2. Bed status and occupancy readiness.
3. Links to inpatient and housekeeping workflows.
4. Create/edit modals for facility admins.
5. Filters by facility, ward, room, status, and readiness.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Facility admins can configure spaces.
- Bed states are usable by IPD/ICU/housekeeping.
- Physical-space data is not duplicated in modules.

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
