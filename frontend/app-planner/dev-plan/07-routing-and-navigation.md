# 07 - Routing and navigation

## Goal
Configure declarative routing, route names, route guards, and responsive shell navigation.

## Applies app rules
- [`navigation.md`](../app-rules/navigation.md)
- [`authentication_session.md`](../app-rules/authentication_session.md)
- [`permissions.md`](../app-rules/permissions.md)
- [`responsive_adaptive_design.md`](../app-rules/responsive_adaptive_design.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create `app_routes.dart` for route names and paths.
3. Create `app_router.dart` with `go_router`.
4. Add a home route and localized not-found route.
5. Add auth/session guard placeholders without requiring a real backend.
6. Use a shell route for persistent navigation.
7. Avoid raw route strings inside pages.

## Expected output
- Central router configuration.
- Route constants/helpers.
- Guard-ready route flow.
- Shell route connected to responsive layout.

## Acceptance criteria
- Web URLs are readable.
- Unknown routes show localized not-found UI.
- Protected-route behavior can be enabled without restructuring routes.
