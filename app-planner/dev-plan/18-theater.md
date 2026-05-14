# 18 - Theater Module

## Goal
Manage theater/theatre bookings, procedure flow, anesthesia records, post-op notes, and handover.

## Backend Routes To Align With
- `/api/v1/theatre-cases`
- `/api/v1/theatre-flows`
- `/api/v1/anesthesia-records`
- `/api/v1/post-op-notes`
- `/api/v1/procedures`
- `/api/v1/transfer-requests`

## Implementation Scope
1. Theater schedule and case board.
2. Pre-theater checklist and readiness status.
3. Theater room allocation.
4. Procedure status tracking.
5. Anesthesia record and post-op note capture.
6. Handover back to ward, ICU, outpatient, or discharge.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Theater cases are scheduled and tracked.
- Pre/post-op states are clear.
- Anesthesia and post-op records are linked.
- Backend spelling `theatre` is respected while UI can display `Theater`.

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
