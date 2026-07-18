# 12 - State Management and DI
Use Riverpod as the single override-friendly global state and dependency system.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`state_management.mdc`](../.cursor/state_management.mdc), [`architecture.mdc`](../.cursor/architecture.mdc), [`testing.mdc`](../.cursor/testing.mdc), and [`startup_flow.mdc`](../.cursor/startup_flow.mdc).

## Implementation
1. Place app-level providers under `lib/app/` or `lib/core/` by responsibility.
2. Put feature controllers under `features/<feature>/presentation/controllers/`.
3. Keep repository providers near their contracts and implementations.
4. Tests and non-production starters must use provider overrides.
5. Global mutable singletons must not be introduced.
6. Add theme, locale, router, config, and startup providers only where needed.

## Acceptance Criteria
- UI must not instantiate repositories, clients, storage, or databases.
- Tests must override dependencies without production services.
- Riverpod must remain the only global state system.
- Provider organization and test override examples must be clear.
