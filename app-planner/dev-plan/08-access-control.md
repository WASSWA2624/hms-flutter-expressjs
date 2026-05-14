# 08 - Access Control, Permissions, and Entitlements

## Goal
Ensure every route, menu, button, modal action, report, and API operation is controlled by roles, permissions, action rules, tenant scope, facility scope, and module subscriptions.

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
4. Gate buttons and modal actions by permission.
5. Display forbidden pages or disabled states clearly.
6. Respect module subscription and license status before showing paid/disabled modules.
7. Support users with multiple roles.
8. Keep backend as final authority for authorization.

## Admin UX
Admins should manage:
- users;
- roles;
- permissions;
- role assignments;
- department/facility scope;
- active/disabled status;
- default demo accounts;
- module access where subscription allows it.

## Done Criteria
- Frontend and backend permission names align.
- Users only see allowed destinations and actions.
- Forbidden backend responses are handled gracefully.
- Module access follows active subscription/module entitlement state.

## Rule References
### Frontend rules
- `frontend/app-planner/app-rules/permissions.md`
- `frontend/app-planner/app-rules/navigation.md`
- `frontend/app-planner/app-rules/authentication_session.md`
- `frontend/app-planner/app-rules/security.md`
- `frontend/app-planner/app-rules/state_management.md`
### Backend rules
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/validation.md`
### Additional references
- `backend/src/config/permissions.js`
- `backend/src/config/roles.js`
- `frontend/lib/core/permissions/`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
