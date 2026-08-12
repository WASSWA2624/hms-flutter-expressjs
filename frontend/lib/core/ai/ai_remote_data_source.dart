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
    );
  }
}
