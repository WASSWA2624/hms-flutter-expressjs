import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/security/session_tokens.dart';
import 'package:flutter_template/core/storage/secure/app_secure_storage.dart';
import 'package:flutter_template/core/storage/storage_providers.dart';

final secureSessionStorageProvider = Provider<SecureSessionStorage>((ref) {
  return SecureAppSessionStorage(ref.watch(appSecureStorageProvider));
});

abstract interface class SecureSessionStorage {
  Future<SessionTokens?> readTokens();

  Future<void> writeTokens(SessionTokens tokens);

  Future<void> clear();
}

final class SecureAppSessionStorage implements SecureSessionStorage {
  const SecureAppSessionStorage(this._secureStorage);

  final AppSecureStorage _secureStorage;

  @override
  Future<SessionTokens?> readTokens() async {
    final accessToken = await _secureStorage.read(
      SecureStorageKeys.accessToken,
    );
    final normalizedAccessToken = accessToken?.trim();
    if (normalizedAccessToken == null || normalizedAccessToken.isEmpty) {
      return null;
    }

    final refreshToken = await _secureStorage.read(
      SecureStorageKeys.refreshToken,
    );
    final expiresAtResult = await _readAccessTokenExpiresAt();
    if (expiresAtResult.isInvalid) {
      await clear();
      return null;
    }

    return SessionTokens(
      accessToken: normalizedAccessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: expiresAtResult.value,
    );
  }

  @override
  Future<void> writeTokens(SessionTokens tokens) async {
    await _secureStorage.write(
      key: SecureStorageKeys.accessToken,
      value: tokens.accessToken,
    );

    final refreshToken = tokens.refreshToken;
    if (refreshToken == null) {
      await _secureStorage.delete(SecureStorageKeys.refreshToken);
    } else {
      await _secureStorage.write(
        key: SecureStorageKeys.refreshToken,
        value: refreshToken,
      );
    }

    final expiresAt = tokens.accessTokenExpiresAt;
    if (expiresAt == null) {
      await _secureStorage.delete(SecureStorageKeys.accessTokenExpiresAt);
    } else {
      await _secureStorage.write(
        key: SecureStorageKeys.accessTokenExpiresAt,
        value: expiresAt.toUtc().toIso8601String(),
      );
    }
  }

  @override
  Future<void> clear() async {
    await _secureStorage.delete(SecureStorageKeys.accessToken);
    await _secureStorage.delete(SecureStorageKeys.refreshToken);
    await _secureStorage.delete(SecureStorageKeys.accessTokenExpiresAt);
  }

  Future<_StoredDateTimeResult> _readAccessTokenExpiresAt() async {
    final rawExpiresAt = await _secureStorage.read(
      SecureStorageKeys.accessTokenExpiresAt,
    );
    final normalizedExpiresAt = rawExpiresAt?.trim();
    if (normalizedExpiresAt == null || normalizedExpiresAt.isEmpty) {
      return const _StoredDateTimeResult();
    }

    final parsedExpiresAt = DateTime.tryParse(normalizedExpiresAt);
    if (parsedExpiresAt == null) {
      return const _StoredDateTimeResult.invalid();
    }

    return _StoredDateTimeResult(parsedExpiresAt.toUtc());
  }
}

final class _StoredDateTimeResult {
  const _StoredDateTimeResult([this.value]) : isInvalid = false;

  const _StoredDateTimeResult.invalid() : value = null, isInvalid = true;

  final DateTime? value;
  final bool isInvalid;
}
