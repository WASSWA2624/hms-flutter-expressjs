import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/storage/database/app_database.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/example/data/mappers/example_resource_cache_mapper.dart';
import 'package:hosspi_hms/features/example/domain/entities/example_resource.dart';

typedef ExampleResourceClock = DateTime Function();

final exampleResourceLocalDataSourceProvider =
    Provider<ExampleResourceLocalDataSource>((ref) {
      return DriftExampleResourceLocalDataSource(
        database: ref.watch(appDatabaseProvider),
      );
    });

abstract interface class ExampleResourceLocalDataSource {
  Future<ExampleResource?> fetchById(String id);

  Stream<ExampleResource?> watchById(String id);

  Future<void> upsert(ExampleResource resource);

  Future<void> deleteById(String id);
}

final class DriftExampleResourceLocalDataSource
    implements ExampleResourceLocalDataSource {
  const DriftExampleResourceLocalDataSource({
    required AppDatabase database,
    ExampleResourceClock clock = DateTime.now,
  }) : _database = database,
       _clock = clock;

  final AppDatabase _database;
  final ExampleResourceClock _clock;

  @override
  Future<ExampleResource?> fetchById(String id) async {
    final row = await _entryById(id).getSingleOrNull();

    return row?.toEntity();
  }

  @override
  Stream<ExampleResource?> watchById(String id) {
    return _entryById(id).watchSingleOrNull().map((row) => row?.toEntity());
  }

  @override
  Future<void> upsert(ExampleResource resource) async {
    final normalizedResource = ExampleResource(
      id: resource.id.trim(),
      title: resource.title.trim(),
    );
    if (normalizedResource.id.isEmpty || normalizedResource.title.isEmpty) {
      throw ArgumentError.value(resource, 'resource', 'Resource is invalid.');
    }

    final now = _clock().toUtc();
    final existing = await _entryById(normalizedResource.id).getSingleOrNull();

    await _database
        .into(_database.exampleResourceCacheEntries)
        .insertOnConflictUpdate(
          normalizedResource.toCacheCompanion(
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> deleteById(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    await (_database.delete(
      _database.exampleResourceCacheEntries,
    )..where((table) => table.id.equals(normalizedId))).go();
  }

  Selectable<ExampleResourceCacheEntry> _entryById(String id) {
    final normalizedId = id.trim();

    return _database.select(_database.exampleResourceCacheEntries)
      ..where((table) => table.id.equals(normalizedId));
  }
}
