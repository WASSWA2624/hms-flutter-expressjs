import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_nurse_dashboard_context.dart';

void main() {
  group('nurse dashboard context', () {
    test('infers department kind from HR signals', () {
      expect(
        inferNurseDepartmentKind(departmentName: 'Theatre nursing unit'),
        NurseDepartmentKind.theatre,
      );
      expect(
        inferNurseDepartmentKind(departmentName: 'Radiology department'),
        NurseDepartmentKind.radiology,
      );
      expect(
        inferNurseDepartmentKind(staffPosition: 'OPD charge nurse'),
        NurseDepartmentKind.opd,
      );
      expect(
        inferNurseDepartmentKind(departmentName: 'ICU'),
        NurseDepartmentKind.icu,
      );
    });

    test(
      'tailors nurse profile with five metric slots and expanded actions',
      () {
        final HomeDashboardProfile base = homeProfileForRole(AppRole.nurse);
        final AppAccessPolicy policy = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'token'),
            user: const AuthUserProfile(
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
              roles: <String>['NURSE'],
            ),
            permissions: const <AppPermission>[
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
              AppPermissions.labRead,
              AppPermissions.emergencyRead,
            ],
            moduleEntitlements: const <AppModuleEntitlement>[
              AppModuleEntitlement(code: 'clinical'),
              AppModuleEntitlement(code: 'nursing'),
              AppModuleEntitlement(code: 'scheduling'),
              AppModuleEntitlement(code: 'lab'),
              AppModuleEntitlement(code: 'ipd'),
            ],
          ),
        );

        final HomeDashboardProfile tailored = tailorNurseDashboardProfile(
          base: base,
          departmentKind: NurseDepartmentKind.opd,
          policy: policy,
        );

        expect(tailored.maxStatusCards, 5);
        expect(tailored.effectiveMaxStatusCards, 5);
        expect(tailored.maxQuickActions, 8);
        expect(tailored.homeTitle, 'OPD nursing');
        expect(tailored.statusCards.first.id, 'appointments_today');
        expect(
          tailored.quickActionIds,
          containsAll(<String>['route_patient', 'record_vitals']),
        );
        expect(tailored.metricRouteTargets, contains('inpatient_flow'));
      },
    );
  });
}
