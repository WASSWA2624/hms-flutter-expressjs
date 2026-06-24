import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';

import 'test_harness.dart';

void main() {
  group('provider override examples', () {
    test('builds a ready app container without production services', () {
      final container = createTestContainer(overrides: testReadyAppOverrides());

      expect(container.read(homeRepositoryProvider), isA<HomeRepositoryImpl>());
    });

    test('overrides a repository dependency for controller tests', () async {
      final dashboard = _dashboardFixture();
      final repository = _FakeHomeRepository(
        Result<HomeDashboard>.success(dashboard),
      );
      final container = createTestContainer(
        overrides: <Object?>[
          homeRepositoryProvider.overrideWithValue(repository),
        ],
      );

      final result = await container.read(
        homeControllerProvider(HomeDashboardRequest.empty).future,
      );

      result.when(
        success: (HomeDashboard value) => expect(value, same(dashboard)),
        failure: (_) => fail('Expected overridden repository success.'),
      );
      expect(repository.callCount, 1);
      expect(repository.lastRequest, HomeDashboardRequest.empty);
    });
  });
}

HomeDashboard _dashboardFixture() {
  final profile = homeProfileForRole(AppRole.tenantAdmin);

  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: const HomeDashboardContext(roleValue: 'TENANT_ADMIN'),
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
