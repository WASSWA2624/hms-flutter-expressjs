import 'package:flutter_template/core/security/secure_session_storage.dart';
import 'package:flutter_template/core/security/session_manager.dart';
import 'package:flutter_template/core/security/session_state.dart';
import 'package:flutter_template/core/security/session_tokens.dart';
import 'package:flutter_template/core/storage/secure/app_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionManager', () {
    test('restores authenticated sessions when a token exists', () async {
      final storage = _MemorySecureStorage()
        ..values[SecureStorageKeys.accessToken] = ' access-token ';
      final manager = SessionManager(
        sessionStorage: SecureAppSessionStorage(storage),
      );

      final readiness = await manager.restore();

      expect(readiness.status, SessionStatus.authenticated);
      expect(await manager.readAccessToken(), 'access-token');
    });

    test('clears expired tokens during restoration', () async {
      final storage = _MemorySecureStorage()
        ..values[SecureStorageKeys.accessToken] = 'expired-token'
        ..values[SecureStorageKeys.refreshToken] = 'refresh-token'
        ..values[SecureStorageKeys.accessTokenExpiresAt] = DateTime.utc(
          2024,
        ).toIso8601String();
      final manager = SessionManager(
        sessionStorage: SecureAppSessionStorage(storage),
        now: () => DateTime.utc(2026),
      );

      final readiness = await manager.restore();

      expect(readiness.status, SessionStatus.expired);
      expect(storage.values, isEmpty);
      expect(await manager.readAccessToken(), isNull);
    });

    test(
      'persists session tokens through the secure session boundary',
      () async {
        final storage = _MemorySecureStorage();
        final manager = SessionManager(
          sessionStorage: SecureAppSessionStorage(storage),
        );

        await manager.persistTokens(
          SessionTokens(
            accessToken: ' access-token ',
            refreshToken: ' refresh-token ',
            accessTokenExpiresAt: DateTime.utc(2027),
          ),
        );

        expect(storage.values[SecureStorageKeys.accessToken], 'access-token');
        expect(storage.values[SecureStorageKeys.refreshToken], 'refresh-token');
        expect(
          storage.values[SecureStorageKeys.accessTokenExpiresAt],
          DateTime.utc(2027).toIso8601String(),
        );
      },
    );

    test(
      'clears sensitive session artifacts on unauthorized responses',
      () async {
        final storage = _MemorySecureStorage()
          ..values[SecureStorageKeys.accessToken] = 'access-token'
          ..values[SecureStorageKeys.refreshToken] = 'refresh-token'
          ..values[SecureStorageKeys.accessTokenExpiresAt] = DateTime.utc(
            2027,
          ).toIso8601String();
        final manager = SessionManager(
          sessionStorage: SecureAppSessionStorage(storage),
        );

        await manager.handleUnauthorizedResponse();

        expect(storage.values, isEmpty);
      },
    );

    test('redacts token values from diagnostics strings', () {
      final tokens = SessionTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );

      expect(tokens.toString(), isNot(contains('access-token')));
      expect(tokens.toString(), isNot(contains('refresh-token')));
    });
  });
}

final class _MemorySecureStorage implements AppSecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
