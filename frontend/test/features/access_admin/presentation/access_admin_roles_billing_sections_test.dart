import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:hosspi_hms/features/access_admin/presentation/access_admin_roles_billing.dart';
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_dialogs.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/role_mutation_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/layout/flat_section_layout_test_helpers.dart';

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
      isAuthorizationHydrated: true,
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
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => Result<AccessAdminWorkspaceData>.success(
      data ?? _rolesData(),
    ),
  );

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
    registerFallbackValue(const AccessAdminRoleDraft(name: 'fallback'));
  });

  setUp(() {
    repository = _MockAccessAdminRepository();
  });

  group('AccessAdminRolesBillingInventory (AC1)', () {
    test('every mounted atom is explicitly not billable to patient ledgers', () {
      expect(
        AccessAdminRolesBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(AccessAdminRolesBillingInventory.billableClasses, isEmpty);
    });

    test('permission sync uses NOT_BILLED audit — no ledger mutation', () {
      final AccessAdminRolesFinancialAtom syncAtom =
          AccessAdminRolesBillingInventory.atoms.firstWhere(
        (AccessAdminRolesFinancialAtom atom) =>
            atom.id == 'sync_role_permissions',
      );
      expect(syncAtom.auditCode, 'NOT_BILLED');
      expect(
        syncAtom.financialClass,
        AccessAdminRolesFinancialClass.notBilled,
      );
    });

    test('reserved financial atoms are unmounted', () {
      final List<String> unmounted = AccessAdminRolesBillingInventory.atoms
          .where((AccessAdminRolesFinancialAtom atom) => !atom.mounted)
          .map((AccessAdminRolesFinancialAtom atom) => atom.id)
          .toList();
      expect(unmounted, containsAll(<String>[
        'collect_payment',
        'issue_invoice_adjust_refund',
        'sync_role_permissions',
        'role_permissions_editor_dialog',
        'restore_role',
        'permanent_delete_role',
      ]));
    });

    test('tab has no billable actions helper', () {
      expect(accessAdminRolesTabHasNoBillableActions(), isTrue);
    });

    test('scope note documents ledger isolation', () {
      expect(accessAdminRolesBillingScopeNote, contains('Billing'));
      expect(accessAdminRolesBillingScopeNote, contains('historical'));
    });
  });

  group('Roles billing bypass + authorization (AC2–AC5)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(),
        data: _rolesData(canWrite: true),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminPanelRoles), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('authorized writer sees Create/Edit without billing chrome', (
      WidgetTester tester,
    ) async {
      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(),
        data: _rolesData(canWrite: true),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminCreateRoleAction), findsOneWidget);
      expect(find.text(l10n.accessAdminEditRoleAction), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('unauthorized reader cannot reach billing collect chrome', (
      WidgetTester tester,
    ) async {
      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
      );

      expect(find.text('Ward Nurse'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('detail dialog lists permissions read-only without sync', (
      WidgetTester tester,
    ) async {
      when(() => repository.listRolePermissions(any())).thenAnswer(
        (_) async => const Result<List<AccessAdminRolePermissionAssignment>>
            .success(<AccessAdminRolePermissionAssignment>[
          AccessAdminRolePermissionAssignment(
            id: 'rp-1',
            permissionId: 'perm-1',
            permissionName: 'billing:write',
          ),
        ]),
      );

      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(),
        data: _rolesData(canWrite: true),
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_roleItem);
      await tester.pumpAndSettle();

      verify(() => repository.listRolePermissions('role-1')).called(1);
      verifyNever(
        () => repository.syncRolePermissions(
          roleId: any(named: 'roleId'),
          permissionIds: any(named: 'permissionIds'),
        ),
      );
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });
  });

  group('Roles section layout (AC5)', () {
    testWidgets('desktop worklist: flat titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(),
        viewport: const Size(1280, 900),
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('mobile worklist: flat titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(),
        viewport: const Size(390, 844),
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('create role dialog tenant scope: no nested sections', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  unawaited(
                    showRoleMutationDialog(
                      context: context,
                      mode: RoleMutationMode.create,
                      allowPlatformScope: true,
                      allowTenantScope: true,
                      allowFacilityScope: true,
                      loadTenantOptions: () async =>
                          const <AccessAdminLookupOption>[
                            AccessAdminLookupOption(
                              id: 'tenant-1',
                              label: 'DemoCare General Hospital',
                            ),
                          ],
                      onSubmit: (List<AccessAdminRoleDraft> drafts) async =>
                          null,
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tenant(s)'));
      await tester.pumpAndSettle();

      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'create role tenant scope',
      );
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(),
        themeMode: ThemeMode.light,
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(),
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(tester);
    });
  });

  group('Roles sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('idempotent getWorkspace replay returns stable roles list', (
      WidgetTester tester,
    ) async {
      var callCount = 0;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        callCount += 1;
        return Result<AccessAdminWorkspaceData>.success(_rolesData());
      });

      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(),
      );

      expect(callCount, greaterThan(0));
      expect(find.text('Ward Nurse'), findsWidgets);
      verifyNever(
        () => repository.syncRolePermissions(
          roleId: any(named: 'roleId'),
          permissionIds: any(named: 'permissionIds'),
        ),
      );
    });

    testWidgets('role list reload does not call billing sync APIs', (
      WidgetTester tester,
    ) async {
      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(),
      );

      expect(find.text('Ward Nurse'), findsWidgets);
      verify(() => repository.getWorkspace(any())).called(greaterThan(0));
      verifyNever(
        () => repository.syncRolePermissions(
          roleId: any(named: 'roleId'),
          permissionIds: any(named: 'permissionIds'),
        ),
      );
      verifyNever(() => repository.createRole(any()));
    });

    testWidgets('empty authorized state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpRoles(
        tester,
        repository: repository,
        policy: _policy(),
        data: _rolesData(items: const <AccessAdminItem>[]),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      expect(find.text(context.l10n.accessAdminEmptyTitle), findsOneWidget);
    });

    testWidgets('error/retry remains for authorized readers', (
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      expect(find.text(context.l10n.errorNetworkMessage), findsWidgets);
    });

    testWidgets('create role dialog blocked without mutate ∩', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      AccessAdminItem? createResult = _roleItem;
      final AccessAdminWorkspaceState state = AccessAdminWorkspaceState(
        data: _rolesData(canWrite: true),
        query: _rolesData().query,
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
                    },
                    child: const Text('probe-create'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('probe-create'));
      await tester.pumpAndSettle();

      expect(createResult, isNull);
      verifyNever(() => repository.createRole(any()));
    });
  });
}
