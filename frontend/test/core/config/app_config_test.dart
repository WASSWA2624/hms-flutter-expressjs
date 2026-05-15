import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('builds typed configuration from supported values', () {
      final config = AppConfig.fromValues(
        environmentName: 'development',
        apiBaseUrl: 'http://localhost:8080',
        logLevelName: 'debug',
        featureFlags: const FeatureFlags(enableDeveloperTools: true),
      );

      expect(config.environment, AppEnvironment.development);
      expect(config.apiBaseUrl, Uri.parse('http://localhost:8080'));
      expect(config.apiTimeout, const Duration(seconds: 30));
      expect(config.logLevel, AppLogLevel.debug);
      expect(config.featureFlags.enableDeveloperTools, isTrue);
    });

    test('throws a clear error when required values are missing', () {
      expect(
        () => AppConfig.fromValues(environmentName: '', apiBaseUrl: ''),
        throwsA(
          isA<AppConfigException>()
              .having(
                (error) => error.messages,
                'messages',
                contains(startsWith('APP_ENV is required.')),
              )
              .having(
                (error) => error.messages,
                'messages',
                contains(startsWith('API_BASE_URL is required.')),
              ),
        ),
      );
    });

    test('rejects unsupported environment names', () {
      expect(
        () => AppConfig.fromValues(
          environmentName: 'qa',
          apiBaseUrl: 'https://api.example.com',
        ),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.messages.single,
            'message',
            contains('APP_ENV "qa" is not supported.'),
          ),
        ),
      );
    });

    test('requires https API URLs in production', () {
      expect(
        () => AppConfig.fromValues(
          environmentName: 'production',
          apiBaseUrl: 'http://api.example.com',
        ),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.messages,
            'messages',
            contains('Production API_BASE_URL must use https.'),
          ),
        ),
      );
    });

    test('rejects local API URLs in production', () {
      expect(
        () => AppConfig.fromValues(
          environmentName: 'production',
          apiBaseUrl: 'https://localhost:8080',
        ),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.messages,
            'messages',
            contains(
              'Production API_BASE_URL must not point to a local '
              'development host.',
            ),
          ),
        ),
      );
    });

    test('rejects developer tools in production', () {
      expect(
        () => AppConfig.fromValues(
          environmentName: 'production',
          apiBaseUrl: 'https://api.example.com',
          featureFlags: const FeatureFlags(enableDeveloperTools: true),
        ),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.messages,
            'messages',
            contains(
              'FEATURE_DEVELOPER_TOOLS_ENABLED must be false in production.',
            ),
          ),
        ),
      );
    });

    test('rejects verbose logging in production', () {
      expect(
        () => AppConfig.fromValues(
          environmentName: 'production',
          apiBaseUrl: 'https://api.example.com',
          logLevelName: 'debug',
        ),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.messages,
            'messages',
            contains('LOG_LEVEL must not be debug in production.'),
          ),
        ),
      );
    });

    test('normalizes local development API host to the current app host', () {
      final config = AppConfig.fromValues(
        environmentName: 'development',
        apiBaseUrl: 'http://localhost:3000',
        appBaseUrl: Uri.parse('http://127.0.0.1:5214/opd'),
      );

      expect(config.apiBaseUrl, Uri.parse('http://127.0.0.1:3000'));
    });
  });
}
