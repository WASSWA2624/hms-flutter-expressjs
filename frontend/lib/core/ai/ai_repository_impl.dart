import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/ai/ai_models.dart';
import 'package:hosspi_hms/core/ai/ai_remote_data_source.dart';
import 'package:hosspi_hms/core/ai/ai_repository.dart';
import 'package:hosspi_hms/core/network/api_result.dart';
import 'package:hosspi_hms/core/network/network_failure_mapper.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';

final aiRemoteDataSourceProvider = Provider<AiRemoteDataSource>((ref) {
  return DioAiRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepositoryImpl(
    remoteDataSource: ref.watch(aiRemoteDataSourceProvider),
    failureMapper: ref.watch(networkFailureMapperProvider),
  );
});

final class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl({
    required AiRemoteDataSource remoteDataSource,
    NetworkFailureMapper failureMapper = const NetworkFailureMapper(),
    Duration statusCacheTtl = const Duration(seconds: 30),
  }) : _remoteDataSource = remoteDataSource,
       _failureMapper = failureMapper,
       _statusCacheTtl = statusCacheTtl;

  final AiRemoteDataSource _remoteDataSource;
  final NetworkFailureMapper _failureMapper;
  final Duration _statusCacheTtl;

  AiStatus? _cachedStatus;
  DateTime? _cachedStatusAt;

  @override
  Future<Result<AiStatus>> status({CancelToken? cancelToken}) async {
    final DateTime now = DateTime.now();
    final AiStatus? cached = _cachedStatus;
    final DateTime? cachedAt = _cachedStatusAt;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _statusCacheTtl) {
      return Result<AiStatus>.success(cached);
    }

    try {
      final ApiResult<AiStatus> result = await _remoteDataSource.status(
        cancelToken: cancelToken,
      );
      return result.when(
        success: (AiStatus status) {
          _cachedStatus = status;
          _cachedStatusAt = DateTime.now();
          return Result<AiStatus>.success(status);
        },
        failure: (AppFailure failure) => Result<AiStatus>.failure(failure),
      );
    } catch (error, stackTrace) {
      return Result<AiStatus>.failure(_failureMapper.map(error, stackTrace));
    }
  }

  @override
  Future<Result<AiTaskResult>> runTask(
    String taskKey,
    Map<String, Object?> body, {
    CancelToken? cancelToken,
  }) async {
    final String normalizedKey = taskKey.trim();
    if (normalizedKey.isEmpty) {
      return Result<AiTaskResult>.failure(
        AppFailure.validation(
          code: 'ai.task_key_required',
          validationFields: const <String>{'task_key'},
        ),
      );
    }

    try {
      final ApiResult<AiTaskResult> result = await _remoteDataSource.runTask(
        normalizedKey,
        body,
        cancelToken: cancelToken,
      );
      return result.when(
        success: Result<AiTaskResult>.success,
        failure: Result<AiTaskResult>.failure,
      );
    } catch (error, stackTrace) {
      return Result<AiTaskResult>.failure(
        _failureMapper.map(error, stackTrace),
      );
    }
  }
}
