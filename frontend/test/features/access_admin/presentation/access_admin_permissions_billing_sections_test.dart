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
import 'package:hosspi_hms/features/access_admin/presentation/access_admin_permissions_billing.dart';
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_harness.dart';
import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockAccessAdminRepository extends Mock
    implements AccessAdminRepository {}

const AccessAdminItem _permissionItem = AccessAdminItem(
  id: 'perm-1',
  resource: AccessAdminResource.permissions,
  displayId: 'PERM-1',
  title: 'Patient Read',
  permissionName: 'patient:read',
  subtitle: 'View patient demographics and encounters',
);

const AccessAdminItem _billingPermissionItem = AccessAdminItem(
  id: 'perm-billing',
  resource: AccessAdminResource.permissions,
  displayId: 'PERM-BILL',
  title: 'Billing Write',
  permissionName: 'billing:write',
  subtitle: 'Allows write access within billing.',
);

AccessAdminWorkspaceData _permissionsData({
  bool canWrite = true,
  List<AccessAdminItem> items = const <AccessAdminItem>[_permissionItem],
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
      panel: AccessAdminPanel.permissions,
      resource: AccessAdminResource.permissions,
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

void _stubWorkspace(
  _MockAccessAdminRepository repository, {
  AccessAdminWorkspaceData? data,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => Result<AccessAdminWorkspaceData>.success(
      data ?? _permissionsData(),
    ),
  );
}

Future<void> _pumpPermissions(
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
    initialLocation: '/admin/access?panel=permissions',
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

  group('AccessAdminPermissionsBillingInventory (AC1)', () {
    test('every mounted atom is explicitly not billable to patient ledgers', () {
      expect(
        AccessAdminPermissionsBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(AccessAdminPermissionsBillingInventory.billableClasses, isEmpty);
    });

    test('billing:write catalog row uses NOT_BILLED audit — no ledger mutation', () {
      final AccessAdminPermissionsFinancialAtom billingAtom =
          AccessAdminPermissionsBillingInventory.atoms.firstWhere(
        (AccessAdminPermissionsFinancialAtom atom) =>
            atom.id == 'billing_permission_catalog_display',
      );
      expect(billingAtom.auditCode, 'NOT_BILLED');
      expect(
        billingAtom.financialClass,
        AccessAdminPermissionsFinancialClass.notBilled,
      );
    });

    test('reserved write and financial atoms are unmounted', () {
      final List<String> unmounted =
          AccessAdminPermissionsBillingInventory.atoms
              .where((AccessAdminPermissionsFinancialAtom atom) => !atom.mounted)
              .map((AccessAdminPermissionsFinancialAtom atom) => atom.id)
              .toList();
      expect(unmounted, containsAll(<String>[
        'create_permission',
        'update_permission',
        'delete_permission',
        'collect_payment',
        'issue_invoice_adjust_refund',
      ]));
    });

    test('scope note documents ledger isolation', () {
      expect(accessAdminPermissionsBillingScopeNote, contains('Billing'));
      expect(accessAdminPermissionsBillingScopeNote, contains('historical'));
    });

    test('reserved write atoms do not expose billable create/settle paths', () {
      expect(
        AccessAdminPermissionsAtomPermissions.create.allPermissions,
        AccessAdminPermissionsAtomPermissions.write.allPermissions,
      );
      expect(canMutateAccessAdminPermissions(_policy()), isTrue);
    });
  });

  group('Permissions billing bypass + authorization (AC2–AC5)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpPermissions(
        tester,
        repository: repository,
        policy: _policy(),
        data: _permissionsData(canWrite: true),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminPanelPermissions), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets(
      'billing:write catalog row is read-only metadata — no ledger mutation',
      (WidgetTester tester) async {
        await _pumpPermissions(
          tester,
          repository: repository,
          policy: _policy(),
          data: _permissionsData(
            canWrite: true,
            items: const <AccessAdminItem>[_billingPermissionItem],
          ),
        );

        expect(find.text('Billing Write'), findsWidgets);
        expect(find.text('billing:write'), findsWidgets);

        final AppListTable<AccessAdminItem> table = tester
            .widgetList<AppListTable<AccessAdminItem>>(
              find.byType(AppListTable<AccessAdminItem>),
            )
            .first;
        table.onRowSelected!(_billingPermissionItem);
        await tester.pumpAndSettle();

        expect(find.text('Read-only'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expectFlatTitledSectionLayout(tester);
      },
    );

    testWidgets('detail dialog is Close-only — no financial controls', (
      WidgetTester tester,
    ) async {
      await _pumpPermissions(
        tester,
        repository: repository,
        policy: _policy(),
        data: _permissionsData(canWrite: true),
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_permissionItem);
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(AppDialog));
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.commonCloseActionLabel), findsOneWidget);
      expect(find.text(l10n.accessAdminDeleteRoleAction), findsNothing);
      expect(find.text(l10n.tenantFacilityEditAction), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('unauthorized reader cannot reach billing collect chrome', (
      WidgetTester tester,
    ) async {
      await _pumpPermissions(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
      );

      expect(find.text('Patient Read'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
    });
  });

  group('Permissions section layout (AC5)', () {
    testWidgets('desktop worklist: flat titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpPermissions(
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
      await _pumpPermissions(
        tester,
        repository: repository,
        policy: _policy(),
        viewport: const Size(390, 844),
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('detail dialog: sibling sections only, never nested', (
      WidgetTester tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () {
                showAccessAdminPermissionDetailDialog(
                  context,
                  permission: _permissionItem,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'permission detail dialog',
      );
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpPermissions(
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
      await _pumpPermissions(
        tester,
        repository: repository,
        policy: _policy(),
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(tester);
    });
  });

  group('Permissions sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('permission list reload does not call billing sync APIs', (
      WidgetTester tester,
    ) async {
      await _pumpPermissions(
        tester,
        repository: repository,
        policy: _policy(),
      );

      expect(find.text('Patient Read'), findsWidgets);
      verify(() => repository.getWorkspace(any())).called(greaterThan(0));
      verifyNever(
        () => repository.syncRolePermissions(
          roleId: any(named: 'roleId'),
          permissionIds: any(named: 'permissionIds'),
        ),
      );
    });

    testWidgets('empty authorized state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpPermissions(
        tester,
        repository: repository,
        policy: _policy(),
        data: _permissionsData(items: const <AccessAdminItem>[]),
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
        initialLocation: '/admin/access?panel=permissions',
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
  });
}
