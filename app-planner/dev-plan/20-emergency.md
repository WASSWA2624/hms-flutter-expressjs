# 20 - Emergency and Ambulance

## Goal
Support emergency intake, response, ambulance dispatch, trips, and clinical handover.

## Backend Routes To Align With
- `/api/v1/emergency-cases`
- `/api/v1/triage-assessments`
- `/api/v1/emergency-responses`
- `/api/v1/ambulances`
- `/api/v1/ambulance-dispatches`
- `/api/v1/ambulance-trips`

## Implementation Scope
1. Emergency case list and priority board.
2. Rapid triage/assessment capture.
3. Emergency response documentation.
4. Ambulance availability, dispatch, and trip tracking.
5. Handover to OPD, inpatient, ICU, theater, mortuary, or discharge where applicable.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Emergency users can act quickly.
- Ambulance state is visible.
- Handover target is recorded.
- High-priority states stand out without visual clutter.

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
