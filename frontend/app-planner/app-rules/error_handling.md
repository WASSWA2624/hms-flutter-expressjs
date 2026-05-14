# Error Handling Strategy

## Scope
Defines typed failures, UI error states, retries, and safe messages.

## Mandatory rules
- Convert thrown exceptions into typed failures at layer boundaries.
- Do not expose raw technical errors directly to users.
- Keep user-facing error messages localized.
- Provide retry actions for recoverable failures.
- Use consistent loading, empty, error, and success views.
- Log diagnostic details safely without secrets or sensitive data.
- Preserve user input on recoverable form failures.
- Handle startup, navigation, network, storage, validation, and permission errors explicitly.

## Failure categories
| Category | Example UI behavior |
|---|---|
| network | retry option |
| validation | field errors or form summary |
| unauthorized | restore session or redirect to login |
| forbidden | forbidden page/state |
| not found | not-found page/state |
| storage | safe fallback or recovery guidance |
| unexpected | generic safe message with diagnostics logged |

## Acceptance checklist
- No feature displays raw exception text to users.
- Error states are visually consistent.
- Errors are testable through provider/repository overrides.

## Related rules
- [`network_api.md`](./network_api.md)
- [`forms.md`](./forms.md)
- [`observability.md`](./observability.md)
- [`localization_i18n.md`](./localization_i18n.md)
