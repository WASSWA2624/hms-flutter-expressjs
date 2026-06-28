import 'package:dio/dio.dart';

const String connectionRetryCountExtraKey = 'connection_retry_count';

/// Retries transient connection failures that can occur during shell startup.
final class ConnectionRetryInterceptor extends Interceptor {
  ConnectionRetryInterceptor({
    required Dio retryClient,
    this.maxRetries = 2,
  }) : _retryClient = retryClient;

  final Dio _retryClient;
  final int maxRetries;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final int retries =
        (err.requestOptions.extra[connectionRetryCountExtraKey] as int?) ?? 0;
    if (retries >= maxRetries) {
      handler.next(err);
      return;
    }

    err.requestOptions.extra[connectionRetryCountExtraKey] = retries + 1;
    await Future<void>.delayed(Duration(milliseconds: 100 * (retries + 1)));

    try {
      final Response<dynamic> response = await _retryClient.fetch<dynamic>(
        err.requestOptions,
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (error) {
      handler.next(err);
    }
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout;
  }
}
