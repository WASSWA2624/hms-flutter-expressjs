import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/secure/app_secure_storage.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';

void main() {
  group('HomeController', () {
    test('loads dashboard through an overridden repository provider', () async {
      final dashboard = _dashboardFixture();
      final repository = _FakeHomeRepository(
        Result<HomeDashboard>.success(dashboard),
      );
      final container = ProviderContainer(
        overrides: [homeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final value = await container.read(
        homeControllerProvider(HomeDashboardRequest.empty).future,
      );

      value.when(
        success: (HomeDashboard loadedDashboard) {
          expect(loadedDashboard, same(dashboard));
        },
        failure: (_) => fail('Expected a successful dashboard result.'),
      );
      expect(repository.callCount, 1);
      expect(repository.lastRequest?.phase, HomeDashboardPhase.core);
      expect(
        container.read(homeControllerProvider(HomeDashboardRequest.empty)),
        isA<AsyncData<Result<HomeDashboard>>>(),
      );
    });

    test('enriches a partial core pack with the full workspace', () async {
      final HomeDashboard core = _dashboardFixture(
        role: AppRole.doctor,
        state: HomeDashboardLoadState.partial,
      );
      final HomeDashboard full = _dashboardFixture(
        role: AppRole.doctor,
        state: HomeDashboardLoadState.ready,
      );
      final repository = _SequencedHomeRepository(<Result<HomeDashboard>>[
        Result<HomeDashboard>.success(core),
        Result<HomeDashboard>.success(full),
      ]);
      final container = ProviderContainer(
        overrides: [homeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final List<HomeDashboardLoadState> states = <HomeDashboardLoadState>[];
      final subscription = container.listen(
        homeCoreControllerProvider(HomeDashboardRequest.empty),
        (
          AsyncValue<Result<HomeDashboard>>? previous,
          AsyncValue<Result<HomeDashboard>> next,
        ) {
          next.whenData((Result<HomeDashboard> result) {
            result.when(
              success: (HomeDashboard dashboard) => states.add(dashboard.state),
              failure: (_) {},
            );
          });
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final Result<HomeDashboard> coreResult = await container.read(
        homeCoreControllerProvider(HomeDashboardRequest.empty).future,
      );
      coreResult.when(
        success: (HomeDashboard dashboard) {
          expect(dashboard.state, HomeDashboardLoadState.partial);
        },
        failure: (_) => fail('Expected partial core pack.'),
      );

      final Result<HomeDashboard> completed = await container.read(
        homeControllerProvider(HomeDashboardRequest.empty).future,
      );

      expect(repository.callCount, 2);
      expect(repository.phases, <HomeDashboardPhase>[
        HomeDashboardPhase.core,
        HomeDashboardPhase.full,
      ]);
      expect(states, contains(HomeDashboardLoadState.partial));
      completed.when(
        success: (HomeDashboard dashboard) {
          expect(dashboard.state, HomeDashboardLoadState.ready);
          expect(dashboard, same(full));
        },
        failure: (_) => fail('Expected enriched dashboard.'),
      );
    });

    test('exposes repository failures as typed result state', () async {
      const failure = AppFailure.network();
      final repository = _FakeHomeRepository(
        const Result<HomeDashboard>.failure(failure),
      );
      final container = ProviderContainer(
        overrides: [homeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final value = await container.read(
        homeControllerProvider(HomeDashboardRequest.empty).future,
      );

      value.when(
        success: (_) => fail('Expected a failed dashboard result.'),
        failure: (AppFailure mappedFailure) => expect(mappedFailure, failure),
      );
      expect(
        container
            .read(homeControllerProvider(HomeDashboardRequest.empty))
            .hasError,
        isFalse,
      );
      expect(repository.callCount, 1);
    });

    test('reloads when session identity changes after account switch', () async {
      final first = _dashboardFixture(role: AppRole.doctor);
      final second = _dashboardFixture(role: AppRole.nurse);
      final repository = _SequencedHomeRepository(<Result<HomeDashboard>>[
        Result<HomeDashboard>.success(first),
        Result<HomeDashboard>.success(second),
      ]);
      final firstSession = AuthSession(
        tokens: SessionTokens(accessToken: 'token-1'),
        user: const AuthUserProfile(
          id: 'user-1',
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
        ),
      );
      final secondSession = AuthSession(
        tokens: SessionTokens(accessToken: 'token-2'),
        user: const AuthUserProfile(
          id: 'user-2',
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(session: firstSession),
          ),
          secureSessionStorageProvider.overrideWithValue(
            SecureAppSessionStorage(_MemorySecureStorage()),
          ),
          sessionIsolationServiceProvider.overrideWith(
            (Ref ref) => _EpochOnlySessionIsolation(ref),
          ),
          homeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        homeControllerProvider(HomeDashboardRequest.empty),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final Result<HomeDashboard> firstResult = await container.read(
        homeControllerProvider(HomeDashboardRequest.empty).future,
      );
      firstResult.when(
        success: (HomeDashboard loaded) => expect(loaded, same(first)),
        failure: (_) => fail('Expected first dashboard.'),
      );
      expect(repository.callCount, 1);

      await container
          .read(sessionStateProvider.notifier)
          .persistSession(secondSession);

      final Result<HomeDashboard> secondResult = await container.read(
        homeControllerProvider(HomeDashboardRequest.empty).future,
      );
      secondResult.when(
        success: (HomeDashboard loaded) => expect(loaded, same(second)),
        failure: (_) => fail('Expected second dashboard.'),
      );
      expect(repository.callCount, greaterThanOrEqualTo(2));
    });
    test('reloads when authorization enrichment updates the session', () async {
      final limited = _dashboardFixture(role: AppRole.other);
      final lab = _dashboardFixture(role: AppRole.labTech);
      final repository = _SequencedHomeRepository(<Result<HomeDashboard>>[
        Result<HomeDashboard>.success(limited),
        Result<HomeDashboard>.success(lab),
      ]);
      final jwtSession = AuthSession(
        tokens: SessionTokens(accessToken: 'token-1'),
        user: const AuthUserProfile(
          id: 'user-1',
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['LAB_TECH'],
        ),
        isAuthorizationHydrated: false,
        isModuleCatalogHydrated: false,
      );
      final enrichedSession = AuthSession(
        tokens: SessionTokens(accessToken: 'token-1'),
        user: const AuthUserProfile(
          id: 'user-1',
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['LAB_TECH'],
        ),
        permissions: <AppPermission>{
          const AppPermission('lab.read'),
          const AppPermission('profile.read'),
        },
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'lab'),
        ],
        isAuthorizationHydrated: true,
        isModuleCatalogHydrated: true,
      );
      final container = ProviderContainer(
        overrides: [
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(session: jwtSession),
          ),
          secureSessionStorageProvider.overrideWithValue(
            SecureAppSessionStorage(_MemorySecureStorage()),
          ),
          sessionIsolationServiceProvider.overrideWith(
            (Ref ref) => _EpochOnlySessionIsolation(ref),
          ),
          homeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        homeControllerProvider(HomeDashboardRequest.empty),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final Result<HomeDashboard> firstResult = await container.read(
        homeControllerProvider(HomeDashboardRequest.empty).future,
      );
      firstResult.when(
        success: (HomeDashboard loaded) => expect(loaded, same(limited)),
        failure: (_) => fail('Expected limited dashboard.'),
      );
      expect(repository.callCount, 1);

      await container
          .read(sessionStateProvider.notifier)
          .persistSession(enrichedSession);

      final Result<HomeDashboard> secondResult = await container.read(
        homeControllerProvider(HomeDashboardRequest.empty).future,
      );
      secondResult.when(
        success: (HomeDashboard loaded) => expect(loaded, same(lab)),
        failure: (_) => fail('Expected enriched lab dashboard.'),
      );
      expect(repository.callCount, greaterThanOrEqualTo(2));
    });
  });
}

HomeDashboard _dashboardFixture({
  AppRole role = AppRole.tenantAdmin,
  HomeDashboardLoadState state = HomeDashboardLoadState.ready,
}) {
  final profile = homeProfileForRole(role);

  return HomeDashboard(
    state: state,
    profile: profile,
    context: HomeDashboardContext(
      roleValue: profile.role.value,
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
    ),
    statusCards: profile.fallbackStatusCards(),
    trend: HomeDashboardTrend.empty,
    distribution: HomeDashboardDistribution.empty,
    quickActionIds: profile.quickActionIds,
    shortcutIds: profile.shortcutIds,
    queuePreview: const <HomeQueueItem>[],
    alerts: const <HomeAlertItem>[],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
  );
}

final class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository(this.result);

  final Result<HomeDashboard> result;
  int callCount = 0;
  HomeDashboardRequest? lastRequest;

  @override
  Future<Result<HomeDashboard>> loadDashboard(
    HomeDashboardRequest request,
  ) async {
    callCount += 1;
    lastRequest = request;
    return result;
  }

  @override
  Future<Result<HomeDashboardLookups>> loadLookups(
    HomeDashboardRequest request,
  ) async {
    return const Result<HomeDashboardLookups>.success(HomeDashboardLookups());
  }
}

final class _SequencedHomeRepository implements HomeRepository {
  _SequencedHomeRepository(this.results);

  final List<Result<HomeDashboard>> results;
  int callCount = 0;
  final List<HomeDashboardPhase?> phases = <HomeDashboardPhase?>[];

  @override
  Future<Result<HomeDashboard>> loadDashboard(
    HomeDashboardRequest request,
  ) async {
    phases.add(request.phase);
    final int index = callCount.clamp(0, results.length - 1);
    callCount += 1;
    return results[index];
  }

  @override
  Future<Result<HomeDashboardLookups>> loadLookups(
    HomeDashboardRequest request,
  ) async {
    return const Result<HomeDashboardLookups>.success(HomeDashboardLookups());
  }
}

final class _EpochOnlySessionIsolation extends SessionIsolationService {
  _EpochOnlySessionIsolation(super.ref);

  @override
  Future<void> disposeAuthenticatedState({
    bool closeNetwork = true,
    bool clearLocalCaches = true,
  }) async {
    ref.read(sessionEpochProvider.notifier).bump();
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
