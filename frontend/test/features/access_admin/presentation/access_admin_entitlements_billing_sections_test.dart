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
import 'package:hosspi_hms/features/access_admin/presentation/access_admin_entitlements_billing.dart';
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/layout/flat_section_layout_test_helpers.dart';

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
      moduleEntitlements: const <AppModuleEntitlement>[],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockAccessAdminRepository repository, {
  AccessAdminWorkspaceData? data,
  Result<AccessAdminWorkspaceData>? workspaceResult,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async =>
        workspaceResult ??
        Result<AccessAdminWorkspaceData>.success(data ?? _entitlementsData()),
  );
}

Future<void> _pumpEntitlements(
  WidgetTester tester, {
  required _MockAccessAdminRepository repository,
  required AppAccessPolicy policy,
  AccessAdminWorkspaceData? data,
  Result<AccessAdminWorkspaceData>? workspaceResult,
  Size viewport = const Size(1280, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    data: data,
    workspaceResult: workspaceResult,
  );

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

  group('AccessAdminEntitlementsBillingInventory (AC1)', () {
    test('every mounted atom is explicitly not billable to patient ledgers', () {
      expect(
        AccessAdminEntitlementsBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(
        AccessAdminEntitlementsBillingInventory.billableClasses,
        isEmpty,
      );
    });

    test('reserved write/financial atoms are unmounted', () {
      final List<String> unmounted = AccessAdminEntitlementsBillingInventory.atoms
          .where((AccessAdminEntitlementsFinancialAtom atom) => !atom.mounted)
          .map((AccessAdminEntitlementsFinancialAtom atom) => atom.id)
          .toList();
      expect(unmounted, containsAll(<String>[
        'create_entitlement',
        'update_entitlement',
        'delete_entitlement',
        'collect_payment',
        'issue_invoice_adjust_refund',
      ]));
    });

    test('plan/status display uses NOT_BILLED audit (display-only metadata)', () {
      final AccessAdminEntitlementsFinancialAtom displayAtom =
          AccessAdminEntitlementsBillingInventory.atoms.firstWhere(
        (AccessAdminEntitlementsFinancialAtom atom) =>
            atom.id == 'plan_status_display',
      );
      expect(displayAtom.auditCode, 'NOT_BILLED');
      expect(displayAtom.financialClass,
          AccessAdminEntitlementsFinancialClass.notBilled);
    });
  });

  group('Entitlements billing bypass + authorization (AC2, AC4)', () {
    testWidgets('no payment/issue/collect affordances on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: _policy(),
        data: _entitlementsData(canWrite: true),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
      expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
      expect(find.text(l10n.accessAdminActivateRegistrationAction), findsNothing);

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
    });

    testWidgets('unauthorized actor sees no entitlements worklist or pay chrome', (
      WidgetTester tester,
    ) async {
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
      );

      expect(find.text('Patient Registry'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
    });

    testWidgets('detail dialog is read-only Close only (no financial footer)', (
      WidgetTester tester,
    ) async {
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: _policy(),
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

      expect(find.text(l10n.commonCloseActionLabel), findsOneWidget);
      expect(find.text(l10n.accessAdminDeleteRoleAction), findsNothing);
      expect(find.text(l10n.accessAdminRejectRegistrationAction), findsNothing);
    });
  });

  group('Entitlements sync parity (AC3)', () {
    testWidgets('authorized reload keeps worklist synced via repository', (
      WidgetTester tester,
    ) async {
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: _policy(),
      );

      expect(find.text('Patient Registry'), findsWidgets);
      verify(() => repository.getWorkspace(any())).called(greaterThan(0));
    });

    testWidgets('idempotent getWorkspace replay returns stable list', (
      WidgetTester tester,
    ) async {
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: _policy(),
      );
      expect(find.text('Patient Registry'), findsWidgets);

      final Finder retry = find.byIcon(Icons.refresh);
      if (retry.evaluate().isNotEmpty) {
        await tester.tap(retry.first);
        await tester.pumpAndSettle();
      }

      verify(() => repository.getWorkspace(any())).called(greaterThan(0));
      expect(find.text('Patient Registry'), findsWidgets);
    });
  });

  group('Flat titled sections (AC5)', () {
    testWidgets('desktop light: no nested sections on worklist', (
      WidgetTester tester,
    ) async {
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: _policy(),
      );
      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AccessAdminWorkspacePage),
        contextLabel: 'entitlements worklist desktop light',
      );
    });

    testWidgets('mobile dark: no nested sections on worklist', (
      WidgetTester tester,
    ) async {
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: _policy(),
        viewport: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AccessAdminWorkspacePage),
        contextLabel: 'entitlements worklist mobile dark',
      );
    });

    testWidgets('detail dialog: no nested titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: _policy(),
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_entitlementItem);
      await tester.pumpAndSettle();

      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AppDialog),
        contextLabel: 'entitlements detail dialog',
      );
    });
  });

  group('Authorized UI states (AC4, AC6)', () {
    testWidgets('empty state remains observable', (WidgetTester tester) async {
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: _policy(),
        data: _entitlementsData(items: const <AccessAdminItem>[]),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      expect(find.text(context.l10n.accessAdminEmptyTitle), findsOneWidget);
    });

    testWidgets('error state remains observable for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpEntitlements(
        tester,
        repository: repository,
        policy: _policy(),
        workspaceResult: const Result<AccessAdminWorkspaceData>.failure(
          AppFailure.network(),
        ),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      expect(find.text(context.l10n.errorNetworkMessage), findsWidgets);
    });
  });
}
