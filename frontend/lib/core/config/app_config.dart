final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.apiTimeout,
    required this.logLevel,
    this.appName = defaultAppName,
    this.appLogoUrl = defaultAppLogoUrl,
    this.appAdministratorName,
    this.appAdministratorEmail,
    this.appAdministratorPhone,
    this.appSupportUrl,
    this.featureFlags = const FeatureFlags(),
  });

  static const int defaultApiTimeoutSeconds = 30;
  static const String defaultAppName = 'HOSSPI Hospital Management System';
  static const String defaultAppLogoUrl = 'assets/logos/logo.png';

  final AppEnvironment environment;
  final Uri apiBaseUrl;
  final Duration apiTimeout;
  final AppLogLevel logLevel;
  final String appName;
  final String appLogoUrl;
  final String? appAdministratorName;
  final String? appAdministratorEmail;
  final String? appAdministratorPhone;
  final String? appSupportUrl;
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
    const appName = String.fromEnvironment(
      'APP_NAME',
      defaultValue: AppConfig.defaultAppName,
    );
    const appLogoUrl = String.fromEnvironment(
      'APP_LOGO_URL',
      defaultValue: AppConfig.defaultAppLogoUrl,
    );
    const appAdministratorName = String.fromEnvironment('APP_ADMIN_NAME');
    const appAdministratorEmail = String.fromEnvironment('APP_ADMIN_EMAIL');
    const appAdministratorPhone = String.fromEnvironment('APP_ADMIN_PHONE');
    const appSupportUrl = String.fromEnvironment('APP_SUPPORT_URL');

    return AppConfig._fromRawValues(
      environmentName: environmentName,
      apiBaseUrl: apiBaseUrl,
      apiTimeoutSeconds: apiTimeoutSeconds,
      logLevelName: logLevelName,
      appName: appName,
      appLogoUrl: appLogoUrl,
      appAdministratorName: appAdministratorName,
      appAdministratorEmail: appAdministratorEmail,
      appAdministratorPhone: appAdministratorPhone,
      appSupportUrl: appSupportUrl,
      featureFlags: const FeatureFlags.fromEnvironment(),
    );
  }

  factory AppConfig.fromValues({
    required String environmentName,
    required String apiBaseUrl,
    int apiTimeoutSeconds = AppConfig.defaultApiTimeoutSeconds,
    String logLevelName = 'info',
    String appName = AppConfig.defaultAppName,
    String appLogoUrl = AppConfig.defaultAppLogoUrl,
    String? appAdministratorName,
    String? appAdministratorEmail,
    String? appAdministratorPhone,
    String? appSupportUrl,
    FeatureFlags featureFlags = const FeatureFlags(),
    Uri? appBaseUrl,
  }) {
    return AppConfig._fromRawValues(
      environmentName: environmentName,
      apiBaseUrl: apiBaseUrl,
      apiTimeoutSeconds: apiTimeoutSeconds,
      logLevelName: logLevelName,
      appName: appName,
      appLogoUrl: appLogoUrl,
      appAdministratorName: appAdministratorName,
      appAdministratorEmail: appAdministratorEmail,
      appAdministratorPhone: appAdministratorPhone,
      appSupportUrl: appSupportUrl,
      featureFlags: featureFlags,
      appBaseUrl: appBaseUrl,
    );
  }

  factory AppConfig._fromRawValues({
    required String environmentName,
    required String apiBaseUrl,
    required int apiTimeoutSeconds,
    required String logLevelName,
    required String appName,
    required String appLogoUrl,
    String? appAdministratorName,
    String? appAdministratorEmail,
    String? appAdministratorPhone,
    String? appSupportUrl,
    required FeatureFlags featureFlags,
    Uri? appBaseUrl,
  }) {
    final errors = <String>[];

    final environment = _parseEnvironment(environmentName, errors);
    final uri = _parseApiBaseUrl(apiBaseUrl, errors);
    final logLevel = _parseLogLevel(logLevelName, errors);
    final normalizedAppName = _normalizeRequiredText(
      value: appName,
      fieldName: 'APP_NAME',
      errors: errors,
    );
    final normalizedAppLogoUrl = _normalizeOptionalText(appLogoUrl);
    final normalizedAppAdministratorName = _normalizeOptionalText(
      appAdministratorName,
    );
    final normalizedAppAdministratorEmail = _normalizeOptionalText(
      appAdministratorEmail,
    );
    final normalizedAppAdministratorPhone = _normalizeOptionalText(
      appAdministratorPhone,
    );
    final normalizedAppSupportUrl = _normalizeOptionalText(appSupportUrl);

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
      appName: normalizedAppName!,
      appLogoUrl: normalizedAppLogoUrl ?? AppConfig.defaultAppLogoUrl,
      appAdministratorName: normalizedAppAdministratorName,
      appAdministratorEmail: normalizedAppAdministratorEmail,
      appAdministratorPhone: normalizedAppAdministratorPhone,
      appSupportUrl: normalizedAppSupportUrl,
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
    String? appName,
    String? appLogoUrl,
    String? appAdministratorName,
    String? appAdministratorEmail,
    String? appAdministratorPhone,
    String? appSupportUrl,
    FeatureFlags? featureFlags,
  }) {
    return AppConfig(
      environment: environment ?? this.environment,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiTimeout: apiTimeout ?? this.apiTimeout,
      logLevel: logLevel ?? this.logLevel,
      appName: appName ?? this.appName,
      appLogoUrl: appLogoUrl ?? this.appLogoUrl,
      appAdministratorName: appAdministratorName ?? this.appAdministratorName,
      appAdministratorEmail:
          appAdministratorEmail ?? this.appAdministratorEmail,
      appAdministratorPhone:
          appAdministratorPhone ?? this.appAdministratorPhone,
      appSupportUrl: appSupportUrl ?? this.appSupportUrl,
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

  static String? _normalizeRequiredText({
    required String value,
    required String fieldName,
    required List<String> errors,
  }) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      errors.add('$fieldName must not be empty.');
      return null;
    }

    return normalized;
  }

  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
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
