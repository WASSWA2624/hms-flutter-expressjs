import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hosspi_hms/core/storage/database/app_database.dart';
import 'package:hosspi_hms/core/storage/preferences/app_preferences_store.dart';
import 'package:hosspi_hms/core/storage/secure/app_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('sharedPreferencesProvider must be overridden at startup.');
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  throw StateError('secureStorageProvider must be overridden at startup.');
});

final appPreferencesStoreProvider = Provider<AppPreferencesStore>((ref) {
  return SharedPreferencesAppPreferencesStore(
    ref.watch(sharedPreferencesProvider),
  );
});

final appSecureStorageProvider = Provider<AppSecureStorage>((ref) {
  return FlutterAppSecureStorage(ref.watch(secureStorageProvider));
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  ref.onDispose(() {
    unawaited(database.close());
  });

  return database;
});
