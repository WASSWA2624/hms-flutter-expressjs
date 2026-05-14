# 14 - Data modeling, storage, and offline sync

## Goal
Create clear model boundaries and storage/offline readiness without forcing unnecessary persistence.

## Applies app rules
- [`data_modeling.md`](../app-rules/data_modeling.md)
- [`storage_strategy.md`](../app-rules/storage_strategy.md)
- [`database_strategy.md`](../app-rules/database_strategy.md)
- [`offline_sync.md`](../app-rules/offline_sync.md)
- [`code_generation.md`](../app-rules/code_generation.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Define domain entities separately from DTOs and database models.
3. Add explicit mappers between DTOs, database models, and domain entities.
4. Add simple preference storage only for non-sensitive starter settings when needed.
5. Add secure storage only when session/auth is implemented.
6. Add Drift only when structured local data or sync queues are implemented.
7. Document sync conflict and retry strategy when offline behavior is added.

## Expected output
- Model boundary examples.
- Storage abstraction readiness.
- Optional offline/sync contracts.

## Acceptance criteria
- Data models do not leak into widgets.
- Sensitive data is never stored in plain preferences.
- Offline logic remains explicit and testable.
