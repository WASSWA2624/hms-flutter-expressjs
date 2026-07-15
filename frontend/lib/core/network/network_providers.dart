import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/locale/app_locale_controller.dart';
import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_interceptors.dart';
import 'package:hosspi_hms/core/network/connection_retry_interceptor.dart';
import 'package:hosspi_hms/core/network/dio_adapter_configurer.dart';
import 'package:hosspi_hms/core/network/http_response_cache_interceptor.dart';
import 'package:hosspi_hms/core/network/network_failure_mapper.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_token_provider.dart';

final networkFailureMapperProvider = Provider<NetworkFailureMapper>((ref) {
  return const NetworkFailureMapper();
});

BaseOptions _dioBaseOptions(AppConfig config) {
  return BaseOptions(
    baseUrl: config.apiBaseUrl.toString(),
    connectTimeout: config.apiTimeout,
    receiveTimeout: config.apiTimeout,
    sendTimeout: config.apiTimeout,
  );
}

String? _readRequestLocale(Ref ref) {
  return ref.read(appLocaleProvider)?.languageCode;
}

final publicDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final csrfDio = Dio(_dioBaseOptions(config));
  configureDioAdapter(csrfDio);

  final dio = Dio(_dioBaseOptions(config));
  configureDioAdapter(dio);
  dio.interceptors.addAll(<Interceptor>[
    LocaleInterceptor(readLocale: () => _readRequestLocale(ref)),
    CsrfInterceptor(tokenDio: csrfDio),
    SafeDiagnosticsInterceptor(
      enabled: !config.isProduction && config.logLevel == AppLogLevel.debug,
    ),
  ]);

  ref.onDispose(() {
    csrfDio.close(force: true);
    dio.close(force: true);
  });

  return dio;
});

final publicApiClientProvider = Provider<ApiClient>((ref) {
  return DioApiClient(
    dio: ref.watch(publicDioProvider),
    failureMapper: ref.watch(networkFailureMapperProvider),
  );
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  // Use read (not watch) to avoid a circular provider chain:
  // sessionTokenProvider -> authRepositoryProvider -> apiClientProvider -> dioProvider.
  final tokenProvider = ref.read(sessionTokenProvider);
  final csrfDio = Dio(_dioBaseOptions(config));
  configureDioAdapter(csrfDio);

  final dio = Dio(_dioBaseOptions(config));
  configureDioAdapter(dio);
  dio.interceptors.addAll(<Interceptor>[
    LocaleInterceptor(readLocale: () => _readRequestLocale(ref)),
    CsrfInterceptor(tokenDio: csrfDio),
    AuthInterceptor(
      readAccessToken: tokenProvider.readAccessToken,
      onTokenRefresh: () async {
        return (await tokenProvider.refreshStoredSession()) != null;
      },
      onUnauthorizedResponse: () async {
        await ref
            .read(sessionStateProvider.notifier)
            .handleUnauthorizedResponse();
      },
      retryClient: dio,
    ),
    ConnectionRetryInterceptor(retryClient: dio),
    HttpResponseCacheInterceptor(),
    SafeDiagnosticsInterceptor(
      enabled: !config.isProduction && config.logLevel == AppLogLevel.debug,
    ),
  ]);

  ref.onDispose(() {
    csrfDio.close(force: true);
    dio.close(force: true);
  });

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return DioApiClient(
    dio: ref.watch(dioProvider),
    failureMapper: ref.watch(networkFailureMapperProvider),
  );
});
