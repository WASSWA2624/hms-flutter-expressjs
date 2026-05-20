# 05 - Authentication, Session, and User Menu

## Goal
Implement HMS authentication screens and account actions using the existing Flutter session foundation and backend auth APIs.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Align with current backend auth/session routes and response formats for implementation details.
- Use `app-write-up.md` and `08-access-control.md` for role and module access expectations.
- Use frontend auth, session, security, forms, navigation, and permissions rules for implementation.


## Current Implementation Baseline
- Current frontend status: `frontend/lib/features/auth/` already contains login, register, verify-email, change-password dialog, session controller integration, DTOs, repository, and route guards.
- Required adjustment: extend the existing auth controller/repository/pages only; do not create a parallel auth flow or alternate session storage.
- UI similarity rule: keep auth forms on shared fields/buttons/state messaging, route through existing guards, and use `AppDialog` for password/session actions.

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

Confirm each auth/session contract against the current backend router/API contract before wiring frontend calls. If a contract is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
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

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: login/register/change-password forms, password field, submit button, auth error state, session-loading screen, user avatar/menu, protected-route wrapper, and forbidden/unauthenticated state.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: auth DTOs, session storage, route guards, role/module visibility, and logout cleanup must reflect backend auth/session responses.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Auth forms | Use shared form shell/fields, localized validation, disabled/loading submit states, and safe server-error mapping. |
| Session state | Session restoration, refresh, logout, and profile updates must update only auth/session providers and route guards, not reload the whole app. |
| User actions | Change password, logout confirmation, user profile shortcuts, and security notices should use `AppDialog` where they are short actions. |
| Access sync | `AuthSession` must feed `AppAccessPolicy`, roles, permissions, tenant/facility context, and module entitlements used by routes and actions. |
| Backend boundary | Do not create frontend-only permissions or roles; align with backend `ROLES`, `PERMISSIONS`, auth routes, and session response payloads. |


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
