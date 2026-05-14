import 'package:dio/dio.dart';
import 'package:flutter_template/core/logging/app_logger.dart';

typedef AuthTokenReader = Future<String?> Function();
typedef UnauthorizedResponseHandler = Future<void> Function();
typedef DiagnosticsLogSink = void Function(String message);

const authorizationHeaderName = 'Authorization';

final class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required AuthTokenReader readAccessToken,
    UnauthorizedResponseHandler? onUnauthorizedResponse,
  }) : _readAccessToken = readAccessToken,
       _onUnauthorizedResponse = onUnauthorizedResponse;

  final AuthTokenReader _readAccessToken;
  final UnauthorizedResponseHandler? _onUnauthorizedResponse;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = (await _readAccessToken())?.trim();
      if (token != null && token.isNotEmpty) {
        options.headers[authorizationHeaderName] = 'Bearer $token';
      }
    } catch (_) {
      // Token lookup failures are handled by the eventual API response.
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        await _onUnauthorizedResponse?.call();
      } catch (_) {
        // Session recovery failures are mapped by the repository boundary.
      }
    }

    handler.next(err);
  }
}

final class SafeDiagnosticsInterceptor extends Interceptor {
  const SafeDiagnosticsInterceptor({
    required this.enabled,
    DiagnosticsLogSink debugLog = AppLogger.debug,
    DiagnosticsLogSink warningLog = AppLogger.warning,
  }) : _debugLog = debugLog,
       _warningLog = warningLog;

  final bool enabled;
  final DiagnosticsLogSink _debugLog;
  final DiagnosticsLogSink _warningLog;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      _debugLog('HTTP ${options.method} ${_safePath(options.uri)} started.');
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled) {
      _debugLog(
        'HTTP ${response.requestOptions.method} '
        '${_safePath(response.requestOptions.uri)} completed with status '
        '${response.statusCode ?? 0}.',
      );
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      final statusCode = err.response?.statusCode;
      final statusDescription = statusCode == null
          ? 'without response (${err.type.name})'
          : 'with status $statusCode';

      _warningLog(
        'HTTP ${err.requestOptions.method} '
        '${_safePath(err.requestOptions.uri)} failed $statusDescription.',
      );
    }

    handler.next(err);
  }

  static String _safePath(Uri uri) {
    if (uri.path.isEmpty) {
      return '/';
    }

    return uri.path;
  }
}
