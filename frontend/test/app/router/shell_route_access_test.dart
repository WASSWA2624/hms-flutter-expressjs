import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

const List<AppModuleEntitlement> _activeShellModules = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'inpatient-bed-management',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'icu-critical-care', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'physiotherapy', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'radiology-workflows', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'pharmacy-dispensing', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'facilities-maintenance', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'biomedical-engineering-suite',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(
    code: 'notifications-communications',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'integrations-core', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'theatre-anesthesia', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'reporting-analytics', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'mortuary', licenseStatus: 'ACTIVE'),
];

void main() {
  group('shell route access matrix', () {
    AppAccessPolicy policyForRole(String role) {
      return AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>[role],
          ),
          moduleEntitlements: _activeShellModules,
        ),
      );
    }

    bool canAccess(AppRouteData route, AppAccessPolicy policy) {
      return canAccessShellRoute(route, policy);
    }

    test('doctor access follows clinical permission pack', () {
      final policy = policyForRole('DOCTOR');

      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.opd, policy), isTrue);
      expect(canAccess(AppRoutes.clinical, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      expect(canAccess(AppRoutes.pharmacy, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      // Nursing/physiotherapy share clinical/patient permission codes.
      expect(canAccess(AppRoutes.nursing, policy), isTrue);
      expect(canAccess(AppRoutes.physiotherapy, policy), isTrue);
      expect(canAccess(AppRoutes.billing, policy), isFalse);
      expect(canAccess(AppRoutes.hr, policy), isFalse);
    });

    test('nurse access follows nursing permission pack', () {
      final policy = policyForRole('NURSE');

      expect(canAccess(AppRoutes.nursing, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.clinical, policy), isTrue);
      expect(canAccess(AppRoutes.billing, policy), isFalse);
    });

    test('ambulance access follows emergency permission pack', () {
      final policy = policyForRole('AMBULANCE_OPERATOR');

      expect(canAccess(AppRoutes.emergency, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isFalse);
      // OPD accepts emergency:read among its any-permissions.
      expect(canAccess(AppRoutes.opd, policy), isTrue);
    });

    test('lab access follows lab permission pack', () {
      final policy = policyForRole('LAB_TECH');

      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      expect(canAccess(AppRoutes.communications, policy), isTrue);
      expect(canAccess(AppRoutes.settings, policy), isTrue);
      expect(canAccess(AppRoutes.opd, policy), isFalse);
      expect(canAccess(AppRoutes.nursing, policy), isFalse);
      expect(canAccess(AppRoutes.physiotherapy, policy), isFalse);
      expect(canAccess(AppRoutes.theater, policy), isFalse);
      expect(canAccess(AppRoutes.reports, policy), isFalse);
    });

    test('pharmacist shell is limited to pharmacy-focused routes', () {
      final policy = policyForRole('PHARMACIST');

      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.pharmacy, policy), isTrue);
      expect(canAccess(AppRoutes.communications, policy), isTrue);
      expect(canAccess(AppRoutes.settings, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isFalse);
      expect(canAccess(AppRoutes.opd, policy), isFalse);
      expect(canAccess(AppRoutes.nursing, policy), isFalse);
      expect(canAccess(AppRoutes.lab, policy), isFalse);
      expect(canAccess(AppRoutes.clinical, policy), isFalse);
      expect(canAccess(AppRoutes.billing, policy), isFalse);
    });

    test('billing access follows billing permission pack', () {
      final policy = policyForRole('BILLING');

      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.billing, policy), isTrue);
      expect(canAccess(AppRoutes.claims, policy), isTrue);
      // OPD accepts billing:read / patient:read among its any-permissions.
      expect(canAccess(AppRoutes.opd, policy), isTrue);
    });

    test('operations access follows operations permission pack', () {
      final policy = policyForRole('OPERATIONS');

      expect(canAccess(AppRoutes.operations, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isFalse);
    });

    test('hr sees hr tenant setup and reports', () {
      final policy = policyForRole('HR');

      expect(canAccess(AppRoutes.hr, policy), isTrue);
      expect(canAccess(AppRoutes.tenantFacilitySetup, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isFalse);
    });

    test('admins see full shell including integrations', () {
      for (final String role in <String>[
        'SUPER_ADMIN',
        'TENANT_ADMIN',
        'FACILITY_ADMIN',
      ]) {
        final policy = policyForRole(role);

        expect(canAccess(AppRoutes.integrations, policy), isTrue, reason: role);
        expect(canAccess(AppRoutes.nursing, policy), isTrue, reason: role);
      }

      expect(
        canAccess(AppRoutes.subscriptions, policyForRole('SUPER_ADMIN')),
        isTrue,
      );
      expect(
        canAccess(AppRoutes.subscriptions, policyForRole('TENANT_ADMIN')),
        isFalse,
      );
      expect(
        canAccess(AppRoutes.subscriptions, policyForRole('FACILITY_ADMIN')),
        isFalse,
      );
    });

    test('custom role permissions unlock matching shell routes', () {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['TESTING'],
          ),
          permissions: <AppPermission>[
            AppPermissions.patientRead,
            AppPermissions.billingRead,
            AppPermissions.clinicalRead,
            AppPermissions.labRead,
          ],
          moduleEntitlements: _activeShellModules,
        ),
      );

      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.settings, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.billing, policy), isTrue);
      expect(canAccess(AppRoutes.clinical, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      expect(canAccess(AppRoutes.pharmacy, policy), isFalse);
      expect(canAccess(AppRoutes.hr, policy), isFalse);
    });
  });
}
