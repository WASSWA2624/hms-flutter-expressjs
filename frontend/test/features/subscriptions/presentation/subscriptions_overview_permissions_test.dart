import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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

const List<AppModuleEntitlement> _subscriptionModules = <AppModuleEntitlement>[
  AppModuleEntitlement(
    code: subscriptionsControlsModule,
    licenseStatus: 'ACTIVE',
  ),
];

const SubscriptionTenantAccount _activeAccount = SubscriptionTenantAccount(
  id: 'acct-active',
  tenantId: 'tenant-1',
  tenantLabel: 'Acme Clinic',
  subscriptionId: 'sub-1',
  status: 'ACTIVE',
  planId: 'plan-1',
  planLabel: 'Starter Plan',
  planCode: 'STARTER',
);

const SubscriptionTenantAccount _unsubscribedAccount = SubscriptionTenantAccount(
  id: 'acct-none',
  tenantId: 'tenant-2',
  tenantLabel: 'Fresh Clinic',
  status: 'NONE',
);

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

void _stubWorkspace(_MockSubscriptionsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final SubscriptionsWorkspaceQuery query =
        invocation.positionalArguments.single as SubscriptionsWorkspaceQuery;
    return Result<SubscriptionsWorkspaceData>.success(
      SubscriptionsWorkspaceData(
        query: query,
        summary: const <SubscriptionSummaryMetric>[
          SubscriptionSummaryMetric(
            id: 'past_due_invoices',
            label: 'Past due invoices',
            value: 2,
          ),
          SubscriptionSummaryMetric(
            id: 'pending_changes',
            label: 'Pending changes',
            value: 1,
          ),
        ],
        queueSummaries: const <SubscriptionQueueSummary>[
          SubscriptionQueueSummary(
            id: 'past_due_billing',
            label: 'Past due invoices',
            count: 2,
            panel: SubscriptionPanel.billing,
            resource: SubscriptionResource.subscriptionInvoices,
            queue: 'past_due',
          ),
          SubscriptionQueueSummary(
            id: 'pending_changes',
            label: 'Pending changes',
            count: 1,
            panel: SubscriptionPanel.operations,
            resource: SubscriptionResource.subscriptions,
            queue: 'pending_changes',
          ),
        ],
        panelSummaries: const <SubscriptionPanelSummary>[],
        lookups: const SubscriptionLookups(
          tenants: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'tenant-1', label: 'Acme Clinic'),
            SubscriptionLookupItem(id: 'tenant-2', label: 'Fresh Clinic'),
          ],
          plans: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'plan-1', label: 'Starter Plan'),
          ],
        ),
        items: AppPage<SubscriptionItem>(
          items: const <SubscriptionItem>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
        overview: const SubscriptionsOverview(
          activePlanTenants: SubscriptionTenantCohortSummary(
            cohort: SubscriptionTenantCohort.active,
            count: 1,
            accounts: <SubscriptionTenantAccount>[_activeAccount],
          ),
          notSubscribedTenants: SubscriptionTenantCohortSummary(
            cohort: SubscriptionTenantCohort.notSubscribed,
            count: 1,
            accounts: <SubscriptionTenantAccount>[_unsubscribedAccount],
          ),
          closedSubscriptionTenants: SubscriptionTenantCohortSummary(
            cohort: SubscriptionTenantCohort.closed,
            count: 0,
          ),
          usageSummary: SubscriptionUsageSummary(
            usersUsed: 3,
            facilitiesUsed: 1,
            storageUsedMb: 128,
            modulesUsed: 2,
          ),
          currentSubscription: SubscriptionItem(
            id: 'sub-1',
            resource: SubscriptionResource.subscriptions,
            maxUsers: 10,
            maxFacilities: 2,
            maxStorageMb: 1024,
            maxModules: 5,
          ),
          recommendations: <SubscriptionRecommendation>[
            SubscriptionRecommendation(
              id: 'rec-1',
              title: 'Upgrade storage',
              description: 'Approaching storage limit',
            ),
          ],
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
      SubscriptionPlanDetail(
        plan: SubscriptionItem(
          id: 'plan-1',
          resource: SubscriptionResource.subscriptionPlans,
        ),
      ),
    ),
  );
}

