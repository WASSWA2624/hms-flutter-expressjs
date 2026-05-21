import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
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

    test('tenant admin profile uses oversight actions only', () {
      final profile = homeProfileForRole(AppRole.tenantAdmin);

      expect(
        profile.quickActionIds,
        containsAll(<String>[
          'create_facility',
          'manage_users_roles',
          'manage_subscription',
          'add_staff_profile',
          'run_report',
          'review_audit',
        ]),
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
  });
}
