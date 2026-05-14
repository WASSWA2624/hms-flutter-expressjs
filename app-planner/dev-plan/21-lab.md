# 21 - Laboratory

## Goal
Manage lab catalog, orders, samples, results, QC, and lab workspace actions.

## Backend Routes To Align With
- `/api/v1/lab`
- `/api/v1/lab-tests`
- `/api/v1/lab-panels`
- `/api/v1/lab-orders`
- `/api/v1/lab-order-items`
- `/api/v1/lab-samples`
- `/api/v1/lab-results`
- `/api/v1/lab-qc-logs`

## Implementation Scope
1. Lab order queue.
2. Sample collection and status tracking.
3. Result entry and review.
4. QC log visibility.
5. Patient/order context links.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Lab staff can process orders by status.
- Results are linked to patients/orders.
- QC data is available.
- Clinical users can view completed results where permitted.

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
