# 33 - Subscription Management

## Goal
Manage subscription plans, active subscriptions, module subscriptions, licenses, subscription invoices, and entitlement-driven module access.

## Backend Routes To Align With
- `/api/v1/subscriptions-workspace`
- `/api/v1/subscription-plans`
- `/api/v1/subscriptions`
- `/api/v1/subscription-invoices`
- `/api/v1/modules`
- `/api/v1/module-subscriptions`
- `/api/v1/licenses`

## Implementation Scope
1. Subscription workspace dashboard.
2. Plan list and plan details.
3. Tenant subscription state.
4. Module subscription visibility.
5. License status.
6. Subscription invoice list.
7. Module entitlement warnings in navigation and admin settings.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Admins can see active plan, license, modules, limits, and invoice state.
- Disabled modules are not shown as usable.
- Subscription state affects module visibility consistently.

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
