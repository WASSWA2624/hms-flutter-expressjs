# 13 - API and repository readiness

## Goal
Prepare backend integration boundaries without requiring a real backend.

## Applies app rules
- [`network_api.md`](../app-rules/network_api.md)
- [`repository_pattern_example.md`](../app-rules/repository_pattern_example.md)
- [`architecture.md`](../app-rules/architecture.md)
- [`error_handling.md`](../app-rules/error_handling.md)
- [`environment_configuration.md`](../app-rules/environment_configuration.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create API client abstraction under `lib/core/network/`.
3. Add a real HTTP package only when an actual HTTP client is implemented.
4. Create repository contracts in feature domain folders.
5. Create repository implementations in feature data folders.
6. Use fake or in-memory implementations for the runnable starter when no backend exists.
7. Map network errors into typed failures.

## Expected output
- API client contract/readiness.
- Repository contract example.
- Fake or in-memory starter implementation.
- Typed failure mapping.

## Acceptance criteria
- App runs without a real backend.
- Widgets do not call API clients directly.
- Repositories are override-friendly in tests.
