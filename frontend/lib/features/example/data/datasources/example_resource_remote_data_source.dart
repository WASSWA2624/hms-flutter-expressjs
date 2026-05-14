import 'package:dio/dio.dart';
import 'package:flutter_template/core/network/api_client.dart';
import 'package:flutter_template/core/network/api_endpoints.dart';
import 'package:flutter_template/core/network/api_result.dart';
import 'package:flutter_template/features/example/data/dtos/example_resource_dto.dart';

abstract interface class ExampleResourceRemoteDataSource {
  Future<ApiResult<ExampleResourceDto>> fetchById(
    String id, {
    CancelToken? cancelToken,
  });
}

final class DioExampleResourceRemoteDataSource
    implements ExampleResourceRemoteDataSource {
  const DioExampleResourceRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<ApiResult<ExampleResourceDto>> fetchById(
    String id, {
    CancelToken? cancelToken,
  }) {
    return _apiClient.get<ExampleResourceDto>(
      ApiEndpoints.exampleResource(id),
      decoder: ExampleResourceDto.fromResponseData,
      cancelToken: cancelToken,
    );
  }
}
