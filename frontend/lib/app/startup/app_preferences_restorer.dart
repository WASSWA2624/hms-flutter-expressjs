import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_preferences.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class AppPreferenceKeys {
  static const String themeMode = 'app.theme_mode';
  static const String locale = 'app.locale';
  static const String reduceMotion = 'app.accessibility.reduce_motion';
  static const String boldText = 'app.accessibility.bold_text';
  static const String textScaleLevel = 'app.accessibility.text_scale_level';
  static const String sidebarCollapsed = 'app.shell.sidebar_collapsed';
}

abstract final class AppPreferencesRestorer {
  static ThemeMode restoreThemeMode(SharedPreferences preferences) {
    final value = preferences.getString(AppPreferenceKeys.themeMode);

    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      null => ThemeMode.light,
      _ => ThemeMode.light,
    };
  }

  static String themeModePreferenceValue(ThemeMode themeMode) {
    return switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  static Locale? restoreLocale(SharedPreferences preferences) {
    final value = preferences.getString(AppPreferenceKeys.locale)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    for (final Locale locale in AppLocalizations.supportedLocales) {
      if (_matchesLocale(locale, value)) {
        return locale;
      }
    }

    return null;
  }

  static bool _matchesLocale(Locale locale, String value) {
    final normalizedValue = value.replaceAll('_', '-').toLowerCase();
    final languageCode = locale.languageCode.toLowerCase();
    final countryCode = locale.countryCode?.toLowerCase();

    if (countryCode == null || countryCode.isEmpty) {
      return normalizedValue == languageCode;
    }

    return normalizedValue == languageCode ||
        normalizedValue == '$languageCode-$countryCode';
  }

  static AppAccessibilityPreferences restoreAccessibility(
    SharedPreferences preferences,
  ) {
    return AppAccessibilityPreferences(
      reduceMotion:
          preferences.getBool(AppPreferenceKeys.reduceMotion) ?? false,
      boldText: preferences.getBool(AppPreferenceKeys.boldText) ?? false,
      textScaleLevel: AppTextScaleLevel.fromStorage(
        preferences.getInt(AppPreferenceKeys.textScaleLevel),
      ),
    );
  }
}
