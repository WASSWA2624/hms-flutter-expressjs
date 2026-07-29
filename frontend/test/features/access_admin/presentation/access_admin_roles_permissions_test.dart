import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
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
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/access_admin_access.dart';
import 'package:hosspi_hms/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart';
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_dialogs.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccessAdminRepository extends Mock
    implements AccessAdminRepository {}

const AccessAdminItem _roleItem = AccessAdminItem(
  id: 'role-1',
  resource: AccessAdminResource.roles,
  displayId: 'ROL-1',
  title: 'Ward Nurse',
  roleScope: 'FACILITY',
  userCount: 3,
  isSystemCritical: false,
);

AccessAdminWorkspaceData _rolesData({
  bool canWrite = true,
  List<AccessAdminItem> items = const <AccessAdminItem>[_roleItem],
}) {
  return AccessAdminWorkspaceData(
    permissions: AccessAdminWorkspacePermissions(
      canRead: true,
      canWrite: canWrite,
    ),
    lookups: const AccessAdminLookups(),
    items: items,
    page: AppPage<AccessAdminItem>(
      items: items,
      request: const AppPageRequest(pageSize: 12),
      totalItemCount: items.length,
    ),
    query: const AccessAdminWorkspaceQuery(
      panel: AccessAdminPanel.roles,
      resource: AccessAdminResource.roles,
    ),
  );
}

