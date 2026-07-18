# 06 - Startup Bootstrap
Initialize the app predictably while keeping startup failures recoverable.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`startup_flow.mdc`](../.cursor/startup_flow.mdc), [`state_management.mdc`](../.cursor/state_management.mdc), [`environment_configuration.mdc`](../.cursor/environment_configuration.mdc), and [`error_handling.mdc`](../.cursor/error_handling.mdc).

## Implementation
1. `lib/main.dart` must only call `bootstrap`.
2. `lib/bootstrap.dart` must initialize Flutter bindings, startup services, and `ProviderScope`.
3. Add state under `lib/app/startup/` when initialization may fail or take time.
4. Network calls must not occur inside widget `build` methods.
5. Asynchronous startup must show predictable loading and localized error states.

## Acceptance Criteria
- Cold start must be deterministic.
- Startup errors must provide a safe recovery path.
- The app must launch without a real backend.
- A startup controller/provider may be omitted when initialization is synchronous.
