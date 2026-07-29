import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/profile/presentation/profile_access.dart';

void main() {
  group('profile access requirements', () {
    test('profileReadRequirement requires profile:read intersection', () {
      expect(
        profileReadRequirement.isAllowed(_policy(<AppPermission>[])),
        isFalse,
      );
      expect(
        profileReadRequirement.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileUpdate]),
        ),
        isFalse,
      );
      expect(
        profileReadRequirement.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
    });

    test('profileUpdateRequirement requires profile:update intersection', () {
      expect(
        profileUpdateRequirement.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isFalse,
      );
      expect(
        profileUpdateRequirement.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileUpdate]),
        ),
        isTrue,
      );
    });

    test(
      'profile rights remain allowed without subscription modules (core/platform)',
      () {
        final AppAccessPolicy tenantPolicy = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            permissions: <AppPermission>{
              AppPermissions.profileRead,
              AppPermissions.profileUpdate,
            },
            isAuthorizationHydrated: true,
            user: const AuthUserProfile(
              id: 'user-1',
              tenantId: 'tenant-1',
              roles: <String>['doctor'],
            ),
            moduleEntitlements: const <AppModuleEntitlement>[],
          ),
        );

        expect(profileReadRequirement.isAllowed(tenantPolicy), isTrue);
        expect(profileUpdateRequirement.isAllowed(tenantPolicy), isTrue);
      },
    );
  });

  group('profile financial inventory', () {
    test('profile tab has no billable actions', () {
      expect(profileTabHasNoBillableActions(), isTrue);
    });

    test('inventory covers view and mutation atoms', () {
      final Set<String> ids = profileFinancialInventory
          .map((ProfileFinancialAtom atom) => atom.id)
          .toSet();
      expect(ids, containsAll(<String>[
        'tab_surface',
        'change_password',
        'edit_profile',
        'edit_profile_save',
        'account_details_read',
      ]));
    });
  });
}

AppAccessPolicy _policy(List<AppPermission> permissions) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      permissions: permissions.toSet(),
      isAuthorizationHydrated: true,
      user: const AuthUserProfile(
        id: 'user-1',
        tenantId: 'tenant-1',
        roles: <String>['doctor'],
      ),
    ),
  ).copyWithPermissions(permissions);
}
