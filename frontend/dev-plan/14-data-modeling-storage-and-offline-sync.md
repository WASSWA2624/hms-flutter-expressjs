# 14 - Data Modeling, Storage, and Offline Sync
Keep persistence optional while making model conversion and future synchronization explicit.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`data_modeling.mdc`](../.cursor/data_modeling.mdc), [`storage_strategy.mdc`](../.cursor/storage_strategy.mdc), [`database_strategy.mdc`](../.cursor/database_strategy.mdc), [`offline_sync.mdc`](../.cursor/offline_sync.mdc), and [`code_generation.mdc`](../.cursor/code_generation.mdc).

## Implementation
1. Separate domain entities from DTOs and database models.
2. Add explicit mappers between model layers.
3. Plain preferences may store only non-sensitive settings.
4. Add secure storage only with session/auth implementation.
5. Add Drift only for structured local data or sync queues.
6. When offline behavior is added, document conflict and retry strategy.

## Acceptance Criteria
- Data models must not leak into widgets.
- Sensitive data must never use plain preferences.
- Offline logic must remain explicit and testable.
- Model examples, storage abstractions, and any sync contracts must preserve layer boundaries.
