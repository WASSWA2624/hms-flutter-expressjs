import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/subscriptions/data/repositories/subscriptions_repository_impl.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/domain/repositories/subscriptions_repository.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSubscriptionsRepository extends Mock
    implements SubscriptionsRepository {}

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabToolbarPrimary),
  matching: find.text(label),
);

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
);

const SubscriptionItem _subscriptionItem = SubscriptionItem(
  id: 'sub-1',
  resource: SubscriptionResource.subscriptions,
  displayId: 'SUB-1',
  tenantId: 'tenant-1',
  tenantLabel: 'Acme Clinic',
  planId: 'plan-1',
  planLabel: 'Starter Plan',
  status: 'ACTIVE',
);

const SubscriptionItem _invoiceItem = SubscriptionItem(
  id: 'inv-1',
  resource: SubscriptionResource.subscriptionInvoices,
  displayId: 'SINV-1',
  invoiceId: 'inv-1',
  invoiceDisplayId: 'SINV-1',
  tenantLabel: 'Acme Clinic',
  status: 'PAST_DUE',
  totalAmount: 49,
);

AppAccessPolicy _subscriptionsWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['SUPER_ADMIN']),
      permissions: <AppPermission>{
        AppPermissions.subscriptionsRead,
        AppPermissions.subscriptionsWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'subscription-controls',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

AppAccessPolicy _subscriptionsReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['SUPER_ADMIN']),
      permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'subscription-controls',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

List<SubscriptionItem> _itemsForResource(SubscriptionResource resource) {
  return switch (resource) {
    SubscriptionResource.subscriptionPlans => <SubscriptionItem>[_planItem],
    SubscriptionResource.subscriptions => <SubscriptionItem>[
      _subscriptionItem,
    ],
    SubscriptionResource.subscriptionInvoices => <SubscriptionItem>[
      _invoiceItem,
    ],
    _ => const <SubscriptionItem>[],
  };
}

void _stubWorkspace(_MockSubscriptionsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final SubscriptionsWorkspaceQuery query =
        invocation.positionalArguments.single as SubscriptionsWorkspaceQuery;
    final List<SubscriptionItem> items = _itemsForResource(query.resource);
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
          ],
          plans: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'plan-1', label: 'Starter Plan'),
          ],
          modules: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'mod-1', label: 'OPD'),
          ],
          tiers: <SubscriptionLookupItem>[
            SubscriptionLookupItem(id: 'BASIC', label: 'Basic'),
          ],
        ),
        items: AppPage<SubscriptionItem>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
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
      SubscriptionPlanDetail(
        plan: _planItem,
        stats: SubscriptionPlanStats(),
      ),
    ),
  );
}

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockSubscriptionsRepository repository;
  final GoRouter router;
}

