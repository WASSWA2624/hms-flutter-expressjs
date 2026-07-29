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
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/domain/repositories/subscriptions_repository.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/subscriptions_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSubscriptionsRepository extends Mock
    implements SubscriptionsRepository {}

const SubscriptionItem _planItem = SubscriptionItem(
  id: 'plan-1',
  resource: SubscriptionResource.subscriptionPlans,
  displayId: 'PLAN-1',
  name: 'Starter Plan',
  code: 'STARTER',
  tierCode: 'BASIC',
  status: 'ACTIVE',
  monthlyPrice: 49,
  annualPrice: 490,
  includedModuleIds: <String>['mod-1'],
);

const List<AppModuleEntitlement> _subscriptionModules = <AppModuleEntitlement>[
  AppModuleEntitlement(
    code: subscriptionsControlsModule,
    licenseStatus: 'ACTIVE',
  ),
];

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = _subscriptionModules,
  List<String> roles = const <String>['BILLING'],
  String? tenantId = 'tenant-1',
  String? facilityId,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

Finder _tabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.textContaining(label),
  );
}

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabToolbarPrimary),
  matching: find.text(label),
);

void _stubWorkspace(
  _MockSubscriptionsRepository repository, {
  List<SubscriptionItem> items = const <SubscriptionItem>[_planItem],
  bool empty = false,
  AppFailure? failure,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (failure != null) {
      return Result<SubscriptionsWorkspaceData>.failure(failure);
    }
    final SubscriptionsWorkspaceQuery query =
        invocation.positionalArguments.single as SubscriptionsWorkspaceQuery;
    final List<SubscriptionItem> pageItems = empty
        ? const <SubscriptionItem>[]
        : (query.resource == SubscriptionResource.subscriptionPlans ||
                  query.resource == SubscriptionResource.modules
              ? items
              : const <SubscriptionItem>[]);
    return Result<SubscriptionsWorkspaceData>.success(
      SubscriptionsWorkspaceData(
        query: query,
        summary: const <SubscriptionSummaryMetric>[],
        queueSummaries: const <SubscriptionQueueSummary>[],
        panelSummaries: const <SubscriptionPanelSummary>[],
        lookups: const SubscriptionLookups(
          modules: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'mod-1', label: 'OPD'),
          ],
          tiers: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'BASIC', label: 'Basic'),
          ],
          plans: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'plan-1', label: 'Starter Plan'),
          ],
        ),
        items: AppPage<SubscriptionItem>(
          items: pageItems,
          request: query.pageRequest,
          totalItemCount: pageItems.length,
        ),
        overview: const SubscriptionsOverview(
          activePlanTenants: SubscriptionTenantCohortSummary(
            cohort: SubscriptionTenantCohort.active,
            count: 3,
          ),
          notSubscribedTenants: SubscriptionTenantCohortSummary(
            cohort: SubscriptionTenantCohort.notSubscribed,
            count: 1,
          ),
          closedSubscriptionTenants: SubscriptionTenantCohortSummary(
            cohort: SubscriptionTenantCohort.closed,
            count: 0,
          ),
        ),
        timeline: const <SubscriptionTimelineItem>[],
      ),
    );
  });
  when(
    () => repository.getReferenceData(tenantId: any(named: 'tenantId')),
  ).thenAnswer(
    (_) async =>
        const Result<SubscriptionLookups>.success(SubscriptionLookups()),
  );
  when(() => repository.getPlanDetail(any())).thenAnswer(
    (_) async => const Result<SubscriptionPlanDetail>.success(
      SubscriptionPlanDetail(plan: _planItem),
    ),
  );
  when(() => repository.createPlan(any())).thenAnswer(
    (_) async => const Result<void>.success(null),
  );
  when(() => repository.updatePlan(any(), any())).thenAnswer(
    (_) async => const Result<void>.success(null),
  );
}

