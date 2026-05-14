import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_template/core/sync/sync_queue_entry.dart';

part 'app_database.g.dart';
part 'migrations/app_database_migrations.dart';
part 'tables/example_resource_cache_entries.dart';
part 'tables/sync_queue_entries.dart';

@DriftDatabase(tables: [ExampleResourceCacheEntries, SyncQueueEntries])
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'app_database'));

  @override
  int get schemaVersion => AppDatabaseMigrations.currentSchemaVersion;

  @override
  MigrationStrategy get migration {
    return AppDatabaseMigrations.forDatabase(this);
  }
}
