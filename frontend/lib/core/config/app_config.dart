final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.apiTimeout,
    required this.logLevel,
    this.featureFlags = const FeatureFlags(),
  });

  static const int defaultApiTimeoutSeconds = 30;

  final AppEnvironment environment;
  final Uri apiBaseUrl;
  final Duration apiTimeout;
  final AppLogLevel logLevel;
  final FeatureFlags featureFlags;

  bool get isDevelopment => environment == AppEnvironment.development;

  bool get isStaging => environment == AppEnvironment.staging;

  bool get isProduction => environment == AppEnvironment.production;

  factory AppConfig.fromEnvironment() {
    const environmentName = String.fromEnvironment('APP_ENV');
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const apiTimeoutSeconds = int.fromEnvironment(
      'API_TIMEOUT_SECONDS',
      defaultValue: AppConfig.defaultApiTimeoutSeconds,
    );
    const logLevelName = String.fromEnvironment(
      'LOG_LEVEL',
      defaultValue: 'info',
    );

    return AppConfig._fromRawValues(
      environmentName: environmentName,
      apiBaseUrl: apiBaseUrl,
      apiTimeoutSeconds: apiTimeoutSeconds,
      logLevelName: logLevelName,
      featureFlags: const FeatureFlags.fromEnvironment(),
    );
  }

  factory AppConfig.fromValues({
    required String environmentName,
    required String apiBaseUrl,
    int apiTimeoutSeconds = AppConfig.defaultApiTimeoutSeconds,
    String logLevelName = 'info',
    FeatureFlags featureFlags = const FeatureFlags(),
    Uri? appBaseUrl,
  }) {
    return AppConfig._fromRawValues(
      environmentName: environmentName,
      apiBaseUrl: apiBaseUrl,
      apiTimeoutSeconds: apiTimeoutSeconds,
      logLevelName: logLevelName,
      featureFlags: featureFlags,
      appBaseUrl: appBaseUrl,
    );
  }

  factory AppConfig._fromRawValues({
    required String environmentName,
    required String apiBaseUrl,
    required int apiTimeoutSeconds,
    required String logLevelName,
    required FeatureFlags featureFlags,
    Uri? appBaseUrl,
  }) {
    final errors = <String>[];

    final environment = _parseEnvironment(environmentName, errors);
    final uri = _parseApiBaseUrl(apiBaseUrl, errors);
    final logLevel = _parseLogLevel(logLevelName, errors);

    if (apiTimeoutSeconds <= 0) {
      errors.add('API_TIMEOUT_SECONDS must be greater than zero.');
    }

    if (errors.isNotEmpty) {
      throw AppConfigException(errors);
    }

    final normalizedApiBaseUrl = _normalizeDevelopmentApiBaseUrl(
      environment: environment,
      apiBaseUrl: uri,
      appBaseUrl: appBaseUrl ?? Uri.base,
    );

    final config = AppConfig(
      environment: environment!,
      apiBaseUrl: normalizedApiBaseUrl!,
      apiTimeout: Duration(seconds: apiTimeoutSeconds),
      logLevel: logLevel!,
      featureFlags: featureFlags,
    );

    config.validate();
    return config;
  }

  void validate() {
    final errors = <String>[];
    final scheme = apiBaseUrl.scheme.toLowerCase();

    if (!apiBaseUrl.hasScheme || !apiBaseUrl.hasAuthority) {
      errors.add('API_BASE_URL must be an absolute URL with a host.');
    }

    if (scheme != 'http' && scheme != 'https') {
      errors.add('API_BASE_URL must use http or https.');
    }

    if (apiBaseUrl.userInfo.isNotEmpty) {
      errors.add('API_BASE_URL must not include credentials.');
    }

    if (isProduction && scheme != 'https') {
      errors.add('Production API_BASE_URL must use https.');
    }

    if (isProduction && _isLocalDevelopmentHost(apiBaseUrl.host)) {
      errors.add(
        'Production API_BASE_URL must not point to a local development host.',
      );
    }

    if (apiTimeout <= Duration.zero) {
      errors.add('API_TIMEOUT_SECONDS must be greater than zero.');
    }

    if (isProduction && featureFlags.enableDeveloperTools) {
      errors.add(
        'FEATURE_DEVELOPER_TOOLS_ENABLED must be false in production.',
      );
    }

    if (isProduction && logLevel == AppLogLevel.debug) {
      errors.add('LOG_LEVEL must not be debug in production.');
    }

    if (errors.isNotEmpty) {
      throw AppConfigException(errors);
    }
  }

  AppConfig copyWith({
    AppEnvironment? environment,
    Uri? apiBaseUrl,
    Duration? apiTimeout,
    AppLogLevel? logLevel,
    FeatureFlags? featureFlags,
  }) {
    return AppConfig(
      environment: environment ?? this.environment,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiTimeout: apiTimeout ?? this.apiTimeout,
      logLevel: logLevel ?? this.logLevel,
      featureFlags: featureFlags ?? this.featureFlags,
    );
  }

  static AppEnvironment? _parseEnvironment(String value, List<String> errors) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      errors.add(
        'APP_ENV is required. Supported values: '
        '${AppEnvironment.supportedValues}.',
      );
      return null;
    }

    final environment = AppEnvironment.tryParse(trimmedValue);
    if (environment == null) {
      errors.add(
        'APP_ENV "$trimmedValue" is not supported. Supported values: '
        '${AppEnvironment.supportedValues}.',
      );
    }

    return environment;
  }

  static Uri? _parseApiBaseUrl(String value, List<String> errors) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      errors.add(
        'API_BASE_URL is required. Provide a public, non-secret URL with '
        '--dart-define=API_BASE_URL=...',
      );
      return null;
    }

    final uri = Uri.tryParse(trimmedValue);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      errors.add('API_BASE_URL must be an absolute URL with a host.');
      return null;
    }

    return uri;
  }

  static Uri? _normalizeDevelopmentApiBaseUrl({
    required AppEnvironment? environment,
    required Uri? apiBaseUrl,
    required Uri appBaseUrl,
  }) {
    if (environment != AppEnvironment.development || apiBaseUrl == null) {
      return apiBaseUrl;
    }

    if (!appBaseUrl.hasAuthority ||
        !_isLocalDevelopmentHost(appBaseUrl.host) ||
        !_isLocalDevelopmentHost(apiBaseUrl.host) ||
        appBaseUrl.host == apiBaseUrl.host) {
      return apiBaseUrl;
    }

    return apiBaseUrl.replace(host: appBaseUrl.host);
  }

  static AppLogLevel? _parseLogLevel(String value, List<String> errors) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      errors.add(
        'LOG_LEVEL must not be empty. Supported values: '
        '${AppLogLevel.supportedValues}.',
      );
      return null;
    }

    final logLevel = AppLogLevel.tryParse(trimmedValue);
    if (logLevel == null) {
      errors.add(
        'LOG_LEVEL "$trimmedValue" is not supported. Supported values: '
        '${AppLogLevel.supportedValues}.',
      );
    }

    return logLevel;
  }

  static bool _isLocalDevelopmentHost(String host) {
    final normalizedHost = host.trim().toLowerCase();

    return normalizedHost == 'localhost' ||
        normalizedHost == '127.0.0.1' ||
        normalizedHost == '0.0.0.0' ||
        normalizedHost == '::1' ||
        normalizedHost == '[::1]';
  }
}

