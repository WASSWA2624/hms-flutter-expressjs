import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';

const List<AppModuleEntitlement> _modules = <AppModuleEntitlement>[
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

AppAccessPolicy _customPolicy(List<AppPermission> permissions) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: <String>['TESTING'],
      ),
      permissions: permissions,
      moduleEntitlements: _modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  group('custom role RBAC accuracy throughout the app', () {
    late AppAccessPolicy policy;

    setUp(() {
      policy = _customPolicy(const <AppPermission>[
        AppPermissions.billingRead,
        AppPermissions.claimsRead,
        AppPermissions.clinicalRead,
        AppPermissions.labRead,
        AppPermissions.profileRead,
      ]);
    });

    test('is treated as permission-scoped (no canonical staff role)', () {
      expect(policy.isPermissionScopedShellUser, isTrue);
      expect(policy.hasRole(AppRole.doctor), isFalse);
      expect(policy.hasRole(AppRole.labTech), isFalse);
      expect(policy.hasRole(AppRole.billing), isFalse);
    });

    test('shell only unlocks matching permission domains', () {
      expect(canAccessShellRoute(AppRoutes.home, policy), isTrue);
      expect(canAccessShellRoute(AppRoutes.settings, policy), isTrue);
      expect(canAccessShellRoute(AppRoutes.profile, policy), isTrue);
      expect(canAccessShellRoute(AppRoutes.billing, policy), isTrue);
      expect(canAccessShellRoute(AppRoutes.claims, policy), isTrue);
      expect(canAccessShellRoute(AppRoutes.clinical, policy), isTrue);
      expect(canAccessShellRoute(AppRoutes.lab, policy), isTrue);

      expect(canAccessShellRoute(AppRoutes.patients, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.reception, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.opd, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.ipd, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.nursing, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.icu, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.theater, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.physiotherapy, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.discharge, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.pharmacy, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.radiology, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.hr, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.communications, policy), isFalse);
      expect(canAccessShellRoute(AppRoutes.accessAdmin, policy), isFalse);
    });

    test('read grants do not unlock write home actions', () {
      expect(homeActionLibrary['review_overdue_invoices']!.isAllowed(policy), isTrue);
      expect(homeActionLibrary['review_pending_payments']!.isAllowed(policy), isTrue);
      expect(homeActionLibrary['review_claims_pending']!.isAllowed(policy), isTrue);

      expect(homeActionLibrary['create_invoice']!.isAllowed(policy), isFalse);
      expect(homeActionLibrary['receive_payment']!.isAllowed(policy), isFalse);
      expect(homeActionLibrary['receive_sample']!.isAllowed(policy), isFalse);
      expect(homeActionLibrary['enter_lab_result']!.isAllowed(policy), isFalse);
      expect(homeActionLibrary['continue_consultation']!.isAllowed(policy), isFalse);
      expect(homeActionLibrary['write_clinical_note']!.isAllowed(policy), isFalse);
      expect(homeActionLibrary['register_patient']!.isAllowed(policy), isFalse);
    });

    test('write grants unlock matching actions without canonical roles', () {
      final AppAccessPolicy writer = _customPolicy(const <AppPermission>[
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
        AppPermissions.labRead,
        AppPermissions.labWrite,
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.profileRead,
      ]);

      expect(writer.grants(AppPermissions.billingWrite), isTrue);
      expect(canAccessShellRoute(AppRoutes.billing, writer), isTrue);
      expect(homeActionLibrary['create_invoice']!.isAllowed(writer), isTrue);
      expect(homeActionLibrary['receive_sample']!.isAllowed(writer), isTrue);
      expect(
        homeActionLibrary['continue_consultation']!.isAllowed(writer),
        isTrue,
      );
      expect(canAccessShellRoute(AppRoutes.pharmacy, writer), isFalse);
      expect(homeActionLibrary['dispense_medication']!.isAllowed(writer), isFalse);
    });

    test('shortcuts follow shell permission-domain accuracy', () {
      expect(homeShortcutLibrary['billing']!.isAllowed(policy), isTrue);
      expect(homeShortcutLibrary['lab']!.isAllowed(policy), isTrue);
      expect(homeShortcutLibrary['clinical']!.isAllowed(policy), isTrue);
      expect(homeShortcutLibrary['patients']!.isAllowed(policy), isFalse);
      expect(homeShortcutLibrary['pharmacy']!.isAllowed(policy), isFalse);
    });
  });
}
