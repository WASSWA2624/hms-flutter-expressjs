import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_guided_content.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';

void main() {
  group('guidedFallbackQueueHints', () {
    test('includes OPD and IPD entry points for clinical roles', () {
      final doctorHints = guidedFallbackQueueHints(
        homeProfileForRole(AppRole.doctor),
      );
      final nurseHints = guidedFallbackQueueHints(
        homeProfileForRole(AppRole.nurse),
      );

      expect(
        doctorHints.map((item) => item.moduleSlug),
        containsAll(<String>['clinical', 'scheduling']),
      );
      expect(nurseHints.map((item) => item.moduleSlug), contains('ipd'));
    });

    test('includes front desk queue for receptionist', () {
      final hints = guidedFallbackQueueHints(
        homeProfileForRole(AppRole.receptionist),
      );

      expect(hints, isNotEmpty);
      expect(
        hints.map((item) => item.moduleSlug),
        containsAll(<String>['scheduling', 'emergency']),
      );
      expect(
        hints.map((item) => item.id),
        containsAll(<String>[
          'guided_appointments',
          'guided_doctor_assignment',
          'guided_emergency_intake',
        ]),
      );
    });
  });

  group('guidedFallbackAlerts', () {
    test('includes billing and bed pressure for facility admin', () {
      final alerts = guidedFallbackAlerts(
        homeProfileForRole(AppRole.facilityAdmin),
      );

      expect(
        alerts.map((item) => item.target?.moduleSlug),
        containsAll(<String>['ipd', 'billing']),
      );
    });

    test('system admin surfaces security, audit, and integration alerts', () {
      final alerts = guidedFallbackAlerts(
        homeProfileForRole(AppRole.platformAdmin),
      );

      expect(
        alerts.map((item) => item.id),
        containsAll(<String>[
          'security_alerts',
          'audit_summary',
          'integration_status',
        ]),
      );
    });

    test('tenant admin surfaces compliance alerts', () {
      final alerts = guidedFallbackAlerts(
        homeProfileForRole(AppRole.tenantAdmin),
      );

      expect(
        alerts.map((item) => item.id),
        contains('compliance_alerts'),
      );
    });
  });

  group('guidedFallbackQueueHints platform', () {
    test('platform admin uses platform queue id (platform:admin)', () {
      final hints = guidedFallbackQueueHints(
        homeProfileForRole(AppRole.platformAdmin),
      );

      expect(
        hints.map((item) => item.id),
        contains('guided_platform_queue'),
      );
      expect(
        hints.map((item) => item.id),
        isNot(contains('guided_tenant_setup')),
      );
    });
  });
}
