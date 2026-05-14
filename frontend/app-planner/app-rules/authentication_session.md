# Authentication and Session Strategy

## Scope
Defines sign-in, registration readiness, session restoration, secure token storage, logout, and protected routes.

## Mandatory rules
- Keep authentication logic inside the auth feature and core session services.
- Store sensitive session tokens only in secure storage where supported.
- Do not store tokens in `shared_preferences`, plain files, logs, screenshots, or analytics.
- Restore session state during startup before protected route checks finish.
- Refresh tokens before expiry when the backend supports refresh tokens.
- Use a refresh lock to avoid multiple simultaneous refresh calls.
- If refresh fails, clear the session and redirect to login.
- Logout must clear sensitive local session data.
- UI route protection must be backed by backend authorization.

## Session states
| State | Meaning |
|---|---|
| unknown | startup restoration is running |
| unauthenticated | no valid session |
| authenticated | valid session and user profile available |
| expired | session failed refresh or was rejected |
| forbidden | authenticated user lacks permission for route/action |

## Acceptance checklist
- Authenticated routes cannot be entered without a valid session.
- Session restoration does not flash protected content to unauthenticated users.
- Token values never appear in logs or UI.

## Related rules
- [`navigation.md`](./navigation.md)
- [`permissions.md`](./permissions.md)
- [`security.md`](./security.md)
- [`storage_strategy.md`](./storage_strategy.md)
