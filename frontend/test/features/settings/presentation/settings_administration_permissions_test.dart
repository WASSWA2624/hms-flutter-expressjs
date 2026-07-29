import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';

void main() {
  group('SettingsAdministrationAtomPermissions', () {
    test('module label and feature helpers (no second vocabulary)', () {
      expect(settingsAdministrationModuleLabel, 'settings / admin setup');
      expect(
        SettingsAdministrationAtomPermissions.tab,
        same(settingsAdministrationReadRequirement),
      );
      expect(
        SettingsAdministrationAtomPermissions.tenantFacilitySetup,
        same(RouteAccessCatalog.setupEntry),
      );
      expect(
        SettingsAdministrationAtomPermissions.subscriptions,
        same(RouteAccessCatalog.subscriptionsEntry),
      );
      expect(
        SettingsAdministrationAtomPermissions.accessAdmin,
        same(RouteAccessCatalog.accessAdminEntry),
      );
      expect(
        SettingsAdministrationAtomPermissions.routeEntry,
        same(RouteAccessCatalog.authenticatedCore),
      );
      expect(
        SettingsAdministrationAtomPermissions.create,
        same(settingsFacilityAdminRequirement),
      );
      expect(
        SettingsAdministrationAtomPermissions.delete,
        same(settingsFacilityAdminRequirement),
      );
    });

    test('view = profile:read ∩ admin ∪', () {
      expect(
        settingsAdministrationReadRequirement.allPermissions,
        <AppPermission>[AppPermissions.profileRead],
      );
      expect(
        settingsAdministrationReadRequirement.anyPermissions,
        settingsAdminAnyPermissions,
      );
      expect(
        settingsAdminAnyPermissions,
        <AppPermission>[
          AppPermissions.facilityAdmin,
          AppPermissions.tenantAdmin,
          AppPermissions.systemAdmin,
        ],
      );
    });

    test('intersection denial: missing profile:read blocks tab', () {
      expect(
        SettingsAdministrationAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[
            AppPermissions.facilityAdmin,
            AppPermissions.setupRead,
          ]),
        ),
        isFalse,
      );
    });

    test('intersection denial: profile:read without admin ∪ blocks tab', () {
      expect(
        SettingsAdministrationAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isFalse,
      );
    });

    test('union allowance: each admin ∪ key satisfies tab with profile:read', () {
      for (final AppPermission admin in settingsAdminAnyPermissions) {
        expect(
          SettingsAdministrationAtomPermissions.tab.isAllowed(
            _policy(<AppPermission>[AppPermissions.profileRead, admin]),
          ),
          isTrue,
          reason: '$admin should satisfy admin ∪',
        );
      }
    });

    test('create/update/delete matrix ∩ (not mounted on tab)', () {
      expect(
        SettingsAdministrationAtomPermissions.create.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsAdministrationAtomPermissions.update.allPermissions,
        <AppPermission>[AppPermissions.profileUpdate],
      );
      expect(
        SettingsAdministrationAtomPermissions.delete.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsAdministrationAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isTrue,
      );
      expect(
        SettingsAdministrationAtomPermissions.update.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isFalse,
      );
      expect(
        SettingsAdministrationAtomPermissions.update.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileUpdate]),
        ),
        isTrue,
      );
    });

    test('nested cross-module rows are _(n/a)_ / reuse tab gates', () {
      expect(
        SettingsAdministrationAtomPermissions.nestedRead,
        same(settingsAdministrationReadRequirement),
      );
      expect(
        SettingsAdministrationAtomPermissions.nestedWrite,
        same(settingsAdministrationUpdateRequirement),
      );
    });

    test(
      'subscription strip: subscriptions navigate needs subscription-controls',
      () {
        final AppAccessPolicy noModule = _policy(
          <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.facilityAdmin,
            AppPermissions.subscriptionsRead,
          ],
          modules: const <AppModuleEntitlement>[],
        );
        expect(
          SettingsAdministrationAtomPermissions.subscriptions.isAllowed(
            noModule,
          ),
          isFalse,
        );

        final AppAccessPolicy withModule = _policy(
          <AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.facilityAdmin,
            AppPermissions.subscriptionsRead,
          ],
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'subscription-controls',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          SettingsAdministrationAtomPermissions.subscriptions.isAllowed(
            withModule,
          ),
          isTrue,
        );
      },
    );

    test('ABAC: setup navigate strips without facility context', () {
      final AppAccessPolicy noFacility = _policy(
        <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
          AppPermissions.setupRead,
        ],
        facilityId: null,
      );
      expect(noFacility.hasFacilityContext, isFalse);
      expect(
        SettingsAdministrationAtomPermissions.tenantFacilitySetup.isAllowed(
          noFacility,
        ),
        isFalse,
      );
    });

    test('ABAC: access-admin navigate strips without tenant context', () {
      final AppAccessPolicy noTenant = _policy(
        <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.tenantAdmin,
          AppPermissions.accessAdminRead,
        ],
        tenantId: null,
        facilityId: null,
      );
      expect(noTenant.hasTenantContext, isFalse);
      expect(
        SettingsAdministrationAtomPermissions.accessAdmin.isAllowed(noTenant),
        isFalse,
      );
    });

    test(
      'settingsAdministrationSectionVisible collapses without destinations',
      () {
        final AppAccessPolicy adminOnly = _policy(<AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ]);
        expect(
          settingsAdministrationSectionVisible(
            adminOnly,
            settingsWorkspaceVisible: false,
          ),
          isFalse,
        );

        final AppAccessPolicy withSetup = _policy(<AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
          AppPermissions.setupRead,
        ]);
        expect(
          settingsAdministrationSectionVisible(
            withSetup,
            settingsWorkspaceVisible: false,
          ),
          isTrue,
        );
      },
    );

    test('workspace mode exposes only subscriptions destination', () {
      expect(
        settingsAdministrationNavigateDestinations(
          settingsWorkspaceVisible: true,
        ),
        orderedEquals(<Object>[
          settingsAdministrationSubscriptionsNavigateRequirement,
        ]),
      );
      expect(
        settingsAdministrationNavigateDestinations(
          settingsWorkspaceVisible: false,
        ),
        orderedEquals(<Object>[
          settingsAdministrationTenantFacilityNavigateRequirement,
          settingsAdministrationSubscriptionsNavigateRequirement,
          settingsAdministrationAccessAdminNavigateRequirement,
        ]),
      );
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
