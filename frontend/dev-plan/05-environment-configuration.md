# 05 - Environment Configuration
Provide override-friendly development, staging, and production configuration without exposing secrets.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`environment_configuration.mdc`](../.cursor/environment_configuration.mdc), [`security.mdc`](../.cursor/security.mdc), [`feature_flags.mdc`](../.cursor/feature_flags.mdc), and [`startup_flow.mdc`](../.cursor/startup_flow.mdc).

## Implementation
1. Create `env/development.json.example`, `env/staging.json.example`, and `env/production.json.example` containing non-secret values only.
2. Implement `AppConfig` under `lib/core/config/`.
3. Read compile-time values through Flutter defines or define files.
4. Validate required values during startup.
5. Tests must be able to override configuration.
6. Secrets must not be committed.

## Acceptance Criteria
- Missing required configuration must fail with a clear message.
- Production must reject unsafe debug logging and non-HTTPS public API URLs.
- Example files, the configuration model/provider, and startup validation must exist.
