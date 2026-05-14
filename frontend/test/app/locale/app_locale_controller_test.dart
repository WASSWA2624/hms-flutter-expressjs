import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/app/locale/app_locale_controller.dart';
import 'package:flutter_template/app/startup/app_preferences_restorer.dart';
import 'package:flutter_template/app/startup/app_startup_state.dart';
import 'package:flutter_template/app/startup/startup_providers.dart';
import 'package:flutter_template/core/security/session_state.dart';
import 'package:flutter_template/core/storage/storage_providers.dart';
import 'package:flutter_template/core/storage/storage_readiness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppLocaleController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('starts from restored startup state', () async {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          appStartupStateProvider.overrideWithValue(
            const AppStartupState(
              themeMode: ThemeMode.light,
              locale: Locale('en'),
              storageReadiness: StorageReadiness.ready(),
              sessionReadiness: SessionState.ready(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(appLocaleProvider), const Locale('en'));
    });

    test('updates state and persists locale', () async {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          appStartupStateProvider.overrideWithValue(
            const AppStartupState.defaults(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(appLocaleProvider.notifier)
          .setLocale(const Locale('en'));

      expect(container.read(appLocaleProvider), const Locale('en'));
      expect(preferences.getString(AppPreferenceKeys.locale), 'en');
    });
  });
}
