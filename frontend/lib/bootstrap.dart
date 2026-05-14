import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/app/app.dart';
import 'package:flutter_template/app/router/url_strategy.dart';
import 'package:flutter_template/app/startup/app_startup_initializer.dart';
import 'package:flutter_template/app/startup/startup_shell.dart';
import 'package:flutter_template/core/config/app_config.dart';
import 'package:flutter_template/core/logging/app_logger.dart';

Future<void> bootstrap({
  AppConfig? config,
  AppStartupInitializer startupInitializer = const AppStartupInitializer(),
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrlStrategy();
  final String initialLocation = _platformInitialLocation();

  runApp(ProviderScope(key: UniqueKey(), child: const StartupLoadingApp()));

  try {
    final startupResult = await startupInitializer.initialize(config: config);

    runApp(
      ProviderScope(
        key: UniqueKey(),
        overrides: startupResult
            .providerOverrides(initialLocation: initialLocation)
            .cast(),
        child: const TemplateApp(),
      ),
    );
  } catch (error, stackTrace) {
    AppLogger.error('Startup failed.', error, stackTrace);

    runApp(
      ProviderScope(
        key: UniqueKey(),
        child: StartupErrorApp(
          onRetry: () {
            unawaited(
              bootstrap(config: config, startupInitializer: startupInitializer),
            );
          },
        ),
      ),
    );
  }
}

String _platformInitialLocation() {
  final String routeName =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;

  if (routeName.isEmpty || !routeName.startsWith('/')) {
    return '/';
  }

  return routeName;
}
