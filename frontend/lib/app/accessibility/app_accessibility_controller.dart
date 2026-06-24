import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_preferences.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/app/startup/startup_providers.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';

final appAccessibilityProvider =
    NotifierProvider<AppAccessibilityController, AppAccessibilityPreferences>(
      AppAccessibilityController.new,
    );

final class AppAccessibilityController
    extends Notifier<AppAccessibilityPreferences> {
  @override
  AppAccessibilityPreferences build() {
    return ref.watch(
      appStartupStateProvider.select((startup) => startup.accessibility),
    );
  }

  Future<void> setReduceMotion(bool value) async {
    await _persist(state.copyWith(reduceMotion: value));
  }

  Future<void> setBoldText(bool value) async {
    await _persist(state.copyWith(boldText: value));
  }

  Future<void> setTextScaleLevel(AppTextScaleLevel level) async {
    if (level == state.textScaleLevel) {
      return;
    }

    await _persist(state.copyWith(textScaleLevel: level));
  }

  Future<void> _persist(AppAccessibilityPreferences next) async {
    if (next == state) {
      return;
    }

    final AppAccessibilityPreferences previous = state;
    state = next;

    try {
      final store = ref.read(appPreferencesStoreProvider);
      final bool saved = await Future.wait<bool>(<Future<bool>>[
        store.setBool(
          AppPreferenceKeys.reduceMotion,
          value: next.reduceMotion,
        ),
        store.setBool(AppPreferenceKeys.boldText, value: next.boldText),
        store.setInt(
          AppPreferenceKeys.textScaleLevel,
          next.textScaleLevel.storageValue,
        ),
      ]).then((List<bool> results) => results.every((bool entry) => entry));

      if (!saved) {
        throw StateError('Unable to persist accessibility preferences.');
      }
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}
