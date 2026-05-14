import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/errors/app_failure.dart';
import 'package:flutter_template/core/errors/result.dart';
import 'package:flutter_template/core/network/network_failure_mapper.dart';
import 'package:flutter_template/core/network/network_providers.dart';
import 'package:flutter_template/features/example/data/datasources/example_resource_remote_data_source.dart';
import 'package:flutter_template/features/example/domain/entities/example_resource.dart';
import 'package:flutter_template/features/example/domain/repositories/example_resource_repository.dart';

final exampleResourceRemoteDataSourceProvider =
    Provider<ExampleResourceRemoteDataSource>((ref) {
      return DioExampleResourceRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      );
    });

final exampleResourceRepositoryProvider = Provider<ExampleResourceRepository>((
  ref,
) {
  return ExampleResourceRepositoryImpl(
    remoteDataSource: ref.watch(exampleResourceRemoteDataSourceProvider),
    failureMapper: ref.watch(networkFailureMapperProvider),
  );
});

final class ExampleResourceRepositoryImpl implements ExampleResourceRepository {
  const ExampleResourceRepositoryImpl({
    required ExampleResourceRemoteDataSource remoteDataSource,
    NetworkFailureMapper failureMapper = const NetworkFailureMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _failureMapper = failureMapper;

  final ExampleResourceRemoteDataSource _remoteDataSource;
  final NetworkFailureMapper _failureMapper;

  @override
  Future<Result<ExampleResource>> fetchById(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      return Result<ExampleResource>.failure(
        AppFailure.validation(
          code: 'example_resource.id_required',
          validationFields: const <String>{'id'},
        ),
      );
    }

    try {
      final result = await _remoteDataSource.fetchById(normalizedId);

      return result.when(
        success: (dto) => Result<ExampleResource>.success(dto.toEntity()),
        failure: (failure) => Result<ExampleResource>.failure(failure),
      );
    } catch (error, stackTrace) {
      return Result<ExampleResource>.failure(
        _failureMapper.map(error, stackTrace),
      );
    }
  }
}
