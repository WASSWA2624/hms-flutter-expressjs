# 15 - Auth, session, security, and permissions

## Goal
Prepare authentication, session, security, and permission boundaries without forcing product-specific auth flows.

## Applies app rules
- [`authentication_session.md`](../app-rules/authentication_session.md)
- [`security.md`](../app-rules/security.md)
- [`permissions.md`](../app-rules/permissions.md)
- [`navigation.md`](../app-rules/navigation.md)
- [`storage_strategy.md`](../app-rules/storage_strategy.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create session state types: unknown, unauthenticated, authenticated, expired, and forbidden.
3. Create auth repository contract without assuming a specific provider.
4. Create secure session storage abstraction when tokens are used.
5. Wire route guards to session state.
6. Add permission types and helpers.
7. Add logout behavior that clears sensitive local session data.

## Expected output
- Auth/session contracts.
- Session provider.
- Permission helpers.
- Guarded route example.

## Acceptance criteria
- Protected routes are blocked without session when enabled.
- Token values are never logged.
- Permission checks are centralized.
