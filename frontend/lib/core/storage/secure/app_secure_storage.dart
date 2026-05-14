import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AppSecureStorage {
  Future<String?> read(String key);

  Future<void> write({required String key, required String value});

  Future<void> delete(String key);

  Future<void> deleteAll();
}

abstract final class SecureStorageKeys {
  static const String accessToken = 'session.access_token';
  static const String refreshToken = 'session.refresh_token';
  static const String accessTokenExpiresAt = 'session.access_token_expires_at';
}

final class FlutterAppSecureStorage implements AppSecureStorage {
  const FlutterAppSecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() {
    return _storage.deleteAll();
  }
}
