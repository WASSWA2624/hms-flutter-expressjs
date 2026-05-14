# 12 - State management and DI

## Goal
Set up Riverpod as the single state management and dependency injection system.

## Applies app rules
- [`state_management.md`](../app-rules/state_management.md)
- [`architecture.md`](../app-rules/architecture.md)
- [`testing.md`](../app-rules/testing.md)
- [`startup_flow.md`](../app-rules/startup_flow.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Place app-level providers under `lib/app/` or `lib/core/` by responsibility.
3. Place feature controllers under `features/<feature>/presentation/controllers/`.
4. Place repository providers near repository implementations and contracts.
5. Use provider overrides for tests and non-production starter implementations.
6. Avoid global mutable singletons.

## Expected output
- Provider structure.
- App-level providers for theme, locale, router, config, and startup where needed.
- Test override examples.

## Acceptance criteria
- UI does not instantiate repositories, clients, storage, or databases directly.
- Tests can override dependencies without touching production services.
- Riverpod is the only global state system.
