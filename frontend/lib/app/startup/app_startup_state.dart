import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_preferences.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/storage/storage_readiness.dart';

final class AppStartupState {
  const AppStartupState({
    required this.themeMode,
    required this.locale,
    required this.accessibility,
    required this.storageReadiness,
    required this.sessionReadiness,
  });

  const AppStartupState.defaults()
    : themeMode = ThemeMode.light,
      locale = null,
      accessibility = const AppAccessibilityPreferences(),
      storageReadiness = const StorageReadiness.notReady(),
      sessionReadiness = const SessionState.notReady();

  final ThemeMode themeMode;
  final Locale? locale;
  final AppAccessibilityPreferences accessibility;
  final StorageReadiness storageReadiness;
  final SessionState sessionReadiness;

  bool get isReady => storageReadiness.isReady && sessionReadiness.isReady;
}