enum AppEnvironment {
  development('development'),
  staging('staging'),
  production('production');

  const AppEnvironment(this.configValue);

  final String configValue;

  static String get supportedValues {
    return values.map((environment) => environment.configValue).join(', ');
  }

  static AppEnvironment? tryParse(String value) {
    final normalizedValue = value.trim().toLowerCase();

    for (final environment in values) {
      if (environment.configValue == normalizedValue) {
        return environment;
      }
    }

    return null;
  }
}

enum AppLogLevel {
  debug('debug'),
  info('info'),
  warn('warn'),
  error('error');

  const AppLogLevel(this.configValue);

  final String configValue;

  static String get supportedValues {
    return values.map((logLevel) => logLevel.configValue).join(', ');
  }

  static AppLogLevel? tryParse(String value) {
    final normalizedValue = value.trim().toLowerCase();

    for (final logLevel in values) {
      if (logLevel.configValue == normalizedValue) {
        return logLevel;
      }
    }

    return null;
  }
}

final class FeatureFlags {
  const FeatureFlags({this.enableDeveloperTools = false});

  const factory FeatureFlags.fromEnvironment() = FeatureFlags._fromEnvironment;

  const FeatureFlags._fromEnvironment()
    : enableDeveloperTools = const bool.fromEnvironment(
        'FEATURE_DEVELOPER_TOOLS_ENABLED',
      );

  final bool enableDeveloperTools;

  FeatureFlags copyWith({bool? enableDeveloperTools}) {
    return FeatureFlags(
      enableDeveloperTools: enableDeveloperTools ?? this.enableDeveloperTools,
    );
  }
}

final class AppConfigException implements Exception {
  const AppConfigException(this.messages);

  final List<String> messages;

  @override
  String toString() {
    return 'AppConfigException: ${messages.join(' ')}';
  }
}
