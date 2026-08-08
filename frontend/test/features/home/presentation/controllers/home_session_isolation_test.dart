import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_session_isolation.dart';

void main() {
  group('homeSessionIsolationBinderProvider', () {
    test(
      'epoch bump after Home dispose drops prior account dashboard state',
      () async {
        final Completer<Result<HomeDashboard>> nextLoad =
            Completer<Result<HomeDashboard>>();
        var loadCount = 0;
        final repository = _SequencedHomeRepository((int call) {
          loadCount = call;
          if (call == 1) {
            return Future<Result<HomeDashboard>>.value(
              Result<HomeDashboard>.success(_platformDashboard(value: 11)),
            );
          }
          return nextLoad.future;
        });
        final container = ProviderContainer(
          overrides: [homeRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final binderSub = container.listen(
          homeSessionIsolationBinderProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(binderSub.close);

        final homeSub = container.listen(
          homeControllerProvider(HomeDashboardRequest.empty),
          (_, _) {},
          fireImmediately: true,
        );

        final Result<HomeDashboard> first = await container.read(
          homeControllerProvider(HomeDashboardRequest.empty).future,
        );
        first.when(
          success: (HomeDashboard dashboard) {
            expect(dashboard.statusCards.first.value, 11);
          },
          failure: (_) => fail('Expected first dashboard load.'),
        );
        expect(loadCount, 1);

        // Leaving Home (logout → login route) disposes autoDispose keep-alive.
        homeSub.close();
        await container.pump();

        expect(
          container.exists(homeControllerProvider(HomeDashboardRequest.empty)),
          isFalse,
          reason: 'Home dashboard must dispose when no longer watched',
        );

        container.read(sessionEpochProvider.notifier).bump();
        await container.pump();

        final AsyncValue<Result<HomeDashboard>> afterEpoch = container.read(
          homeControllerProvider(HomeDashboardRequest.empty),
        );
        expect(
          afterEpoch.hasValue,
          isFalse,
          reason: 'Prior account dashboard must not survive session isolation',
        );
        expect(afterEpoch.isLoading, isTrue);

        nextLoad.complete(
          Result<HomeDashboard>.success(_platformDashboard(value: 42)),
        );
        final Result<HomeDashboard> second = await container.read(
          homeControllerProvider(HomeDashboardRequest.empty).future,
        );
        second.when(
          success: (HomeDashboard dashboard) {
            expect(dashboard.statusCards.first.value, 42);
          },
          failure: (_) => fail('Expected post-isolation dashboard load.'),
        );
        expect(loadCount, greaterThanOrEqualTo(2));
      },
    );
  });
}

HomeDashboard _platformDashboard({required int value}) {
  final HomeDashboardProfile profile = homeProfileForRole(AppRole.superAdmin);
  return HomeDashboard(
    state: HomeDashboardLoadState.ready,
    profile: profile,
    context: const HomeDashboardContext(roleValue: 'SUPER_ADMIN'),
    statusCards: <HomeStatusCard>[
      HomeStatusCard(
        id: 'tenants_active',
        label: 'Tenants',
        value: value,
        secondaryValue: value + 1,
      ),
    ],
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

final class _SequencedHomeRepository implements HomeRepository {
  _SequencedHomeRepository(this._loader);

  final Future<Result<HomeDashboard>> Function(int call) _loader;
  int _callCount = 0;

  @override
  Future<Result<HomeDashboard>> loadDashboard(
    HomeDashboardRequest request,
  ) async {
    _callCount += 1;
    return _loader(_callCount);
  }

  @override
  Future<Result<HomeDashboardLookups>> loadLookups(
    HomeDashboardRequest request,
  ) async {
    return const Result<HomeDashboardLookups>.success(HomeDashboardLookups());
  }
}
