import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/storage/database/app_database.dart';
import 'package:flutter_template/core/storage/storage_providers.dart';
import 'package:flutter_template/core/sync/sync_queue_entry.dart';

typedef DateTimeReader = DateTime Function();

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return DriftSyncQueueService(database: ref.watch(appDatabaseProvider));
});

abstract interface class SyncQueueService {
  Future<void> enqueue(SyncQueueEnqueueRequest request);

  Future<List<SyncQueueEntry>> nextBatch({int limit = 50});

  Future<void> markSyncing(String localId);

  Future<void> markSynced(String localId);

  Future<void> markFailed(String localId, {required String failureCode});

  Future<void> markConflict(String localId, {required String failureCode});
}

final class DriftSyncQueueService implements SyncQueueService {
  const DriftSyncQueueService({
    required AppDatabase database,
    DateTimeReader clock = DateTime.now,
  }) : _database = database,
       _clock = clock;

  final AppDatabase _database;
  final DateTimeReader _clock;

  @override
  Future<void> enqueue(SyncQueueEnqueueRequest request) async {
    final DateTime now = _clock().toUtc();

    await _database
        .into(_database.syncQueueEntries)
        .insertOnConflictUpdate(
          SyncQueueEntriesCompanion.insert(
            localId: request.localId,
            operation: request.operation,
            payloadJson: request.payload.value,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<List<SyncQueueEntry>> nextBatch({int limit = 50}) async {
    final boundedLimit = limit.clamp(1, 100);
    final rows =
        await (_database.select(_database.syncQueueEntries)
              ..where(
                (table) => table.status.isInValues(const [
                  SyncQueueStatus.pending,
                  SyncQueueStatus.failed,
                ]),
              )
              ..orderBy([
                (table) => OrderingTerm.asc(table.createdAt),
                (table) => OrderingTerm.asc(table.updatedAt),
              ])
              ..limit(boundedLimit))
            .get();

    return rows.map(_syncQueueEntryFromRow).toList(growable: false);
  }

  @override
  Future<void> markSyncing(String localId) {
    return _mark(
      localId,
      status: SyncQueueStatus.syncing,
      lastAttemptAt: _clock().toUtc(),
    );
  }

  @override
  Future<void> markSynced(String localId) {
    return _mark(localId, status: SyncQueueStatus.synced);
  }

  @override
  Future<void> markFailed(String localId, {required String failureCode}) async {
    final row = await _rowByLocalId(localId);
    if (row == null) {
      return;
    }

    await _mark(
      localId,
      status: SyncQueueStatus.failed,
      failureCode: failureCode,
      lastAttemptAt: _clock().toUtc(),
      retryCount: row.retryCount + 1,
    );
  }

  @override
  Future<void> markConflict(String localId, {required String failureCode}) {
    return _mark(
      localId,
      status: SyncQueueStatus.conflict,
      failureCode: failureCode,
      lastAttemptAt: _clock().toUtc(),
    );
  }

  Future<void> _mark(
    String localId, {
    required SyncQueueStatus status,
    String? failureCode,
    DateTime? lastAttemptAt,
    int? retryCount,
  }) async {
    final normalizedLocalId = localId.trim();
    if (normalizedLocalId.isEmpty) {
      return;
    }

    await (_database.update(
      _database.syncQueueEntries,
    )..where((table) => table.localId.equals(normalizedLocalId))).write(
      SyncQueueEntriesCompanion(
        status: Value(status),
        updatedAt: Value(_clock().toUtc()),
        lastAttemptAt: Value(lastAttemptAt),
        failureCode: Value(failureCode),
        retryCount: retryCount == null
            ? const Value.absent()
            : Value(retryCount),
      ),
    );
  }

  Future<SyncQueueEntryRow?> _rowByLocalId(String localId) {
    final normalizedLocalId = localId.trim();
    if (normalizedLocalId.isEmpty) {
      return Future<SyncQueueEntryRow?>.value();
    }

    return (_database.select(_database.syncQueueEntries)
          ..where((table) => table.localId.equals(normalizedLocalId)))
        .getSingleOrNull();
  }
}

SyncQueueEntry _syncQueueEntryFromRow(SyncQueueEntryRow row) {
  return SyncQueueEntry(
    localId: row.localId,
    operation: row.operation,
    payload: SyncQueuePayload.fromJsonString(row.payloadJson),
    status: row.status,
    retryCount: row.retryCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    lastAttemptAt: row.lastAttemptAt,
    failureCode: row.failureCode,
  );
}