Future<void> _pumpOverviewTab(
  WidgetTester tester, {
  required _MockSubscriptionsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/subscriptions?panel=overview',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository);

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
      const SubscriptionDraft(tenantId: 't', planId: 'p', status: 'ACTIVE'),
    );
  });

  setUp(() {
    repository = _MockSubscriptionsRepository();
  });

  group('subscriptions_access helpers (Overview matrix)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        SubscriptionsOverviewAtomPermissions.tab,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsOverviewAtomPermissions.kpi,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsOverviewAtomPermissions.create,
        same(subscriptionsWorkspaceCreateRequirement),
      );
      expect(
        SubscriptionsOverviewAtomPermissions.update,
        same(subscriptionsWorkspaceUpdateRequirement),
      );
      expect(
        SubscriptionsOverviewAtomPermissions.delete,
        same(subscriptionsWorkspaceDeleteRequirement),
      );
      expect(
        SubscriptionsOverviewAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.subscriptionsEntry),
      );
      expect(
        SubscriptionsOverviewAtomPermissions.routeEntry,
        same(subscriptionsWorkspaceRouteEntryRequirement),
      );
      expect(
        subscriptionsPanelTabRequirement(SubscriptionPanel.overview),
        same(SubscriptionsOverviewAtomPermissions.tab),
      );
    });

    test('∩ denial: missing subscriptions:read blocks overview tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsWrite},
      );
      expect(
        SubscriptionsOverviewAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        canViewSubscriptionsPanel(writeOnly, SubscriptionPanel.overview),
        isFalse,
      );
    });

    test('∩ presence: subscriptions:read + module allows read atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );
      expect(SubscriptionsOverviewAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(SubscriptionsOverviewAtomPermissions.kpi.isAllowed(reader), isTrue);
      expect(
        SubscriptionsOverviewAtomPermissions.usageLimits.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsOverviewAtomPermissions.recommendations.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsOverviewAtomPermissions.cohortDialog.isAllowed(reader),
        isTrue,
      );
      expect(
        SubscriptionsOverviewAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        SubscriptionsOverviewAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
    });

    test('∩ write requires subscriptions:write for cohort mutations', () {
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
        SubscriptionsOverviewAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        SubscriptionsOverviewAtomPermissions.update.isAllowed(writer),
        isTrue,
      );
      expect(
        SubscriptionsOverviewAtomPermissions.nestedWrite.isAllowed(writer),
        isTrue,
      );
    });

    test('∩ delete requires subscriptions:delete (not mounted on Overview)', () {
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
        SubscriptionsOverviewAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );
      expect(
        SubscriptionsOverviewAtomPermissions.delete.isAllowed(deleter),
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
        SubscriptionsOverviewAtomPermissions.routeEntry.isAllowed(systemOnly),
        isTrue,
      );
      expect(canEnterSubscriptionsWorkspace(systemOnly), isTrue);
    });

    test('nested cross-module _(n/a)_ reuses workspace read/write ∩', () {
      expect(
        SubscriptionsOverviewAtomPermissions.nestedRead,
        same(subscriptionsWorkspaceReadRequirement),
      );
      expect(
        SubscriptionsOverviewAtomPermissions.nestedWrite,
        same(subscriptionsWorkspaceWriteRequirement),
      );
    });

    test('subscription strip: role pack without module omits overview', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        SubscriptionsOverviewAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(subscriptionsAllowedPanels(noModule), isEmpty);
    });
  });

  group('Overview tab widget gates', () {
    testWidgets(
      '∩ denial: read-only shows KPIs; hides cohort New/Edit and create primary',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpOverviewTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tabLabel('Overview'), findsWidgets);
        expect(find.text('Active plans'), findsOneWidget);
        expect(find.text('Not subscribed'), findsOneWidget);
        expect(find.text('Closed subscriptions'), findsOneWidget);
        expect(find.text('Users'), findsOneWidget);
        expect(find.text('Recommendations'), findsOneWidget);
        expect(find.text('Upgrade storage'), findsOneWidget);
        expect(_toolbarPrimary('New subscription'), findsNothing);
        expect(_toolbarPrimary('Create plan'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Active plans'));
        await tester.pumpAndSettle();

        expect(find.text('Acme Clinic'), findsWidgets);
        expect(find.text('Edit subscription'), findsNothing);
        expect(find.text('New subscription'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Close').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Not subscribed'));
        await tester.pumpAndSettle();
        expect(find.text('Fresh Clinic'), findsWidgets);
        expect(find.text('New subscription'), findsNothing);
      },
    );

    testWidgets(
      '∩ presence: write mounts cohort Edit/New; create primary still absent',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpOverviewTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(find.byType(AppTabToolbarPrimary), findsNothing);
        expect(find.text('Active plans'), findsOneWidget);

        await tester.tap(find.text('Active plans'));
        await tester.pumpAndSettle();
        expect(find.text('Edit subscription'), findsOneWidget);

        await tester.tap(find.text('Close').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Not subscribed'));
        await tester.pumpAndSettle();
        expect(find.text('New subscription'), findsOneWidget);
      },
    );

    testWidgets(
      '∪ allowance: system:admin route entry; scoped session still needs '
      'subscriptions:* for overview atoms',
      (WidgetTester tester) async {
        final AppAccessPolicy scopedSystem = _policy(
          permissions: <AppPermission>{AppPermissions.systemAdmin},
          roles: const <String>['SUPER_ADMIN'],
          tenantId: 'tenant-1',
        );
        expect(
          SubscriptionsOverviewAtomPermissions.routeEntry
              .isAllowed(scopedSystem),
          isTrue,
        );
        expect(
          SubscriptionsOverviewAtomPermissions.tab.isAllowed(scopedSystem),
          isFalse,
        );

        await _pumpOverviewTab(
          tester,
          repository: repository,
          accessPolicy: scopedSystem,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Active plans'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'subscription/ABAC strip: module missing omits overview chrome',
      (WidgetTester tester) async {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
          modules: const <AppModuleEntitlement>[],
        );

        await _pumpOverviewTab(
          tester,
          repository: repository,
          accessPolicy: noModule,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Active plans'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module UI absent without nested rights (n/a → none)',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        );

        await _pumpOverviewTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        await tester.tap(find.text('Active plans'));
        await tester.pumpAndSettle();

        expect(find.text('Receive payment'), findsNothing);
        expect(find.text('Submit claim'), findsNothing);
        expect(find.text('Open operations'), findsNothing);
        expect(find.text('Manage modules'), findsNothing);
      },
    );

    testWidgets(
      'authorized cohort Edit syncs workspace after mutation',
      (WidgetTester tester) async {
        when(
          () => repository.updateSubscription(any(), any()),
        ).thenAnswer((_) async => const Result<void>.success(null));

        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.subscriptionsRead,
            AppPermissions.subscriptionsWrite,
          },
        );

        await _pumpOverviewTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        await tester.tap(find.text('Active plans'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit subscription'));
        await tester.pumpAndSettle();

        expect(find.text('Save subscription'), findsOneWidget);
        await tester.tap(find.text('Save subscription'));
        await tester.pumpAndSettle();

        verify(() => repository.updateSubscription('sub-1', any())).called(1);
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
      },
    );

    testWidgets('authorized empty cohort remains observable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );

      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      await tester.tap(find.text('Closed subscriptions'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No accounts'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('authorized loading/error chrome remains on overview path', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      );

      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Active plans'), findsOneWidget);
      expect(
        find.widgetWithText(FilterChip, 'Past due invoices (2)'),
        findsOneWidget,
      );
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('mobile viewport: overview KPIs and cohort remain usable', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );

      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Active plans'), findsWidgets);
      await tester.tap(find.text('Active plans').first);
      await tester.pumpAndSettle();
      expect(find.text('Edit subscription'), findsOneWidget);
    });

    testWidgets('desktop viewport: overview KPIs and usage mount', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.subscriptionsRead,
          AppPermissions.subscriptionsWrite,
        },
      );

      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(1440, 900),
      );

      expect(find.text('Active plans'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.byType(AppListTable<SubscriptionItem>), findsNothing);
    });

    testWidgets('light theme: authorized overview chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.subscriptionsRead},
        ),
        themeMode: ThemeMode.light,
      );

      expect(_tabLabel('Overview'), findsWidgets);
      expect(find.text('Active plans'), findsOneWidget);
    });

    testWidgets('dark theme: authorized overview chrome mounts', (
      WidgetTester tester,
    ) async {
      await _pumpOverviewTab(
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

      expect(_tabLabel('Overview'), findsWidgets);
      await tester.tap(find.text('Not subscribed'));
      await tester.pumpAndSettle();
      expect(find.text('New subscription'), findsOneWidget);
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
          SubscriptionsOverviewAtomPermissions.catalogEntry,
          same(RouteAccessCatalog.subscriptionsEntry),
        );

        await _pumpOverviewTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.subscriptionsRead},
          ),
        );

        expect(_tabLabel('Overview'), findsWidgets);
      },
    );
  });
}
