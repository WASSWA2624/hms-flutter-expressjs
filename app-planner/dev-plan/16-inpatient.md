# 16 - Inpatient Management

## Goal
Manage patients under admission, beds, ward rounds, inpatient nursing coordination, progress, and transfers.

## Backend Routes To Align With
- `/api/v1/admissions`
- `/api/v1/ipd-flows`
- `/api/v1/bed-assignments`
- `/api/v1/ward-rounds`
- `/api/v1/transfer-requests`
- `/api/v1/wards`
- `/api/v1/beds`

## Implementation Scope
1. Admission list and admitted-patient board.
2. Bed assignment and bed transfer actions.
3. Ward-round capture and progress tracking.
4. Inpatient nursing coordination.
5. Transfer requests to ward, ICU, theater, or discharge pathway.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Admitted patients are visible by ward/bed/status.
- Bed assignment is clear.
- Ward rounds are recorded.
- Transfers and discharge readiness are traceable.

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