AppAccessPolicy _policy({
  Set<AppPermission>? permissions,
  List<String> roles = const <String>['TENANT_ADMIN'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        tenantId: tenantId,
        facilityId: facilityId,
        roles: roles,
      ),
      permissions: permissions ??
          <AppPermission>{
            AppPermissions.tenantAdmin,
            AppPermissions.facilityAdmin,
          },
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockAccessAdminRepository repository, {
  AccessAdminWorkspaceData? data,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => Result<AccessAdminWorkspaceData>.success(
      data ?? _rolesData(),
    ),
  );
}

Future<void> _pumpRoles(
  WidgetTester tester, {
  required _MockAccessAdminRepository repository,
  required AppAccessPolicy policy,
  AccessAdminWorkspaceData? data,
  Size viewport = const Size(1280, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, data: data);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/admin/access?panel=roles',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/access',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: AccessAdminWorkspacePage(
              initialQuery: AccessAdminWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accessAdminRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  late _MockAccessAdminRepository repository;

  setUpAll(() {
    registerFallbackValue(const AccessAdminWorkspaceQuery());
    registerFallbackValue(
      const AccessAdminRoleDraft(name: 'fallback'),
    );
  });

  setUp(() {
    repository = _MockAccessAdminRepository();
  });

  group('access_admin_access helpers (Roles matrix)', () {
    test('∪ read: facility:admin alone satisfies roles read', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(canReadAccessAdminRoles(facilityOnly), isTrue);
      expect(
        AccessAdminRolesAtomPermissions.tab.isAllowed(facilityOnly),
        isTrue,
      );
      expect(
        accessAdminAllowedPanels(facilityOnly)
            .contains(AccessAdminPanel.roles),
        isTrue,
      );
    });

    test('∪ read: system:admin alone satisfies roles read', () {
      final AppAccessPolicy systemOnly = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
        roles: const <String>['SUPER_ADMIN'],
      );
      expect(canReadAccessAdminRoles(systemOnly), isTrue);
    });

    test('∪ denial: clinical:read alone cannot read roles', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['DOCTOR'],
      );
      expect(canReadAccessAdminRoles(clinical), isFalse);
      expect(
        accessAdminAllowedPanels(clinical).contains(AccessAdminPanel.roles),
        isFalse,
      );
    });

    test('∩ write: facility:admin without tenant:admin cannot mutate', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      // Source canWrite may be true; matrix still requires tenant:admin.
      expect(
        canMutateAccessAdminRoles(facilityOnly, workspaceCanWrite: true),
        isFalse,
      );
      expect(accessAdminRolesWriteRequirement.isAllowed(facilityOnly), isFalse);
      expect(
        AccessAdminRolesAtomPermissions.create.isAllowed(facilityOnly),
        isFalse,
      );
      expect(
        AccessAdminRolesAtomPermissions.update.isAllowed(facilityOnly),
        isFalse,
      );
      expect(
        AccessAdminRolesAtomPermissions.delete.isAllowed(facilityOnly),
        isFalse,
      );
    });

    test('∩ write: tenant:admin + workspace canWrite allows mutate', () {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      expect(
        canMutateAccessAdminRoles(tenant, workspaceCanWrite: true),
        isTrue,
      );
      expect(
        canMutateAccessAdminRoles(tenant, workspaceCanWrite: false),
        isFalse,
      );
    });

    test('ABAC: missing tenant context denies roles read', () {
      final AppAccessPolicy noTenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
        tenantId: null,
      );
      expect(accessAdminRolesReadRequirement.isAllowed(noTenant), isFalse);
    });

    test('nested cross-module write n/a — no nested module atoms on Roles', () {
      expect(
        identical(
          AccessAdminRolesAtomPermissions.write,
          accessAdminRolesWriteRequirement,
        ),
        isTrue,
      );
    });

    test('Requirement helpers reuse AccessRequirement vocabulary', () {
      expect(
        identical(
          accessAdminRolesReadRequirement,
          accessAdminWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          accessAdminRolesWriteRequirement,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminRolesAtomPermissions.create,
          accessAdminCreateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminRolesAtomPermissions.update,
          accessAdminUpdateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminRolesAtomPermissions.delete,
          accessAdminDeleteRequirement,
        ),
        isTrue,
      );
    });

    test(
      'subscription commercial modules do not gate admin keys (platform)',
      () {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(canReadAccessAdminRoles(tenant), isTrue);
        expect(accessAdminModuleLabel, 'access administration');
        expect(accessAdminActiveModule, 'access_admin');
      },
    );

    test('route entry ∪ aligns with Roles read matrix', () {
      expect(
        AppRoutes.accessAdmin.requiredAnyPermissions,
        containsAll(<AppPermission>[
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.systemAdmin,
        ]),
      );
      expect(
        accessAdminRolesReadRequirement.anyPermissions,
        accessAdminReadPermissions,
      );
    });

    test('Registrations panel only when elevated', () {
      final AppAccessPolicy tenant = _policy();
      final AppAccessPolicy elevated = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
        roles: const <String>['SUPER_ADMIN'],
      );
      expect(
        accessAdminAllowedPanels(tenant)
            .contains(AccessAdminPanel.registrations),
        isFalse,
      );
      expect(canAccessAccessAdminRegistrations(elevated), isTrue);
    });
  });

  group('Roles UI permissions', () {
    testWidgets(
      'facility:admin read-only: list visible, Create/Edit absent (∩)',
      (WidgetTester tester) async {
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        await _pumpRoles(
          tester,
          repository: repository,
          policy: facilityOnly,
          data: _rolesData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text('Ward Nurse'), findsWidgets);
        expect(find.text(l10n.accessAdminPanelRoles), findsOneWidget);
        expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
        expect(find.text(l10n.accessAdminEditRoleAction), findsNothing);
        expect(find.text(l10n.accessAdminDeleteRoleAction), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        expect(find.textContaining('No access'), findsNothing);
        expect(find.text(l10n.accessAdminPanelRegistrations), findsNothing);

        final AppListTable<AccessAdminItem> table = tester
            .widgetList<AppListTable<AccessAdminItem>>(
              find.byType(AppListTable<AccessAdminItem>),
            )
            .first;
        expect(
          table.columns.any(
            (AppListTableColumn<AccessAdminItem> column) =>
                column.id == 'next_action',
          ),
          isFalse,
        );
      },
    );

    testWidgets(
      'tenant:admin writer: Create role + Edit role present (∩ full set)',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpRoles(
          tester,
          repository: repository,
          policy: tenant,
          data: _rolesData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminCreateRoleAction), findsOneWidget);
        expect(find.text(l10n.accessAdminEditRoleAction), findsWidgets);
        expect(find.text('Ward Nurse'), findsWidgets);
      },
    );

    testWidgets(
      '∪ allowance: system:admin alone shows Roles chrome + write',
      (WidgetTester tester) async {
        final AppAccessPolicy systemOnly = _policy(
          permissions: <AppPermission>{AppPermissions.systemAdmin},
          roles: const <String>['SUPER_ADMIN'],
        );
        await _pumpRoles(
          tester,
          repository: repository,
          policy: systemOnly,
          // Super-admin is elevated → write allowed when workspace canWrite.
          data: _rolesData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelRoles), findsOneWidget);
        expect(find.text('Ward Nurse'), findsWidgets);
        expect(find.text(l10n.accessAdminCreateRoleAction), findsOneWidget);
        expect(find.text(l10n.accessAdminEditRoleAction), findsWidgets);
      },
    );

    testWidgets(
      'missing admin permissions: workspace gate hides surface',
      (WidgetTester tester) async {
        final AppAccessPolicy none = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        );
        await _pumpRoles(
          tester,
          repository: repository,
          policy: none,
        );

        expect(find.text('Ward Nurse'), findsNothing);
        expect(find.byType(AppTabStrip), findsNothing);
      },
    );

    testWidgets(
      'workspace canWrite false strips Create/Edit even with tenant:admin',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpRoles(
          tester,
          repository: repository,
          policy: tenant,
          data: _rolesData(canWrite: false),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text('Ward Nurse'), findsWidgets);
        expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
        expect(find.text(l10n.accessAdminEditRoleAction), findsNothing);
      },
    );

    testWidgets('empty authorized Roles keeps empty state + Create', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpRoles(
        tester,
        repository: repository,
        policy: tenant,
        data: _rolesData(canWrite: true, items: const <AccessAdminItem>[]),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminEmptyTitle), findsOneWidget);
      expect(find.text(l10n.accessAdminCreateRoleAction), findsOneWidget);
    });

    testWidgets(
      'detail Delete role present for writer; absent for read-only',
      (WidgetTester tester) async {
        when(() => repository.listRolePermissions(any())).thenAnswer(
          (_) async => const Result<List<AccessAdminRolePermissionAssignment>>
              .success(<AccessAdminRolePermissionAssignment>[]),
        );

        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpRoles(
          tester,
          repository: repository,
          policy: tenant,
          data: _rolesData(canWrite: true),
        );

        final AppListTable<AccessAdminItem> table = tester
            .widgetList<AppListTable<AccessAdminItem>>(
              find.byType(AppListTable<AccessAdminItem>),
            )
            .first;
        table.onRowSelected!(_roleItem);
        await tester.pumpAndSettle();

        final BuildContext context = tester.element(find.byType(AppDialog));
        final AppLocalizations l10n = context.l10n;

        // Delete is detail-footer only; Edit stays on the worklist next-action.
        expect(find.text(l10n.accessAdminDeleteRoleAction), findsOneWidget);
        expect(find.text(l10n.commonCloseActionLabel), findsOneWidget);

        await tester.tap(find.text(l10n.commonCloseActionLabel));
        await tester.pumpAndSettle();

        // Read-only ∩ denial: reopen under facility:admin.
        await _pumpRoles(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{AppPermissions.facilityAdmin},
            roles: const <String>['FACILITY_ADMIN'],
          ),
          data: _rolesData(canWrite: true),
        );
        final AppListTable<AccessAdminItem> readTable = tester
            .widgetList<AppListTable<AccessAdminItem>>(
              find.byType(AppListTable<AccessAdminItem>),
            )
            .first;
        readTable.onRowSelected!(_roleItem);
        await tester.pumpAndSettle();

        final BuildContext readContext = tester.element(find.byType(AppDialog));
        final AppLocalizations readL10n = readContext.l10n;
        expect(find.text(readL10n.accessAdminDeleteRoleAction), findsNothing);
        expect(find.text(readL10n.commonCloseActionLabel), findsOneWidget);
      },
    );

    testWidgets(
      'nested write dialogs refuse open without mutate ∩',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        AccessAdminItem? createResult = _roleItem;
        AccessAdminItem? editResult = _roleItem;
        final AccessAdminWorkspaceData data = _rolesData(canWrite: true);
        final AccessAdminWorkspaceState state = AccessAdminWorkspaceState(
          data: data,
          query: data.query,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accessAdminRepositoryProvider.overrideWithValue(repository),
              sharedPreferencesProvider.overrideWithValue(preferences),
              initialSessionStateProvider.overrideWithValue(
                const SessionState.ready(),
              ),
              appAccessPolicyProvider.overrideWithValue(facilityOnly),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Consumer(
                  builder: (BuildContext context, WidgetRef ref, _) {
                    return TextButton(
                      onPressed: () async {
                        createResult = await openAccessAdminCreateRoleDialog(
                          context,
                          ref,
                          state,
                        );
                        editResult = await openAccessAdminEditRoleDialog(
                          context,
                          ref,
                          state,
                          _roleItem,
                        );
                      },
                      child: const Text('probe-roles-mutate'),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('probe-roles-mutate'));
        await tester.pumpAndSettle();

        expect(createResult, isNull);
        expect(editResult, isNull);
        expect(find.byType(AppDialog), findsNothing);
      },
    );

    testWidgets(
      'system-critical role: Edit and Delete absent even for writers',
      (WidgetTester tester) async {
        const AccessAdminItem critical = AccessAdminItem(
          id: 'role-critical',
          resource: AccessAdminResource.roles,
          displayId: 'ROL-SYS',
          title: 'System Admin Role',
          roleScope: 'PLATFORM',
          userCount: 1,
          isSystemCritical: true,
        );
        when(() => repository.listRolePermissions(any())).thenAnswer(
          (_) async => const Result<List<AccessAdminRolePermissionAssignment>>
              .success(<AccessAdminRolePermissionAssignment>[]),
        );

        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpRoles(
          tester,
          repository: repository,
          policy: tenant,
          data: _rolesData(canWrite: true, items: const <AccessAdminItem>[critical]),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminCreateRoleAction), findsOneWidget);
        // Column header may reuse the Edit label; the row action button must not mount.
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(
          accessAdminMobileNextAction(
            context,
            resource: AccessAdminResource.roles,
            item: critical,
            canWrite: true,
            onUserStatusToggle: (_) async {},
            onRoleEdit: (_) {},
            onRegistrationActivate: (_) async {},
          ),
          isNull,
        );

        final AppListTable<AccessAdminItem> table = tester
            .widgetList<AppListTable<AccessAdminItem>>(
              find.byType(AppListTable<AccessAdminItem>),
            )
            .first;
        table.onRowSelected!(critical);
        await tester.pumpAndSettle();

        expect(find.text(l10n.accessAdminDeleteRoleAction), findsNothing);
        expect(find.text(l10n.commonCloseActionLabel), findsOneWidget);
      },
    );

    testWidgets('create role syncs worklist after mutation', (
      WidgetTester tester,
    ) async {
      const AccessAdminItem created = AccessAdminItem(
        id: 'role-2',
        resource: AccessAdminResource.roles,
        displayId: 'ROL-2',
        title: 'Night Shift Lead',
        roleScope: 'FACILITY',
        userCount: 0,
        isSystemCritical: false,
      );
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      var createdCalled = false;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        final List<AccessAdminItem> items = createdCalled
            ? const <AccessAdminItem>[_roleItem, created]
            : const <AccessAdminItem>[_roleItem];
        return Result<AccessAdminWorkspaceData>.success(
          _rolesData(canWrite: true, items: items),
        );
      });
      when(() => repository.createRole(any())).thenAnswer((_) async {
        createdCalled = true;
        return const Result<AccessAdminItem>.success(created);
      });

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessAdminRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(tenant),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AccessAdminWorkspacePage(
                initialQuery: AccessAdminWorkspaceQuery(
                  panel: AccessAdminPanel.roles,
                  resource: AccessAdminResource.roles,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Night Shift Lead'), findsNothing);
      expect(find.text('Ward Nurse'), findsWidgets);

      final AccessAdminWorkspaceController controller =
          ProviderScope.containerOf(
            tester.element(find.byType(AccessAdminWorkspacePage)),
          ).read(accessAdminWorkspaceControllerProvider.notifier);

      final Result<AccessAdminItem> result = await controller.createRole(
        const AccessAdminRoleDraft(name: 'Night Shift Lead'),
      );
      expect(result.isSuccess, isTrue);
      await tester.pumpAndSettle();

      verify(() => repository.createRole(any())).called(1);
      expect(find.text('Night Shift Lead'), findsWidgets);
      expect(find.text('Ward Nurse'), findsWidgets);
    });

    testWidgets(
      'desktop authorized reader: search chrome present, write absent (∪)',
      (WidgetTester tester) async {
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        await _pumpRoles(
          tester,
          repository: repository,
          policy: facilityOnly,
          data: _rolesData(canWrite: true),
          viewport: const Size(1280, 900),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.byType(AppListTable<AccessAdminItem>), findsOneWidget);
        expect(find.text(l10n.accessAdminSearchHint), findsOneWidget);
        expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
        expect(find.text(l10n.accessAdminEditRoleAction), findsNothing);
      },
    );

    testWidgets('delete role syncs worklist after mutation', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      when(() => repository.listRolePermissions(any())).thenAnswer(
        (_) async => const Result<List<AccessAdminRolePermissionAssignment>>
            .success(<AccessAdminRolePermissionAssignment>[]),
      );
      when(() => repository.deleteRole(any())).thenAnswer(
        (_) async => const Result<void>.success(null),
      );

      await _pumpRoles(
        tester,
        repository: repository,
        policy: tenant,
        data: _rolesData(canWrite: true),
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_roleItem);
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(AppDialog));
      final AppLocalizations l10n = context.l10n;

      await tester.tap(find.text(l10n.accessAdminDeleteRoleAction));
      await tester.pumpAndSettle();

      final Finder confirm = find.text(l10n.tenantFacilityDeleteConfirmAction);
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      verify(() => repository.deleteRole('role-1')).called(1);
      expect(find.text('Ward Nurse'), findsNothing);
      expect(find.text(l10n.accessAdminEmptyTitle), findsOneWidget);
    });

    testWidgets('mobile viewport: next-action absent without write', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      await _pumpRoles(
        tester,
        repository: repository,
        policy: facilityOnly,
        data: _rolesData(canWrite: true),
        viewport: const Size(390, 844),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text(l10n.accessAdminPanelRoles), findsOneWidget);
      expect(find.text(l10n.accessAdminEditRoleAction), findsNothing);
      expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('dark theme: authorized Roles atoms remain visible', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpRoles(
        tester,
        repository: repository,
        policy: tenant,
        data: _rolesData(canWrite: true),
        themeMode: ThemeMode.dark,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminCreateRoleAction), findsOneWidget);
      expect(find.text('Ward Nurse'), findsWidgets);
    });

    testWidgets(
      'error/retry remains for authorized readers',
      (WidgetTester tester) async {
        when(() => repository.getWorkspace(any())).thenAnswer(
          (_) async => const Result<AccessAdminWorkspaceData>.failure(
            AppFailure.network(),
          ),
        );

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();

        final GoRouter router = GoRouter(
          initialLocation: '/admin/access?panel=roles',
          routes: <RouteBase>[
            GoRoute(
              path: '/admin/access',
              builder: (BuildContext context, GoRouterState state) {
                return Scaffold(
                  body: AccessAdminWorkspacePage(
                    initialQuery: AccessAdminWorkspaceQuery.fromUri(state.uri),
                  ),
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accessAdminRepositoryProvider.overrideWithValue(repository),
              sharedPreferencesProvider.overrideWithValue(preferences),
              initialSessionStateProvider.overrideWithValue(
                const SessionState.ready(),
              ),
              appAccessPolicyProvider.overrideWithValue(_policy()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        // Avoid pumpAndSettle — initial-load timeout timer stays pending on failure.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(AccessAdminWorkspacePage), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );
  });

  group('accessAdminDefaultColumns Roles next_action gate', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (BuildContext context) => child),
      );
    }

    testWidgets('omits next_action column when canWrite is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      final List<String> ids = accessAdminDefaultColumns(
            context,
            resource: AccessAdminResource.roles,
            canWrite: false,
            onUserStatusToggle: (_) async {},
            onRoleEdit: (_) {},
            onRegistrationActivate: (_) async {},
          )
          .map((AppListTableColumn<AccessAdminItem> column) => column.id)
          .whereType<String>()
          .toList();

      expect(ids, isNot(contains('next_action')));
      expect(ids, contains('role_id'));
      expect(ids, contains('role_name'));
    });

    testWidgets('includes next_action when canWrite is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      final List<String> ids = accessAdminDefaultColumns(
            context,
            resource: AccessAdminResource.roles,
            canWrite: true,
            onUserStatusToggle: (_) async {},
            onRoleEdit: (_) {},
            onRegistrationActivate: (_) async {},
          )
          .map((AppListTableColumn<AccessAdminItem> column) => column.id)
          .whereType<String>()
          .toList();

      expect(ids, contains('next_action'));
    });

    testWidgets('mobile Roles next-action null without write', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      expect(
        accessAdminMobileNextAction(
          context,
          resource: AccessAdminResource.roles,
          item: _roleItem,
          canWrite: false,
          onUserStatusToggle: (_) async {},
          onRoleEdit: (_) {},
          onRegistrationActivate: (_) async {},
        ),
        isNull,
      );
    });

    testWidgets('mobile Roles next-action present with write', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      expect(
        accessAdminMobileNextAction(
          context,
          resource: AccessAdminResource.roles,
          item: _roleItem,
          canWrite: true,
          onUserStatusToggle: (_) async {},
          onRoleEdit: (_) {},
          onRegistrationActivate: (_) async {},
        ),
        isNotNull,
      );
      expect(
        accessAdminMobileNextAction(
          context,
          resource: AccessAdminResource.roles,
          item: _roleItem.copyWith(isSystemCritical: true),
          canWrite: true,
          onUserStatusToggle: (_) async {},
          onRoleEdit: (_) {},
          onRegistrationActivate: (_) async {},
        ),
        isNull,
      );
    });
  });
}
