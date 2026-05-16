# 05 - Authentication, Session, and User Menu

## Goal
Implement HMS authentication screens and account actions using the existing Flutter session foundation and backend auth APIs.

## Source of Truth
- Use backend auth/session routes and response formats as the source of truth.
- Use `app-write-up.md` and `08-access-control.md` for role and module access expectations.
- Use frontend auth, session, security, forms, navigation, and permissions rules for implementation.

## Current State
- Frontend session management and route guards should be reused where present under `frontend/lib/core/security/` and `frontend/lib/app/router/`.
- Backend auth routes exist under `/api/v1/auth` and session routes under `/api/v1/user-sessions`.
- The user dropdown UI may not yet be HMS-complete.

## Scope
1. Create login screen.
2. Create registration screen only if the product flow allows user self-registration; otherwise restrict account creation to admin workflows.
3. Create change-password modal or page based on complexity.
4. Implement logout and session cleanup.
5. Restore session on app startup.
6. Add logged-in user avatar to the app bar.
7. Add user dropdown actions: profile, settings, change password, logout.
8. Redirect authenticated and unauthenticated users predictably.
9. Surface session expiry and forbidden states clearly.
10. Load role, permission, tenant, facility, and module entitlement context after login.

## Backend Contracts
Use existing backend auth/session contracts. Confirm payload names, token handling, refresh behavior, session expiry, permission payloads, module entitlement payloads, and error format before implementing UI.

## UX Rules
- Keep auth forms narrow and centered.
- Use clear field labels and validation messages.
- Disable duplicate submissions.
- Never expose raw backend error details.
- After first setup, guide admins to tenant/facility setup.
- After normal login, route users to the most relevant allowed workspace, not to inaccessible modules.
- Update only session-dependent UI pieces after login/logout: shell, menu, avatar, route guards, badges, and accessible modules.

## Access Rules
- Menus and routes must be rebuilt from the authenticated user's roles, permissions, scopes, and active module entitlements.
- Staff must not see actions outside their roles.
- Backend `401` should trigger session handling; backend `403` should show a localized forbidden state.

## Done Criteria
- Login, logout, change password, and session restoration work.
- User dropdown appears only for authenticated users.
- Protected routes cannot be entered without a valid session.
- Session storage is cleared on logout.
- Menus, module visibility, and modal actions respect the current user access context.

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
- `frontend/app-planner/app-rules/authentication_session.md`
- `frontend/app-planner/app-rules/startup_flow.md`
- `backend/src/modules/auth/`
- `backend/src/modules/user-session/`
- `frontend/lib/core/security/`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
