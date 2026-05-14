# 17 - Error handling and observability

## Goal
Create typed failures, safe logging, and consistent state views.

## Applies app rules
- [`error_handling.md`](../app-rules/error_handling.md)
- [`observability.md`](../app-rules/observability.md)
- [`network_api.md`](../app-rules/network_api.md)
- [`security.md`](../app-rules/security.md)
- [`localization_i18n.md`](../app-rules/localization_i18n.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create typed failure classes or sealed failures.
3. Create error-to-message mapping through localization.
4. Create safe logger abstraction under `lib/core/logging/`.
5. Wire `AsyncStateScaffold` to typed loading, empty, error, and success states.
6. Add tests for failure mapping.

## Expected output
- Typed failure model.
- Safe logger.
- Localized error views.
- State-view tests.

## Acceptance criteria
- Raw exceptions are not shown to users.
- Logs do not expose sensitive data.
- Recoverable errors have retry paths.