Future<void> _pumpPlansTab(
  WidgetTester tester, {
  required _MockSubscriptionsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/subscriptions?panel=catalog',
  List<SubscriptionItem> items = const <SubscriptionItem>[_planItem],
  bool empty = false,
  AppFailure? loadFailure,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    items: items,
    empty: empty,
    failure: loadFailure,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/subscriptions',
        name: AppRoutes.subscriptions.name,
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: SubscriptionsWorkspacePage(
              initialQuery: SubscriptionsWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subscriptionsRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
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
  late _MockSubscriptionsRepository repository;

  setUpAll(() {
    registerFallbackValue(const SubscriptionsWorkspaceQuery());
    registerFallbackValue(
      const SubscriptionPlanDraft(
        name: 'fallback',
        monthlyPrice: '0',
        annualPrice: '0',
        billingCycle: 'MONTHLY',
      ),
    );
  });

  setUp(() {
    repository = _MockSubscriptionsRepository();
  });

  group('subscriptions_access helpers (Plans matrix)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        SubscriptionsPlansAtomPermissions.tab,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsPlansAtomPermissions.create,
        same(subscriptionsWorkspaceCreateRequirement),
      );
      expect(
        SubscriptionsPlansAtomPermissions.edit,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsPlansAtomPermissions.manageModules,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsPlansAtomPermissions.delete,
        same(subscriptionsWorkspaceDeleteRequirement),
      );
      expect(
        SubscriptionsPlansAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.subscriptionsEntry),
      );
      expect(
        SubscriptionsPlansAtomPermissions.routeEntry,
        same(subscriptionsWorkspaceRouteEntryRequirement),
      );
      expect(
        subscriptionsPanelTabRequirement(SubscriptionPanel.catalog),
        same(SubscriptionsPlansAtomPermissions.tab),
      );
    });

    test('∩ denial: missing subscriptions:read blocks Plans tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsWrite},
      );
      expect(
        SubscriptionsPlansAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        canViewSubscriptionsPanel(writeOnly, SubscriptionPanel.catalog),
        isFalse,
      );
    });

    test('∩ presence: subscriptions:read + module allows read atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );
      expect(
        SubscriptionsPlansAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsPlansAtomPermissions.listChrome.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsPlansAtomPermissions.rowSelect.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsPlansAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        SubscriptionsPlansAtomPermissions.edit.isAllowed(reader),
        isFalse,
      );
      expect(
        SubscriptionsPlansAtomPermissions.manageModules.isAllowed(reader),
        isFalse,
      );
    });

    test('∩ write requires subscriptions:write', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );
      expect(canWriteSubscriptions(reader), isFalse);
      expect(canWriteSubscriptions(writer), isTrue);
      expect(
        SubscriptionsPlansAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        SubscriptionsPlansAtomPermissions.edit.isAllowed(writer),
        isTrue,
      );
      expect(
        SubscriptionsPlansAtomPermissions.manageModules.isAllowed(writer),
        isTrue,
      );
    });

    test('∩ delete requires subscriptions:delete (not mounted on tab)', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );
      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsDelete,
        },
      );
      expect(
        SubscriptionsPlansAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );
      expect(
        SubscriptionsPlansAtomPermissions.delete.isAllowed(deleter),
        isTrue,
      );
    });

    test('∪ route entry: system:admin alone satisfies AppRoutes entry', () {
      final AppAccessPolicy systemOnly = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
        roles: const <String>['SUPER_ADMIN'],
        modules: const <AppModuleEntitlement>[],
        tenantId: null,
      );
      expect(
        SubscriptionsPlansAtomPermissions.routeEntry.isAllowed(systemOnly),
        isTrue,
      );
      expect(canEnterSubscriptionsWorkspace(systemOnly), isTrue);
    });

    test('nested cross-module _(n/a)_ reuses workspace read/write ∩', () {
      expect(
        SubscriptionsPlansAtomPermissions.nestedRead,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsPlansAtomPermissions.nestedWrite,
        same(subscriptionsWorkspaceWriteRequirement),
      );
    });

    test('subscription strip: role pack without module omits Plans', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        SubscriptionsPlansAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(subscriptionsAllowedPanels(noModule), isEmpty);
    });
  });

  group('Plans tab widget gates', () {
    testWidgets(
      '∩ denial: read-only hides Create/Edit/Manage; list remains',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpPlansTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tabLabel('Plans'), findsWidgets);
        expect(find.text('Starter Plan'), findsOneWidget);
        expect(_toolbarPrimary('Create plan'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Starter Plan'));
        await tester.pumpAndSettle();

        expect(find.text('Edit plan'), findsNothing);
        expect(find.text('Manage modules'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∩ presence: write mounts Create/Edit/Manage; delete absent',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpPlansTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(_toolbarPrimary('Create plan'), findsOneWidget);
        expect(find.text('Delete plan'), findsNothing);

        await tester.tap(find.text('Starter Plan'));
        await tester.pumpAndSettle();

        expect(find.text('Edit plan'), findsOneWidget);
        expect(find.text('Manage modules'), findsOneWidget);
        expect(find.text('Delete'), findsNothing);
        expect(find.text('Revoke'), findsNothing);
      },
    );

    testWidgets(
      '∪ allowance: system:admin satisfies route entry; plan atoms still '
      'need subscriptions:read ∩ module',
      (WidgetTester tester) async {
        // Non-elevated holder of system:admin (route ∪) without subscriptions:*.
        final AppAccessPolicy systemOnly = _policy(
          permissions: <AppPermission>{AppPermissions.systemAdmin},
          roles: const <String>['OTHER'],
        );
        expect(
          SubscriptionsPlansAtomPermissions.routeEntry.isAllowed(systemOnly),
          isTrue,
        );
        expect(
          SubscriptionsPlansAtomPermissions.tab.isAllowed(systemOnly),
          isFalse,
        );

        await _pumpPlansTab(
          tester,
          repository: repository,
          accessPolicy: systemOnly,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(_toolbarPrimary('Create plan'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'subscription/ABAC strip: module missing omits Plans strip',
      (WidgetTester tester) async {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
          modules: const <AppModuleEntitlement>[],
        );

        await _pumpPlansTab(
          tester,
          repository: repository,
          accessPolicy: noModule,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Starter Plan'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module UI absent without nested rights (n/a → none)',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpPlansTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        await tester.tap(find.text('Starter Plan'));
        await tester.pumpAndSettle();

        expect(find.text('Receive payment'), findsNothing);
        expect(find.text('Submit claim'), findsNothing);
        expect(find.text('Open operations'), findsNothing);
        expect(find.text('New subscription'), findsNothing);
      },
    );

    testWidgets(
      'authorized Manage modules flow syncs workspace after mutation',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpPlansTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('Starter Plan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manage modules'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        await tester.tap(find.text('Save modules'));
        await tester.pumpAndSettle();

        verify(() => repository.updatePlan('plan-1', any())).called(1);
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );

      await _pumpPlansTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        empty: true,
      );

      expect(find.textContaining('No subscription records'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('authorized filters chrome remains observable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );

      await _pumpPlansTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Starter Plan'), findsOneWidget);
    });

    testWidgets('mobile viewport: Plans list and detail remain usable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );

      await _pumpPlansTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Starter Plan'), findsWidgets);
      await tester.tap(find.text('Starter Plan').first);
      await tester.pumpAndSettle();
      expect(find.text('Edit plan'), findsOneWidget);
      expect(find.text('Manage modules'), findsOneWidget);
    });

    testWidgets('desktop viewport: Plans table and mutations mount', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );

      await _pumpPlansTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(1440, 900),
      );

      expect(find.byType(AppListTable<SubscriptionItem>), findsOneWidget);
      expect(_toolbarPrimary('Create plan'), findsOneWidget);
      await tester.tap(find.text('Starter Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Edit plan'), findsOneWidget);
    });

    testWidgets('light theme: authorized Plans chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpPlansTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        ),
        themeMode: ThemeMode.light,
      );

      expect(_tabLabel('Plans'), findsWidgets);
      expect(find.text('Starter Plan'), findsOneWidget);
    });

    testWidgets('dark theme: authorized Plans chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpPlansTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        ),
        themeMode: ThemeMode.dark,
      );

      expect(_tabLabel('Plans'), findsWidgets);
      await tester.tap(find.text('Starter Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Edit plan'), findsOneWidget);
    });

    testWidgets(
      'integration: AppRoutes.subscriptions name + catalog entry align',
      (WidgetTester tester) async {
        expect(AppRoutes.subscriptions.name, 'subscriptions');
        expect(
          RouteAccessCatalog.subscriptionsEntry.allPermissions,
          <AppPermission>[AppPermissions.subscriptionsRead],
        );
        expect(
          SubscriptionsPlansAtomPermissions.catalogEntry,
          same(RouteAccessCatalog.subscriptionsEntry),
        );

        await _pumpPlansTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.subscriptionsRead},
          ),
        );

        expect(_tabLabel('Plans'), findsWidgets);
        final List<AppTabStrip> strips = tester
            .widgetList<AppTabStrip>(find.byType(AppTabStrip))
            .toList(growable: false);
        expect(strips.length, greaterThanOrEqualTo(2));
        expect(
          strips[1].tabs.map((AppTabItem tab) => tab.label),
          <String>['Plans', 'Modules'],
        );
      },
    );
  });
}
