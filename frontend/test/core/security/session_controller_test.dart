import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/secure/app_secure_storage.dart';

void main() {
  group('SessionController', () {
    test('starts from the initial session state override', () {
      const reportsReadPermission = AppPermission('reports.read');
      final initialSession = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        permissions: <AppPermission>{reportsReadPermission},
      );
      final container = ProviderContainer(
        overrides: [
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(session: initialSession),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(sessionStateProvider).isAuthenticated, isTrue);
      expect(
        container
            .read(grantedAppPermissionsProvider)
            .grants(reportsReadPermission),
        isTrue,
      );
    });

    test('logout clears sensitive session data and state', () async {
      final storage = _MemorySecureStorage()
        ..values[SecureStorageKeys.accessToken] = 'access-token'
        ..values[SecureStorageKeys.refreshToken] = 'refresh-token';
      final initialSession = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
      );
      final container = ProviderContainer(
        overrides: [
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(session: initialSession),
          ),
          secureSessionStorageProvider.overrideWithValue(
            SecureAppSessionStorage(storage),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionStateProvider.notifier).logout();

      expect(
        container.read(sessionStateProvider).status,
        SessionStatus.unauthenticated,
      );
      expect(storage.values, isEmpty);
    });

    test(
      'unauthorized responses clear storage and mark the session expired',
      () async {
        final storage = _MemorySecureStorage()
          ..values[SecureStorageKeys.accessToken] = 'access-token'
          ..values[SecureStorageKeys.refreshToken] = 'refresh-token';
        final container = ProviderContainer(
          overrides: [
            secureSessionStorageProvider.overrideWithValue(
              SecureAppSessionStorage(storage),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionStateProvider.notifier)
            .handleUnauthorizedResponse();

        expect(
          container.read(sessionStateProvider).status,
          SessionStatus.expired,
        );
        expect(storage.values, isEmpty);
      },
    );
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
