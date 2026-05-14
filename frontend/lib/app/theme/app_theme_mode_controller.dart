import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/app/startup/startup_providers.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';

final appThemeModeProvider =
    NotifierProvider<AppThemeModeController, ThemeMode>(
      AppThemeModeController.new,
    );

final class AppThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ref.watch(
      appStartupStateProvider.select((state) => state.themeMode),
    );
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (themeMode == state) {
      return;
    }

    final ThemeMode previousThemeMode = state;
    state = themeMode;

    try {
      final saved = await ref
          .read(appPreferencesStoreProvider)
          .setString(
            AppPreferenceKeys.themeMode,
            AppPreferencesRestorer.themeModePreferenceValue(themeMode),
          );

      if (!saved) {
        throw StateError('Unable to persist theme mode.');
      }
    } catch (_) {
      state = previousThemeMode;
      rethrow;
    }
  }
}
