import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/storage/database/app_database.dart';
import 'package:hosspi_hms/core/sync/sync_queue_entry.dart';
import 'package:hosspi_hms/core/sync/sync_queue_service.dart';

void main() {
  group('DriftSyncQueueService', () {
    late AppDatabase database;
    late DateTime now;
    late DriftSyncQueueService service;
    late SessionDataPartition partition;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      now = DateTime.utc(2026, 5, 13, 10);
      partition = SessionDataPartition(
        userId: 'user-1',
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      );
      service = DriftSyncQueueService(
        database: database,
        partition: partition,
        clock: () => now,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('enqueues pending writes in durable order', () async {
      await service.enqueue(
        SyncQueueEnqueueRequest(
          localId: ' local-1 ',
          operation: SyncQueueOperation.create,
          payload: SyncQueuePayload.fromMap(<String, Object?>{'id': 'local-1'}),
        ),
      );

      final batch = await service.nextBatch();

      expect(batch, hasLength(1));
      expect(batch.single.localId, 'local-1');
      expect(batch.single.operation, SyncQueueOperation.create);
      expect(batch.single.status, SyncQueueStatus.pending);
      expect(batch.single.payload.value, '{"id":"local-1"}');
      expect(batch.single.partition.key, partition.key);
    });

    test(
      'tracks failures and excludes synced entries from the next batch',
      () async {
        await service.enqueue(
          SyncQueueEnqueueRequest(
            localId: 'local-1',
            operation: SyncQueueOperation.update,
            payload: SyncQueuePayload.fromJsonString('{"id":"local-1"}'),
          ),
        );
        now = DateTime.utc(2026, 5, 13, 11);

        await service.markFailed('local-1', failureCode: 'network.offline');

        var batch = await service.nextBatch();
        expect(batch.single.status, SyncQueueStatus.failed);
        expect(batch.single.retryCount, 1);
        expect(batch.single.failureCode, 'network.offline');

        await service.markSynced('local-1');

        batch = await service.nextBatch();
        expect(batch, isEmpty);
      },
    );

    test('marks conflicts as explicit non-retryable queue states', () async {
      await service.enqueue(
        SyncQueueEnqueueRequest(
          localId: 'local-1',
          operation: SyncQueueOperation.update,
          payload: SyncQueuePayload.fromMap(<String, Object?>{'id': 'local-1'}),
        ),
      );
      now = DateTime.utc(2026, 5, 13, 11);

      await service.markConflict('local-1', failureCode: 'sync.conflict');

      final rows = await database.select(database.syncQueueEntries).get();
      final row = rows.single;

      expect(row.status, SyncQueueStatus.conflict);
      expect(row.failureCode, 'sync.conflict');
      expect(row.lastAttemptAt?.toUtc(), DateTime.utc(2026, 5, 13, 11));
      expect(row.retryCount, 0);
      expect(await service.nextBatch(), isEmpty);
    });

    test('bounds sync batches to the supported retry window', () async {
      for (var index = 0; index < 105; index++) {
        now = DateTime.utc(2026, 5, 13, 10, index);
        await service.enqueue(
          SyncQueueEnqueueRequest(
            localId: 'local-$index',
            operation: SyncQueueOperation.update,
            payload: SyncQueuePayload.fromMap(<String, Object?>{
              'id': 'local-$index',
            }),
          ),
        );
      }

      final batch = await service.nextBatch(limit: 500);

      expect(batch, hasLength(100));
      expect(batch.first.localId, 'local-0');
      expect(batch.last.localId, 'local-99');
    });

    test('never exposes another account or facility queue', () async {
      await service.enqueue(
        SyncQueueEnqueueRequest(
          localId: 'same-local-id',
          operation: SyncQueueOperation.update,
          payload: SyncQueuePayload.fromMap(<String, Object?>{'owner': 'one'}),
        ),
      );
      final otherService = DriftSyncQueueService(
        database: database,
        partition: SessionDataPartition(
          userId: 'user-2',
          tenantId: 'tenant-1',
          facilityId: 'facility-2',
        ),
        clock: () => now,
      );
      await otherService.enqueue(
        SyncQueueEnqueueRequest(
          localId: 'same-local-id',
          operation: SyncQueueOperation.update,
          payload: SyncQueuePayload.fromMap(<String, Object?>{'owner': 'two'}),
        ),
      );

      expect(
        (await service.nextBatch()).single.payload.value,
        '{"owner":"one"}',
      );
      expect(
        (await otherService.nextBatch()).single.payload.value,
        '{"owner":"two"}',
      );
    });
  });
}
