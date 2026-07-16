import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';

AppAccessPolicy _policyFor({required Set<AppPermission> permissions}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(roles: <String>['BILLING']),
      permissions: permissions,
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

void main() {
  group('claims access requirements', () {
    test('write requirement needs billing:write', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );

      expect(claimsWorkspaceWriteRequirement.isAllowed(reader), isFalse);
      expect(claimsWorkspaceWriteRequirement.isAllowed(writer), isTrue);
    });

    test('financial approve requirement needs financial:approve', () {
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      final AppAccessPolicy approver = _policyFor(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );

      expect(claimsFinancialApproveRequirement.isAllowed(writer), isFalse);
      expect(claimsFinancialApproveRequirement.isAllowed(approver), isTrue);
    });
  });
}
