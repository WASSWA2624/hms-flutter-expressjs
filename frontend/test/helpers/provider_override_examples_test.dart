import 'package:dio/dio.dart';
import 'package:hosspi_hms/core/network/api_result.dart';
import 'package:hosspi_hms/features/example/data/datasources/example_resource_remote_data_source.dart';
import 'package:hosspi_hms/features/example/data/dtos/example_resource_dto.dart';
import 'package:hosspi_hms/features/example/data/repositories/example_resource_repository_impl.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_readiness_snapshot.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  group('provider override examples', () {
    test('builds a ready app container without production services', () {
      final container = createTestContainer(overrides: testReadyAppOverrides());

      expect(container.read(homeRepositoryProvider), isA<HomeRepositoryImpl>());
    });

    test('overrides a repository dependency for controller tests', () async {
      const snapshot = HomeReadinessSnapshot(
        providerGraphReady: true,
        dependenciesOverrideable: true,
        asyncStateReady: true,
      );
      final repository = _FakeHomeRepository(
        const Result<HomeReadinessSnapshot>.success(snapshot),
      );
      final container = createTestContainer(
        overrides: <Object?>[
          homeRepositoryProvider.overrideWithValue(repository),
        ],
      );

      final result = await container.read(homeControllerProvider.future);

      result.when(
        success: (value) => expect(value, same(snapshot)),
        failure: (_) => fail('Expected overridden repository success.'),
      );
      expect(repository.callCount, 1);
    });

    test('overrides a data source dependency for repository tests', () async {
      final remoteDataSource = _FakeExampleResourceRemoteDataSource(
        const Result<ExampleResourceDto>.success(
          ExampleResourceDto(id: 'resource-1', title: 'Starter resource'),
        ),
      );
      final container = createTestContainer(
        overrides: <Object?>[
          exampleResourceRemoteDataSourceProvider.overrideWithValue(
            remoteDataSource,
          ),
        ],
      );

      final repository = container.read(exampleResourceRepositoryProvider);
      final result = await repository.fetchById('resource-1');

      result.when(
        success: (resource) {
          expect(resource.id, 'resource-1');
          expect(resource.title, 'Starter resource');
        },
        failure: (_) => fail('Expected overridden data source success.'),
      );
      expect(remoteDataSource.requestedIds, <String>['resource-1']);
    });
  });
}

final class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository(this.result);

  final Result<HomeReadinessSnapshot> result;
  int callCount = 0;

  @override
  Future<Result<HomeReadinessSnapshot>> loadReadiness() async {
    callCount += 1;

    return result;
  }
}

final class _FakeExampleResourceRemoteDataSource
    implements ExampleResourceRemoteDataSource {
  _FakeExampleResourceRemoteDataSource(this.result);

  final ApiResult<ExampleResourceDto> result;
  final List<String> requestedIds = <String>[];

  @override
  Future<ApiResult<ExampleResourceDto>> fetchById(
    String id, {
    CancelToken? cancelToken,
  }) async {
    requestedIds.add(id);

    return result;
  }
}
