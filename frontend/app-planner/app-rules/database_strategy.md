# Database Strategy

## Scope
Defines how the template uses local structured storage through Drift.

## Mandatory rules
- Use Drift for local structured records, offline cache, drafts, and sync queue tables.
- Keep database access inside local data sources.
- Do not query Drift from widgets or controllers directly.
- Use explicit migrations for schema changes.
- Test migrations when schema versions change.
- Add indexes for frequently queried fields.
- Use pagination or streams for large result sets.
- Avoid destructive migrations unless the product explicitly requires them and the behavior is documented.

## Folder standard
```txt
core/storage/database/
├── app_database.dart
├── migrations/
├── tables/
└── type_converters/
```

## Migration rules
- Increment schema versions intentionally.
- Keep migration code deterministic.
- Document schema changes in the related feature or ADR.
- Back up important data before destructive changes where the product supports it.

## Acceptance checklist
- Local data can be read offline through repositories.
- Database code is not imported by presentation widgets.
- Migration tests exist for non-trivial schema changes.

## Related rules
- [`storage_strategy.md`](./storage_strategy.md)
- [`offline_sync.md`](./offline_sync.md)
- [`data_modeling.md`](./data_modeling.md)
- [`testing.md`](./testing.md)
