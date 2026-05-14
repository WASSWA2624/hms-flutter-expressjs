part of '../app_database.dart';

@DataClassName('ExampleResourceCacheEntry')
@TableIndex(
  name: 'example_resource_cache_entries_updated_at_idx',
  columns: {#updatedAt},
)
class ExampleResourceCacheEntries extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
