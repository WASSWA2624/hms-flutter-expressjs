# 08 - Access Control, Permissions, and Entitlements

## Goal
Ensure every route, menu, button, modal action, report, export, print action, notification action, and API operation is controlled by roles, permissions, action rules, tenant scope, facility scope, and module subscriptions.

## Source of Truth
- Use `app-write-up.md` for access expectations.
- Use backend role, permission, ABAC, module-subscription, and license contracts as the source of truth.
- Use frontend permission rules only to present allowed UI and prevent accidental access.

## Backend Routes and Files
- `/api/v1/users`
- `/api/v1/roles`
- `/api/v1/permissions`
- `/api/v1/role-permissions`
- `/api/v1/user-roles`
- `/api/v1/abac-policies`
- `/api/v1/module-subscriptions`
- `backend/src/config/permissions.js`
- `backend/src/config/roles.js`

## Scope
1. Build frontend permission mapping from backend permissions.
2. Protect routes in `AppRoutes` and router guards.
3. Hide or disable menu items the user cannot access.
4. Gate buttons, row actions, modal actions, print/export actions, and notification actions by permission.
5. Display forbidden pages or disabled states clearly.
6. Respect module subscription and license status before showing paid/disabled modules.
7. Support users with multiple roles.
8. Keep backend as final authority for authorization.
9. Apply access consistently across OPD, triage, clinical, IPD, billing, reports, and all support modules.

## Admin UX
Admins should manage:
- users;
- roles;
- permissions;
- role assignments;
- department/facility/unit/ward scope;
- active/disabled status;
- default demo accounts;
- module access where subscription allows it.

## UI Contract
| Area | Rule |
| --- | --- |
| Menus | Show only modules the user can access. |
| Screens | Guard routes and show localized forbidden state when denied. |
| Actions | Hide unavailable actions; disable only when the reason is useful to the user. |
| Modals | Open action modals only when the user can perform the action. |
| Reports | Gate report view, export, print, and audit access separately. |
| Notifications | Route notification actions only to allowed destinations. |
| Backend errors | Map `403` to safe forbidden UI and do not expose raw server details. |

## Done Criteria
- Frontend and backend permission names align.
- Users only see allowed destinations and actions.
- Forbidden backend responses are handled gracefully.
- Module access follows active subscription/module entitlement state.
- Access checks are applied to reports, print actions, queue actions, and modal actions.

## Rule References
### Product and flow references
- `app-planner/app-write-up.md`
- `app-planner/opd-flow.md`
- `app-planner/ipd-flow.md`
- `app-planner/dev-plan/01-policy.md`
- `app-planner/dev-plan/10-workspace-ui.md`

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
- `frontend/app-planner/app-rules/search_filtering.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`
- `frontend/app-planner/app-rules/localization_i18n.md`
- `frontend/app-planner/app-rules/performance.md`
- `frontend/app-planner/app-rules/accessibility.md`

### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`

### Additional references
- `backend/src/config/permissions.js`
- `backend/src/config/roles.js`
- `frontend/lib/core/permissions/`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
