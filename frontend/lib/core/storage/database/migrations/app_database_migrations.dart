part of '../app_database.dart';

abstract final class AppDatabaseMigrations {
  static const int currentSchemaVersion = 1;

  static MigrationStrategy forDatabase(AppDatabase database) {
    return MigrationStrategy(
      onCreate: (Migrator migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (Migrator migrator, int from, int to) async {
        if (from == to) {
          return;
        }

        throw UnsupportedError(
          'Add an explicit Drift migration from schema $from to $to.',
        );
      },
      beforeOpen: (OpeningDetails details) async {
        await database.customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
