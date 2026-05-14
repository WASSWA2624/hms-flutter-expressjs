import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/app/startup/startup_providers.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';

final appLocaleProvider = NotifierProvider<AppLocaleController, Locale?>(
  AppLocaleController.new,
);

final class AppLocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    return ref.watch(appStartupStateProvider.select((state) => state.locale));
  }

  Future<void> setLocale(Locale? locale) async {
    if (_sameLocale(locale, state)) {
      return;
    }

    final Locale? previousLocale = state;
    state = locale;

    try {
      final saved = locale == null
          ? await ref
                .read(appPreferencesStoreProvider)
                .remove(AppPreferenceKeys.locale)
          : await ref
                .read(appPreferencesStoreProvider)
                .setString(AppPreferenceKeys.locale, locale.toLanguageTag());

      if (!saved) {
        throw StateError('Unable to persist locale.');
      }
    } catch (_) {
      state = previousLocale;
      rethrow;
    }
  }

  bool _sameLocale(Locale? left, Locale? right) {
    return left?.toLanguageTag() == right?.toLanguageTag();
  }
}
