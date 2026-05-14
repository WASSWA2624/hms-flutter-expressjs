import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/app/startup/app_startup_state.dart';
import 'package:hosspi_hms/app/startup/startup_providers.dart';
import 'package:hosspi_hms/app/theme/app_theme_mode_controller.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppThemeModeController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('defaults missing preferences to light mode', () async {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      expect(
        AppPreferencesRestorer.restoreThemeMode(preferences),
        ThemeMode.light,
      );
    });

    test('starts from restored startup state', () async {
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

      expect(container.read(appThemeModeProvider), ThemeMode.light);
    });

    test('updates state and persists dark mode', () async {
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
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(container.read(appThemeModeProvider), ThemeMode.dark);
      expect(preferences.getString(AppPreferenceKeys.themeMode), 'dark');
    });

    test('updates state and persists system mode', () async {
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
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.system);

      expect(container.read(appThemeModeProvider), ThemeMode.system);
      expect(preferences.getString(AppPreferenceKeys.themeMode), 'system');
    });
  });
}
