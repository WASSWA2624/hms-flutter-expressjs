import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/settings/data/repositories/settings_workspace_repository_impl.dart';
import 'package:hosspi_hms/features/settings/domain/entities/settings_workspace_entities.dart';
import 'package:hosspi_hms/features/settings/domain/repositories/settings_workspace_repository.dart';
import 'package:hosspi_hms/features/settings/presentation/pages/settings_page.dart';

import '../../../../helpers/test_harness.dart';

void main() {
  testWidgets(
    'HR policy sees personal settings and HR facility setup workspace',
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
            initialSessionStateProvider.overrideWithValue(
              SessionState.authenticated(session: session),
            ),
            settingsWorkspaceRepositoryProvider.overrideWithValue(
              _FakeSettingsWorkspaceRepository(
                workspace: _hrWorkspace(),
                referenceData: _referenceData(),
              ),
            ),
          ],
          child: const SettingsPage(initialQuery: SettingsPageQuery()),
        ),
        size: const Size(1280, 1400),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Accessibility'), findsOneWidget);
      expect(find.text('Account and security'), findsOneWidget);
      expect(find.text('Administration boundaries'), findsOneWidget);
      expect(find.text('Tenant and facility setup'), findsOneWidget);
      expect(find.text('Administrative setup workspace'), findsOneWidget);
      expect(find.text('Department'), findsWidgets);
      expect(find.text('Unit'), findsWidgets);
      expect(find.text('Subscriptions'), findsNothing);
      expect(find.text('Users and access'), findsNothing);
      expect(find.text('User and security settings'), findsNothing);
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
