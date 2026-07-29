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
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccessAdminRepository extends Mock
    implements AccessAdminRepository {}

const AccessAdminItem _entitlementItem = AccessAdminItem(
  id: 'mod-1',
  resource: AccessAdminResource.moduleEntitlements,
  displayId: 'MOD-1',
  title: 'Patient Registry',
  moduleGroup: 'Clinical',
  planLabel: 'Basic',
  isActive: true,
  moduleSlug: 'patient-registry',
);

AccessAdminWorkspaceData _entitlementsData({
  bool canWrite = true,
  List<AccessAdminItem> items = const <AccessAdminItem>[_entitlementItem],
}) {
  return AccessAdminWorkspaceData(
    permissions: AccessAdminWorkspacePermissions(
      canRead: true,
      canWrite: canWrite,
    ),
    items: items,
    page: AppPage<AccessAdminItem>(
      items: items,
      request: const AppPageRequest(pageSize: 12),
      totalItemCount: items.length,
    ),
    query: const AccessAdminWorkspaceQuery(
      panel: AccessAdminPanel.entitlements,
      resource: AccessAdminResource.moduleEntitlements,
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
      data ?? _entitlementsData(),
    ),
  );
}

Future<void> _pumpEntitlements(
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
    initialLocation: '/admin/access?panel=entitlements',
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

  group('access_admin_access helpers (Entitlements matrix)', () {
    test('∪ read: facility:admin alone satisfies entitlements read', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(canReadAccessAdminEntitlements(facilityOnly), isTrue);
      expect(
        AccessAdminEntitlementsAtomPermissions.tab.isAllowed(facilityOnly),
        isTrue,
      );
      expect(
        accessAdminAllowedPanels(facilityOnly)
            .contains(AccessAdminPanel.entitlements),
        isTrue,
      );
    });

    test('∪ read: system:admin alone satisfies entitlements read', () {
      final AppAccessPolicy systemOnly = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
        roles: const <String>['SUPER_ADMIN'],
      );
      expect(canReadAccessAdminEntitlements(systemOnly), isTrue);
    });

    test('∪ denial: clinical:read alone cannot read entitlements', () {
      final AppAccessPolicy clinical = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        roles: const <String>['DOCTOR'],
      );
      expect(canReadAccessAdminEntitlements(clinical), isFalse);
      expect(
        accessAdminAllowedPanels(clinical)
            .contains(AccessAdminPanel.entitlements),
        isFalse,
      );
    });

    test('∩ write: facility:admin without tenant:admin cannot mutate', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      // Source canWrite may be true; matrix still requires tenant:admin.
      // Inventory: Entitlements catalog has no write atoms; helper still ∩.
      expect(
        canMutateAccessAdminEntitlements(
          facilityOnly,
          workspaceCanWrite: true,
        ),
        isFalse,
      );
      expect(
        accessAdminEntitlementsWriteRequirement.isAllowed(facilityOnly),
        isFalse,
      );
      expect(
        AccessAdminEntitlementsAtomPermissions.create.isAllowed(facilityOnly),
        isFalse,
      );
    });

    test('∩ write: tenant:admin + workspace canWrite allows mutate helper', () {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      expect(
        canMutateAccessAdminEntitlements(tenant, workspaceCanWrite: true),
        isTrue,
      );
      expect(
        canMutateAccessAdminEntitlements(tenant, workspaceCanWrite: false),
        isFalse,
      );
    });

    test('ABAC: missing tenant context denies entitlements read', () {
      final AppAccessPolicy noTenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
        tenantId: null,
      );
      expect(
        accessAdminEntitlementsReadRequirement.isAllowed(noTenant),
        isFalse,
      );
    });

    test('nested cross-module write n/a — write atoms absent on this tab', () {
      expect(
        identical(
          AccessAdminEntitlementsAtomPermissions.write,
          accessAdminEntitlementsWriteRequirement,
        ),
        isTrue,
      );
    });

    test('Requirement helpers reuse AccessRequirement vocabulary', () {
      expect(
        identical(
          accessAdminEntitlementsReadRequirement,
          accessAdminWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          accessAdminEntitlementsWriteRequirement,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminEntitlementsAtomPermissions.create,
          accessAdminCreateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminEntitlementsAtomPermissions.update,
          accessAdminUpdateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminEntitlementsAtomPermissions.delete,
          accessAdminDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminEntitlementsAtomPermissions.write,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        AccessAdminEntitlementsAtomPermissions.create.allPermissions,
        AccessAdminEntitlementsAtomPermissions.write.allPermissions,
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
        expect(canReadAccessAdminEntitlements(tenant), isTrue);
        expect(accessAdminModuleLabel, 'access administration');
        expect(accessAdminActiveModule, 'access_admin');
      },
    );

    test('route entry ∪ aligns with Entitlements read matrix', () {
      expect(
        AppRoutes.accessAdmin.requiredAnyPermissions,
        containsAll(<AppPermission>[
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.systemAdmin,
        ]),
      );
      expect(
        accessAdminEntitlementsReadRequirement.anyPermissions,
        accessAdminReadPermissions,
      );
    });
  });

  group('Entitlements UI permissions', () {
    testWidgets(
      'facility:admin: Entitlements list visible; write chrome absent (∩)',
      (WidgetTester tester) async {
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        await _pumpEntitlements(
          tester,
          repository: repository,
          policy: facilityOnly,
          data: _entitlementsData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelEntitlements), findsOneWidget);
        expect(find.text('Patient Registry'), findsWidgets);
        expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
        expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
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
      'tenant:admin: Entitlements read chrome present; still no write atoms',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpEntitlements(
          tester,
          repository: repository,
          policy: tenant,
          data: _entitlementsData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelEntitlements), findsOneWidget);
        expect(find.text('Patient Registry'), findsWidgets);
        expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
        expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
        // Mutate helper remains true for reserved ∩; panel forces write off.
        expect(canMutateAccessAdminEntitlements(tenant), isTrue);

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
      'elevated writer: Entitlements stays read-only (no create/next_action)',
      (WidgetTester tester) async {
        final AppAccessPolicy elevated = _policy(
          permissions: <AppPermission>{
            AppPermissions.systemAdmin,
            AppPermissions.tenantAdmin,
          },
          roles: const <String>['SUPER_ADMIN'],
        );
        await _pumpEntitlements(
          tester,
          repository: repository,
          policy: elevated,
          data: _entitlementsData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelEntitlements), findsOneWidget);
        expect(find.text('Patient Registry'), findsWidgets);
        expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
        expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
        expect(find.text(l10n.accessAdminPanelRegistrations), findsOneWidget);

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
        expect(canMutateAccessAdminEntitlements(elevated), isTrue);
      },
    );

    testWidgets(
      'workspace canWrite false: Entitlements read chrome still present',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        await _pumpEntitlements(
          tester,
          repository: repository,
          policy: tenant,
          data: _entitlementsData(canWrite: false),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelEntitlements), findsOneWidget);
        expect(find.text('Patient Registry'), findsWidgets);
        expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
        expect(
          canMutateAccessAdminEntitlements(tenant, workspaceCanWrite: false),
          isFalse,
        );
      },
    );

    testWidgets(
      '∪ allowance: system:admin alone shows Entitlements chrome',
      (WidgetTester tester) async {
        final AppAccessPolicy systemOnly = _policy(
          permissions: <AppPermission>{AppPermissions.systemAdmin},
          roles: const <String>['SUPER_ADMIN'],
        );
        await _pumpEntitlements(
          tester,
          repository: repository,
          policy: systemOnly,
          data: _entitlementsData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelEntitlements), findsOneWidget);
        expect(find.text('Patient Registry'), findsWidgets);
      },
    );

    testWidgets(
      'missing admin permissions: workspace gate hides surface',
      (WidgetTester tester) async {
        final AppAccessPolicy none = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        );
        await _pumpEntitlements(
          tester,
          repository: repository,
          policy: none,
        );

        expect(find.text('Patient Registry'), findsNothing);
        expect(find.byType(AppTabStrip), findsNothing);
      },
    );

    testWidgets('empty authorized Entitlements keeps empty state', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: tenant,
        data: _entitlementsData(
          canWrite: true,
          items: const <AccessAdminItem>[],
        ),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminEmptyTitle), findsOneWidget);
      expect(find.text(l10n.accessAdminPanelEntitlements), findsOneWidget);
    });

    testWidgets('detail is read-only Close only (no write footer)', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: tenant,
        data: _entitlementsData(canWrite: true),
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_entitlementItem);
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(AppDialog));
      final AppLocalizations l10n = context.l10n;

      expect(find.text('Patient Registry'), findsWidgets);
      expect(find.text(l10n.commonCloseActionLabel), findsOneWidget);
      expect(find.text(l10n.accessAdminDeleteRoleAction), findsNothing);
      expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
      expect(find.text(l10n.accessAdminRejectRegistrationAction), findsNothing);
    });

    testWidgets('authorized reload keeps Entitlements worklist synced', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      when(() => repository.getWorkspace(any())).thenAnswer(
        (_) async => Result<AccessAdminWorkspaceData>.success(
          _entitlementsData(),
        ),
      );

      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: tenant,
      );

      expect(find.text('Patient Registry'), findsWidgets);
      verify(() => repository.getWorkspace(any())).called(greaterThan(0));
    });

    testWidgets('mobile viewport: Entitlements read atoms; no write trailing', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: facilityOnly,
        data: _entitlementsData(canWrite: true),
        viewport: const Size(390, 844),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminPanelEntitlements), findsOneWidget);
      // Mobile list may virtualize; assert write chrome is absent.
      expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
      expect(find.text(l10n.accessAdminDeactivateAction), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('light theme: authorized Entitlements atoms remain visible', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: tenant,
        data: _entitlementsData(canWrite: true),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminPanelEntitlements), findsOneWidget);
      expect(find.text('Patient Registry'), findsWidgets);
      expect(find.byType(AppSearchBar), findsWidgets);
    });

    testWidgets('dark theme: authorized Entitlements atoms remain visible', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: tenant,
        data: _entitlementsData(canWrite: true),
        themeMode: ThemeMode.dark,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminPanelEntitlements), findsOneWidget);
      expect(find.text('Patient Registry'), findsWidgets);
      expect(find.byType(AppSearchBar), findsWidgets);
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
          initialLocation: '/admin/access?panel=entitlements',
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
        expect(find.textContaining('no access'), findsNothing);
        expect(find.text(l10n.errorNetworkMessage), findsWidgets);
      },
    );
  });

  group('accessAdminDefaultColumns Entitlements next_action gate', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (BuildContext context) => child),
      );
    }

    testWidgets('never exposes next_action even when canWrite is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      final List<String> ids = accessAdminDefaultColumns(
            context,
            resource: AccessAdminResource.moduleEntitlements,
            canWrite: true,
            onUserStatusToggle: (_) async {},
            onRoleEdit: (_) {},
            onRegistrationActivate: (_) async {},
          )
          .map((AppListTableColumn<AccessAdminItem> column) => column.id)
          .whereType<String>()
          .toList();

      expect(ids, isNot(contains('next_action')));
      expect(ids, contains('ent_module'));
      expect(ids, contains('ent_active'));
      expect(ids, contains('ent_plan'));
      expect(ids, contains('ent_denial'));
    });

    testWidgets('mobile Entitlements next-action null regardless of canWrite', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      expect(
        accessAdminMobileNextAction(
          context,
          resource: AccessAdminResource.moduleEntitlements,
          item: _entitlementItem,
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
