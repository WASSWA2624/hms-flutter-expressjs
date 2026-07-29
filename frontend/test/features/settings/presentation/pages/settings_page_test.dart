import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/profile/data/repositories/user_profile_repository_impl.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';
import 'package:hosspi_hms/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:hosspi_hms/features/settings/data/repositories/settings_workspace_repository_impl.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';
import 'package:hosspi_hms/features/settings/domain/repositories/settings_workspace_repository.dart';
import 'package:hosspi_hms/features/settings/presentation/pages/settings_page.dart';

import '../../../../helpers/test_harness.dart';

void main() {
  testWidgets(
    'HR policy sees workspace without Administration tenant/facility duplicate',
    (WidgetTester tester) async {
      final AuthSession session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['HR'],
        ),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'hr-rosters'),
        ],
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        session,
      ).copyWithPermissions(<AppPermission>[AppPermissions.hrWrite]);

      await pumpLocalizedWidget(
        tester,
        ProviderScope(
          overrides: [
            appAccessPolicyProvider.overrideWithValue(policy),
            // Ready session skips bearer-token waits during workspace bootstrap.
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            settingsWorkspaceRepositoryProvider.overrideWithValue(
              _FakeSettingsWorkspaceRepository(
                workspace: _hrWorkspace(),
                referenceData: _referenceData(),
              ),
            ),
          ],
          child: const SettingsPage(
            initialQuery: SettingsPageQuery(tab: 'workspace'),
          ),
        ),
        size: const Size(1280, 1400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Administrative setup workspace'), findsWidgets);
      expect(find.text('Administration boundaries'), findsNothing);
      expect(find.text('Tenant and facility setup'), findsNothing);
      expect(find.text('Subscription plans'), findsNothing);
      expect(find.text('Users and access'), findsNothing);
      expect(find.text('Department'), findsWidgets);
      expect(find.text('Unit'), findsWidgets);
      expect(find.text('Quick actions'), findsNothing);
      expect(find.text('Setup checklist'), findsNothing);
      expect(find.text('Context summary'), findsNothing);
    },
  );

  testWidgets(
    'workspace-authorized elevated admin keeps Subscription plans only under Administration',
    (WidgetTester tester) async {
      final AuthSession session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['SUPER_ADMIN']),
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(session);

      await pumpLocalizedWidget(
        tester,
        ProviderScope(
          overrides: [
            appAccessPolicyProvider.overrideWithValue(policy),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            settingsWorkspaceRepositoryProvider.overrideWithValue(
              _FakeSettingsWorkspaceRepository(
                workspace: _hrWorkspace(),
                referenceData: _referenceData(),
              ),
            ),
          ],
          child: const SettingsPage(
            initialQuery: SettingsPageQuery(tab: 'administration'),
          ),
        ),
        size: const Size(1600, 1400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Administration boundaries'), findsWidgets);
      expect(find.text('Subscription plans'), findsWidgets);
      expect(find.text('Tenant and facility setup'), findsNothing);
      expect(find.text('Users and access'), findsNothing);
      expect(policy.isPlatformElevated, isTrue);
    },
  );

  testWidgets('retapping the selected settings tab keeps section content', (
    WidgetTester tester,
  ) async {
    final AuthSession session = AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: <String>['FACILITY_USER'],
      ),
    );
    final AppAccessPolicy policy = AppAccessPolicy.fromSession(session);

    await pumpLocalizedWidget(
      tester,
      ProviderScope(
        overrides: [
          appAccessPolicyProvider.overrideWithValue(policy),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
        ],
        child: const SettingsPage(initialQuery: SettingsPageQuery()),
      ),
      size: const Size(900, 1000),
    );
    await tester.pumpAndSettle();

    expect(find.text('App theme'), findsOneWidget);

    await tester.tap(find.text('Preferences').first);
    await tester.pumpAndSettle();

    expect(find.text('App theme'), findsOneWidget);
  });

  testWidgets(
    'Account and security strip is absent without profile:read',
    (WidgetTester tester) async {
      final AuthSession session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        permissions: const <AppPermission>{},
        isAuthorizationHydrated: true,
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['doctor'],
        ),
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        session,
      ).copyWithPermissions(const <AppPermission>[]);

      await pumpLocalizedWidget(
        tester,
        ProviderScope(
          overrides: [
            appAccessPolicyProvider.overrideWithValue(policy),
            initialSessionStateProvider.overrideWithValue(
              SessionState.authenticated(session: session),
            ),
          ],
          child: const SettingsPage(
            initialQuery: SettingsPageQuery(tab: 'account'),
          ),
        ),
        size: const Size(900, 1000),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account and security'), findsNothing);
      expect(find.text('Preferences'), findsWidgets);
      expect(find.text('App theme'), findsOneWidget);
    },
  );

  testWidgets(
    'Account and security strip is present with profile:read',
    (WidgetTester tester) async {
      final AuthSession session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        permissions: <AppPermission>{AppPermissions.profileRead},
        isAuthorizationHydrated: true,
        user: const AuthUserProfile(
          id: 'user-1',
          email: 'alex@example.com',
          firstName: 'Alex',
          lastName: 'Demo',
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['doctor'],
        ),
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        session,
      ).copyWithPermissions(<AppPermission>[AppPermissions.profileRead]);

      await pumpLocalizedWidget(
        tester,
        ProviderScope(
          overrides: [
            appAccessPolicyProvider.overrideWithValue(policy),
            initialSessionStateProvider.overrideWithValue(
              SessionState.authenticated(session: session),
            ),
            secureSessionStorageProvider.overrideWithValue(
              _TestSecureSessionStorage(),
            ),
            userProfileRepositoryProvider.overrideWithValue(
              _FakeUserProfileRepository(session),
            ),
          ],
          child: const SettingsPage(
            initialQuery: SettingsPageQuery(tab: 'account'),
          ),
        ),
        size: const Size(900, 1000),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account and security'), findsWidgets);
      expect(find.text('Edit profile'), findsNothing);
      expect(find.text('Change password'), findsNothing);
    },
  );
}

