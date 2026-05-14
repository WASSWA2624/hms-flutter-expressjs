import 'package:dio/dio.dart';
import 'package:hosspi_hms/core/network/api_result.dart';
import 'package:hosspi_hms/features/example/data/datasources/example_resource_remote_data_source.dart';
import 'package:hosspi_hms/features/example/data/dtos/example_resource_dto.dart';
import 'package:hosspi_hms/features/example/data/repositories/example_resource_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExampleResourceRepositoryImpl', () {
    test('maps DTOs into domain entities', () async {
      final remoteDataSource = _FakeRemoteDataSource(
        const ApiResult<ExampleResourceDto>.success(
          ExampleResourceDto(id: 'example-1', title: 'Example resource'),
        ),
      );
      final repository = ExampleResourceRepositoryImpl(
        remoteDataSource: remoteDataSource,
      );

      final result = await repository.fetchById(' example-1 ');

      result.when(
        success: (entity) {
          expect(entity.id, 'example-1');
          expect(entity.title, 'Example resource');
        },
        failure: (_) => fail('Expected a successful repository result.'),
      );
      expect(remoteDataSource.requestedId, 'example-1');
    });

    test(
      'returns typed validation failures for invalid repository input',
      () async {
        final remoteDataSource = _FakeRemoteDataSource(
          const ResultFailure<ExampleResourceDto>(AppFailure.unexpected()),
        );
        final repository = ExampleResourceRepositoryImpl(
          remoteDataSource: remoteDataSource,
        );

        final result = await repository.fetchById('   ');

        result.when(
          success: (_) => fail('Expected a validation failure.'),
          failure: (failure) {
            expect(failure.category, AppFailureCategory.validation);
            expect(failure.validationFields, <String>{'id'});
          },
        );
        expect(remoteDataSource.requestedId, isNull);
      },
    );

    test('maps unexpected data source throws into typed failures', () async {
      final repository = ExampleResourceRepositoryImpl(
        remoteDataSource: _ThrowingRemoteDataSource(),
      );

      final result = await repository.fetchById('example-1');

      result.when(
        success: (_) => fail('Expected a failed repository result.'),
        failure: (failure) =>
            expect(failure.category, AppFailureCategory.unexpectedResponse),
      );
    });
  });
}

final class _FakeRemoteDataSource implements ExampleResourceRemoteDataSource {
  _FakeRemoteDataSource(this.result);

  final ApiResult<ExampleResourceDto> result;
  String? requestedId;

  @override
  Future<ApiResult<ExampleResourceDto>> fetchById(
    String id, {
    CancelToken? cancelToken,
  }) async {
    requestedId = id;
    return result;
  }
}

final class _ThrowingRemoteDataSource
    implements ExampleResourceRemoteDataSource {
  @override
  Future<ApiResult<ExampleResourceDto>> fetchById(
    String id, {
    CancelToken? cancelToken,
  }) async {
    throw const FormatException('Invalid payload.');
  }
}
