import 'package:dio/dio.dart';
import 'package:hosspi_hms/core/network/api_result.dart';
import 'package:hosspi_hms/core/network/network_failure_mapper.dart';

typedef ApiResponseDecoder<T> = T Function(Object? data);

abstract interface class ApiClient {
  factory ApiClient({required Dio dio, NetworkFailureMapper failureMapper}) =
      DioApiClient;

  Uri get baseUri;

  Future<ApiResult<T>> get<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  });

  Future<ApiResult<T>> post<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  });

  Future<ApiResult<T>> put<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  });

  Future<ApiResult<T>> patch<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  });

  Future<ApiResult<T>> delete<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  });

  Future<ApiResult<T>> request<T>({
    required String method,
    required Uri endpoint,
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  });
}

final class DioApiClient implements ApiClient {
  const DioApiClient({
    required Dio dio,
    NetworkFailureMapper failureMapper = const NetworkFailureMapper(),
  }) : _dio = dio,
       _failureMapper = failureMapper;

  final Dio _dio;
  final NetworkFailureMapper _failureMapper;

  Dio get dio => _dio;

  @override
  Uri get baseUri => Uri.parse(_dio.options.baseUrl);

  @override
  Future<ApiResult<T>> get<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request<T>(
      method: 'GET',
      endpoint: endpoint,
      decoder: decoder,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
    );
  }

  @override
  Future<ApiResult<T>> post<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request<T>(
      method: 'POST',
      endpoint: endpoint,
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
    );
  }

  @override
  Future<ApiResult<T>> put<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request<T>(
      method: 'PUT',
      endpoint: endpoint,
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
    );
  }

  @override
  Future<ApiResult<T>> patch<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request<T>(
      method: 'PATCH',
      endpoint: endpoint,
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
    );
  }

  @override
  Future<ApiResult<T>> delete<T>(
    Uri endpoint, {
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request<T>(
      method: 'DELETE',
      endpoint: endpoint,
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
    );
  }

  @override
  Future<ApiResult<T>> request<T>({
    required String method,
    required Uri endpoint,
    required ApiResponseDecoder<T> decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        _pathFor(endpoint),
        data: data,
        queryParameters: _queryParametersFor(endpoint, queryParameters),
        cancelToken: cancelToken,
        options: (options ?? Options()).copyWith(method: method),
      );

      return Result<T>.success(decoder(response.data));
    } catch (error, stackTrace) {
      return Result<T>.failure(_failureMapper.map(error, stackTrace));
    }
  }

  String _pathFor(Uri endpoint) {
    if (endpoint.path.isEmpty) {
      return '/';
    }

    return endpoint.path;
  }

  Map<String, Object?>? _queryParametersFor(
    Uri endpoint,
    Map<String, Object?>? queryParameters,
  ) {
    final mergedQueryParameters = <String, Object?>{
      if (endpoint.hasQuery) ...endpoint.queryParameters,
      ...?queryParameters,
    };

    if (mergedQueryParameters.isEmpty) {
      return null;
    }

    return mergedQueryParameters;
  }
}
