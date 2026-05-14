# Observability Strategy

## Scope
Defines logging, diagnostics, analytics readiness, and privacy constraints.

## Mandatory rules
- Keep logs structured enough to diagnose issues.
- Do not log secrets, tokens, passwords, sensitive payloads, or private user data.
- Use environment-based log levels.
- Disable verbose logs in production builds.
- Capture startup, auth, API, sync, and storage failures with safe context.
- Keep analytics optional and app-specific; do not force a vendor into the base template.
- Add breadcrumbs or context only when they do not expose sensitive information.

## Log levels
| Level | Use |
|---|---|
| debug | development-only details |
| info | normal lifecycle events |
| warning | recoverable unexpected state |
| error | failed operation requiring attention |

## Acceptance checklist
- Production logs are safe.
- Failure diagnostics help developers reproduce issues without exposing private data.
- Logging can be disabled or adjusted per environment.

## Related rules
- [`security.md`](./security.md)
- [`error_handling.md`](./error_handling.md)
- [`environment_configuration.md`](./environment_configuration.md)
