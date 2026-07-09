import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

const List<AppModuleEntitlement> _activeShellModules = <AppModuleEntitlement>[
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
  AppModuleEntitlement(code: 'billing-insurance', licenseStatus: 'ACTIVE'),
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
      return route.accessRequirement.isAllowed(policy);
    }

    test('doctor sees clinical modules but not nursing or billing', () {
      final policy = policyForRole('DOCTOR');

      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.opd, policy), isTrue);
      expect(canAccess(AppRoutes.clinical, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      expect(canAccess(AppRoutes.pharmacy, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.nursing, policy), isFalse);
      expect(canAccess(AppRoutes.billing, policy), isFalse);
      expect(canAccess(AppRoutes.hr, policy), isFalse);
      expect(canAccess(AppRoutes.physiotherapy, policy), isFalse);
    });

    test('nurse sees nursing and lab but not clinical workspace', () {
      final policy = policyForRole('NURSE');

      expect(canAccess(AppRoutes.nursing, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.clinical, policy), isFalse);
      expect(canAccess(AppRoutes.billing, policy), isFalse);
    });

    test('ambulance sees emergency only without patient registry', () {
      final policy = policyForRole('AMBULANCE_OPERATOR');

      expect(canAccess(AppRoutes.emergency, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isFalse);
      expect(canAccess(AppRoutes.opd, policy), isFalse);
    });

    test('lab sees patient registry and laboratory only', () {
      final policy = policyForRole('LAB_TECH');

      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      expect(canAccess(AppRoutes.opd, policy), isFalse);
      expect(canAccess(AppRoutes.reports, policy), isFalse);
    });

    test('billing sees billing and claims with patient registry', () {
      final policy = policyForRole('BILLING');

      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.billing, policy), isTrue);
      expect(canAccess(AppRoutes.claims, policy), isTrue);
      expect(canAccess(AppRoutes.opd, policy), isFalse);
    });

    test('operations sees operations without reports', () {
      final policy = policyForRole('OPERATIONS');

      expect(canAccess(AppRoutes.operations, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isFalse);
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
        expect(
          canAccess(AppRoutes.subscriptions, policy),
          isTrue,
          reason: role,
        );
        expect(canAccess(AppRoutes.nursing, policy), isTrue, reason: role);
      }
    });
  });
}
