import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

const List<AppModuleEntitlement> _allModules = <AppModuleEntitlement>[
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
  AppModuleEntitlement(code: 'subscription-controls', licenseStatus: 'ACTIVE'),
];

AppAccessPolicy _policy({
  Set<AppPermission> permissions = const <AppPermission>{},
  List<String> roles = const <String>[],
  List<AppModuleEntitlement>? modules,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: roles,
      ),
      permissions: permissions,
      isAuthorizationHydrated: true,
      moduleEntitlements: modules ?? _allModules,
    ),
  );
}

void main() {
  group('RouteAccessCatalog atoms', () {
    test('every matrix atom is present with a unique entry permission', () {
      final Set<String> names = <String>{};
      final Set<String> entryKeys = <String>{};
      for (final RouteAccessAtom atom in RouteAccessCatalog.allAtoms) {
        expect(names.add(atom.routeName), isTrue, reason: atom.routeName);
        if (atom.entryPermission != null) {
          final String key = atom.entryPermission!.value;
          expect(
            entryKeys.add(key),
            isTrue,
            reason: 'duplicate entry permission $key',
          );
        }
      }
      expect(RouteAccessCatalog.atomForName('opd'), isNotNull);
      expect(RouteAccessCatalog.opd.entryPermission, AppPermissions.opdRead);
      expect(RouteAccessCatalog.claims.entryPermission, AppPermissions.claimsRead);
    });

    test('AppRouteData.accessRequirement resolves from the catalog', () {
      expect(
        AppRoutes.opd.accessRequirement,
        RouteAccessCatalog.opdEntry,
      );
      expect(
        AppRoutes.billing.accessRequirement,
        RouteAccessCatalog.billingEntry,
      );
      expect(
        AppRoutes.claims.accessRequirement,
        RouteAccessCatalog.claimsEntry,
      );
    });
  });

  group('unique route entry isolation', () {
    test('billing:read alone does not open OPD', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(canAccessShellRoute(AppRoutes.billing, billingOnly), isTrue);
      expect(canAccessShellRoute(AppRoutes.opd, billingOnly), isFalse);
      expect(canAccessShellRoute(AppRoutes.claims, billingOnly), isFalse);
    });

    test('operations:read alone does not open OPD', () {
      final AppAccessPolicy operationsOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(canAccessShellRoute(AppRoutes.operations, operationsOnly), isTrue);
      expect(canAccessShellRoute(AppRoutes.opd, operationsOnly), isFalse);
    });

    test('one route key does not unlock another atom', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(canAccessShellRoute(AppRoutes.clinical, clinicalOnly), isTrue);
      expect(canAccessShellRoute(AppRoutes.ipd, clinicalOnly), isFalse);
      expect(canAccessShellRoute(AppRoutes.nursing, clinicalOnly), isFalse);
      expect(canAccessShellRoute(AppRoutes.discharge, clinicalOnly), isFalse);
    });

    test('custom role with only opd:read sees OPD only among workspaces', () {
      final AppAccessPolicy custom = _policy(
        permissions: <AppPermission>{AppPermissions.opdRead},
        roles: const <String>['CUSTOM_CARE_COORDINATOR'],
      );
      expect(canAccessShellRoute(AppRoutes.home, custom), isTrue);
      expect(canAccessShellRoute(AppRoutes.settings, custom), isTrue);
      expect(canAccessShellRoute(AppRoutes.opd, custom), isTrue);
      expect(canAccessShellRoute(AppRoutes.billing, custom), isFalse);
      expect(canAccessShellRoute(AppRoutes.operations, custom), isFalse);
      expect(canAccessShellRoute(AppRoutes.clinical, custom), isFalse);
      expect(canAccessShellRoute(AppRoutes.reception, custom), isFalse);
    });

    test('missing opd:read forbids OPD deep link via shell gate', () {
      final AppAccessPolicy noOpd = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientsRead,
          AppPermissions.receptionRead,
        },
      );
      expect(canAccessShellRoute(AppRoutes.opd, noOpd), isFalse);
      expect(canAccessShellRoute(AppRoutes.patients, noOpd), isTrue);
      expect(canAccessShellRoute(AppRoutes.reception, noOpd), isTrue);
    });

    test('module denial hides OPD even with opd:read', () {
      final AppAccessPolicy noScheduling = _policy(
        permissions: <AppPermission>{AppPermissions.opdRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
        ],
      );
      expect(canAccessShellRoute(AppRoutes.opd, noScheduling), isFalse);
    });

    test('canonical BILLING role gets billing+claims but not OPD', () {
      final AppAccessPolicy billing = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: const <String>['BILLING'],
          ),
          moduleEntitlements: _allModules,
        ),
      );
      expect(canAccessShellRoute(AppRoutes.billing, billing), isTrue);
      expect(canAccessShellRoute(AppRoutes.claims, billing), isTrue);
      expect(canAccessShellRoute(AppRoutes.opd, billing), isFalse);
    });
  });
}
