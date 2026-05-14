# 17 - ICU Module

## Goal
Manage ICU-specific admission, bed assignment, intensive monitoring, ICU rounds, critical alerts, transfer-out, and discharge readiness.

## Backend Routes To Align With
- `/api/v1/icu-stays`
- `/api/v1/icu-observations`
- `/api/v1/critical-alerts`
- `/api/v1/vital-signs`
- `/api/v1/transfer-requests`
- `/api/v1/bed-assignments`

## Implementation Scope
1. ICU patient board.
2. ICU stay detail with monitoring summary.
3. ICU observation capture.
4. Critical alert visibility.
5. Transfer out to ward, theater, discharge, or other unit.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- ICU status is visible and uncluttered.
- Critical observations are easy to record.
- Alerts and transfer readiness are clear.
- Access is restricted to permitted users.

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
