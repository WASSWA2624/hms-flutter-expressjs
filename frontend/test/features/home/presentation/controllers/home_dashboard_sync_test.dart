import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_sync.dart';

void main() {
  group('homeDashboardWithOptimisticPatch', () {
    test('applies patch against baseline until server catches up', () {
      final HomeDashboard baseline = _tenantDashboard(activeCount: 3);
      final HomeDashboard staleServer = baseline;
      final HomeDashboard freshServer = _tenantDashboard(activeCount: 4);

      final HomeDashboardOptimisticPatchState state =
          HomeDashboardOptimisticPatchState(
            patch: HomeDashboardOptimisticPatch.tenantCreated(),
            baseline: baseline,
          );

      expect(
        homeDashboardWithOptimisticPatch(
          staleServer,
          state,
        ).statusCards.first.value,
        4,
      );
      expect(
        homeDashboardWithOptimisticPatch(
          freshServer,
          state,
        ).statusCards.first.value,
        4,
      );
    });
  });

  group('dashboard optimistic patch lifecycle', () {
    test('survives home controller invalidation', () async {
      final HomeDashboard baseline = _tenantDashboard(activeCount: 3);
      final _CountingHomeRepository repository = _CountingHomeRepository(
        Result<HomeDashboard>.success(baseline),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [homeRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      const HomeDashboardRequest request = HomeDashboardRequest.empty;
      await container.read(homeControllerProvider(request).future);

      container
          .read(homeDashboardOptimisticPatchProvider(request).notifier)
          .state = HomeDashboardOptimisticPatchState(
        patch: HomeDashboardOptimisticPatch.tenantCreated(),
        baseline: baseline,
      );
      container.invalidate(homeControllerProvider(request));

      expect(
        container.read(homeDashboardOptimisticPatchProvider(request)),
        isNotNull,
      );

      await container.read(homeControllerProvider(request).future);

      expect(
        container.read(homeDashboardOptimisticPatchProvider(request)),
        isNotNull,
      );
    });
  });
}

final class _CountingHomeRepository implements HomeRepository {
  _CountingHomeRepository(this.result);

  final Result<HomeDashboard> result;
  int callCount = 0;

  @override
  Future<Result<HomeDashboard>> loadDashboard(
    HomeDashboardRequest request,
  ) async {
    callCount += 1;
    return result;
  }

  @override
  Future<Result<HomeDashboardLookups>> loadLookups(
    HomeDashboardRequest request,
  ) async {
    return const Result<HomeDashboardLookups>.success(HomeDashboardLookups());
  }
}

HomeDashboard _tenantDashboard({required int activeCount}) {
  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: const HomeDashboardProfile(
      id: 'super_admin',
      role: AppRole.superAdmin,
      roleLabel: 'Super Admin',
      homeTitle: 'Dashboard',
      emptyMessage: 'Empty',
      statusCards: <HomeStatusCardTemplate>[],
      quickActionIds: <String>[],
      shortcutIds: <String>[],
    ),
    context: const HomeDashboardContext(),
    statusCards: <HomeStatusCard>[
      HomeStatusCard(
        id: 'tenants_active',
        label: 'Tenants',
        value: activeCount,
        secondaryValue: activeCount,
        format: 'ratio',
      ),
    ],
    trend: HomeDashboardTrend.empty,
    distribution: HomeDashboardDistribution.empty,
    quickActionIds: const <String>[],
    shortcutIds: const <String>[],
    queuePreview: const <HomeQueueItem>[],
    alerts: <HomeAlertItem>[
      HomeAlertItem(
        id: 'tenants_without_subscription',
        label: 'Tenants Without Subscription',
        severity: 'warning',
        count: activeCount - 1,
      ),
    ],
    activity: const <HomeActivityItem>[],
    tenantOptions: const <HomeTenantOption>[],
  );
}
