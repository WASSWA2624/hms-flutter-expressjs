import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';

void main() {
  group('home dashboard layout', () {
    test('frontline roles show charts with unified section order', () {
      final profile = homeProfileForRole(AppRole.doctor);

      expect(profile.layoutTier, HomeDashboardLayoutTier.clinicalQueue);
      expect(profile.showCharts, isTrue);
      expect(profile.queueBeforeMetrics, isFalse);
      expect(profile.alertsBeforeMetrics, isTrue);
      expect(profile.effectiveMaxStatusCards, 4);
      expect(profile.maxQuickActions, 5);
      expect(profile.showShortcutsSection(quickActionCount: 2), isTrue);
      expect(profile.maxShortcutTiles, 6);
      expect(profile.maxResultsItems, 3);
      expect(profile.maxFollowUpItems, 3);
    });

    test('HR profile caps status cards and enables shortcuts', () {
      final profile = homeProfileForRole(AppRole.hr);

      expect(profile.layoutTier, HomeDashboardLayoutTier.workforce);
      expect(profile.showCharts, isTrue);
      expect(profile.showQueuePanel, isFalse);
      expect(profile.effectiveMaxStatusCards, 4);
      expect(profile.maxQuickActions, 0);
      expect(profile.suppressHomeQuickActions, isTrue);
      expect(profile.showShortcutsSection(quickActionCount: 0), isTrue);
    });

    test('facility admin keeps admin shortcuts', () {
      final profile = homeProfileForRole(AppRole.facilityAdmin);

      expect(profile.layoutTier, HomeDashboardLayoutTier.facilityCommand);
      expect(profile.showCharts, isTrue);
      expect(profile.effectiveMaxStatusCards, 4);
      expect(profile.maxShortcutTiles, 2);
      expect(profile.showQueuePanelFor(const []), isTrue);
    });

    test('department roles can show shortcuts when configured', () {
      final profile = homeProfileForRole(AppRole.labTech);

      expect(profile.layoutTier, HomeDashboardLayoutTier.departmentQueue);
      expect(profile.effectiveMaxStatusCards, 4);
      expect(profile.maxQuickActions, 3);
      expect(profile.showActivityPanel(hasQueueItems: true), isFalse);
      expect(profile.showShortcutsSection(quickActionCount: 2), isTrue);
      expect(profile.maxShortcutTiles, 3);
      expect(profile.showQueuePanelFor(const []), isTrue);
      expect(profile.quickActionIds, <String>[
        'receive_sample',
        'enter_lab_result',
        'flag_critical_lab',
      ]);
      expect(profile.metricRouteTargets.keys, contains('pending_results'));
    });

    test('pharmacist dashboard shows four metrics and quick actions', () {
      final profile = homeProfileForRole(AppRole.pharmacist);

      expect(profile.layoutTier, HomeDashboardLayoutTier.departmentQueue);
      expect(profile.isPharmacistDepartmentDashboard, isTrue);
      expect(profile.effectiveMaxStatusCards, 4);
      expect(profile.maxQuickActions, 4);
      expect(profile.maxQueueItems, 5);
      expect(profile.emptyActionIds, isEmpty);
      expect(
        profile.statusCards.take(4).map((template) => template.id),
        <String>[
          'orders_today',
          'pending_dispense',
          'dispensed_today',
          'low_stock',
        ],
      );
      expect(profile.quickActionIds, <String>[
        'dispense_medication',
        'record_pharmacy_sale',
        'receive_pharmacy_stock',
        'adjust_pharmacy_stock',
      ]);
      expect(profile.metricRouteTargets.keys, contains('pending_dispense'));
      expect(profile.emptyMessage, contains('No pending orders'));
    });

    test(
      'receptionist dashboard emphasizes meetings follow-up and quick links',
      () {
        final profile = homeProfileForRole(AppRole.receptionist);

        expect(profile.layoutTier, HomeDashboardLayoutTier.departmentQueue);
        expect(profile.isReceptionistFrontDeskDashboard, isTrue);
        expect(profile.effectiveMaxStatusCards, 4);
        expect(profile.maxQuickActions, 4);
        expect(profile.maxQueueItems, 5);
        expect(profile.maxFollowUpItems, 3);
        expect(profile.maxShortcutTiles, 5);
        expect(profile.emptyActionIds, isEmpty);
        expect(
          profile.statusCards.take(4).map((template) => template.id),
          <String>[
            'appointments_today',
            'desk_queue',
            'turnaround_pressure',
            'no_show_pressure',
          ],
        );
        expect(profile.quickActionIds, <String>[
          'register_patient',
          'book_appointment',
          'check_in_patient',
          'route_patient',
        ]);
        expect(profile.shortcutIds, <String>[
          'patients',
          'opd',
          'emergency',
          'communications',
          'settings',
        ]);
        expect(profile.metricRouteTargets.keys, contains('appointments_today'));
        expect(profile.emptyMessage, contains('quick links'));
      },
    );
  });
}
