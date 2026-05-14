import 'package:hosspi_hms/core/storage/database/app_database.dart';
import 'package:hosspi_hms/features/example/domain/entities/example_resource.dart';

extension ExampleResourceCacheEntryMapper on ExampleResourceCacheEntry {
  ExampleResource toEntity() {
    return ExampleResource(id: id, title: title);
  }
}

extension ExampleResourceCacheWriteMapper on ExampleResource {
  ExampleResourceCacheEntriesCompanion toCacheCompanion({
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return ExampleResourceCacheEntriesCompanion.insert(
      id: id,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