final class _FakeSettingsWorkspaceRepository
    implements SettingsWorkspaceRepository {
  const _FakeSettingsWorkspaceRepository({
    required this.workspace,
    required this.referenceData,
  });

  final SettingsWorkspace workspace;
  final SettingsReferenceData referenceData;

  @override
  Future<Result<SettingsWorkspace>> getWorkspace(
    SettingsWorkspaceQuery query,
  ) async {
    return Result<SettingsWorkspace>.success(workspace);
  }

  @override
  Future<Result<SettingsReferenceData>> getReferenceData(
    SettingsWorkspaceQuery query,
  ) async {
    return Result<SettingsReferenceData>.success(referenceData);
  }
}

final class _FakeUserProfileRepository implements UserProfileRepository {
  const _FakeUserProfileRepository(this.session);

  final AuthSession session;

  @override
  Future<Result<UserProfileView>> loadCurrentProfile(
    AuthSession session,
  ) async {
    return Result<UserProfileView>.success(
      UserProfileView(
        session: this.session,
        record: const UserProfileRecord(
          id: 'profile-1',
          userId: 'user-1',
          firstName: 'Alex',
          lastName: 'Demo',
          gender: 'UNKNOWN',
        ),
      ),
    );
  }

  @override
  Future<Result<UserProfileRecord>> updateProfile(
    String profileId,
    UserProfileDraft draft,
  ) async {
    return Result<UserProfileRecord>.success(
      UserProfileRecord(
        id: profileId,
        userId: 'user-1',
        firstName: draft.firstName,
        middleName: draft.middleName,
        lastName: draft.lastName,
        gender: draft.gender,
      ),
    );
  }
}

final class _TestSecureSessionStorage implements SecureSessionStorage {
  @override
  Future<SessionTokens?> readTokens() async =>
      SessionTokens(accessToken: 'access-token');

  @override
  Future<void> writeTokens(SessionTokens tokens) async {}

  @override
  Future<void> clear() async {}
}

SettingsReferenceData _referenceData() {
  return const SettingsReferenceData(
    tenants: <SettingsReferenceOption>[
      SettingsReferenceOption(id: 'TEN-1', label: 'Acme Health'),
    ],
    facilities: <SettingsReferenceOption>[
      SettingsReferenceOption(id: 'FAC-1', label: 'Central Hospital'),
    ],
  );
}

SettingsWorkspace _hrWorkspace() {
  return SettingsWorkspace(
    status: SettingsWorkspaceStatus.ready,
    generatedAt: DateTime.utc(2026, 5, 22, 9),
    context: const SettingsWorkspaceContext(
      state: SettingsWorkspaceStatus.ready,
      tenantName: 'Acme Health',
      facilityName: 'Central Hospital',
      roleKeys: <String>['HR'],
    ),
    summaryCards: const <SettingsSummaryCard>[
      SettingsSummaryCard(
        id: 'organization',
        labelKey: 'settings.workspace.summary.organization',
        totalModules: 2,
        configuredModules: 2,
        attentionModules: 0,
        totalRecords: 4,
        state: 'configured',
      ),
    ],
    checklist: const SettingsChecklist(
      completedCount: 1,
      totalCount: 1,
      items: <SettingsChecklistItem>[
        SettingsChecklistItem(
          id: 'department',
          labelKey: 'settings.workspace.checklist.department',
          completed: true,
          priority: 1,
          route: '/settings/departments',
        ),
      ],
    ),
    quickActions: const <SettingsQuickAction>[],
    moduleGroups: const <SettingsModuleGroup>[
      SettingsModuleGroup(
        id: 'organization',
        labelKey: 'settings.sidebar.groups.organization',
        modules: <SettingsModuleItem>[
          SettingsModuleItem(
            moduleId: 'department',
            labelKey: 'settings.tabs.department',
            groupId: 'organization',
            count: 2,
            state: SettingsModuleState.configured,
            canRead: true,
            canWrite: true,
            canCreate: true,
            dependencies: <SettingsModuleDependency>[],
            route: '/settings/departments',
            createRoute: '/settings/departments/create',
          ),
          SettingsModuleItem(
            moduleId: 'unit',
            labelKey: 'settings.tabs.unit',
            groupId: 'organization',
            count: 2,
            state: SettingsModuleState.configured,
            canRead: true,
            canWrite: true,
            canCreate: true,
            dependencies: <SettingsModuleDependency>[],
            route: '/settings/units',
            createRoute: '/settings/units/create',
          ),
        ],
      ),
    ],
    referenceData: _referenceData(),
    stats: const SettingsWorkspaceStats(
      totalModules: 2,
      configuredModules: 2,
      attentionModules: 0,
      totalRecords: 4,
    ),
    permissions: const SettingsWorkspacePermissions(canWrite: true),
  );
}
