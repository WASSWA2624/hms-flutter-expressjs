import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
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
      expect(repository.lastRequest, HomeDashboardRequest.empty);
      expect(
        container.read(homeControllerProvider(HomeDashboardRequest.empty)),
        isA<AsyncData<Result<HomeDashboard>>>(),
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
  });
}

HomeDashboard _dashboardFixture() {
  final profile = homeProfileForRole(AppRole.tenantAdmin);

  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: const HomeDashboardContext(roleValue: 'TENANT_ADMIN'),
    statusCards: profile.fallbackStatusCards(),
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
}
