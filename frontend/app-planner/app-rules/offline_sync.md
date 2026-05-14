# Offline and Sync Strategy

## Scope
Defines offline-capable behavior, sync queues, conflict handling, and connectivity use.

## Mandatory rules
- Treat connectivity status as a hint, not proof that the backend is reachable.
- Store offline drafts or pending writes in a structured local queue when offline-capable behavior is required.
- Make sync operations idempotent when possible.
- Show clear sync states: pending, syncing, synced, failed, conflict.
- Do not silently discard offline changes.
- Keep conflict handling explicit and product-specific where needed.
- Repositories should expose a consistent view of local and remote data.

## Sync queue fields
| Field | Purpose |
|---|---|
| local id | stable local reference |
| operation type | create, update, delete, upload |
| payload | serialized request payload |
| status | pending, syncing, failed, synced, conflict |
| retry count | retry policy control |
| created/updated timestamps | ordering and diagnostics |

## Acceptance checklist
- App can show cached or local data where supported.
- Pending writes survive app restart.
- Failed syncs show recoverable UI states.
- Conflict behavior is documented before release.

## Related rules
- [`database_strategy.md`](./database_strategy.md)
- [`network_api.md`](./network_api.md)
- [`error_handling.md`](./error_handling.md)
- [`observability.md`](./observability.md)
