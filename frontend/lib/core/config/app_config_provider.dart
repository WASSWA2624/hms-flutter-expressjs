import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/config/app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  const String environmentName = String.fromEnvironment('APP_ENV');
  if (environmentName.isEmpty) {
    return AppConfig.fromValues(
      environmentName: 'development',
      apiBaseUrl: 'http://localhost:3000',
      logLevelName: 'error',
    );
  }

  return AppConfig.fromEnvironment();
});
