import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';

void main() {
  final AppAccessPolicy p = AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 't'),
      user: const AuthUserProfile(
        roles: <String>['HR'],
        tenantId: '550e8400-e29b-41d4-a716-446655440000',
        facilityId: 'f1',
      ),
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
  // ignore: avoid_print
  print('elevated=${p.isElevated}');
  print('facility=${p.hasFacilityContext}');
  print('canReadAccess=${canReadHrAccess(p)}');
  print('tab=${hrAccessReadRequirement.isAllowed(p)}');
  print('entry=${hrWorkspaceEntryRequirement.isAllowed(p)}');
  print('hasTenantAdmin=${p.grants(AppPermissions.tenantAdmin)}');
  print('hasFacilityAdmin=${p.grants(AppPermissions.facilityAdmin)}');
  print('hasSystemAdmin=${p.grants(AppPermissions.systemAdmin)}');
  print('roles=${p.roles}');
}
