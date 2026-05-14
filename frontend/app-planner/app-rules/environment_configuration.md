# Environment Configuration

## Scope
Defines how development, staging, and production configuration is represented.

## Mandatory rules
- Keep environment-specific values outside feature widgets.
- Do not commit secrets in source code, assets, config files, or docs.
- Use Flutter compile-time define files for non-secret public values.
- Validate required configuration during startup.
- Separate development, staging, and production values.
- Production API base URLs must use HTTPS unless a controlled private network explicitly requires otherwise.
- Logs must clearly identify the environment without exposing secrets.

## Recommended config values
| Value | Example |
|---|---|
| environment name | `development`, `staging`, `production` |
| API base URL | public non-secret URL |
| API timeout | duration in seconds |
| logging level | debug/info/warn/error |
| feature flag defaults | safe defaults |

## Acceptance checklist
- Missing required config fails fast with a clear message.
- Production builds do not include development-only endpoints by accident.
- Tests can override environment config.

## Related rules
- [`security.md`](./security.md)
- [`network_api.md`](./network_api.md)
- [`feature_flags.md`](./feature_flags.md)
- [`ci_cd_quality_gates.md`](./ci_cd_quality_gates.md)
