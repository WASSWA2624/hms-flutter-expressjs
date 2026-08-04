import 'package:dio/dio.dart';
import 'package:hosspi_hms/core/logging/app_logger.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';

typedef AuthTokenReader = Future<String?> Function();
typedef TokenRefreshHandler = Future<bool> Function();
typedef UnauthorizedResponseHandler = Future<void> Function();
typedef DiagnosticsLogSink = void Function(String message);

const authorizationHeaderName = 'Authorization';
const csrfHeaderName = 'x-csrf-token';
const localeHeaderName = 'x-locale';
const authRetryExtraKey = 'auth_retry';
const csrfRetryExtraKey = 'csrf_retry';

typedef RequestLocaleReader = String? Function();

final class LocaleInterceptor extends Interceptor {
  LocaleInterceptor({required RequestLocaleReader readLocale})
    : _readLocale = readLocale;

  final RequestLocaleReader _readLocale;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? locale = _readLocale()?.trim();
    if (locale != null && locale.isNotEmpty) {
      options.headers[localeHeaderName] = locale;
    }

    handler.next(options);
  }
}

final class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AuthTokenReader readAccessToken,
    TokenRefreshHandler? onTokenRefresh,
    UnauthorizedResponseHandler? onUnauthorizedResponse,
    Dio? retryClient,
  }) : _readAccessToken = readAccessToken,
       _onTokenRefresh = onTokenRefresh,
       _onUnauthorizedResponse = onUnauthorizedResponse,
       _retryClient = retryClient;

  final AuthTokenReader _readAccessToken;
  final TokenRefreshHandler? _onTokenRefresh;
  final UnauthorizedResponseHandler? _onUnauthorizedResponse;
  final Dio? _retryClient;

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
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    if (_shouldSkipRefresh(err.requestOptions)) {
      try {
        await _onUnauthorizedResponse?.call();
      } catch (_) {
        // Session recovery failures are mapped by the repository boundary.
      }
      handler.next(err);
      return;
    }

    try {
      final bool refreshed = await _onTokenRefresh?.call() ?? false;
      if (!refreshed) {
        await _onUnauthorizedResponse?.call();
        handler.next(err);
        return;
      }

      final String? token = (await _readAccessToken())?.trim();
      final RequestOptions requestOptions = err.requestOptions;
      requestOptions.extra[authRetryExtraKey] = true;
      if (token != null && token.isNotEmpty) {
        requestOptions.headers[authorizationHeaderName] = 'Bearer $token';
      }

      final Dio client = _retryClient ?? Dio();
      final Response<dynamic> response = await client.fetch<dynamic>(
        requestOptions,
      );
      handler.resolve(response);
    } catch (_) {
      try {
        await _onUnauthorizedResponse?.call();
      } catch (_) {
        // Session recovery failures are mapped by the repository boundary.
      }
      handler.next(err);
    }
  }

  static bool _shouldSkipRefresh(RequestOptions options) {
    if (options.extra[authRetryExtraKey] == true) {
      return true;
    }

    return options.uri.path.endsWith('/auth/refresh');
  }
}

final class CsrfInterceptor extends Interceptor {
  CsrfInterceptor({required Dio tokenDio, Dio? retryClient})
    : _tokenDio = tokenDio,
      _retryClient = retryClient;

  final Dio _tokenDio;
  final Dio? _retryClient;
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
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 403 ||
        !_isCsrfFailure(err.response?.data)) {
      handler.next(err);
      return;
    }

    // Drop the cached token so the retry (and later calls) fetch a fresh
    // CSRF token bound to the current session cookie. Common after backend
    // restarts wipe the in-memory session store.
    _token = null;

    if (err.requestOptions.extra[csrfRetryExtraKey] == true) {
      handler.next(err);
      return;
    }

    try {
      final String freshToken = await _readToken();
      final RequestOptions requestOptions = err.requestOptions;
      requestOptions.extra[csrfRetryExtraKey] = true;
      requestOptions.headers[csrfHeaderName] = freshToken;

      final Dio client = _retryClient ?? Dio();
      final Response<dynamic> response = await client.fetch<dynamic>(
        requestOptions,
      );
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
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
      final String normalizedCode = code.toUpperCase();
      if (normalizedCode == 'MISSING' ||
          normalizedCode == 'INVALID' ||
          normalizedCode == 'CSRF_MISSING' ||
          normalizedCode == 'CSRF_INVALID') {
        return true;
      }
    }

    if (payload case {'type': final String type}) {
      if (type.toLowerCase().contains('csrf')) {
        return true;
      }
    }

    if (payload case {'messageKey': final String messageKey}) {
      return messageKey.toLowerCase().contains('csrf');
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
