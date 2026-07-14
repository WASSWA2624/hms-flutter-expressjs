import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';

const List<AppModuleEntitlement> _activeShellModules = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'notifications-communications',
    licenseStatus: 'ACTIVE',
  ),
];

AppAccessPolicy _policyFor({required List<String> roles}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: roles,
      ),
      moduleEntitlements: _activeShellModules,
    ),
  );
}

void main() {
  group('ReceptionWorkspaceQuery', () {
    test('parses desk section deep links', () {
      final ReceptionWorkspaceQuery query = ReceptionWorkspaceQuery.fromUri(
        Uri.parse('/reception?section=queue&search=Ada'),
      );

      expect(query.section, 'queue');
      expect(query.search, 'Ada');
      expect(query.hasRouteTargeting, isTrue);
    });
  });

  group('Reception authorization split', () {
    test('receptionist can open reception shell route', () {
      final AppAccessPolicy policy = _policyFor(roles: <String>['RECEPTIONIST']);

      expect(canAccessShellRoute(AppRoutes.reception, policy), isTrue);
      expect(canAccessShellRoute(AppRoutes.billing, policy), isFalse);
      expect(receptionWorkspaceRequirement.isAllowed(policy), isTrue);
    });

    test('billing pay-consultation is hidden without billing:write', () {
      final AppAccessPolicy receptionist = _policyFor(
        roles: <String>['RECEPTIONIST'],
      );
      final AppAccessPolicy cashier = _policyFor(roles: <String>['BILLING']);

      expect(opdBillingActionRequirement.isAllowed(receptionist), isFalse);
      expect(
        receptionBillingCashierRequirement.isAllowed(receptionist),
        isFalse,
      );
      expect(
        receptionBillingGuidanceRequirement.isAllowed(receptionist),
        isTrue,
      );

      expect(opdBillingActionRequirement.isAllowed(cashier), isTrue);
      expect(receptionBillingCashierRequirement.isAllowed(cashier), isTrue);
    });

    test('billing guidance remains available with patient:read', () {
      final AppAccessPolicy policy = _policyFor(roles: <String>['RECEPTIONIST']);

      expect(policy.grants(AppPermissions.patientRead), isTrue);
      expect(receptionBillingGuidanceRequirement.isAllowed(policy), isTrue);
      expect(policy.grants(AppPermissions.billingWrite), isFalse);
    });
  });
}
