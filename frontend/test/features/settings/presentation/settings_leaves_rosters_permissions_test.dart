import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/profile/presentation/profile_access.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';

void main() {
  group('SettingsLeavesAtomPermissions', () {
    test('reuses profile:read for staff self-service leave atoms', () {
      expect(SettingsLeavesAtomPermissions.tab, same(profileReadRequirement));
      expect(SettingsLeavesAtomPermissions.request, same(profileReadRequirement));
      expect(
        SettingsLeavesAtomPermissions.routeEntry,
        same(RouteAccessCatalog.authenticatedCore),
      );
    });

    test('profile:read allows leaves; missing profile:read denies', () {
      expect(
        SettingsLeavesAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
      expect(
        SettingsLeavesAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.hrWrite]),
        ),
        isFalse,
      );
    });
  });

  group('SettingsRostersAtomPermissions', () {
    test('reuses profile:read for staff self-service roster atoms', () {
      expect(SettingsRostersAtomPermissions.tab, same(profileReadRequirement));
      expect(SettingsRostersAtomPermissions.list, same(profileReadRequirement));
      expect(
        SettingsRostersAtomPermissions.routeEntry,
        same(RouteAccessCatalog.authenticatedCore),
      );
    });

    test('does not require hr:write for roster calendar', () {
      expect(
        SettingsRostersAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
      expect(
        SettingsRostersAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.hrRead]),
        ),
        isFalse,
      );
    });
  });
}

AppAccessPolicy _policy(List<AppPermission> permissions) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['STAFF']),
    ),
  ).copyWithPermissions(permissions);
}
