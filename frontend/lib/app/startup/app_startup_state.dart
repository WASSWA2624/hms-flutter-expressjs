import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/storage/storage_readiness.dart';

final class AppStartupState {
  const AppStartupState({
    required this.themeMode,
    required this.locale,
    required this.storageReadiness,
    required this.sessionReadiness,
  });

  const AppStartupState.defaults()
    : themeMode = ThemeMode.light,
      locale = null,
      storageReadiness = const StorageReadiness.notReady(),
      sessionReadiness = const SessionState.notReady();

  final ThemeMode themeMode;
  final Locale? locale;
  final StorageReadiness storageReadiness;
  final SessionState sessionReadiness;

  bool get isReady => storageReadiness.isReady && sessionReadiness.isReady;
}
