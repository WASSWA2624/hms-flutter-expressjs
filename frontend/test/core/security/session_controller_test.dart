import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/secure/app_secure_storage.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart';

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
          sessionIsolationServiceProvider.overrideWith(
            (Ref ref) => _NoopSessionIsolation(ref),
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
      expect(container.read(sessionEpochProvider), greaterThan(0));
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
            sessionIsolationServiceProvider.overrideWith(
              (Ref ref) => _NoopSessionIsolation(ref),
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

    test('account context switch invokes session isolation', () async {
      final storage = _MemorySecureStorage();
      final previousSession = AuthSession(
        tokens: SessionTokens(accessToken: 'previous-token'),
        user: const AuthUserProfile(
          id: 'user-1',
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
        ),
      );
      final nextSession = AuthSession(
        tokens: SessionTokens(accessToken: 'next-token'),
        user: const AuthUserProfile(
          id: 'user-2',
          tenantId: 'tenant-2',
          facilityId: 'facility-2',
        ),
      );
      late _RecordingSessionIsolation isolation;
      final container = ProviderContainer(
        overrides: [
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(session: previousSession),
          ),
          secureSessionStorageProvider.overrideWithValue(
            SecureAppSessionStorage(storage),
          ),
          sessionIsolationServiceProvider.overrideWith((Ref ref) {
            return isolation = _RecordingSessionIsolation(ref);
          }),
        ],
      );
      addTearDown(container.dispose);

      final Future<void> switchFuture = container
          .read(sessionStateProvider.notifier)
          .persistSession(nextSession);

      expect(isolation.disposeCalls, 1);
      expect(container.read(sessionEpochProvider), 1);
      expect(
        container.read(sessionStateProvider).status,
        SessionStatus.unknown,
      );
      expect(container.read(sessionStateProvider).session, isNull);

      isolation.complete();
      await switchFuture;

      expect(container.read(sessionStateProvider).session, same(nextSession));
    });

    test('session-scoped controller state cannot survive an epoch bump', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tenantFacilitySetupRefreshProvider.notifier).start();
      expect(container.read(tenantFacilitySetupRefreshProvider), isTrue);

      container.read(sessionEpochProvider.notifier).bump();

      expect(container.read(tenantFacilitySetupRefreshProvider), isFalse);
    });

    test(
      'epoch reload exposes neutral loading without previous data',
      () async {
        final Completer<String> nextValue = Completer<String>();
        var loadCount = 0;
        final container = ProviderContainer(
          overrides: [
            _sessionScopedLoaderProvider.overrideWithValue(() {
              loadCount += 1;
              return loadCount == 1
                  ? Future<String>.value('previous-context')
                  : nextValue.future;
            }),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          _sessionScopedValueProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        expect(
          await container.read(_sessionScopedValueProvider.future),
          'previous-context',
        );

        container.read(sessionEpochProvider.notifier).bump();
        await Future<void>.delayed(Duration.zero);

        final loading = container.read(_sessionScopedValueProvider);
        expect(loading.isLoading, isTrue);
        expect(loading.hasValue, isFalse);

        nextValue.complete('next-context');
        expect(
          await container.read(_sessionScopedValueProvider.future),
          'next-context',
        );
      },
    );
  });
}

final _sessionScopedLoaderProvider = Provider<Future<String> Function()>(
  (_) async => 'unused',
);

final _sessionScopedValueProvider =
    AsyncNotifierProvider<_SessionScopedValueController, String>(
      _SessionScopedValueController.new,
    );

final class _SessionScopedValueController extends AsyncNotifier<String> {
  @override
  Future<String> build() {
    watchSessionEpoch(ref);
    return ref.read(_sessionScopedLoaderProvider)();
  }
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

final class _NoopSessionIsolation extends SessionIsolationService {
  _NoopSessionIsolation(super.ref);

  @override
  Future<void> disposeAuthenticatedState({
    bool closeNetwork = true,
    bool clearLocalCaches = true,
  }) async {
    ref.read(sessionEpochProvider.notifier).bump();
  }
}

final class _RecordingSessionIsolation extends SessionIsolationService {
  _RecordingSessionIsolation(super.ref);

  final Completer<void> _release = Completer<void>();
  int disposeCalls = 0;

  void complete() {
    _release.complete();
  }

  @override
  Future<void> disposeAuthenticatedState({
    bool closeNetwork = true,
    bool clearLocalCaches = true,
  }) async {
    disposeCalls += 1;
    ref.read(sessionEpochProvider.notifier).bump();
    await _release.future;
  }
}
