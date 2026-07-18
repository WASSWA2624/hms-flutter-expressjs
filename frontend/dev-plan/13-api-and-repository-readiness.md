# 13 - API and Repository Readiness
Prepare testable backend integration without requiring a live service.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`network_api.mdc`](../.cursor/network_api.mdc), [`repository-pattern-example.mdc`](../.cursor/reference/repository-pattern-example.mdc), [`architecture.mdc`](../.cursor/architecture.mdc), [`error_handling.mdc`](../.cursor/error_handling.mdc), and [`environment_configuration.mdc`](../.cursor/environment_configuration.mdc).

## Implementation
1. Create an API client abstraction under `lib/core/network/`.
2. Add an HTTP package only when implementing a real client.
3. Put repository contracts in feature domain layers and implementations in data layers.
4. Use fake or in-memory starter implementations when no backend exists.
5. Network errors must map to typed failures.

## Acceptance Criteria
- The app must run without a real backend.
- Widgets must not call API clients directly.
- Repositories must be override-friendly in tests.
- API contracts, a repository example, a starter fake, and failure mapping must be available.
