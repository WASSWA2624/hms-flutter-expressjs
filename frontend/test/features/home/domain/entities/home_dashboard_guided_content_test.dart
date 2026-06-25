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
      expect(hints.first.moduleSlug, 'scheduling');
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
  });
}
