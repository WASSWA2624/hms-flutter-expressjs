part of '../app_database.dart';

@DataClassName('SyncQueueEntryRow')
@TableIndex(
  name: 'sync_queue_entries_status_updated_at_idx',
  columns: {#status, #updatedAt},
)
@TableIndex(name: 'sync_queue_entries_operation_idx', columns: {#operation})
class SyncQueueEntries extends Table {
  TextColumn get localId => text()();

  TextColumn get operation => textEnum<SyncQueueOperation>()();

  TextColumn get payloadJson => text()();

  TextColumn get status => textEnum<SyncQueueStatus>().withDefault(
    Constant(SyncQueueStatus.pending.name),
  )();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  TextColumn get failureCode => text().nullable()();

  @override
  Set<Column> get primaryKey => {localId};
}
