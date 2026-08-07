import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
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
      expect(profile.maxResultsItems, 3);
      expect(profile.maxFollowUpItems, 3);
    });

    test('HR profile caps status cards and suppresses queue', () {
      final profile = homeProfileForRole(AppRole.hr);

      expect(profile.layoutTier, HomeDashboardLayoutTier.workforce);
      expect(profile.showCharts, isTrue);
      expect(profile.showQueuePanel, isFalse);
      expect(profile.effectiveMaxStatusCards, 4);
      expect(profile.maxQuickActions, 0);
      expect(profile.suppressHomeQuickActions, isTrue);
    });

    test('facility admin keeps facility command layout', () {
      final profile = homeProfileForRole(AppRole.facilityAdmin);

      expect(profile.layoutTier, HomeDashboardLayoutTier.facilityCommand);
      expect(profile.showCharts, isTrue);
      expect(profile.effectiveMaxStatusCards, 4);
      expect(profile.showQueuePanelFor(const []), isTrue);
    });

    test('department roles keep queue and metric routing', () {
      final profile = homeProfileForRole(AppRole.labTech);

      expect(profile.layoutTier, HomeDashboardLayoutTier.departmentQueue);
      expect(profile.effectiveMaxStatusCards, 6);
      expect(profile.maxQuickActions, 0);
      expect(profile.showActivityPanel(hasQueueItems: true), isFalse);
      expect(profile.showQueuePanelFor(const []), isTrue);
      expect(profile.metricRouteTargets.keys, contains('lab_pending'));
      expect(
        profile.metricRouteTargets['lab_pending']!.queryParameters,
        <String, String>{'section': 'pending'},
      );
    });

    test('pharmacist dashboard shows pharmacy order and stock metrics', () {
      final profile = homeProfileForRole(AppRole.pharmacist);

      expect(profile.layoutTier, HomeDashboardLayoutTier.departmentQueue);
      expect(profile.isPharmacistDepartmentDashboard, isTrue);
      expect(profile.showQueuePanel, isFalse);
      expect(profile.effectiveMaxStatusCards, 9);
      expect(profile.maxQuickActions, 4);
      expect(profile.maxQueueItems, 5);
      expect(profile.emptyActionIds, isEmpty);
      expect(profile.shortcutIds, isNot(contains('patients')));
      expect(
        profile.statusCards.take(7).map((template) => template.id),
        <String>[
          'orders_today',
          'pending_dispense',
          'dispensed_today',
          'low_stock',
          'out_of_stock',
          'near_expiry',
          'expired',
        ],
      );
      expect(profile.statusCards.first.label, 'Orders today');
      expect(profile.statusCards[2].label, 'Dispensed today');
      expect(profile.quickActionIds, <String>[
        'dispense_medication',
        'record_pharmacy_sale',
        'receive_pharmacy_stock',
      ]);
      expect(profile.metricRouteTargets.keys, contains('pending_dispense'));
      expect(profile.metricRouteTargets['low_stock']!.queryParameters, <String, String>{
        'section': 'low-stock',
      });
      expect(
        profile.metricRouteTargets['out_of_stock']!.queryParameters,
        <String, String>{'section': 'out-of-stock'},
      );
      expect(profile.emptyMessage, 'No pending orders.');
    });

    test(
      'pharmacist expand with patient:read omits admissions and appointments',
      () {
        final AppAccessPolicy policy = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'token'),
            user: const AuthUserProfile(
              roles: <String>['PHARMACIST'],
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
            ),
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
              AppPermissions.patientRead,
            },
            moduleEntitlements: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'pharmacy-dispensing',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'patient-registry',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'scheduling-queue',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'inpatient-bed-management',
                licenseStatus: 'ACTIVE',
              ),
            ],
            isAuthorizationHydrated: true,
          ),
        );
        final HomeDashboardProfile expanded = homeProfileForAccessPolicy(policy);
        final List<String> ids = expanded.statusCards
            .take(expanded.effectiveMaxStatusCards)
            .map((HomeStatusCardTemplate card) => card.id)
            .toList(growable: false);

        expect(expanded.id, 'pharmacist');
        expect(expanded.effectiveMaxStatusCards, 9);
        expect(ids, isNot(contains('appointments_today')));
        expect(ids, isNot(contains('active_admissions')));
        expect(
          ids,
          containsAll(<String>[
            'orders_today',
            'pending_dispense',
            'dispensed_today',
            'low_stock',
            'out_of_stock',
          ]),
        );
      },
    );

    test(
      'receptionist dashboard emphasizes desk queue active visits and follow-ups',
      () {
        final profile = homeProfileForRole(AppRole.receptionist);

        expect(profile.layoutTier, HomeDashboardLayoutTier.departmentQueue);
        expect(profile.isReceptionistFrontDeskDashboard, isTrue);
        expect(profile.effectiveMaxStatusCards, 6);
        expect(profile.showQueuePanel, isFalse);
        expect(profile.maxQuickActions, 4);
        expect(profile.maxQueueItems, 5);
        expect(profile.maxFollowUpItems, 3);
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
        expect(
          profile.statusCards.map((template) => template.id),
          isNot(contains('opd_notifications_attention')),
        );
        expect(profile.statusCards.first.label, 'Appointments today');
        expect(profile.quickActionIds, <String>[
          'register_patient',
          'book_appointment',
          'route_patient',
        ]);
        expect(
          profile.metricRouteTargets['desk_queue']?.queryParameters,
          <String, String>{'section': 'desk-queue'},
        );
        expect(
          profile.metricRouteTargets['no_show_pressure']?.queryParameters,
          <String, String>{'section': 'follow-ups'},
        );
        expect(
          profile.metricRouteTargets['pending_balance_amount']?.queryParameters,
          <String, String>{'section': 'payment-gate'},
        );
        expect(profile.metricRouteTargets.keys, contains('appointments_today'));
        expect(profile.emptyMessage, 'No desk queue items right now.');
      },
    );
  });
}
