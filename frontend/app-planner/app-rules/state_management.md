# State Management and Dependency Injection

## Scope
Defines how app state, feature state, and dependencies are created, read, tested, and overridden.

## Mandatory rules
- Use Riverpod as the single state management and dependency injection solution.
- Do not mix Riverpod with another global state management package in the starter.
- Keep providers close to the layer they own.
- Use generated providers where it improves safety and consistency.
- Controllers own presentation state and user actions.
- Repositories own data coordination, not UI state.
- Providers must be override-friendly for tests.
- Do not perform heavy initialization inside widget `build` methods.
- Use `AsyncValue` or equivalent app wrappers for loading, error, and data states.

## Provider placement
| Provider type | Location |
|---|---|
| App-level config/theme/locale | `lib/app/` or `lib/core/config/` |
| Infrastructure clients | `lib/core/network`, `lib/core/storage`, `lib/core/sync` |
| Feature controllers | `features/<feature>/presentation/controllers` |
| Feature repositories | `features/<feature>/data/repositories` and domain contracts |

## Acceptance checklist
- Features can be tested with provider overrides.
- UI does not instantiate repositories, API clients, or databases directly.
- Loading, empty, error, and success states are handled consistently.

## Related rules
- [`architecture.md`](./architecture.md)
- [`startup_flow.md`](./startup_flow.md)
- [`testing.md`](./testing.md)
- [`error_handling.md`](./error_handling.md)
