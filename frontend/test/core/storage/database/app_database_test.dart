import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/storage/database/app_database.dart';
import 'package:hosspi_hms/core/sync/sync_queue_entry.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('creates production sync queue storage explicitly', () async {
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
        await database.select(database.syncQueueEntries).get(),
        hasLength(1),
      );
      expect(
        database.allSchemaEntities.map((entity) => entity.entityName),
        isNot(contains('example_resource_cache_entries')),
      );
    });
  });
}