Future<_Harness> _pumpSubscriptionsWorkspace(
  WidgetTester tester, {
  required _MockSubscriptionsRepository repository,
  SubscriptionsWorkspaceQuery? initialQuery,
  String initialLocation = '/subscriptions?panel=catalog',
  Size physicalSize = const Size(1440, 900),
  AppAccessPolicy? accessPolicy,
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
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: SubscriptionsWorkspacePage(
              initialQuery:
                  initialQuery ??
                  SubscriptionsWorkspaceQuery.fromUri(state.uri),
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
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _subscriptionsWritePolicy(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  return _Harness(repository: repository, router: router);
}

Future<void> _selectPanelTab(WidgetTester tester, String label) async {
  final Finder visible = find.text(label);
  if (visible.evaluate().isNotEmpty) {
    await tester.tap(visible.first);
    await tester.pumpAndSettle();
    return;
  }

  final Finder more = find.byKey(const ValueKey<String>('tabOverflowMore'));
  expect(more, findsOneWidget);
  await tester.tap(more);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  late _MockSubscriptionsRepository repository;

  setUpAll(() {
    registerFallbackValue(const SubscriptionsWorkspaceQuery());
  });

  setUp(() {
    repository = _MockSubscriptionsRepository();
  });

  testWidgets('panel tabs omit Notifications and show queue chips instead', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(tester, repository: repository);

    final List<AppTabStrip> strips = tester
        .widgetList<AppTabStrip>(find.byType(AppTabStrip))
        .toList(growable: false);
    expect(strips, isNotEmpty);
    final AppTabStrip panelStrip = strips.first;
    expect(
      panelStrip.tabs.map((AppTabItem tab) => tab.label),
      <String>[
        'Overview',
        'Plans',
        'Subscriptions',
        'Invoices',
        'Licenses',
      ],
    );
    expect(find.text('Notifications'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Past due invoices (2)'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Pending changes (1)'), findsOneWidget);
    expect(find.text('Starter Plan'), findsOneWidget);
    expect(_toolbarPrimary('Create plan'), findsOneWidget);
  });

  testWidgets('overview shows cohort metrics without worklist or past-due card', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/subscriptions?panel=overview',
      initialQuery: const SubscriptionsWorkspaceQuery(
        panel: SubscriptionPanel.overview,
        resource: SubscriptionResource.subscriptions,
      ),
    );

    expect(find.text('Active plans'), findsOneWidget);
    expect(find.text('Not subscribed'), findsOneWidget);
    expect(find.text('Closed subscriptions'), findsOneWidget);
    expect(find.text('Past due'), findsNothing);
    expect(find.byType(AppListTable<SubscriptionItem>), findsNothing);
    expect(_toolbarPrimary('Activate subscription'), findsNothing);
    expect(_toolbarPrimary('Create plan'), findsNothing);
  });

  testWidgets('catalog exposes Plans/Modules nested tabs; filters omit Resource', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(tester, repository: repository);

    final List<AppTabStrip> strips = tester
        .widgetList<AppTabStrip>(find.byType(AppTabStrip))
        .toList(growable: false);
    expect(strips.length, greaterThanOrEqualTo(2));
    final AppTabStrip resourceStrip = strips[1];
    expect(resourceStrip.variant, AppTabStripVariant.nested);
    expect(
      resourceStrip.tabs.map((AppTabItem tab) => tab.label),
      <String>['Plans', 'Modules'],
    );

    final AppListTable<SubscriptionItem> table = tester
        .widget<AppListTable<SubscriptionItem>>(
          find.byType(AppListTable<SubscriptionItem>),
        );
    expect(table.search?.showAdvancedFilterButton, isTrue);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Resource'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Close').first);
    await tester.pumpAndSettle();
  });

  testWidgets('operations owns Activate subscription as the sole create entry', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(tester, repository: repository);

    await _selectPanelTab(tester, 'Subscriptions');
    expect(_toolbarPrimary('Activate subscription'), findsOneWidget);
    expect(find.text('Acme Clinic'), findsOneWidget);

    final List<AppTabStrip> strips = tester
        .widgetList<AppTabStrip>(find.byType(AppTabStrip))
        .toList(growable: false);
    expect(strips.length, greaterThanOrEqualTo(2));
    expect(
      strips[1].tabs.map((AppTabItem tab) => tab.label),
      <String>['Subscriptions', 'Module subscriptions'],
    );
  });

  testWidgets('unauthorized users see no create or manage actions', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(
      tester,
      repository: repository,
      accessPolicy: _subscriptionsReadOnlyPolicy(),
    );

    expect(_toolbarPrimary('Create plan'), findsNothing);
    expect(find.text('Manage modules'), findsNothing);

    await tester.tap(find.text('Starter Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Edit plan'), findsNothing);
    expect(find.text('Manage modules'), findsNothing);
    expect(find.text('Print invoice'), findsNothing);
  });

  testWidgets('invoice detail omits Print invoice shell action', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/subscriptions?panel=billing&resource=subscription-invoices',
      initialQuery: const SubscriptionsWorkspaceQuery(
        panel: SubscriptionPanel.billing,
        resource: SubscriptionResource.subscriptionInvoices,
      ),
    );

    expect(find.text('SINV-1'), findsOneWidget);
    await tester.tap(find.text('SINV-1'));
    await tester.pumpAndSettle();
    expect(find.text('Collect invoice'), findsOneWidget);
    expect(find.text('Retry invoice'), findsOneWidget);
    expect(find.text('Print invoice'), findsNothing);
  });

  testWidgets('edit subscription keeps Change plan as the sole plan-change path', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/subscriptions?panel=operations&resource=subscriptions',
      initialQuery: const SubscriptionsWorkspaceQuery(
        panel: SubscriptionPanel.operations,
        resource: SubscriptionResource.subscriptions,
      ),
    );

    await tester.tap(find.text('Acme Clinic'));
    await tester.pumpAndSettle();
    expect(find.text('Edit subscription'), findsOneWidget);
    expect(find.text('Change plan'), findsOneWidget);

    await tester.tap(find.text('Edit subscription'));
    await tester.pumpAndSettle();
    expect(find.text('Edit subscription'), findsWidgets);
    // Plan selector removed from edit form — Change plan owns that goal.
    expect(
      find.descendant(
        of: find.byType(Dialog).last,
        matching: find.text('Plan'),
      ),
      findsNothing,
    );
  });
}
