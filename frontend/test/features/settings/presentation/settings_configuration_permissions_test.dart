import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';

void main() {
  group('SettingsConfigurationAtomPermissions', () {
    test('module label and feature helpers (no second vocabulary)', () {
      expect(settingsConfigurationModuleLabel, 'settings / admin setup');
      expect(
        SettingsConfigurationAtomPermissions.tab,
        same(settingsConfigurationReadRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.listChrome,
        same(settingsConfigurationReadRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.tenantPanel,
        same(settingsConfigurationTenantRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.facilityPanel,
        same(settingsConfigurationFacilityRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.tenantSave,
        same(settingsConfigurationTenantRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.facilitySave,
        same(settingsConfigurationFacilityRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.tenantResetDialog,
        same(settingsConfigurationTenantRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.facilityResetDialog,
        same(settingsConfigurationFacilityRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.create,
        same(settingsFacilityAdminRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.update,
        same(settingsFacilityAdminRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.delete,
        same(settingsFacilityAdminRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.routeEntry,
        same(RouteAccessCatalog.authenticatedCore),
      );
    });

    test('view = profile:read ∩ admin ∪', () {
      expect(
        settingsConfigurationReadRequirement.allPermissions,
        <AppPermission>[AppPermissions.profileRead],
      );
      expect(
        settingsConfigurationReadRequirement.anyPermissions,
        settingsAdminAnyPermissions,
      );
      expect(
        settingsAdminAnyPermissions,
        <AppPermission>[
          AppPermissions.facilityAdmin,
          AppPermissions.tenantAdmin,
          AppPermissions.platformAdmin,
        ],
      );
    });

    test('intersection denial: missing profile:read blocks tab', () {
      expect(
        SettingsConfigurationAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[
            AppPermissions.facilityAdmin,
            AppPermissions.tenantAdmin,
          ]),
        ),
        isFalse,
      );
    });

    test('intersection denial: profile:read without admin ∪ blocks tab', () {
      expect(
        SettingsConfigurationAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isFalse,
      );
    });

    test('union allowance: each admin ∪ key satisfies tab with profile:read', () {
      for (final AppPermission admin in settingsAdminAnyPermissions) {
        expect(
          SettingsConfigurationAtomPermissions.tab.isAllowed(
            _policy(<AppPermission>[AppPermissions.profileRead, admin]),
          ),
          isTrue,
          reason: '$admin should satisfy admin ∪',
        );
      }
    });

    test(
      'source panel mapping vs matrix update ∩ facility:admin',
      () {
        // Matrix update ∩ facility:admin (documented; Save/Reset use source).
        expect(
          settingsConfigurationUpdateRequirement.allPermissions,
          <AppPermission>[AppPermissions.facilityAdmin],
        );

        // Source tenant: tenant:admin ∪ platform:admin — not facility:admin alone.
        expect(
          SettingsConfigurationAtomPermissions.tenantPanel.isAllowed(
            _policy(<AppPermission>[
              AppPermissions.profileRead,
              AppPermissions.facilityAdmin,
            ]),
          ),
          isFalse,
        );
        expect(
          SettingsConfigurationAtomPermissions.tenantPanel.isAllowed(
            _policy(<AppPermission>[
              AppPermissions.profileRead,
              AppPermissions.tenantAdmin,
            ]),
          ),
          isTrue,
        );

        // Source facility includes matrix facility:admin within admin ∪.
        expect(
          SettingsConfigurationAtomPermissions.facilityPanel.isAllowed(
            _policy(<AppPermission>[
              AppPermissions.profileRead,
              AppPermissions.facilityAdmin,
            ]),
          ),
          isTrue,
        );
      },
    );

    test('create/delete matrix ∩ facility:admin (not mounted on tab)', () {
      expect(
        SettingsConfigurationAtomPermissions.create.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsConfigurationAtomPermissions.delete.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsConfigurationAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isTrue,
      );
      expect(
        SettingsConfigurationAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isFalse,
      );
    });

    test('nested cross-module rows are _(n/a)_ / reuse tab gates', () {
      expect(
        SettingsConfigurationAtomPermissions.nestedRead,
        same(settingsConfigurationReadRequirement),
      );
      expect(
        SettingsConfigurationAtomPermissions.nestedWrite,
        same(settingsConfigurationUpdateRequirement),
      );
    });

    test('ABAC: facility panel strips without facility context', () {
      final AppAccessPolicy noFacility = _policy(
        <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        facilityId: null,
      );
      expect(noFacility.hasFacilityContext, isFalse);
      expect(
        SettingsConfigurationAtomPermissions.facilityPanel.isAllowed(
          noFacility,
        ),
        isFalse,
      );
      expect(settingsConfigurationSectionVisible(noFacility), isFalse);
    });

    test('ABAC: tenant panel strips without tenant context', () {
      final AppAccessPolicy noTenant = _policy(
        <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.tenantAdmin,
        ],
        tenantId: null,
        facilityId: null,
      );
      expect(noTenant.hasTenantContext, isFalse);
      expect(
        SettingsConfigurationAtomPermissions.tenantPanel.isAllowed(noTenant),
        isFalse,
      );
    });

    test(
      'admin/profile keys are core — no subscription module strip on tab',
      () {
        // `_policy` defaults to an empty subscription module list.
        final AppAccessPolicy noModules = _policy(<AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ]);
        expect(
          SettingsConfigurationAtomPermissions.tab.isAllowed(noModules),
          isTrue,
        );
        expect(
          SettingsConfigurationAtomPermissions.facilityPanel.isAllowed(
            noModules,
          ),
          isTrue,
        );
        expect(settingsConfigurationSectionVisible(noModules), isTrue);
      },
    );

    test('settingsConfigurationSectionVisible collapses without a panel', () {
      final AppAccessPolicy readOnly = _policy(<AppPermission>[
        AppPermissions.profileRead,
      ]);
      expect(settingsConfigurationSectionVisible(readOnly), isFalse);

      final AppAccessPolicy facilityUnion = _policy(<AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.facilityAdmin,
      ]);
      expect(settingsConfigurationSectionVisible(facilityUnion), isTrue);
    });
  });
}

AppAccessPolicy _policy(
  List<AppPermission> permissions, {
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      permissions: permissions.toSet(),
      isAuthorizationHydrated: true,
      moduleEntitlements: modules,
      user: AuthUserProfile(
        id: 'user-1',
        tenantId: tenantId,
        facilityId: facilityId,
        roles: const <String>['doctor'],
      ),
    ),
  ).copyWithPermissions(permissions);
}
