import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_controller.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_preferences.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/app/startup/app_startup_state.dart';
import 'package:hosspi_hms/app/startup/startup_providers.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/core/storage/storage_readiness.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppTextScaleLevel', () {
    test('maps each level to its percentage-based scale factor', () {
      // Guards against an off-by-100 regression that scaled all app text to
      // 1% of its size and left the entire UI without visible text.
      expect(AppTextScaleLevel.normal.factor, 1.0);
      expect(AppTextScaleLevel.large.factor, 1.15);
      expect(AppTextScaleLevel.extraLarge.factor, 1.30);
    });

    test('defaults to a readable scale factor', () {
      expect(const AppAccessibilityPreferences().textScaleFactor, 1.0);
    });
  });

  group('AppAccessibilityController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('restores accessibility preferences from startup state', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appStartupStateProvider.overrideWithValue(
            const AppStartupState(
              themeMode: ThemeMode.light,
              locale: null,
              accessibility: AppAccessibilityPreferences(
                reduceMotion: true,
                boldText: true,
                textScaleLevel: AppTextScaleLevel.large,
              ),
              storageReadiness: StorageReadiness.ready(),
              sessionReadiness: SessionState.unauthenticated(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(appAccessibilityProvider).reduceMotion, isTrue);
      expect(container.read(appAccessibilityProvider).boldText, isTrue);
      expect(
        container.read(appAccessibilityProvider).textScaleLevel,
        AppTextScaleLevel.large,
      );
    });

    test('persists accessibility preferences', () async {
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
          .read(appAccessibilityProvider.notifier)
          .setReduceMotion(true);
      await container.read(appAccessibilityProvider.notifier).setBoldText(true);
      await container
          .read(appAccessibilityProvider.notifier)
          .setTextScaleLevel(AppTextScaleLevel.extraLarge);

      expect(preferences.getBool(AppPreferenceKeys.reduceMotion), isTrue);
      expect(preferences.getBool(AppPreferenceKeys.boldText), isTrue);
      expect(
        preferences.getInt(AppPreferenceKeys.textScaleLevel),
        AppTextScaleLevel.extraLarge.storageValue,
      );
      expect(
        AppPreferencesRestorer.restoreAccessibility(preferences).textScaleLevel,
        AppTextScaleLevel.extraLarge,
      );
    });
  });
}
