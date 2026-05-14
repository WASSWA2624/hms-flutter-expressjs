import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/app/app.dart';
import 'package:flutter_template/app/router/app_router.dart';
import 'package:flutter_template/app/startup/app_startup_state.dart';
import 'package:flutter_template/app/startup/startup_providers.dart';
import 'package:flutter_template/app/theme/app_theme.dart';
import 'package:flutter_template/core/security/session_controller.dart';
import 'package:flutter_template/core/security/session_state.dart';
import 'package:flutter_template/core/storage/storage_readiness.dart';
import 'package:flutter_template/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const Locale testLocale = Locale('en');

List<Object?> testReadyAppOverrides({
  ThemeMode themeMode = ThemeMode.light,
  Locale? locale = testLocale,
  StorageReadiness storageReadiness = const StorageReadiness.ready(),
  SessionState sessionState = const SessionState.ready(),
  String? initialLocation,
}) {
  return <Object?>[
    appStartupStateProvider.overrideWithValue(
      AppStartupState(
        themeMode: themeMode,
        locale: locale,
        storageReadiness: storageReadiness,
        sessionReadiness: sessionState,
      ),
    ),
    initialSessionStateProvider.overrideWithValue(sessionState),
    if (initialLocation != null)
      appInitialLocationProvider.overrideWithValue(initialLocation),
  ];
}

ProviderContainer createTestContainer({
  List<Object?> overrides = const <Object?>[],
}) {
  final container = ProviderContainer(overrides: overrides.cast());
  addTearDown(container.dispose);

  return container;
}

Future<void> pumpTemplateApp(
  WidgetTester tester, {
  List<Object?> overrides = const <Object?>[],
  Size? size,
}) async {
  setTestViewport(tester, size);

  await tester.pumpWidget(
    ProviderScope(overrides: overrides.cast(), child: const TemplateApp()),
  );
}

Future<void> pumpLocalizedWidget(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 600),
  EdgeInsetsGeometry padding = const EdgeInsets.all(24),
}) async {
  setTestViewport(tester, size);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Padding(padding: padding, child: child),
      ),
    ),
  );
}

void setTestViewport(WidgetTester tester, Size? size) {
  if (size == null) {
    return;
  }

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
