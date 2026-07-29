import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
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
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_workspace_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
<<<<<<< Updated upstream
  testWidgets(
    'renders flat workspace with module Open and Create for facility:admin',
    (WidgetTester tester) async {
      await _pumpWorkspace(
        tester,
        workspace: _workspace(SettingsWorkspaceStatus.ready),
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
      );

      expect(find.text('Administrative setup workspace'), findsOneWidget);
      expect(find.text('Organization'), findsWidgets);
      expect(find.text('Tenant'), findsWidgets);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Search setup modules'), findsWidgets);

      expect(find.text('Context summary'), findsNothing);
      expect(find.text('Setup checklist'), findsNothing);
      expect(find.text('Quick actions'), findsNothing);
      expect(find.text('Unavailable'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('omits Open when module cannot be read', (
=======
  testWidgets('renders flattened workspace with module Open as sole entry', (
>>>>>>> Stashed changes
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(
      tester,
      workspace: _workspace(
        SettingsWorkspaceStatus.ready,
        canRead: false,
        canCreate: false,
      ),
      permissions: <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.facilityAdmin,
      ],
    );

    expect(find.text('Tenant'), findsWidgets);
<<<<<<< Updated upstream
    expect(find.text('Open'), findsNothing);
    expect(find.text('Create'), findsNothing);
    expect(find.text('Unavailable'), findsNothing);
=======
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);

    // Nested overview/setup/modules shell and parallel shortcuts removed.
    expect(find.text('Context summary'), findsNothing);
    expect(find.text('Quick actions'), findsNothing);
    expect(find.text('Create Tenant'), findsNothing);
  });

  testWidgets('checklist is status-only; modules own Open and Create', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      ProviderScope(
        overrides: [
          settingsWorkspaceRepositoryProvider.overrideWithValue(
            _FakeSettingsWorkspaceRepository(
              workspace: _workspace(SettingsWorkspaceStatus.ready),
              referenceData: _referenceData(),
            ),
          ),
        ],
        child: const SettingsWorkspaceSection(),
      ),
      size: const Size(1280, 1200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Setup checklist'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Quick actions'), findsNothing);
    expect(find.text('Manage tenants'), findsNothing);
>>>>>>> Stashed changes
  });

  testWidgets(
    'read-only admin sees Open but not Create without facility:admin create ∩',
    (WidgetTester tester) async {
      await _pumpWorkspace(
        tester,
        workspace: _workspace(SettingsWorkspaceStatus.ready),
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.tenantAdmin,
        ],
      );

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Create'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'HR writer mounts Create via source HR create mapping',
    (WidgetTester tester) async {
      await _pumpWorkspace(
        tester,
        workspace: _workspace(SettingsWorkspaceStatus.ready),
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.hrWrite,
        ],
        roles: const <String>['HR'],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'hr-rosters'),
        ],
      );

      expect(find.text('Administrative setup workspace'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    },
  );

  testWidgets(
    'HR reader (hr:read ∪) sees Open but not Create without write ∩',
    (WidgetTester tester) async {
      await _pumpWorkspace(
        tester,
        workspace: _workspace(SettingsWorkspaceStatus.ready),
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.hrRead,
        ],
        roles: const <String>['HR'],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'hr-rosters'),
        ],
      );

      expect(find.text('Administrative setup workspace'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Create'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'system:admin ∪ with profile:read mounts authorized workspace chrome',
    (WidgetTester tester) async {
      await _pumpWorkspace(
        tester,
        workspace: _workspace(SettingsWorkspaceStatus.ready),
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.systemAdmin,
        ],
        roles: const <String>['SUPER_ADMIN'],
      );

      expect(find.text('Administrative setup workspace'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      // Create remains ∩ facility:admin — system:admin alone does not mount it.
      expect(find.text('Create'), findsNothing);
    },
  );

  testWidgets(
    'authorized loading and error/retry states remain observable',
    (WidgetTester tester) async {
      final Completer<Result<SettingsWorkspace>> pendingWorkspace =
          Completer<Result<SettingsWorkspace>>();
      final _FakeSettingsWorkspaceRepository repository =
          _FakeSettingsWorkspaceRepository(
            workspace: _workspace(SettingsWorkspaceStatus.ready),
            referenceData: _referenceData(),
            pendingWorkspace: pendingWorkspace,
          );

      await _pumpWorkspace(
        tester,
        workspace: _workspace(SettingsWorkspaceStatus.ready),
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        repository: repository,
        settle: false,
      );
      await tester.pump();

      expect(find.text('Loading settings workspace'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsOneWidget);

      pendingWorkspace.complete(
        const Result<SettingsWorkspace>.failure(AppFailure.network()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings workspace unavailable'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      repository.pendingWorkspace = null;
      repository.workspace = _workspace(SettingsWorkspaceStatus.ready);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
    },
  );

  testWidgets(
    'section absent without workspace read rights (intersection denial)',
    (WidgetTester tester) async {
      await _pumpWorkspace(
        tester,
        workspace: _workspace(SettingsWorkspaceStatus.ready),
        permissions: <AppPermission>[AppPermissions.facilityAdmin],
      );

      expect(find.text('Administrative setup workspace'), findsNothing);
      expect(find.text('Open'), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('renders tenant selector when backend requires tenant context', (
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(
      tester,
      workspace: _workspace(SettingsWorkspaceStatus.tenantContextRequired),
      permissions: <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.facilityAdmin,
      ],
      size: const Size(900, 700),
    );

    expect(find.text('Tenant context required'), findsOneWidget);
    expect(find.text('Tenant'), findsWidgets);
    expect(find.text('Tenant context'), findsWidgets);
  });

  testWidgets(
    'authorized empty state and refresh remain observable',
    (WidgetTester tester) async {
      await _pumpWorkspace(
        tester,
        workspace: _workspace(
          SettingsWorkspaceStatus.ready,
          emptyModules: true,
        ),
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
      );

      expect(find.text('No setup modules found'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    },
  );

  testWidgets('mobile viewport keeps Open Create without clipping', (
    WidgetTester tester,
  ) async {
    await _pumpWorkspace(
      tester,
      workspace: _workspace(SettingsWorkspaceStatus.ready),
      permissions: <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.facilityAdmin,
      ],
      size: const Size(390, 844),
      scrollable: true,
    );

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop viewport light + dark themes keep authorized chrome', (
    WidgetTester tester,
  ) async {
    for (final ThemeMode themeMode in <ThemeMode>[
      ThemeMode.light,
      ThemeMode.dark,
    ]) {
      await _pumpWorkspace(
        tester,
        workspace: _workspace(SettingsWorkspaceStatus.ready),
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        size: const Size(1280, 1200),
        themeMode: themeMode,
      );

      expect(find.text('Administrative setup workspace'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.byType(AppTextField), findsWidgets);
    }
  });

  testWidgets(
    'filter search syncs query after submit (post-mutation sync)',
    (WidgetTester tester) async {
      final _FakeSettingsWorkspaceRepository repository =
          _FakeSettingsWorkspaceRepository(
            workspace: _workspace(SettingsWorkspaceStatus.ready),
            referenceData: _referenceData(),
          );

      await _pumpWorkspace(
        tester,
        workspace: _workspace(SettingsWorkspaceStatus.ready),
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        repository: repository,
      );

      await tester.enterText(find.byType(AppTextField).first, 'ward');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(repository.lastQuery?.search, 'ward');
    },
  );

  testWidgets(
    'settings page strip hides workspace without profile:read ∩',
    (WidgetTester tester) async {
      await _pumpSettingsPage(
        tester,
        permissions: <AppPermission>[AppPermissions.facilityAdmin],
        tab: 'workspace',
      );

      expect(find.text('Administrative setup workspace'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'settings page strip shows workspace for facility:admin ∪ with profile:read',
    (WidgetTester tester) async {
      await _pumpSettingsPage(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.facilityAdmin,
        ],
        tab: 'workspace',
      );

      expect(find.text('Administrative setup workspace'), findsWidgets);
      expect(find.text('Open'), findsOneWidget);
    },
  );

  testWidgets(
    'settings page strip shows workspace for hr:read ∪ with profile:read',
    (WidgetTester tester) async {
      await _pumpSettingsPage(
        tester,
        permissions: <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.hrRead,
        ],
        roles: const <String>['HR'],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'hr-rosters'),
        ],
        tab: 'workspace',
        workspace: _hrWorkspace(),
      );

      expect(find.text('Administrative setup workspace'), findsWidgets);
      expect(find.text('Department'), findsWidgets);
      expect(find.text('Unit'), findsWidgets);
    },
  );

  test('no nested cross-module write vocabulary on workspace helpers', () {
    expect(
      SettingsWorkspaceAtomPermissions.nestedRead.anyPermissions,
      settingsWorkspaceViewAnyPermissions,
    );
    expect(
      SettingsWorkspaceAtomPermissions.nestedWrite.allPermissions,
      <AppPermission>[AppPermissions.facilityAdmin],
    );
  });
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required SettingsWorkspace workspace,
  required List<AppPermission> permissions,
  List<String> roles = const <String>['FACILITY_ADMIN'],
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[],
  Size size = const Size(1280, 1200),
  ThemeMode themeMode = ThemeMode.light,
  bool scrollable = false,
  bool settle = true,
  _FakeSettingsWorkspaceRepository? repository,
}) async {
  final AuthSession session = AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    permissions: permissions.toSet(),
    isAuthorizationHydrated: true,
    user: AuthUserProfile(
      id: 'user-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      roles: roles,
    ),
    moduleEntitlements: modules,
  );
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    session,
  ).copyWithPermissions(permissions);
  final _FakeSettingsWorkspaceRepository resolvedRepository =
      repository ??
      _FakeSettingsWorkspaceRepository(
        workspace: workspace,
        referenceData: _referenceData(),
      );

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final Widget body = scrollable
      ? const SingleChildScrollView(child: SettingsWorkspaceSection())
      : const SettingsWorkspaceSection();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy),
        // Ready session skips bearer-token waits during workspace bootstrap.
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        settingsWorkspaceRepositoryProvider.overrideWithValue(
          resolvedRepository,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: body),
      ),
    ),
  );
  await tester.pump();
  if (!settle) {
    return;
  }
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Future<void> _pumpSettingsPage(
  WidgetTester tester, {
  required List<AppPermission> permissions,
  required String tab,
  List<String> roles = const <String>['FACILITY_ADMIN'],
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[],
  SettingsWorkspace? workspace,
  Size size = const Size(1280, 1400),
}) async {
  final AuthSession session = AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    permissions: permissions.toSet(),
    isAuthorizationHydrated: true,
    user: AuthUserProfile(
      id: 'user-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      roles: roles,
    ),
    moduleEntitlements: modules,
  );
  final AppAccessPolicy policy = AppAccessPolicy.fromSession(
    session,
  ).copyWithPermissions(permissions);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(policy),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        settingsWorkspaceRepositoryProvider.overrideWithValue(
          _FakeSettingsWorkspaceRepository(
            workspace: workspace ?? _workspace(SettingsWorkspaceStatus.ready),
            referenceData: _referenceData(),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SettingsPage(initialQuery: SettingsPageQuery(tab: tab)),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

final class _FakeSettingsWorkspaceRepository
    implements SettingsWorkspaceRepository {
  _FakeSettingsWorkspaceRepository({
    required this.workspace,
    required this.referenceData,
    this.pendingWorkspace,
    this.pendingReference,
  });

  SettingsWorkspace workspace;
  SettingsReferenceData referenceData;
  Completer<Result<SettingsWorkspace>>? pendingWorkspace;
  Completer<Result<SettingsReferenceData>>? pendingReference;
  SettingsWorkspaceQuery? lastQuery;

  @override
  Future<Result<SettingsWorkspace>> getWorkspace(
    SettingsWorkspaceQuery query,
  ) async {
    lastQuery = query;
    final Completer<Result<SettingsWorkspace>>? pending = pendingWorkspace;
    if (pending != null) {
      return pending.future;
    }
    return Result<SettingsWorkspace>.success(workspace);
  }

  @override
  Future<Result<SettingsReferenceData>> getReferenceData(
    SettingsWorkspaceQuery query,
  ) async {
    lastQuery = query;
    final Completer<Result<SettingsReferenceData>>? pending = pendingReference;
    if (pending != null) {
      return pending.future;
    }
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

SettingsWorkspace _workspace(
  SettingsWorkspaceStatus status, {
  bool canRead = true,
  bool canCreate = true,
  bool emptyModules = false,
}) {
  final bool ready = status == SettingsWorkspaceStatus.ready;
  return SettingsWorkspace(
    status: status,
    generatedAt: DateTime.utc(2026, 5, 22, 9),
    context: SettingsWorkspaceContext(
      state: status,
      tenantName: ready ? 'Acme Health' : null,
      facilityName: ready ? 'Central Hospital' : null,
      roleKeys: const <String>['TENANT_ADMIN'],
    ),
    summaryCards: ready
        ? const <SettingsSummaryCard>[
            SettingsSummaryCard(
              id: 'organization',
              labelKey: 'settings.workspace.summary.organization',
              totalModules: 1,
              configuredModules: 1,
              attentionModules: 0,
              totalRecords: 1,
              state: 'configured',
            ),
          ]
        : const <SettingsSummaryCard>[],
    checklist: ready
        ? const SettingsChecklist(
            completedCount: 1,
            totalCount: 1,
            items: <SettingsChecklistItem>[
              SettingsChecklistItem(
                id: 'tenant',
                labelKey: 'settings.workspace.checklist.tenant',
                completed: true,
                priority: 1,
                route: '/settings/tenants',
              ),
            ],
          )
        : const SettingsChecklist(
            completedCount: 0,
            totalCount: 0,
            items: <SettingsChecklistItem>[],
          ),
    quickActions: ready
        ? const <SettingsQuickAction>[
            SettingsQuickAction(
              id: 'tenant:create',
              moduleId: 'tenant',
              moduleLabelKey: 'settings.tabs.tenant',
              labelKey: 'settings.workspace.quickActions.createModule',
              canExecute: true,
              route: '/settings/tenants/create',
            ),
          ]
        : const <SettingsQuickAction>[],
    moduleGroups: ready && !emptyModules
        ? <SettingsModuleGroup>[
            SettingsModuleGroup(
              id: 'organization',
              labelKey: 'settings.sidebar.groups.organization',
              modules: <SettingsModuleItem>[
                SettingsModuleItem(
                  moduleId: 'tenant',
                  labelKey: 'settings.tabs.tenant',
                  groupId: 'organization',
                  count: 1,
                  state: SettingsModuleState.configured,
                  canRead: canRead,
                  canWrite: canCreate,
                  canCreate: canCreate,
                  dependencies: const <SettingsModuleDependency>[],
                  route: '/settings/tenants',
                  createRoute: '/settings/tenants/create',
                ),
              ],
            ),
          ]
        : const <SettingsModuleGroup>[],
    referenceData: _referenceData(),
    stats: const SettingsWorkspaceStats(
      totalModules: 1,
      configuredModules: 1,
      attentionModules: 0,
      totalRecords: 1,
    ),
    permissions: const SettingsWorkspacePermissions(canWrite: true),
  );
}
