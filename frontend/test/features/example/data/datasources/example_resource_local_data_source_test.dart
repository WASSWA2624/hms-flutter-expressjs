import 'package:drift/native.dart';
import 'package:hosspi_hms/core/storage/database/app_database.dart';
import 'package:hosspi_hms/features/example/data/datasources/example_resource_local_data_source.dart';
import 'package:hosspi_hms/features/example/domain/entities/example_resource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriftExampleResourceLocalDataSource', () {
    late AppDatabase database;
    late DateTime now;
    late DriftExampleResourceLocalDataSource dataSource;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      now = DateTime.utc(2026, 5, 13);
      dataSource = DriftExampleResourceLocalDataSource(
        database: database,
        clock: () => now,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('maps cached rows into domain entities', () async {
      await dataSource.upsert(
        const ExampleResource(id: ' example-1 ', title: ' Cached resource '),
      );

      final resource = await dataSource.fetchById('example-1');

      expect(resource?.id, 'example-1');
      expect(resource?.title, 'Cached resource');
    });

    test('removes cached rows by id', () async {
      await dataSource.upsert(
        const ExampleResource(id: 'example-1', title: 'Cached resource'),
      );

      await dataSource.deleteById(' example-1 ');

      expect(await dataSource.fetchById('example-1'), isNull);
    });
  });
}
