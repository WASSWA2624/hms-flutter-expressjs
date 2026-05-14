import 'package:drift/native.dart';
import 'package:hosspi_hms/core/storage/database/app_database.dart';
import 'package:hosspi_hms/core/sync/sync_queue_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('creates initial schema tables explicitly', () async {
      await database
          .into(database.exampleResourceCacheEntries)
          .insert(
            ExampleResourceCacheEntriesCompanion.insert(
              id: 'example-1',
              title: 'Example resource',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.syncQueueEntries)
          .insert(
            SyncQueueEntriesCompanion.insert(
              localId: 'local-1',
              operation: SyncQueueOperation.create,
              payloadJson: '{"id":"local-1"}',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );

      expect(
        await database.select(database.exampleResourceCacheEntries).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.syncQueueEntries).get(),
        hasLength(1),
      );
    });
  });
}
