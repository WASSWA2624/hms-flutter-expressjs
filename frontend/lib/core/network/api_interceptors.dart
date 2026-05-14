import 'package:dio/dio.dart';
import 'package:hosspi_hms/core/logging/app_logger.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';

typedef AuthTokenReader = Future<String?> Function();
typedef UnauthorizedResponseHandler = Future<void> Function();
typedef DiagnosticsLogSink = void Function(String message);

const authorizationHeaderName = 'Authorization';
const csrfHeaderName = 'x-csrf-token';

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

final class CsrfInterceptor extends QueuedInterceptor {
  CsrfInterceptor({required Dio tokenDio}) : _tokenDio = tokenDio;

  final Dio _tokenDio;
  String? _token;
  Future<String>? _pendingTokenRequest;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (_requiresCsrf(options)) {
        options.headers[csrfHeaderName] = await _readToken();
      }
    } catch (_) {
      // Let the protected request fail through the normal API error mapper.
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 403 && _isCsrfFailure(err.response?.data)) {
      _token = null;
    }

    handler.next(err);
  }

  Future<String> _readToken() async {
    final cachedToken = _token;
    if (cachedToken != null && cachedToken.isNotEmpty) {
      return cachedToken;
    }

    final pendingRequest = _pendingTokenRequest;
    if (pendingRequest != null) {
      return pendingRequest;
    }

    final request = _fetchToken();
    _pendingTokenRequest = request;
    try {
      return await request;
    } finally {
      _pendingTokenRequest = null;
    }
  }

  Future<String> _fetchToken() async {
    final response = await _tokenDio.get<Object?>(
      ApiEndpoints.auth(AuthEndpoint.csrfToken).path,
    );
    final token = _extractToken(response.data);
    _token = token;
    return token;
  }

  static bool _requiresCsrf(RequestOptions options) {
    final method = options.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD' || method == 'OPTIONS') {
      return false;
    }

    return !_isCsrfExempt(options);
  }

  static bool _isCsrfExempt(RequestOptions options) {
    final method = options.method.toUpperCase();
    final path = options.uri.path;
    return method == 'POST' &&
        <String>{
          '/api/v1/auth/identify',
          '/api/v1/auth/login',
          '/api/v1/auth/register',
          '/api/v1/auth/logout',
          '/api/v1/auth/change-password',
          '/api/v1/auth/verify-email',
          '/api/v1/auth/verify-phone',
          '/api/v1/auth/resend-verification',
          '/api/v1/auth/forgot-password',
          '/api/v1/auth/reset-password',
        }.contains(path);
  }

  static String _extractToken(Object? payload) {
    if (payload case {'data': {'token': final String token}}) {
      return token;
    }
    if (payload case {'token': final String token}) {
      return token;
    }

    throw const FormatException('Invalid CSRF token response.');
  }

  static bool _isCsrfFailure(Object? payload) {
    if (payload case {'code': final String code}) {
      final normalizedCode = code.toUpperCase();
      return normalizedCode == 'MISSING' || normalizedCode == 'INVALID';
    }

    return false;
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
