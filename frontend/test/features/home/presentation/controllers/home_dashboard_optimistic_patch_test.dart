import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';

void main() {
  group('HomeDashboardOptimisticPatch', () {
    test('tenantCreated increments tenant metrics and alert', () {
      const HomeDashboard dashboard = HomeDashboard(
        state: HomeDashboardLoadState.ready,
        profile: HomeDashboardProfile(
          id: 'super_admin',
          role: AppRole.superAdmin,
          roleLabel: 'Super Admin',
          homeTitle: 'Dashboard',
          emptyMessage: 'Empty',
          statusCards: <HomeStatusCardTemplate>[],
          quickActionIds: <String>[],
          shortcutIds: <String>[],
        ),
        context: HomeDashboardContext(),
        statusCards: <HomeStatusCard>[
          HomeStatusCard(
            id: 'tenants_active',
            label: 'Tenants',
            value: 3,
            secondaryValue: 3,
            format: 'ratio',
          ),
          HomeStatusCard(
            id: 'subscriptions_health',
            label: 'Subscriptions',
            value: 1,
            secondaryValue: 3,
            format: 'ratio',
          ),
          HomeStatusCard(
            id: 'facilities_active',
            label: 'Facilities',
            value: 1,
            secondaryValue: 1,
          ),
        ],
        trend: HomeDashboardTrend.empty,
        distribution: HomeDashboardDistribution.empty,
        quickActionIds: <String>[],
        shortcutIds: <String>[],
        queuePreview: <HomeQueueItem>[],
        alerts: <HomeAlertItem>[
          HomeAlertItem(
            id: 'tenants_without_subscription',
            label: 'Tenants Without Subscription',
            severity: 'warning',
            count: 2,
          ),
        ],
        activity: <HomeActivityItem>[],
        tenantOptions: <HomeTenantOption>[],
      );

      final HomeDashboard patched = HomeDashboardOptimisticPatch.tenantCreated()
          .applyTo(dashboard);

      expect(patched.statusCards[0].value, 4);
      expect(patched.statusCards[0].secondaryValue, 4);
      expect(patched.statusCards[1].secondaryValue, 4);
      expect(patched.statusCards[2].value, 2);
      expect(patched.statusCards[2].secondaryValue, 2);
      expect(patched.alerts.first.count, 3);
    });

    test('tenantActiveChanged adjusts active tenant count only', () {
      const HomeDashboard dashboard = HomeDashboard(
        state: HomeDashboardLoadState.ready,
        profile: HomeDashboardProfile(
          id: 'super_admin',
          role: AppRole.superAdmin,
          roleLabel: 'Super Admin',
          homeTitle: 'Dashboard',
          emptyMessage: 'Empty',
          statusCards: <HomeStatusCardTemplate>[],
          quickActionIds: <String>[],
          shortcutIds: <String>[],
        ),
        context: HomeDashboardContext(),
        statusCards: <HomeStatusCard>[
          HomeStatusCard(
            id: 'tenants_active',
            label: 'Tenants',
            value: 3,
            secondaryValue: 4,
            format: 'ratio',
          ),
        ],
        trend: HomeDashboardTrend.empty,
        distribution: HomeDashboardDistribution.empty,
        quickActionIds: <String>[],
        shortcutIds: <String>[],
        queuePreview: <HomeQueueItem>[],
        alerts: <HomeAlertItem>[],
        activity: <HomeActivityItem>[],
        tenantOptions: <HomeTenantOption>[],
      );

      final HomeDashboard patched =
          HomeDashboardOptimisticPatch.tenantActiveChanged(
            wasActive: true,
            isActive: false,
          ).applyTo(dashboard);

      expect(patched.statusCards.first.value, 2);
      expect(patched.statusCards.first.secondaryValue, 4);
    });

    test('patch state stays active until server catches up', () {
      const HomeDashboard baseline = HomeDashboard(
        state: HomeDashboardLoadState.ready,
        profile: HomeDashboardProfile(
          id: 'super_admin',
          role: AppRole.superAdmin,
          roleLabel: 'Super Admin',
          homeTitle: 'Dashboard',
          emptyMessage: 'Empty',
          statusCards: <HomeStatusCardTemplate>[],
          quickActionIds: <String>[],
          shortcutIds: <String>[],
        ),
        context: HomeDashboardContext(),
        statusCards: <HomeStatusCard>[
          HomeStatusCard(
            id: 'tenants_active',
            label: 'Tenants',
            value: 3,
            secondaryValue: 3,
            format: 'ratio',
          ),
        ],
        trend: HomeDashboardTrend.empty,
        distribution: HomeDashboardDistribution.empty,
        quickActionIds: <String>[],
        shortcutIds: <String>[],
        queuePreview: <HomeQueueItem>[],
        alerts: <HomeAlertItem>[
          HomeAlertItem(
            id: 'tenants_without_subscription',
            label: 'Tenants Without Subscription',
            severity: 'warning',
            count: 2,
          ),
        ],
        activity: <HomeActivityItem>[],
        tenantOptions: <HomeTenantOption>[],
      );

      final HomeDashboardOptimisticPatchState state =
          HomeDashboardOptimisticPatchState(
            patch: HomeDashboardOptimisticPatch.tenantCreated(),
            baseline: baseline,
          );

      const HomeDashboard staleServer = baseline;
      const HomeDashboard freshServer = HomeDashboard(
        state: HomeDashboardLoadState.ready,
        profile: HomeDashboardProfile(
          id: 'super_admin',
          role: AppRole.superAdmin,
          roleLabel: 'Super Admin',
          homeTitle: 'Dashboard',
          emptyMessage: 'Empty',
          statusCards: <HomeStatusCardTemplate>[],
          quickActionIds: <String>[],
          shortcutIds: <String>[],
        ),
        context: HomeDashboardContext(),
        statusCards: <HomeStatusCard>[
          HomeStatusCard(
            id: 'tenants_active',
            label: 'Tenants',
            value: 4,
            secondaryValue: 4,
            format: 'ratio',
          ),
        ],
        trend: HomeDashboardTrend.empty,
        distribution: HomeDashboardDistribution.empty,
        quickActionIds: <String>[],
        shortcutIds: <String>[],
        queuePreview: <HomeQueueItem>[],
        alerts: <HomeAlertItem>[
          HomeAlertItem(
            id: 'tenants_without_subscription',
            label: 'Tenants Without Subscription',
            severity: 'warning',
            count: 3,
          ),
        ],
        activity: <HomeActivityItem>[],
        tenantOptions: <HomeTenantOption>[],
      );

      expect(state.isSatisfiedBy(staleServer), isFalse);
      expect(state.isSatisfiedBy(freshServer), isTrue);
    });

    test('fromRealtimePayload decodes backend dashboard deltas', () {
      final HomeDashboardOptimisticPatch? patch =
          HomeDashboardOptimisticPatch.fromRealtimePayload(<String, Object?>{
            'dashboard_deltas': <String, Object?>{
              'status_cards': <String, Object?>{
                'facilities_active': <String, Object?>{
                  'value_delta': 1,
                  'secondary_delta': 1,
                },
              },
            },
          });

      expect(patch, isNotNull);
      expect(patch!.statusCardValueDeltas['facilities_active'], 1);
      expect(patch.statusCardSecondaryDeltas['facilities_active'], 1);
    });
  });
}
