import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/profile/presentation/profile_access.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';

void main() {
  group('SettingsAccountAtomPermissions', () {
    test('reuses profile feature helpers (no second vocabulary)', () {
      expect(SettingsAccountAtomPermissions.tab, same(profileReadRequirement));
      expect(
        SettingsAccountAtomPermissions.read,
        same(profileReadRequirement),
      );
      expect(
        SettingsAccountAtomPermissions.update,
        same(profileUpdateRequirement),
      );
      expect(
        SettingsAccountAtomPermissions.changePassword,
        same(profileReadRequirement),
      );
      expect(
        SettingsAccountAtomPermissions.editProfile,
        same(profileUpdateRequirement),
      );
      expect(
        SettingsAccountAtomPermissions.routeEntry,
        same(RouteAccessCatalog.authenticatedCore),
      );
    });

    test('intersection denial: missing profile:read blocks tab', () {
      expect(
        SettingsAccountAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileUpdate]),
        ),
        isFalse,
      );
      expect(
        SettingsAccountAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isFalse,
      );
    });

    test('intersection presence: profile:read allows read atoms', () {
      expect(
        SettingsAccountAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
      expect(
        SettingsAccountAtomPermissions.summary.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
    });

    test('update ∩ requires profile:update; change password uses profile:read', () {
      expect(
        SettingsAccountAtomPermissions.update.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isFalse,
      );
      expect(
        SettingsAccountAtomPermissions.changePassword.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
      expect(
        SettingsAccountAtomPermissions.update.isAllowed(
          _policy(<AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.profileUpdate,
          ]),
        ),
        isTrue,
      );
      expect(
        SettingsAccountAtomPermissions.changePassword.isAllowed(
          _policy(<AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.profileUpdate,
          ]),
        ),
        isTrue,
      );
    });

    test('create/delete ∩ facility:admin (not mounted on tab)', () {
      expect(
        SettingsAccountAtomPermissions.create.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsAccountAtomPermissions.delete.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsAccountAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isTrue,
      );
      expect(
        SettingsAccountAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileUpdate]),
        ),
        isFalse,
      );
    });

    test('view ∪ and nested cross-module rows are _(n/a)_', () {
      expect(SettingsAccountAtomPermissions.tab.anyPermissions, isEmpty);
      expect(SettingsAccountAtomPermissions.nestedRead.anyPermissions, isEmpty);
      expect(
        SettingsAccountAtomPermissions.nestedWrite,
        same(profileUpdateRequirement),
      );
    });

    test(
      'subscription strip: profile rights remain without plan modules',
      () {
        final AppAccessPolicy emptyModules = AppAccessPolicy.fromSession(
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
              facilityId: 'facility-1',
              roles: <String>['doctor'],
            ),
            moduleEntitlements: const <AppModuleEntitlement>[],
          ),
        );

        expect(SettingsAccountAtomPermissions.tab.isAllowed(emptyModules), isTrue);
        expect(
          SettingsAccountAtomPermissions.update.isAllowed(emptyModules),
          isTrue,
        );
      },
    );

    test(
      'ABAC: missing facility still allows account chrome '
      '(own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          <AppPermission>[AppPermissions.profileRead],
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(SettingsAccountAtomPermissions.tab.isAllowed(noFacility), isTrue);
      },
    );
  });
}

AppAccessPolicy _policy(
  List<AppPermission> permissions, {
  String? facilityId = 'facility-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      permissions: permissions.toSet(),
      isAuthorizationHydrated: true,
      user: AuthUserProfile(
        id: 'user-1',
        tenantId: 'tenant-1',
        facilityId: facilityId,
        roles: const <String>['doctor'],
      ),
    ),
  ).copyWithPermissions(permissions);
}
