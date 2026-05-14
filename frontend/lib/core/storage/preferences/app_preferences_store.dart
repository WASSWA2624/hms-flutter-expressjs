import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppPreferencesStore {
  String? getString(String key);

  bool? getBool(String key);

  int? getInt(String key);

  Future<bool> setString(String key, String value);

  Future<bool> setBool(String key, {required bool value});

  Future<bool> setInt(String key, int value);

  Future<bool> remove(String key);
}

final class SharedPreferencesAppPreferencesStore
    implements AppPreferencesStore {
  const SharedPreferencesAppPreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? getString(String key) {
    return _preferences.getString(key);
  }

  @override
  bool? getBool(String key) {
    return _preferences.getBool(key);
  }

  @override
  int? getInt(String key) {
    return _preferences.getInt(key);
  }

  @override
  Future<bool> setString(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<bool> setBool(String key, {required bool value}) {
    return _preferences.setBool(key, value);
  }

  @override
  Future<bool> setInt(String key, int value) {
    return _preferences.setInt(key, value);
  }

  @override
  Future<bool> remove(String key) {
    return _preferences.remove(key);
  }
}
