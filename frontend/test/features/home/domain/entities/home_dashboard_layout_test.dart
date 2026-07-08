import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';

void main() {
  group('home dashboard layout', () {
    test('frontline roles hide charts and cap density', () {
      final profile = homeProfileForRole(AppRole.doctor);

      expect(profile.layoutTier, HomeDashboardLayoutTier.clinicalQueue);
      expect(profile.showCharts, isFalse);
      expect(profile.queueBeforeMetrics, isTrue);
      expect(profile.effectiveMaxStatusCards, 3);
      expect(profile.maxQuickActions, 2);
      expect(profile.showQueuePanelFor(const []), isFalse);
    });

    test('HR profile is KPI-first workforce layout', () {
      final profile = homeProfileForRole(AppRole.hr);

      expect(profile.layoutTier, HomeDashboardLayoutTier.workforce);
      expect(profile.showCharts, isFalse);
      expect(profile.showQueuePanel, isFalse);
      expect(profile.effectiveMaxStatusCards, 6);
      expect(profile.maxQuickActions, 0);
      expect(profile.suppressHomeQuickActions, isTrue);
      expect(profile.suppressHomeShortcuts, isTrue);
    });

    test('facility admin keeps admin shortcuts only', () {
      final profile = homeProfileForRole(AppRole.facilityAdmin);

      expect(profile.layoutTier, HomeDashboardLayoutTier.facilityCommand);
      expect(profile.showCharts, isFalse);
      expect(profile.effectiveMaxStatusCards, 4);
      expect(profile.maxShortcutTiles, 2);
      expect(profile.showQueuePanelFor(const []), isTrue);
    });

    test('department roles hide shortcuts and empty queues', () {
      final profile = homeProfileForRole(AppRole.labTech);

      expect(profile.layoutTier, HomeDashboardLayoutTier.departmentQueue);
      expect(profile.showActivityPanel(hasQueueItems: true), isFalse);
      expect(profile.showShortcutsSection(quickActionCount: 2), isFalse);
      expect(profile.showQueuePanelFor(const []), isFalse);
    });
  });
}
