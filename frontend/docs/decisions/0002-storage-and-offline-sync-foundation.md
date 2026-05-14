# ADR 0002: Storage and Offline Sync Foundation

## Status

Accepted

## Context

The template needs reusable local persistence boundaries without assuming a
product API, authentication flow, or conflict policy.

Rule sources:

- [`app-rules/data_modeling.md`](../../app-planner/app-rules/data_modeling.md)
- [`app-rules/database_strategy.md`](../../app-planner/app-rules/database_strategy.md)
- [`app-rules/storage_strategy.md`](../../app-planner/app-rules/storage_strategy.md)
- [`app-rules/offline_sync.md`](../../app-planner/app-rules/offline_sync.md)

## Decision

Use Drift for structured local records and sync queue storage. Keep the database
under `lib/core/storage/database`, with table definitions in `tables/` and
schema changes routed through `migrations/`.

Use `shared_preferences` only through `AppPreferencesStore` for small
non-sensitive preferences. Use `flutter_secure_storage` only through
`AppSecureStorage` for tokens and sensitive session artifacts where the platform
supports secure storage.

Represent pending writes with a generic sync queue entry. The queue stores a
stable local id, operation type, serialized JSON payload, sync status, retry
count, timestamps, and optional failure code. Connectivity remains a hint only;
actual sync workers must treat network calls as fallible and idempotent.

The starter conflict boundary is explicit: the core queue can mark entries as
`conflict`, but product features must define the merge, overwrite, retry, or
manual resolution behavior before release.

Retry behavior is intentionally conservative in the starter. `pending` and
`failed` entries are eligible for the next batch in created/updated order,
`syncing`, `synced`, and `conflict` entries are excluded from automatic retry,
and every failure increments `retryCount` while storing a safe `failureCode`.
Product sync workers should add endpoint-specific backoff, maximum retry, and
idempotency-key rules before enabling automatic background sync.

Cache retention is feature-owned. The starter database demonstrates cache rows
and indexes, but it does not delete cached domain data automatically. Features
that cache remote data must define freshness, eviction, and logout-clearing
rules based on the sensitivity and offline requirements of that feature.

## Consequences

- Widgets and controllers do not import Drift tables or generated database row
  classes.
- Feature data sources map generated Drift rows into domain entities before
  data reaches repositories or presentation.
- Schema version `1` has a deterministic create path. Future schema changes
  must add explicit upgrade paths before incrementing the version.
- Offline-capable features can add local data sources and enqueue pending writes
  without changing app-wide storage choices.
- Failed queue entries are recoverable until a feature-specific policy marks
  them `synced`, `conflict`, or removes them through an explicit retention rule.
