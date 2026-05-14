# Storage Strategy

## Scope
Defines local storage choices and ownership.

## Mandatory rules
- Use `shared_preferences` only for small non-sensitive preferences.
- Use `flutter_secure_storage` for tokens and sensitive session artifacts where supported.
- Use Drift for structured local records, offline cache, and sync queues.
- Do not store sensitive data in plain files.
- Keep local storage access inside data sources or core storage services.
- Do not read or write storage directly from widgets.
- Keep cache invalidation and retention rules explicit.

## Storage ownership
| Data type | Storage |
|---|---|
| Theme mode | `shared_preferences` |
| Locale override | `shared_preferences` |
| Session token | secure storage |
| Structured offline records | Drift |
| Sync queue | Drift |
| Temporary cache files | platform cache directory |

## Acceptance checklist
- Storage choices match sensitivity and structure of the data.
- Storage services are provider-driven and testable.
- Logout clears sensitive session data.

## Related rules
- [`database_strategy.md`](./database_strategy.md)
- [`offline_sync.md`](./offline_sync.md)
- [`security.md`](./security.md)
- [`state_management.md`](./state_management.md)
