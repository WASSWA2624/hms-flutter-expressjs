import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';

void main() {
  group('SettingsWorkspaceAtomPermissions', () {
    test('reuses feature helpers (no second vocabulary)', () {
      expect(
        SettingsWorkspaceAtomPermissions.tab,
        same(settingsWorkspaceReadRequirement),
      );
      expect(
        SettingsWorkspaceAtomPermissions.read,
        same(settingsWorkspaceReadRequirement),
      );
      expect(
        SettingsWorkspaceAtomPermissions.create,
        same(settingsWorkspaceCreateRequirement),
      );
      expect(
        SettingsWorkspaceAtomPermissions.create,
        same(settingsFacilityAdminRequirement),
      );
      expect(
        SettingsWorkspaceAtomPermissions.update,
        same(settingsWorkspaceUpdateRequirement),
      );
      expect(
        SettingsWorkspaceAtomPermissions.delete,
        same(settingsWorkspaceDeleteRequirement),
      );
      expect(
        SettingsWorkspaceAtomPermissions.adminGate,
        same(settingsWorkspaceAdminRequirement),
      );
      expect(
        SettingsWorkspaceAtomPermissions.hrGate,
        same(settingsWorkspaceHrRequirement),
      );
      expect(
        SettingsWorkspaceAtomPermissions.hrCreate,
        same(settingsWorkspaceHrCreateRequirement),
      );
    });

    test('matrix read ∩ requires profile:read (intersection denial)', () {
      expect(
        SettingsWorkspaceAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isFalse,
      );
      expect(
        SettingsWorkspaceAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[AppPermissions.hrRead]),
        ),
        isFalse,
      );
      expect(
        settingsWorkspaceSectionVisible(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isFalse,
      );
    });

    test('matrix read ∩ + admin ∪ allows read atoms', () {
      expect(
        SettingsWorkspaceAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.facilityAdmin,
          ]),
        ),
        isTrue,
      );
      expect(
        SettingsWorkspaceAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.tenantAdmin,
          ]),
        ),
        isTrue,
      );
      expect(
        SettingsWorkspaceAtomPermissions.tab.isAllowed(
          _policy(<AppPermission>[
            AppPermissions.profileRead,
            AppPermissions.platformAdmin,
          ]),
        ),
        isTrue,
      );
    });

    test('matrix view ∪ includes hr:read with profile:read', () {
      final AppAccessPolicy hrReader = _policy(
        <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.hrRead,
        ],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'hr-rosters'),
        ],
      );

      expect(
        SettingsWorkspaceAtomPermissions.tab.isAllowed(hrReader),
        isTrue,
      );
      expect(
        settingsWorkspaceHrRequirement.isAllowed(hrReader),
        isTrue,
      );
      expect(settingsWorkspaceSectionVisible(hrReader), isTrue);
    });

    test('source admin gate keeps tenant ABAC (strip without tenant)', () {
      final AppAccessPolicy noTenant = _policy(
        <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        tenantId: null,
        facilityId: 'facility-1',
      );

      expect(noTenant.hasTenantContext, isFalse);
      expect(noTenant.isPlatformElevated, isFalse);
      expect(settingsWorkspaceAdminRequirement.isAllowed(noTenant), isFalse);
      expect(settingsWorkspaceSectionVisible(noTenant), isFalse);
      // Matrix read alone does not encode tenant ABAC.
      expect(
        SettingsWorkspaceAtomPermissions.tab.isAllowed(noTenant),
        isTrue,
      );
    });

    test('create ∩ facility:admin; HR create keeps source mapping', () {
      expect(
        SettingsWorkspaceAtomPermissions.create.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
      expect(
        SettingsWorkspaceAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.profileRead]),
        ),
        isFalse,
      );
      expect(
        SettingsWorkspaceAtomPermissions.create.isAllowed(
          _policy(<AppPermission>[AppPermissions.facilityAdmin]),
        ),
        isTrue,
      );

      final AppAccessPolicy hrWriter = _policy(
        <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.hrWrite,
        ],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'hr-rosters'),
        ],
      );
      expect(
        SettingsWorkspaceAtomPermissions.create.isAllowed(hrWriter),
        isFalse,
      );
      expect(
        SettingsWorkspaceAtomPermissions.hrCreate.isAllowed(hrWriter),
        isTrue,
      );
      expect(settingsWorkspaceCanCreate(hrWriter), isTrue);
    });

    test('update ∩ profile:update and delete ∩ facility:admin (not mounted)', () {
      expect(
        SettingsWorkspaceAtomPermissions.update.allPermissions,
        <AppPermission>[AppPermissions.profileUpdate],
      );
      expect(
        SettingsWorkspaceAtomPermissions.delete.allPermissions,
        <AppPermission>[AppPermissions.facilityAdmin],
      );
    });

    test('nested cross-module rows are _(n/a)_', () {
      expect(
        SettingsWorkspaceAtomPermissions.nestedRead,
        same(settingsWorkspaceReadRequirement),
      );
      expect(
        SettingsWorkspaceAtomPermissions.nestedWrite,
        same(settingsWorkspaceCreateRequirement),
      );
    });

    test(
      'subscription strip: hr:read alone without hr-rosters denies HR ∪ arm',
      () {
        final AppAccessPolicy noModule = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            permissions: <AppPermission>{
              AppPermissions.profileRead,
              AppPermissions.hrRead,
            },
            isAuthorizationHydrated: true,
            user: const AuthUserProfile(
              id: 'user-1',
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
              roles: <String>['HR'],
            ),
            moduleEntitlements: const <AppModuleEntitlement>[],
          ),
        );

        expect(
          SettingsWorkspaceAtomPermissions.tab.isAllowed(noModule),
          isFalse,
        );
        expect(settingsWorkspaceHrRequirement.isAllowed(noModule), isFalse);
        expect(settingsWorkspaceSectionVisible(noModule), isFalse);
      },
    );

    test(
      'facility:admin ∪ still allows when plan has no hr-rosters module',
      () {
        final AppAccessPolicy adminOnly = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            permissions: <AppPermission>{
              AppPermissions.profileRead,
              AppPermissions.facilityAdmin,
            },
            isAuthorizationHydrated: true,
            user: const AuthUserProfile(
              id: 'user-1',
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
              roles: <String>['FACILITY_ADMIN'],
            ),
            moduleEntitlements: const <AppModuleEntitlement>[],
          ),
        );

        expect(
          SettingsWorkspaceAtomPermissions.tab.isAllowed(adminOnly),
          isTrue,
        );
        expect(settingsWorkspaceSectionVisible(adminOnly), isTrue);
      },
    );
  });
}

AppAccessPolicy _policy(
  List<AppPermission> permissions, {
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'hr-rosters'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      permissions: permissions.toSet(),
      isAuthorizationHydrated: true,
      user: AuthUserProfile(
        id: 'user-1',
        tenantId: tenantId,
        facilityId: facilityId,
        roles: const <String>['doctor'],
      ),
      moduleEntitlements: modules,
    ),
  ).copyWithPermissions(permissions);
}
