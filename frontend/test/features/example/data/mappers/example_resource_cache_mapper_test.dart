import 'package:flutter_template/core/storage/database/app_database.dart';
import 'package:flutter_template/features/example/data/mappers/example_resource_cache_mapper.dart';
import 'package:flutter_template/features/example/domain/entities/example_resource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExampleResourceCacheEntryMapper', () {
    final createdAt = DateTime.utc(2026, 5, 13, 8);
    final updatedAt = DateTime.utc(2026, 5, 13, 9);

    test('maps cache rows into domain entities', () {
      final entry = ExampleResourceCacheEntry(
        id: 'resource-1',
        title: 'Cached resource',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final entity = entry.toEntity();

      expect(entity.id, 'resource-1');
      expect(entity.title, 'Cached resource');
    });

    test('maps domain entities into cache companions', () {
      final companion = const ExampleResource(
        id: 'resource-1',
        title: 'Cached resource',
      ).toCacheCompanion(createdAt: createdAt, updatedAt: updatedAt);

      expect(companion.id.value, 'resource-1');
      expect(companion.title.value, 'Cached resource');
      expect(companion.createdAt.value, createdAt);
      expect(companion.updatedAt.value, updatedAt);
    });
  });
}
