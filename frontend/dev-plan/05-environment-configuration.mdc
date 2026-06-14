# 05 - Environment configuration

## Goal
Create safe environment configuration for development, staging, and production without committing secrets.

## Applies app rules
- [`environment_configuration.md`](../app-rules/environment_configuration.md)
- [`security.md`](../app-rules/security.md)
- [`feature_flags.md`](../app-rules/feature_flags.md)
- [`startup_flow.md`](../app-rules/startup_flow.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create `env/development.json.example`, `env/staging.json.example`, and `env/production.json.example` with non-secret values only.
3. Create `AppConfig` under `lib/core/config/`.
4. Read compile-time values with Flutter defines or define files.
5. Validate required values during startup.
6. Keep tests override-friendly.

## Expected output
- Environment example files.
- `AppConfig` model/provider.
- Startup validation for required config.

## Acceptance criteria
- Missing required config fails clearly.
- Production config rejects unsafe debug logging and accidental non-HTTPS public API URLs.
- No secrets are committed.
