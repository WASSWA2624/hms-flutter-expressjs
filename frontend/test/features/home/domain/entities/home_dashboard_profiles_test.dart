import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';

void main() {
  group('home dashboard profiles', () {
    test('defines a dedicated profile for every canonical role', () {
      for (final AppRole role in AppRole.values) {
        final profile = homeProfileForRole(role);

        expect(profile.role, role);
        if (role != AppRole.operations) {
          expect(profile.id, isNot('operations'));
        }
        expect(profile.id, isNot('admin'));
      }
    });

    test('only patient-flow roles include OPD notification status cards', () {
      const allowedRoles = <AppRole>{
        AppRole.facilityAdmin,
        AppRole.doctor,
        AppRole.nurse,
        AppRole.receptionist,
        AppRole.wardManager,
      };

      for (final AppRole role in AppRole.values) {
        final hasOpdStatusCard = homeProfileForRole(role).statusCards.any((
          template,
        ) {
          return template.id == 'opd_notifications_attention';
        });

        expect(
          hasOpdStatusCard,
          allowedRoles.contains(role),
          reason: role.value,
        );
      }
    });

    test('super admin profile uses platform create and manage actions', () {
      final profile = homeProfileForRole(AppRole.superAdmin);

      expect(profile.quickActionIds, isEmpty);
      expect(profile.emptyActionIds, <String>[
        'manage_tenants',
        'manage_facilities',
        'manage_roles_access',
        'manage_users',
      ]);
      expect(profile.quickActionIds, isNot(contains('select_context')));
      expect(profile.shortcutIds.length, greaterThanOrEqualTo(4));
    });

    test('tenant admin profile uses facility governance actions only', () {
      final profile = homeProfileForRole(AppRole.tenantAdmin);

      expect(profile.quickActionIds, isEmpty);
      expect(profile.quickActionIds, isNot(contains('manage_subscription')));
      expect(profile.quickActionIds, isNot(contains('manage_users_roles')));
      expect(profile.quickActionIds, isNot(contains('manage_users')));
      expect(profile.emptyActionIds, <String>[
        'manage_facilities',
        'manage_roles_access',
        'manage_users',
        'add_staff_profile',
      ]);
      expect(
        profile.shortcutIds,
        containsAll(<String>[
          'tenant_facility_setup',
          'settings',
          'reports',
          'subscriptions',
        ]),
      );
      expect(profile.statusCards.map((template) => template.id), <String>[
        'facilities_active',
        'active_users',
        'module_adoption',
        'subscription_health',
      ]);
      expect(profile.emptyMessage, isEmpty);
      for (final actionId in <String>[
        'start_consultation',
        'record_vitals',
        'enter_lab_result',
        'dispense_medication',
      ]) {
        expect(profile.quickActionIds, isNot(contains(actionId)));
      }
    });

    test('facility admin and receptionist omit check-in duplicate of book', () {
      final facility = homeProfileForRole(AppRole.facilityAdmin);
      final receptionist = homeProfileForRole(AppRole.receptionist);

      expect(facility.quickActionIds, <String>[
        'register_patient',
        'book_appointment',
      ]);
      expect(facility.quickActionIds, isNot(contains('check_in_patient')));
      expect(facility.emptyActionIds, isEmpty);
      expect(receptionist.quickActionIds, <String>[
        'register_patient',
        'book_appointment',
        'route_patient',
      ]);
      expect(receptionist.quickActionIds, isNot(contains('check_in_patient')));
    });

    test('patient profile keeps one profile entry and contact', () {
      final patient = homeProfileForRole(AppRole.patient);

      expect(patient.quickActionIds, <String>[
        'update_own_profile',
        'contact_facility',
      ]);
      expect(patient.quickActionIds, isNot(contains('view_my_care')));
      expect(patient.emptyActionIds, isEmpty);
    });

    test('patient and fallback profiles stay self-service only', () {
      final patient = homeProfileForRole(AppRole.patient);
      final fallback = homeProfileForRole(AppRole.other);

      expect(
        patient.statusCards.map((template) => template.id),
        containsAll(<String>[
          'my_upcoming_appointments',
          'my_open_bills',
          'my_prescriptions',
          'my_released_results',
          'my_messages',
          'my_profile_status',
        ]),
      );
      expect(patient.quickActionIds, isNot(contains('register_patient')));
      expect(fallback.statusCards.map((template) => template.id), [
        'profile_status',
        'assigned_links',
        'unread_messages',
        'facility_notices',
      ]);
      expect(fallback.quickActionIds, isNot(contains('register_patient')));
    });

    test('HR profile is read-only insight surface', () {
      final profile = homeProfileForRole(AppRole.hr);

      expect(profile.quickActionIds, isEmpty);
      expect(profile.shortcutIds, containsAll(<String>['hr', 'reports']));
      expect(profile.emptyActionIds, isEmpty);
      expect(profile.maxStatusCards, 4);
      expect(
        profile.toolbarActionIds,
        contains(HomeToolbarActionId.openHrWorkspace),
      );
      expect(profile.suppressHomeQuickActions, isTrue);
      expect(profile.suppressHomeShortcuts, isFalse);
      expect(profile.metricActionTargets, contains('active_staff'));
      expect(
        profile.metricActionTargets['pending_leaves']?.hrQueue,
        'LEAVE_REQUESTS',
      );
      expect(
        profile.statusCards.map((template) => template.id),
        containsAll(<String>[
          'on_leave_today',
          'attended_today',
          'missed_shifts_today',
          'payroll_pending',
        ]),
      );
    });

    test('lab technologist profile exposes lab operations surface', () {
      final profile = homeProfileForRole(AppRole.labTech);

      expect(profile.quickActionIds, <String>[
        'receive_sample',
        'enter_lab_result',
        'flag_critical_lab',
      ]);
      expect(profile.shortcutIds, <String>[
        'lab',
        'patients',
        'reports',
        'settings',
        'communications',
      ]);
      expect(profile.maxStatusCards, 4);
      expect(
        profile.statusCards.map((template) => template.id),
        containsAll(<String>[
          'orders_today',
          'in_process',
          'pending_results',
          'critical_results',
        ]),
      );
      expect(profile.metricRouteTargets.keys, contains('in_process'));
    });

    test('doctor profile still exposes quick actions', () {
      final profile = homeProfileForRole(AppRole.doctor);

      expect(profile.quickActionIds, hasLength(4));
      expect(
        profile.quickActionIds,
        containsAll(<String>[
          'continue_consultation',
          'order_lab',
          'order_radiology',
          'write_clinical_note',
        ]),
      );
      expect(profile.quickActionIds, isNot(contains('start_consultation')));
      expect(
        profile.emptyActionIds,
        isNot(contains('start_consultation')),
      );
      expect(
        profile.shortcutIds,
        containsAll(<String>[
          'clinical',
          'opd',
          'emergency',
          'lab',
          'radiology',
          'ipd',
        ]),
      );
    });

    test(
      'nurse profile supports five metrics and permission-aware actions',
      () {
        final profile = homeProfileForRole(AppRole.nurse);

        expect(profile.maxStatusCards, 5);
        expect(profile.effectiveMaxStatusCards, 5);
        expect(profile.maxQuickActions, 8);
        expect(profile.maxShortcutTiles, 6);
        expect(profile.maxQueueItems, 5);
        expect(
          profile.statusCards.map((template) => template.id),
          containsAll(<String>[
            'appointments_today',
            'emergency_cases_today',
            'theatre_cases_today',
            'radiology_pending',
          ]),
        );
        expect(
          profile.quickActionIds,
          containsAll(<String>[
            'record_vitals',
            'mark_med_administered',
            'create_handover',
            'write_clinical_note',
            'route_patient',
            'check_in_patient',
          ]),
        );
        expect(profile.metricRouteTargets, contains('critical_labs'));
      },
    );

    test('manager overlay roles do not override primary dashboard role', () {
      expect(
        homeProfileForRoles(<AppRole>[
          AppRole.doctor,
          AppRole.theatreManager,
        ]).role,
        AppRole.doctor,
      );
      expect(
        homeProfileForRoles(<AppRole>[
          AppRole.nurse,
          AppRole.wardManager,
          AppRole.icuManager,
        ]).role,
        AppRole.nurse,
      );
      expect(
        homeProfileForRoles(<AppRole>[
          AppRole.biomed,
          AppRole.biomedManager,
        ]).role,
        AppRole.biomed,
      );
      expect(
        homeProfileForRoles(<AppRole>[
          AppRole.houseKeeper,
          AppRole.housekeepingManager,
        ]).role,
        AppRole.houseKeeper,
      );
      expect(
        homeProfileForRoles(<AppRole>[
          AppRole.tenantAdmin,
          AppRole.unitManager,
        ]).role,
        AppRole.tenantAdmin,
      );
    });

    test('infers dashboard profile from permissions for custom roles', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['TESTING'],
          ),
          permissions: AppPermissions.adminAccess,
        ),
      );

      expect(homeProfileForAccessPolicy(policy).role, AppRole.tenantAdmin);
    });
  });
}
