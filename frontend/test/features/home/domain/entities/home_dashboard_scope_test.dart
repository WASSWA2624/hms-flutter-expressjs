import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_scope.dart';

void main() {
  group('home dashboard scope', () {
    test('scopes status cards to profile templates', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final List<HomeStatusCard> scoped = scopeHomeStatusCards(
        profile: profile,
        apiCards: const <HomeStatusCard>[
          HomeStatusCard(
            id: 'assigned',
            label: 'Wrong label',
            value: 4,
          ),
          HomeStatusCard(
            id: 'procedures_today',
            label: 'Theatre only',
            value: 9,
          ),
        ],
      );

      expect(scoped.map((card) => card.id), contains('assigned'));
      expect(scoped.map((card) => card.id), isNot(contains('procedures_today')));
      expect(
        scoped.firstWhere((card) => card.id == 'assigned').label,
        'Assigned',
      );
      expect(
        scoped.firstWhere((card) => card.id == 'assigned').value,
        4,
      );
    });

    test('merge uses session profile over API profile', () {
      final HomeDashboardProfile doctor = homeProfileForRole(AppRole.doctor);
      final HomeDashboard merged = mergeHomeDashboardForProfile(
        profile: doctor,
        dashboard: HomeDashboard(
          state: HomeDashboardLoadState.ready,
          profile: homeProfileForRole(AppRole.theatreManager),
          context: const HomeDashboardContext(roleValue: 'THEATRE_MANAGER'),
          statusCards: const <HomeStatusCard>[
            HomeStatusCard(
              id: 'procedures_today',
              label: 'Procedures today',
              value: 2,
            ),
          ],
          trend: HomeDashboardTrend.empty,
          distribution: HomeDashboardDistribution.empty,
          quickActionIds: const <String>['publish_roster'],
          shortcutIds: const <String>['theater'],
          queuePreview: const <HomeQueueItem>[],
          alerts: const <HomeAlertItem>[],
          activity: const <HomeActivityItem>[],
          tenantOptions: const <HomeTenantOption>[],
        ),
      );

      expect(merged.profile.role, AppRole.doctor);
      expect(merged.statusCards.map((card) => card.id), contains('assigned'));
      expect(merged.quickActionIds, contains('start_consultation'));
      expect(merged.quickActionIds, isNot(contains('publish_roster')));
    });
  });
}
