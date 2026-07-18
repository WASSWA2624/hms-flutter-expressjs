# 17 - Error Handling and Observability
Make failures recoverable, localized, testable, and safe to observe.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`error_handling.mdc`](../.cursor/error_handling.mdc), [`observability.mdc`](../.cursor/observability.mdc), [`network_api.mdc`](../.cursor/network_api.mdc), [`security.mdc`](../.cursor/security.mdc), and [`localization_i18n.mdc`](../.cursor/localization_i18n.mdc).

## Implementation
1. Create typed or sealed failure classes.
2. Map failures to localized user messages.
3. Add a safe logger abstraction under `lib/core/logging/`.
4. Connect `AsyncStateScaffold` to typed loading, empty, error, and success states.
5. Add failure-mapping and state-view tests.

## Acceptance Criteria
- Raw exceptions must not be shown to users.
- Logs must not expose sensitive data.
- Recoverable errors must provide retry paths.
- Typed failures, safe logging, localized views, and relevant tests must work consistently.
