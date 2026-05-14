# 05 - Authentication, Session, and User Menu

## Goal
Implement HMS authentication screens and account actions using the existing Flutter session foundation and backend auth APIs.

## Current State
- Frontend session management and route guards already exist under `frontend/lib/core/security/` and `frontend/lib/app/router/`.
- Backend auth routes exist under `/api/v1/auth` and session routes under `/api/v1/user-sessions`.
- The user dropdown UI is not yet HMS-complete.

## Scope
1. Create login screen.
2. Create registration screen only if the product flow allows user self-registration; otherwise restrict account creation to admin workflows.
3. Create change-password screen/modal.
4. Implement logout and session cleanup.
5. Restore session on app startup.
6. Add logged-in user avatar to the app bar.
7. Add user dropdown actions: profile, settings, change password, logout.
8. Redirect authenticated and unauthenticated users predictably.
9. Surface session expiry and forbidden states clearly.

## Backend Contracts
Use existing backend auth/session contracts. Confirm payload names, token handling, refresh behavior, and error format before implementing UI.

## UX Rules
- Keep auth forms narrow and centered.
- Use clear field labels and validation messages.
- Disable duplicate submissions.
- Never expose raw backend error details.
- After first setup, guide admins to tenant/facility setup.

## Done Criteria
- Login, logout, change password, and session restoration work.
- User dropdown appears only for authenticated users.
- Protected routes cannot be entered without a valid session.
- Session storage is cleared on logout.

## Rule References
### Frontend rules
- `frontend/app-planner/app-rules/authentication_session.md`
- `frontend/app-planner/app-rules/startup_flow.md`
- `frontend/app-planner/app-rules/security.md`
- `frontend/app-planner/app-rules/forms.md`
- `frontend/app-planner/app-rules/navigation.md`
- `frontend/app-planner/app-rules/permissions.md`
### Backend rules
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/validation.md`
### Additional references
- `backend/src/modules/auth/`
- `backend/src/modules/user-session/`
- `frontend/lib/core/security/`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
