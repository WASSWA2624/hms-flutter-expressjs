import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';

void main() {
  group('home dashboard layout', () {
    test('frontline roles hide charts and prioritize queue', () {
      final profile = homeProfileForRole(AppRole.doctor);

      expect(profile.layoutTier, HomeDashboardLayoutTier.clinicalQueue);
      expect(profile.showCharts, isFalse);
      expect(profile.queueBeforeMetrics, isTrue);
      expect(profile.maxStatusCards, 4);
    });

    test('HR profile is KPI-first workforce layout', () {
      final profile = homeProfileForRole(AppRole.hr);

      expect(profile.layoutTier, HomeDashboardLayoutTier.workforce);
      expect(profile.showCharts, isFalse);
      expect(profile.showQueuePanel, isFalse);
      expect(profile.maxStatusCards, 8);
      expect(profile.suppressHomeQuickActions, isTrue);
      expect(profile.suppressHomeShortcuts, isTrue);
    });

    test('facility admin keeps charts and six KPI cap', () {
      final profile = homeProfileForRole(AppRole.facilityAdmin);

      expect(profile.layoutTier, HomeDashboardLayoutTier.facilityCommand);
      expect(profile.showCharts, isTrue);
      expect(profile.queueBeforeMetrics, isFalse);
      expect(profile.maxStatusCards, 6);
    });

    test('department roles hide activity and shortcuts', () {
      final profile = homeProfileForRole(AppRole.labTech);

      expect(profile.layoutTier, HomeDashboardLayoutTier.departmentQueue);
      expect(profile.showActivityPanel(hasQueueItems: true), isFalse);
      expect(profile.showShortcutsSection(quickActionCount: 2), isFalse);
    });
  });
}
