import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
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

const AccessAdminItem _demoUser = AccessAdminItem(
  id: 'demo-1',
  resource: AccessAdminResource.demoUsers,
  displayId: 'DEM-1',
  title: 'Demo Nurse',
  email: 'demo.nurse@example.com',
  status: 'ACTIVE',
  facilityName: 'Main Campus',
  isDemo: true,
);

AccessAdminWorkspaceData _demoData({
  bool canWrite = true,
  bool canResetDemoPasswords = false,
  List<AccessAdminItem> items = const <AccessAdminItem>[_demoUser],
}) {
  return AccessAdminWorkspaceData(
    permissions: AccessAdminWorkspacePermissions(
      canRead: true,
      canWrite: canWrite,
      canResetDemoPasswords: canResetDemoPasswords,
    ),
    lookups: const AccessAdminLookups(
      userStatuses: <String>['ACTIVE', 'INACTIVE'],
    ),
    items: items,
    page: AppPage<AccessAdminItem>(
      items: items,
      request: const AppPageRequest(pageSize: 12),
      totalItemCount: items.length,
    ),
    query: const AccessAdminWorkspaceQuery(
      panel: AccessAdminPanel.demo,
      resource: AccessAdminResource.demoUsers,
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
      data ?? _demoData(),
    ),
  );
  when(
    () => repository.getUserDetail(
      any(),
      tenantId: any(named: 'tenantId'),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => Result<AccessAdminUserDetail>.success(
      AccessAdminUserDetail(
        item: (data ?? _demoData()).items.isNotEmpty
            ? (data ?? _demoData()).items.first
            : _demoUser,
      ),
    ),
  );
}

Future<void> _pumpDemo(
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
    initialLocation: '/admin/access?panel=demo',
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
  });

  setUp(() {
    repository = _MockAccessAdminRepository();
  });

  group('access_admin_access helpers (Demo matrix)', () {
    test('∪ read: facility:admin alone satisfies Demo read', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(canReadAccessAdminDemo(facilityOnly), isTrue);
      expect(accessAdminDemoReadRequirement.isAllowed(facilityOnly), isTrue);
      expect(
        AccessAdminDemoAtomPermissions.tab.isAllowed(facilityOnly),
        isTrue,
      );
      expect(
        accessAdminAllowedPanels(facilityOnly).contains(AccessAdminPanel.demo),
        isTrue,
      );
    });

    test('∪ read: platform:admin alone satisfies Demo read', () {
      final AppAccessPolicy systemOnly = _policy(
        permissions: <AppPermission>{AppPermissions.platformAdmin},
        roles: const <String>['PLATFORM_ADMIN'],
      );
      expect(canReadAccessAdminDemo(systemOnly), isTrue);
    });

    test('∪ denial: clinical:read alone cannot read Demo', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['DOCTOR'],
      );
      expect(canReadAccessAdminDemo(clinical), isFalse);
      expect(
        accessAdminAllowedPanels(clinical).contains(AccessAdminPanel.demo),
        isFalse,
      );
    });

    test('∩ write: facility:admin without tenant:admin cannot write Demo', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      // Source canWrite may be true; matrix still requires tenant:admin.
      expect(
        canMutateAccessAdminDemo(facilityOnly, workspaceCanWrite: true),
        isFalse,
      );
      expect(
        canWriteAccessAdmin(facilityOnly, workspaceCanWrite: true),
        isFalse,
      );
      expect(accessAdminWriteRequirement.isAllowed(facilityOnly), isFalse);
      expect(
        AccessAdminDemoAtomPermissions.create.isAllowed(facilityOnly),
        isFalse,
      );
      expect(
        AccessAdminDemoAtomPermissions.update.isAllowed(facilityOnly),
        isFalse,
      );
      expect(
        AccessAdminDemoAtomPermissions.delete.isAllowed(facilityOnly),
        isFalse,
      );
    });

    test('∩ write: tenant:admin + workspace canWrite allows Demo write', () {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      expect(canMutateAccessAdminDemo(tenant, workspaceCanWrite: true), isTrue);
      expect(
        canMutateAccessAdminDemo(tenant, workspaceCanWrite: false),
        isFalse,
      );
      expect(canWriteAccessAdmin(tenant, workspaceCanWrite: true), isTrue);
      expect(canWriteAccessAdmin(tenant, workspaceCanWrite: false), isFalse);
      expect(AccessAdminDemoAtomPermissions.create.isAllowed(tenant), isTrue);
    });

    test('Demo reset requires write ∩ and backend reset flag', () {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      expect(
        canResetDemoPasswordAccessAdmin(
          tenant,
          workspaceCanWrite: true,
          workspaceCanResetDemoPasswords: true,
        ),
        isTrue,
      );
      expect(
        canResetDemoPasswordAccessAdmin(
          tenant,
          workspaceCanWrite: true,
          workspaceCanResetDemoPasswords: false,
        ),
        isFalse,
      );
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(
        canResetDemoPasswordAccessAdmin(
          facilityOnly,
          workspaceCanWrite: true,
          workspaceCanResetDemoPasswords: true,
        ),
        isFalse,
      );
    });

    test('ABAC: missing tenant context denies Demo read requirement', () {
      final AppAccessPolicy noTenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
        tenantId: null,
      );
      expect(accessAdminDemoReadRequirement.isAllowed(noTenant), isFalse);
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
        expect(canReadAccessAdminDemo(tenant), isTrue);
        expect(canMutateAccessAdminDemo(tenant, workspaceCanWrite: true), isTrue);
        expect(accessAdminModuleLabel, 'access administration');
        expect(accessAdminActiveModule, 'access_admin');
      },
    );

    test('Demo reuses shared AccessRequirement helpers (no second vocabulary)', () {
      expect(
        identical(
          accessAdminDemoReadRequirement,
          accessAdminWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDemoAtomPermissions.tab,
          accessAdminDemoReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDemoAtomPermissions.create,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDemoAtomPermissions.update,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDemoAtomPermissions.delete,
          accessAdminDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDemoAtomPermissions.write,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(accessAdminModuleLabel, 'access administration');
    });

    test('route integration accepts any admin ∪ key', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(canAccessShellRoute(AppRoutes.accessAdmin, facilityOnly), isTrue);
      expect(
        canAccessShellRoute(
          AppRoutes.accessAdmin,
          _policy(permissions: <AppPermission>{AppPermissions.clinicalRead}),
        ),
        isFalse,
      );
    });

    test('nested cross-module rows are n/a for Demo matrix', () {
      // Inventory Open HR is staffProfileId-only; matrix nested rows are n/a.
      expect(AccessAdminDemoAtomPermissions.write.allPermissions, isNotEmpty);
      expect(
        AccessAdminDemoAtomPermissions.delete.allPermissions,
        AccessAdminDemoAtomPermissions.write.allPermissions,
      );
      expect(
        identical(
          AccessAdminDemoAtomPermissions.create,
          accessAdminCreateRequirement,
        ),
        isTrue,
      );
    });
  });

  group('Demo UI permissions', () {
    testWidgets(
      'facility:admin read-only: list visible, Create/Deactivate absent (∩)',
      (WidgetTester tester) async {
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        await _pumpDemo(
          tester,
          repository: repository,
          policy: facilityOnly,
          data: _demoData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text('Demo Nurse'), findsWidgets);
        expect(find.text(l10n.accessAdminPanelDemo), findsOneWidget);
        expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
        expect(find.text(l10n.accessAdminDeactivateAction), findsNothing);
        expect(find.text(l10n.accessAdminActivateAction), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        expect(find.textContaining('No access'), findsNothing);
        expect(find.text(l10n.accessAdminPanelRegistrations), findsNothing);
      },
    );

    testWidgets(
      'tenant:admin writer: Create user + Deactivate present (∩ full set)',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpDemo(
          tester,
          repository: repository,
          policy: tenant,
          data: _demoData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminCreateUserAction), findsOneWidget);
        expect(find.text(l10n.accessAdminDeactivateAction), findsWidgets);
        expect(find.text('Demo Nurse'), findsWidgets);
      },
    );

    testWidgets(
      '∪ allowance: platform:admin alone shows Demo chrome',
      (WidgetTester tester) async {
        final AppAccessPolicy systemOnly = _policy(
          permissions: <AppPermission>{AppPermissions.platformAdmin},
          roles: const <String>['PLATFORM_ADMIN'],
        );
        await _pumpDemo(
          tester,
          repository: repository,
          policy: systemOnly,
          data: _demoData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelDemo), findsOneWidget);
        expect(find.text('Demo Nurse'), findsWidgets);
        // Elevated PLATFORM_ADMIN qualifies write via canWriteAccessAdmin.
        expect(find.text(l10n.accessAdminCreateUserAction), findsOneWidget);
      },
    );

    testWidgets(
      'missing admin permissions: workspace gate hides Demo surface',
      (WidgetTester tester) async {
        final AppAccessPolicy none = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        );
        await _pumpDemo(
          tester,
          repository: repository,
          policy: none,
        );

        expect(find.text('Demo Nurse'), findsNothing);
        expect(find.byType(AppTabStrip), findsNothing);
      },
    );

    testWidgets(
      'workspace canWrite false strips Create even with tenant:admin',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpDemo(
          tester,
          repository: repository,
          policy: tenant,
          data: _demoData(canWrite: false),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text('Demo Nurse'), findsWidgets);
        expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
        expect(find.text(l10n.accessAdminDeactivateAction), findsNothing);
      },
    );

    testWidgets(
      'nested write dialogs refuse open without Demo mutate ∩',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        AccessAdminItem? createResult = _demoUser;
        final AccessAdminWorkspaceData data = _demoData(canWrite: true);
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
                        createResult = await openAccessAdminCreateUserDialog(
                          context,
                          ref,
                          state,
                        );
                      },
                      child: const Text('probe-demo-mutate'),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('probe-demo-mutate'));
        await tester.pumpAndSettle();

        expect(createResult, isNull);
        expect(find.byType(AppDialog), findsNothing);
      },
    );

    testWidgets(
      'desktop authorized reader: search chrome present, write absent (∪)',
      (WidgetTester tester) async {
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        await _pumpDemo(
          tester,
          repository: repository,
          policy: facilityOnly,
          data: _demoData(canWrite: true),
          viewport: const Size(1280, 900),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.byType(AppListTable<AccessAdminItem>), findsOneWidget);
        expect(find.text(l10n.accessAdminSearchHint), findsOneWidget);
        expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
        expect(find.text(l10n.accessAdminDeactivateAction), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'detail Close remains for readers; Open HR when staffProfileId set',
      (WidgetTester tester) async {
        const AccessAdminItem linked = AccessAdminItem(
          id: 'demo-hr',
          resource: AccessAdminResource.demoUsers,
          displayId: 'DEM-HR',
          title: 'HR Linked Demo',
          email: 'demo.hr@example.com',
          status: 'ACTIVE',
          facilityName: 'Main Campus',
          isDemo: true,
          staffProfileId: 'staff-1',
        );
        when(
          () => repository.getUserDetail(
            any(),
            tenantId: any(named: 'tenantId'),
            facilityId: any(named: 'facilityId'),
          ),
        ).thenAnswer(
          (_) async => const Result<AccessAdminUserDetail>.success(
            AccessAdminUserDetail(item: linked),
          ),
        );

        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        await _pumpDemo(
          tester,
          repository: repository,
          policy: facilityOnly,
          data: _demoData(
            canWrite: true,
            items: const <AccessAdminItem>[linked],
          ),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        final AppListTable<AccessAdminItem> table = tester
            .widgetList<AppListTable<AccessAdminItem>>(
              find.byType(AppListTable<AccessAdminItem>),
            )
            .first;
        table.onRowSelected!(linked);
        await tester.pumpAndSettle();

        expect(find.text(l10n.commonCloseActionLabel), findsOneWidget);
        expect(find.text(l10n.accessAdminOpenHrProfileAction), findsOneWidget);
        expect(find.text(l10n.accessAdminDeactivateAction), findsNothing);
        expect(find.text(l10n.accessAdminActivateAction), findsNothing);
        expect(
          find.text(l10n.accessAdminResetDemoPasswordAction),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Reset demo password present when write ∩ + backend reset flag',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpDemo(
          tester,
          repository: repository,
          policy: tenant,
          data: _demoData(canWrite: true, canResetDemoPasswords: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        await tester.tap(find.text('Demo Nurse').first);
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.accessAdminResetDemoPasswordAction),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Reset demo password absent without backend reset flag (∩ write alone)',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpDemo(
          tester,
          repository: repository,
          policy: tenant,
          data: _demoData(canWrite: true, canResetDemoPasswords: false),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        await tester.tap(find.text('Demo Nurse').first);
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.accessAdminResetDemoPasswordAction),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Reset demo password absent for facility:admin (∩ denial)',
      (WidgetTester tester) async {
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        await _pumpDemo(
          tester,
          repository: repository,
          policy: facilityOnly,
          data: _demoData(canWrite: true, canResetDemoPasswords: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        await tester.tap(find.text('Demo Nurse').first);
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.accessAdminResetDemoPasswordAction),
          findsNothing,
        );
      },
    );

    testWidgets('empty authorized Demo keeps empty state + Create', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpDemo(
        tester,
        repository: repository,
        policy: tenant,
        data: _demoData(canWrite: true, items: const <AccessAdminItem>[]),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminEmptyTitle), findsOneWidget);
      expect(find.text(l10n.accessAdminCreateUserAction), findsOneWidget);
    });

    testWidgets('status toggle syncs Demo worklist after mutation', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      var deactivated = false;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        final AccessAdminItem item = deactivated
            ? _demoUser.copyWith(status: 'INACTIVE')
            : _demoUser;
        return Result<AccessAdminWorkspaceData>.success(
          _demoData(items: <AccessAdminItem>[item]),
        );
      });
      when(() => repository.setUserStatus(any(), any())).thenAnswer((
        _,
      ) async {
        deactivated = true;
        return const Result<void>.success(null);
      });

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/admin/access?panel=demo',
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
            appAccessPolicyProvider.overrideWithValue(tenant),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminDeactivateAction), findsWidgets);
      await tester.tap(find.text(l10n.accessAdminDeactivateAction).first);
      await tester.pumpAndSettle();

      verify(() => repository.setUserStatus('demo-1', 'INACTIVE')).called(1);
      expect(find.text(l10n.accessAdminActivateAction), findsWidgets);
    });

    testWidgets('mobile viewport: Demo next-action absent without write', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      await _pumpDemo(
        tester,
        repository: repository,
        policy: facilityOnly,
        data: _demoData(canWrite: true),
        viewport: const Size(390, 844),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      // Mobile list may virtualize; assert write chrome is absent.
      expect(find.byType(AccessAdminWorkspacePage), findsOneWidget);
      expect(find.text(l10n.accessAdminPanelDemo), findsOneWidget);
      expect(find.text(l10n.accessAdminDeactivateAction), findsNothing);
      expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
    });

    testWidgets('dark theme: authorized Demo atoms remain visible', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpDemo(
        tester,
        repository: repository,
        policy: tenant,
        data: _demoData(canWrite: true),
        themeMode: ThemeMode.dark,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminCreateUserAction), findsOneWidget);
      expect(find.text('Demo Nurse'), findsWidgets);
    });

    testWidgets('error/retry remains for authorized Demo readers', (
      WidgetTester tester,
    ) async {
      when(() => repository.getWorkspace(any())).thenAnswer(
        (_) async => const Result<AccessAdminWorkspaceData>.failure(
          AppFailure.network(),
        ),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final GoRouter router = GoRouter(
        initialLocation: '/admin/access?panel=demo',
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;
      expect(find.text(l10n.errorNetworkMessage), findsWidgets);
    });
  });

  group('accessAdminDefaultColumns Demo next_action gate', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (BuildContext context) => child),
      );
    }

    testWidgets('omits next_action for demoUsers when canWrite is false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      final List<String> ids = accessAdminDefaultColumns(
            context,
            resource: AccessAdminResource.demoUsers,
            canWrite: false,
            onUserStatusToggle: (_) async {},
            onRoleEdit: (_) {},
            onRegistrationApprove: (_) async {},
          )
          .map((AppListTableColumn<AccessAdminItem> column) => column.id)
          .whereType<String>()
          .toList();

      expect(ids, isNot(contains('next_action')));
    });

    testWidgets('includes next_action for demoUsers when canWrite is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      final List<String> ids = accessAdminDefaultColumns(
            context,
            resource: AccessAdminResource.demoUsers,
            canWrite: true,
            onUserStatusToggle: (_) async {},
            onRoleEdit: (_) {},
            onRegistrationApprove: (_) async {},
          )
          .map((AppListTableColumn<AccessAdminItem> column) => column.id)
          .whereType<String>()
          .toList();

      expect(ids, contains('next_action'));
    });

    testWidgets('mobile Demo next-action null when unauthorized', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      expect(
        accessAdminMobileNextAction(
          context,
          resource: AccessAdminResource.demoUsers,
          item: _demoUser,
          canWrite: false,
          onUserStatusToggle: (_) async {},
          onRoleEdit: (_) {},
          onRegistrationApprove: (_) async {},
        ),
        isNull,
      );
    });
  });
}
