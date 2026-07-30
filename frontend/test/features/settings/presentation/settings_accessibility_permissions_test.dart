import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/profile/presentation/profile_access.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';

void main() {
  group('SettingsAccessibilityAtomPermissions', () {
    test('reuses profile feature helpers (no second vocabulary)', () {
      expect(
        SettingsAccessibilityAtomPermissions.tab,
        same(profileReadRequirement),
      );
      expect(
        SettingsAccessibilityAtomPermissions.read,
        same(profileReadRequirement),
      );
      expect(
        SettingsAccessibilityAtomPermissions.listChrome,
        same(profileReadRequirement),
      );
      expect(
        SettingsAccessibilityAtomPermissions.update,
        same(profileReadRequirement),
      );
      expect(
        SettingsAccessibilityAtomPermissions.reduceMotion,
        same(profileReadRequirement),
      );
      expect(
        SettingsAccessibilityAtomPermissions.boldText,
        same(profileReadRequirement),
      );
      expect(
        SettingsAccessibilityAtomPermissions.textScale,
        same(profileReadRequirement),
      );
      expect(
        SettingsAccessibilityAtomPermissions.routeEntry,
        same(RouteAccessCatalog.authenticatedCore),
      );
    });

    test('intersection denial: missing profile:read blocks tab', () {
      expect(
        SettingsAccessibilityAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileUpdate]),
        ),
        isFalse,
      );
      expect(
        SettingsAccessibilityAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isFalse,
      );
    });

    test('intersection presence: profile:read allows read atoms', () {
      expect(
        SettingsAccessibilityAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
      expect(
        SettingsAccessibilityAtomPermissions.reduceMotionValue.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
    });

    test('local accessibility prefs update with profile:read', () {
      expect(
        SettingsAccessibilityAtomPermissions.update.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isTrue,
      );
      expect(
        SettingsAccessibilityAtomPermissions.update.isAllowed(
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
        SettingsAccessibilityAtomPermissions.create.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsAccessibilityAtomPermissions.delete.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsAccessibilityAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isTrue,
      );
      expect(
        SettingsAccessibilityAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileUpdate]),
        ),
        isFalse,
      );
    });

    test('view ∪ and nested cross-module rows are _(n/a)_', () {
      expect(SettingsAccessibilityAtomPermissions.tab.anyPermissions, isEmpty);
      expect(
        SettingsAccessibilityAtomPermissions.nestedRead.anyPermissions,
        isEmpty,
      );
      expect(
        SettingsAccessibilityAtomPermissions.nestedWrite,
        same(profileReadRequirement),
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
          SettingsAccessibilityAtomPermissions.tab.isAllowed(emptyModules),
          isTrue,
        );
        expect(
          SettingsAccessibilityAtomPermissions.update.isAllowed(emptyModules),
          isTrue,
        );
      },
    );

    test(
      'ABAC: missing facility still allows accessibility chrome '
      '(own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          <AppPermission>[AppPermissions.profileRead],
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          SettingsAccessibilityAtomPermissions.tab.isAllowed(noFacility),
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
