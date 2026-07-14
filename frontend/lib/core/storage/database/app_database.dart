import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:hosspi_hms/core/sync/sync_queue_entry.dart';

part 'app_database.g.dart';
part 'migrations/app_database_migrations.dart';
part 'tables/example_resource_cache_entries.dart';
part 'tables/sync_queue_entries.dart';

@DriftDatabase(tables: [SyncQueueEntries, ExampleResourceCacheEntries])
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'app_database'));

  @override
  int get schemaVersion => AppDatabaseMigrations.currentSchemaVersion;

  @override
  MigrationStrategy get migration {
    return AppDatabaseMigrations.forDatabase(this);
  }

  /// Clears locally persisted user/workspace caches on logout or context switch.
  Future<void> clearUserScopedCaches() async {
    await transaction(() async {
      await delete(syncQueueEntries).go();
      await delete(exampleResourceCacheEntries).go();
    });
  }
}
