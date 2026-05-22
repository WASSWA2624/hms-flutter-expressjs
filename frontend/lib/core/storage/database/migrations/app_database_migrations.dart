part of '../app_database.dart';

abstract final class AppDatabaseMigrations {
  static const int currentSchemaVersion = 2;

  static MigrationStrategy forDatabase(AppDatabase database) {
    return MigrationStrategy(
      onCreate: (Migrator migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (Migrator migrator, int from, int to) async {
        if (from == to) {
          return;
        }

        if (from < 2) {
          await database.customStatement(
            'DROP INDEX IF EXISTS example_resource_cache_entries_updated_at_idx',
          );
          await database.customStatement(
            'DROP TABLE IF EXISTS example_resource_cache_entries',
          );
        }

        if (to > currentSchemaVersion) {
          throw UnsupportedError(
            'Add an explicit Drift migration from schema $from to $to.',
          );
        }
      },
      beforeOpen: (OpeningDetails details) async {
        await database.customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
