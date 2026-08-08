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

const AccessAdminItem _directoryUser = AccessAdminItem(
  id: 'user-1',
  resource: AccessAdminResource.users,
  displayId: 'USR-1',
  title: 'Ada Lovelace',
  email: 'ada@example.com',
  status: 'ACTIVE',
  facilityName: 'Main Campus',
);

AccessAdminWorkspaceData _directoryData({
  bool canWrite = true,
  List<AccessAdminItem> items = const <AccessAdminItem>[_directoryUser],
}) {
  return AccessAdminWorkspaceData(
    permissions: AccessAdminWorkspacePermissions(
      canRead: true,
      canWrite: canWrite,
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
      panel: AccessAdminPanel.directory,
      resource: AccessAdminResource.users,
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
      data ?? _directoryData(),
    ),
  );
}

Future<void> _pumpDirectory(
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
    initialLocation: '/admin/access?panel=directory',
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
      const AccessAdminUserDraft(
        tenantId: 'tenant-1',
        email: 'fallback@example.com',
        positionTitle: 'Staff',
        firstName: 'Fallback',
      ),
    );
  });

  setUp(() {
    repository = _MockAccessAdminRepository();
  });

  group('access_admin_access helpers (Directory matrix)', () {
    test('∪ read: facility:admin alone satisfies directory read', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(canReadAccessAdminDirectory(facilityOnly), isTrue);
      expect(accessAdminDirectoryReadRequirement.isAllowed(facilityOnly), isTrue);
      expect(
        AccessAdminDirectoryAtomPermissions.tab.isAllowed(facilityOnly),
        isTrue,
      );
      expect(
        accessAdminAllowedPanels(facilityOnly)
            .contains(AccessAdminPanel.directory),
        isTrue,
      );
    });

    test('∪ read: platform:admin alone satisfies directory read', () {
      final AppAccessPolicy systemOnly = _policy(
        permissions: <AppPermission>{AppPermissions.platformAdmin},
        roles: const <String>['PLATFORM_ADMIN'],
      );
      expect(canReadAccessAdminDirectory(systemOnly), isTrue);
    });

    test('∪ denial: clinical:read alone cannot read directory', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['DOCTOR'],
      );
      expect(canReadAccessAdminDirectory(clinical), isFalse);
      expect(accessAdminAllowedPanels(clinical), isEmpty);
    });

    test('∩ write: facility:admin without tenant:admin cannot write', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      // Source canWrite may be true; matrix still requires tenant:admin.
      expect(
        canMutateAccessAdminDirectory(facilityOnly, workspaceCanWrite: true),
        isFalse,
      );
      expect(accessAdminWriteRequirement.isAllowed(facilityOnly), isFalse);
      expect(
        AccessAdminDirectoryAtomPermissions.create.isAllowed(facilityOnly),
        isFalse,
      );
      expect(
        AccessAdminDirectoryAtomPermissions.update.isAllowed(facilityOnly),
        isFalse,
      );
      expect(
        AccessAdminDirectoryAtomPermissions.delete.isAllowed(facilityOnly),
        isFalse,
      );
    });

    test('∩ write: tenant:admin + workspace canWrite allows write', () {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      expect(
        canMutateAccessAdminDirectory(tenant, workspaceCanWrite: true),
        isTrue,
      );
      expect(
        canMutateAccessAdminDirectory(tenant, workspaceCanWrite: false),
        isFalse,
      );
      expect(
        AccessAdminDirectoryAtomPermissions.create.isAllowed(tenant),
        isTrue,
      );
    });

    test('ABAC: missing tenant context denies read requirement', () {
      final AppAccessPolicy noTenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
        tenantId: null,
      );
      expect(accessAdminDirectoryReadRequirement.isAllowed(noTenant), isFalse);
    });

    test('Registrations panel only when elevated', () {
      final AppAccessPolicy tenant = _policy();
      final AppAccessPolicy elevated = _policy(
        permissions: <AppPermission>{AppPermissions.platformAdmin},
        roles: const <String>['PLATFORM_ADMIN'],
      );
      expect(
        accessAdminAllowedPanels(tenant)
            .contains(AccessAdminPanel.registrations),
        isFalse,
      );
      expect(canAccessAccessAdminRegistrations(elevated), isTrue);
      expect(
        accessAdminAllowedPanels(elevated)
            .contains(AccessAdminPanel.registrations),
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
        expect(canReadAccessAdminDirectory(tenant), isTrue);
        expect(canWriteAccessAdmin(tenant, workspaceCanWrite: true), isTrue);
        expect(accessAdminModuleLabel, 'access administration');
        expect(accessAdminActiveModule, 'access_admin');
      },
    );

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

    test('nested cross-module rows are n/a for Directory matrix', () {
      // Inventory Open HR is staffProfileId-only; matrix nested rows are n/a.
      expect(
        identical(
          AccessAdminDirectoryAtomPermissions.write,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDirectoryAtomPermissions.create,
          accessAdminCreateRequirement,
        ),
        isTrue,
      );
    });

    test('Requirement helpers reuse AccessRequirement vocabulary', () {
      expect(
        identical(
          accessAdminCreateRequirement,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          accessAdminUpdateRequirement,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          accessAdminDeleteRequirement,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          accessAdminDirectoryReadRequirement,
          accessAdminWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDirectoryAtomPermissions.tab,
          accessAdminDirectoryReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDirectoryAtomPermissions.create,
          accessAdminCreateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDirectoryAtomPermissions.update,
          accessAdminUpdateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDirectoryAtomPermissions.delete,
          accessAdminDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminDirectoryAtomPermissions.write,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
    });
  });

  group('Directory UI permissions', () {
    testWidgets(
      'facility:admin read-only: list visible, Create/Deactivate absent (∩)',
      (WidgetTester tester) async {
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        await _pumpDirectory(
          tester,
          repository: repository,
          policy: facilityOnly,
          data: _directoryData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text('Ada Lovelace'), findsWidgets);
        expect(find.text(l10n.accessAdminPanelDirectory), findsOneWidget);
        expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
        expect(find.text(l10n.accessAdminDeactivateAction), findsNothing);
        expect(find.text(l10n.accessAdminActivateAction), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        expect(find.textContaining('No access'), findsNothing);
        expect(
          find.text(l10n.accessAdminPanelRegistrations),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tenant:admin writer: Create user + Deactivate present (∩ full set)',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpDirectory(
          tester,
          repository: repository,
          policy: tenant,
          data: _directoryData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminCreateUserAction), findsOneWidget);
        expect(find.text(l10n.accessAdminDeactivateAction), findsWidgets);
        expect(find.text('Ada Lovelace'), findsWidgets);
      },
    );

    testWidgets(
      '∪ allowance: platform:admin alone shows Directory chrome',
      (WidgetTester tester) async {
        final AppAccessPolicy systemOnly = _policy(
          permissions: <AppPermission>{AppPermissions.platformAdmin},
          roles: const <String>['PLATFORM_ADMIN'],
        );
        await _pumpDirectory(
          tester,
          repository: repository,
          policy: systemOnly,
          // Super-admin is elevated → write allowed when workspace canWrite.
          data: _directoryData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelDirectory), findsOneWidget);
        expect(find.text('Ada Lovelace'), findsWidgets);
        expect(find.text(l10n.accessAdminCreateUserAction), findsOneWidget);
      },
    );

    testWidgets(
      'missing admin permissions: workspace gate hides surface',
      (WidgetTester tester) async {
        final AppAccessPolicy none = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        );
        await _pumpDirectory(
          tester,
          repository: repository,
          policy: none,
        );

        expect(find.text('Ada Lovelace'), findsNothing);
        expect(find.byType(AppTabStrip), findsNothing);
      },
    );

    testWidgets(
      'workspace canWrite false strips Create even with tenant:admin',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpDirectory(
          tester,
          repository: repository,
          policy: tenant,
          data: _directoryData(canWrite: false),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text('Ada Lovelace'), findsWidgets);
        expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
        expect(find.text(l10n.accessAdminDeactivateAction), findsNothing);
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
        AccessAdminItem? createResult = _directoryUser;
        final AccessAdminWorkspaceData data = _directoryData(canWrite: true);
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
                      child: const Text('probe-directory-mutate'),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('probe-directory-mutate'));
        await tester.pumpAndSettle();

        expect(createResult, isNull);
        expect(find.byType(AppDialog), findsNothing);
      },
    );

    testWidgets('empty authorized Directory keeps empty state', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: tenant,
        data: _directoryData(canWrite: true, items: const <AccessAdminItem>[]),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminEmptyTitle), findsOneWidget);
      expect(find.text(l10n.accessAdminCreateUserAction), findsOneWidget);
    });

    testWidgets('create user syncs worklist after mutation', (
      WidgetTester tester,
    ) async {
      const AccessAdminItem created = AccessAdminItem(
        id: 'user-2',
        resource: AccessAdminResource.users,
        displayId: 'USR-2',
        title: 'Grace Hopper',
        email: 'grace@example.com',
        status: 'ACTIVE',
        facilityName: 'Main Campus',
      );
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      var createdCalled = false;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        final List<AccessAdminItem> items = createdCalled
            ? const <AccessAdminItem>[_directoryUser, created]
            : const <AccessAdminItem>[_directoryUser];
        return Result<AccessAdminWorkspaceData>.success(
          _directoryData(canWrite: true, items: items),
        );
      });
      when(() => repository.createUser(any())).thenAnswer((_) async {
        createdCalled = true;
        return const Result<String>.success('user-2');
      });
      when(
        () => repository.getUserDetail(
          any(),
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
        ),
      ).thenAnswer(
        (_) async => Result<AccessAdminUserDetail>.success(
          AccessAdminUserDetail(
            item: createdCalled ? created : _directoryUser,
          ),
        ),
      );

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
                  panel: AccessAdminPanel.directory,
                  resource: AccessAdminResource.users,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Grace Hopper'), findsNothing);
      expect(find.text('Ada Lovelace'), findsWidgets);

      final AccessAdminWorkspaceController controller =
          ProviderScope.containerOf(
            tester.element(find.byType(AccessAdminWorkspacePage)),
          ).read(accessAdminWorkspaceControllerProvider.notifier);

      final Result<AccessAdminItem> result = await controller.createUserReviewed(
        const AccessAdminUserDraft(
          tenantId: 'tenant-1',
          email: 'grace@example.com',
          positionTitle: 'Engineer',
          firstName: 'Grace',
          lastName: 'Hopper',
        ),
      );
      expect(result.isSuccess, isTrue);
      await tester.pumpAndSettle();

      verify(() => repository.createUser(any())).called(1);
      expect(find.text('Grace Hopper'), findsWidgets);
      expect(find.text('Ada Lovelace'), findsWidgets);
    });

    testWidgets(
      'desktop authorized reader: search chrome present, write absent (∪)',
      (WidgetTester tester) async {
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        await _pumpDirectory(
          tester,
          repository: repository,
          policy: facilityOnly,
          data: _directoryData(canWrite: true),
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
          id: 'user-hr',
          resource: AccessAdminResource.users,
          displayId: 'USR-HR',
          title: 'HR Linked User',
          email: 'hr@example.com',
          status: 'ACTIVE',
          facilityName: 'Main Campus',
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
        await _pumpDirectory(
          tester,
          repository: repository,
          policy: facilityOnly,
          data: _directoryData(
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
      },
    );

    testWidgets('status toggle syncs worklist after mutation', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      var call = 0;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        call += 1;
        final AccessAdminItem item = call <= 1
            ? _directoryUser
            : _directoryUser.copyWith(status: 'INACTIVE');
        return Result<AccessAdminWorkspaceData>.success(
          _directoryData(items: <AccessAdminItem>[item]),
        );
      });
      when(
        () => repository.setUserStatus(any(), any()),
      ).thenAnswer((_) async => const Result<void>.success(null));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/admin/access?panel=directory',
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
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminDeactivateAction), findsWidgets);
      await tester.tap(find.text(l10n.accessAdminDeactivateAction).first);
      await tester.pumpAndSettle();

      verify(() => repository.setUserStatus('user-1', 'INACTIVE')).called(1);
      expect(find.text(l10n.accessAdminActivateAction), findsWidgets);
    });

    testWidgets('mobile viewport: next-action absent without write', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: facilityOnly,
        data: _directoryData(canWrite: true),
        viewport: const Size(390, 844),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text(l10n.accessAdminPanelDirectory), findsOneWidget);
      expect(find.text(l10n.accessAdminDeactivateAction), findsNothing);
      expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('mobile viewport: writer sees Create + Deactivate', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: tenant,
        data: _directoryData(canWrite: true),
        viewport: const Size(390, 844),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      // Compact toolbar is icon-only; semantics keep the Create label.
      expect(find.byType(AppTabToolbarPrimary), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.accessAdminCreateUserAction),
        findsOneWidget,
      );
      expect(find.text(l10n.accessAdminDeactivateAction), findsWidgets);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
    });

    testWidgets('dark theme: authorized Directory atoms remain visible', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: tenant,
        data: _directoryData(canWrite: true),
        themeMode: ThemeMode.dark,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminCreateUserAction), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsWidgets);
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
          initialLocation: '/admin/access?panel=directory',
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
        await tester.pumpAndSettle();

        // Authorized readers still see failure / retry chrome (no "no access").
        expect(find.byType(AccessAdminWorkspacePage), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );
  });

  group('accessAdminDefaultColumns Directory next_action gate', () {
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
            resource: AccessAdminResource.users,
            canWrite: false,
            onUserStatusToggle: (_) async {},
            onRoleEdit: (_) {},
            onRegistrationActivate: (_) async {},
          )
          .map((AppListTableColumn<AccessAdminItem> column) => column.id)
          .whereType<String>()
          .toList();

      expect(ids, isNot(contains('next_action')));
    });

    testWidgets('includes next_action column when canWrite is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      final List<String> ids = accessAdminDefaultColumns(
            context,
            resource: AccessAdminResource.users,
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
  });
}
