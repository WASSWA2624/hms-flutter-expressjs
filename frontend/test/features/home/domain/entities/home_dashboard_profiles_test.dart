import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
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

      expect(profile.quickActionIds, <String>[
        'create_tenant',
        'create_facility',
        'create_role',
        'create_user',
      ]);
      expect(profile.emptyActionIds, <String>[
        'manage_tenants',
        'manage_facilities',
        'manage_roles_access',
        'manage_users',
      ]);
      expect(profile.quickActionIds, isNot(contains('select_context')));
    });

    test('tenant admin profile uses facility governance actions only', () {
      final profile = homeProfileForRole(AppRole.tenantAdmin);

      expect(
        profile.quickActionIds,
        containsAll(<String>[
          'create_facility',
          'create_role',
          'create_user',
          'add_staff_profile',
          'manage_facilities',
          'manage_roles_access',
          'manage_users_roles',
          'manage_users',
        ]),
      );
      expect(profile.quickActionIds, isNot(contains('manage_subscription')));
      expect(
        profile.quickActionIds.take(4),
        <String>[
          'create_facility',
          'create_role',
          'create_user',
          'add_staff_profile',
        ],
      );
      expect(
        profile.emptyActionIds,
        <String>[
          'manage_facilities',
          'manage_roles_access',
          'manage_users_roles',
          'manage_users',
        ],
      );
      expect(
        profile.shortcutIds,
        containsAll(<String>['tenant_facility_setup', 'settings', 'reports', 'subscriptions']),
      );
      expect(
        profile.statusCards.map((template) => template.id),
        <String>[
          'facilities_active',
          'active_users',
          'module_adoption',
          'subscription_health',
        ],
      );
      for (final actionId in <String>[
        'start_consultation',
        'record_vitals',
        'enter_lab_result',
        'dispense_medication',
      ]) {
        expect(profile.quickActionIds, isNot(contains(actionId)));
      }
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
      expect(profile.maxStatusCards, 6);
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

    test('doctor profile still exposes quick actions', () {
      final profile = homeProfileForRole(AppRole.doctor);

      expect(profile.quickActionIds, hasLength(5));
      expect(profile.quickActionIds, containsAll(<String>[
        'start_consultation',
        'continue_consultation',
        'order_lab',
        'order_radiology',
        'write_clinical_note',
      ]));
      expect(profile.shortcutIds, containsAll(<String>[
        'clinical',
        'opd',
        'emergency',
        'lab',
        'radiology',
        'ipd',
      ]));
    });

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
