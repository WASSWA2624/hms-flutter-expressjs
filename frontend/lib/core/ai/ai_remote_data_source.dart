import 'package:dio/dio.dart';
import 'package:hosspi_hms/core/ai/ai_models.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/api_response.dart';
import 'package:hosspi_hms/core/network/api_result.dart';

abstract interface class AiRemoteDataSource {
  Future<ApiResult<AiStatus>> status({CancelToken? cancelToken});

  Future<ApiResult<AiTaskResult>> runTask(
    String taskKey,
    Map<String, Object?> body, {
    CancelToken? cancelToken,
  });
}

final class DioAiRemoteDataSource implements AiRemoteDataSource {
  const DioAiRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<ApiResult<AiStatus>> status({CancelToken? cancelToken}) {
    return _apiClient.get<AiStatus>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.ai.path, 'status']),
      decoder: (Object? data) => ApiResponseEnvelope.decodeData<AiStatus>(
        data,
        decoder: (Object? payload) {
          if (payload is! Map) {
            throw const FormatException('Invalid AI status payload.');
          }
          return AiStatus.fromJson(Map<String, Object?>.from(payload));
        },
      ),
      cancelToken: cancelToken,
    );
  }

  @override
  Future<ApiResult<AiTaskResult>> runTask(
    String taskKey,
    Map<String, Object?> body, {
    CancelToken? cancelToken,
  }) {
    final bool longRunning = taskKey.trim() == 'clinical_note_format';
    // Local small-model rewrites commonly take 30–60s; the app-wide API
    // timeout is 30s in development, so this request must override it.
    final Options? longRunningOptions = longRunning
        ? Options(
            sendTimeout: const Duration(seconds: 120),
            receiveTimeout: const Duration(seconds: 120),
            // Ensure Dio treats this as a distinct long-poll style call.
            extra: const <String, Object?>{'ai_long_running': true},
          )
        : null;
    return _apiClient.post<AiTaskResult>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.ai.path,
        'tasks',
        taskKey,
      ]),
      data: body,
      decoder: (Object? data) => ApiResponseEnvelope.decodeData<AiTaskResult>(
        data,
        decoder: (Object? payload) {
          if (payload is! Map) {
            throw const FormatException('Invalid AI task payload.');
          }
          return AiTaskResult.fromJson(Map<String, Object?>.from(payload));
        },
      ),
      cancelToken: cancelToken,
      options: longRunningOptions,
    );
  }
}
