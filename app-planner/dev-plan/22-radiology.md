# 22 - Radiology and Imaging

## Goal
Manage radiology tests, orders, results, imaging studies, assets, PACS links, and radiology workspace actions.

## Backend Routes To Align With
- `/api/v1/radiology`
- `/api/v1/radiology-tests`
- `/api/v1/radiology-orders`
- `/api/v1/radiology-results`
- `/api/v1/imaging-studies`
- `/api/v1/imaging-assets`
- `/api/v1/pacs-links`

## Implementation Scope
1. Radiology order queue.
2. Imaging test catalog visibility.
3. Result capture and review.
4. Imaging study and asset links.
5. PACS link display where provided.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Radiology orders are trackable.
- Results and imaging links are accessible to permitted users.
- No unsupported PACS behavior is faked.

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
