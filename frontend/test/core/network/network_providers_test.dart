import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_template/core/config/app_config.dart';
import 'package:flutter_template/core/config/app_config_provider.dart';
import 'package:flutter_template/core/network/api_client.dart';
import 'package:flutter_template/core/network/network_providers.dart';
import 'package:flutter_template/core/storage/storage_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('network providers', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test('build Dio from an overridden app configuration', () {
      final config = AppConfig.fromValues(
        environmentName: 'development',
        apiBaseUrl: 'http://localhost:8080',
        apiTimeoutSeconds: 10,
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
        ],
      );
      addTearDown(container.dispose);

      final dio = container.read(dioProvider);

      expect(dio.options.baseUrl, config.apiBaseUrl.toString());
      expect(dio.options.connectTimeout, config.apiTimeout);
      expect(dio.options.receiveTimeout, config.apiTimeout);
      expect(dio.options.sendTimeout, config.apiTimeout);
    });

    test('allows tests to override the Dio client', () {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test.local'));
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      final ApiClient apiClient = container.read(apiClientProvider);

      expect(apiClient, isA<DioApiClient>());
      expect((apiClient as DioApiClient).dio, same(dio));
      expect(apiClient.baseUri, Uri.parse('https://api.test.local'));
    });
  });
}
