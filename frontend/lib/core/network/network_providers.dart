import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/config/app_config_provider.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_interceptors.dart';
import 'package:hosspi_hms/core/network/dio_adapter_configurer.dart';
import 'package:hosspi_hms/core/network/network_failure_mapper.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_manager.dart';

final networkFailureMapperProvider = Provider<NetworkFailureMapper>((ref) {
  return const NetworkFailureMapper();
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final sessionManager = ref.watch(sessionManagerProvider);
  BaseOptions baseOptions() {
    return BaseOptions(
      baseUrl: config.apiBaseUrl.toString(),
      connectTimeout: config.apiTimeout,
      receiveTimeout: config.apiTimeout,
      sendTimeout: config.apiTimeout,
    );
  }

  final csrfDio = Dio(baseOptions());
  configureDioAdapter(csrfDio);

  final dio = Dio(baseOptions());
  configureDioAdapter(dio);
  dio.interceptors.addAll(<Interceptor>[
    CsrfInterceptor(tokenDio: csrfDio),
    AuthInterceptor(
      readAccessToken: sessionManager.readAccessToken,
      onUnauthorizedResponse: () async {
        await ref
            .read(sessionStateProvider.notifier)
            .handleUnauthorizedResponse();
      },
    ),
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
