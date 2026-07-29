import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/profile/presentation/profile_access.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';

void main() {
  group('SettingsPreferencesAtomPermissions', () {
    test('reuses profile feature helpers (no second vocabulary)', () {
      expect(
        SettingsPreferencesAtomPermissions.tab,
        same(profileReadRequirement),
      );
      expect(
        SettingsPreferencesAtomPermissions.read,
        same(profileReadRequirement),
      );
      expect(
        SettingsPreferencesAtomPermissions.listChrome,
        same(profileReadRequirement),
      );
      expect(
        SettingsPreferencesAtomPermissions.themeModeValue,
        same(profileReadRequirement),
      );
      expect(
        SettingsPreferencesAtomPermissions.update,
        same(profileUpdateRequirement),
      );
      expect(
        SettingsPreferencesAtomPermissions.themeMode,
        same(profileUpdateRequirement),
      );
      expect(
        SettingsPreferencesAtomPermissions.success,
        same(profileUpdateRequirement),
      );
      expect(
        SettingsPreferencesAtomPermissions.validation,
        same(profileUpdateRequirement),
      );
      expect(
        SettingsPreferencesAtomPermissions.routeEntry,
        same(RouteAccessCatalog.authenticatedCore),
      );
      expect(
        SettingsPreferencesAtomPermissions.create,
        same(settingsFacilityAdminRequirement),
      );
      expect(
        SettingsPreferencesAtomPermissions.delete,
        same(settingsFacilityAdminRequirement),
      );
    });

    test('intersection denial: missing profile:read blocks tab', () {
      expect(
        SettingsPreferencesAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileUpdate]),
        ),
        isFalse,
      );
      expect(
        SettingsPreferencesAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isFalse,
      );
      expect(
        SettingsPreferencesAtomPermissions.themeModeValue.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileUpdate]),
        ),
        isFalse,
      );
    });

    test('intersection presence: profile:read allows read atoms', () {
      expect(
        SettingsPreferencesAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
      expect(
        SettingsPreferencesAtomPermissions.themeModeValue.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
      expect(
        SettingsPreferencesAtomPermissions.listChrome.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
    });

    test('update ∩ requires profile:update', () {
      expect(
        SettingsPreferencesAtomPermissions.update.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isFalse,
      );
      expect(
        SettingsPreferencesAtomPermissions.themeMode.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isFalse,
      );
      expect(
        SettingsPreferencesAtomPermissions.update.isAllowed(
          _policy(<AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.profileUpdate,
          ]),
        ),
        isTrue,
      );
      expect(
        SettingsPreferencesAtomPermissions.themeMode.isAllowed(
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
        SettingsPreferencesAtomPermissions.create.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsPreferencesAtomPermissions.delete.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsPreferencesAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isTrue,
      );
      expect(
        SettingsPreferencesAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileUpdate]),
        ),
        isFalse,
      );
    });

    test('view ∪ and nested cross-module rows are _(n/a)_', () {
      // Matrix view ∪ / nested ∪ / nested ∩ are _(n/a)_ — no union allowance
      // case on this tab; AC6 union clause applies only when the matrix uses ∪.
      expect(SettingsPreferencesAtomPermissions.tab.anyPermissions, isEmpty);
      expect(
        SettingsPreferencesAtomPermissions.read.anyPermissions,
        isEmpty,
      );
      expect(
        SettingsPreferencesAtomPermissions.update.anyPermissions,
        isEmpty,
      );
      expect(
        SettingsPreferencesAtomPermissions.nestedRead.anyPermissions,
        isEmpty,
      );
      expect(
        SettingsPreferencesAtomPermissions.nestedWrite,
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

        expect(
          SettingsPreferencesAtomPermissions.tab.isAllowed(emptyModules),
          isTrue,
        );
        expect(
          SettingsPreferencesAtomPermissions.update.isAllowed(emptyModules),
          isTrue,
        );
      },
    );

    test(
      'ABAC: missing facility still allows preferences chrome '
      '(own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          <AppPermission>[AppPermissions.profileRead],
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          SettingsPreferencesAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
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
