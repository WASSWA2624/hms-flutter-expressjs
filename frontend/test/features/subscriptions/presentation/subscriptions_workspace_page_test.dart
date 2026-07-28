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

AppAccessPolicy _writePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['ADMIN']),
      permissions: <AppPermission>{
        AppPermissions.subscriptionsRead,
        AppPermissions.subscriptionsWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'subscriptions', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

AppAccessPolicy _readOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['VIEWER']),
      permissions: <AppPermission>{AppPermissions.subscriptionsRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'subscriptions', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

const SubscriptionItem _activeSubscription = SubscriptionItem(
  id: 'sub-1',
  resource: SubscriptionResource.subscriptions,
  displayId: 'SUB-001',
  tenantId: 'tenant-1',
  tenantLabel: 'Acme Clinic',
  planId: 'plan-1',
  planLabel: 'Pro',
  status: 'ACTIVE',
);

const SubscriptionItem _trialSubscription = SubscriptionItem(
  id: 'sub-trial',
  resource: SubscriptionResource.subscriptions,
  displayId: 'SUB-TRIAL',
  tenantId: 'tenant-2',
  tenantLabel: 'Beta Hospital',
  planId: 'plan-1',
  planLabel: 'Pro',
  status: 'TRIAL',
);

const SubscriptionItem _planItem = SubscriptionItem(
  id: 'plan-1',
  resource: SubscriptionResource.subscriptionPlans,
  displayId: 'PLAN-PRO',
  name: 'Pro',
  code: 'PRO',
  status: 'ACTIVE',
  monthlyPrice: 99,
);

SubscriptionsWorkspaceData _workspaceFor(SubscriptionsWorkspaceQuery query) {
  final List<SubscriptionItem> items = switch (query.resource) {
    SubscriptionResource.subscriptionPlans => <SubscriptionItem>[_planItem],
    SubscriptionResource.subscriptions => <SubscriptionItem>[
      _activeSubscription,
      _trialSubscription,
    ],
    _ => const <SubscriptionItem>[],
  };

  return SubscriptionsWorkspaceData(
    query: query,
    summary: const <SubscriptionSummaryMetric>[
      SubscriptionSummaryMetric(
        id: 'pending_changes',
        label: 'Pending changes',
        value: 2,
      ),
      SubscriptionSummaryMetric(
        id: 'past_due_invoices',
        label: 'Past due invoices',
        value: 1,
      ),
    ],
    queueSummaries: const <SubscriptionQueueSummary>[
      SubscriptionQueueSummary(
        id: 'pending_changes',
        label: 'Pending changes',
        count: 2,
        panel: SubscriptionPanel.operations,
        resource: SubscriptionResource.subscriptions,
        queue: 'pending_changes',
      ),
      SubscriptionQueueSummary(
        id: 'past_due_billing',
        label: 'Past due invoices',
        count: 1,
        panel: SubscriptionPanel.billing,
        resource: SubscriptionResource.subscriptionInvoices,
        queue: 'past_due_billing',
      ),
    ],
    panelSummaries: const <SubscriptionPanelSummary>[],
    lookups: const SubscriptionLookups(
      tenants: <SubscriptionLookupItem>[
        SubscriptionLookupItem(id: 'tenant-1', label: 'Acme Clinic'),
      ],
      plans: <SubscriptionLookupItem>[
        SubscriptionLookupItem(id: 'plan-1', label: 'Pro'),
      ],
      modules: <SubscriptionLookupItem>[
        SubscriptionLookupItem(id: 'mod-1', label: 'Billing'),
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
        count: 1,
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
  );
}

void _stubRepository(_MockSubscriptionsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((invocation) async {
    final SubscriptionsWorkspaceQuery query =
        invocation.positionalArguments.single as SubscriptionsWorkspaceQuery;
    return Result<SubscriptionsWorkspaceData>.success(_workspaceFor(query));
  });
  when(
    () => repository.getReferenceData(tenantId: any(named: 'tenantId')),
  ).thenAnswer(
    (_) async => const Result<SubscriptionLookups>.success(
      SubscriptionLookups(
        tenants: <SubscriptionLookupItem>[
          SubscriptionLookupItem(id: 'tenant-1', label: 'Acme Clinic'),
        ],
        plans: <SubscriptionLookupItem>[
          SubscriptionLookupItem(id: 'plan-1', label: 'Pro'),
        ],
      ),
    ),
  );
}

Future<void> _pumpSubscriptionsWorkspace(
  WidgetTester tester, {
  required _MockSubscriptionsRepository repository,
  String initialLocation = '/subscriptions?panel=operations&resource=subscriptions',
  AppAccessPolicy? accessPolicy,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository);

  tester.view.physicalSize = const Size(1440, 900);
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
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _writePolicy(),
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

  testWidgets('omits Notifications tab and shows queue chips', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(tester, repository: repository);

    expect(find.text('Notifications'), findsNothing);
    expect(find.textContaining('Pending changes (2)'), findsOneWidget);
    expect(find.textContaining('Past due invoices (1)'), findsOneWidget);
  });

  testWidgets('New subscription is the sole create primary on Subscriptions', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(tester, repository: repository);

    expect(_toolbarPrimary('New subscription'), findsOneWidget);
    expect(find.text('Activate subscription'), findsNothing);
    expect(_toolbarPrimary('Create plan'), findsNothing);
    expect(find.text('Acme Clinic'), findsWidgets);
  });

  testWidgets('unauthorized users see no create primaries', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(
      tester,
      repository: repository,
      accessPolicy: _readOnlyPolicy(),
    );

    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(find.text('New subscription'), findsNothing);
    expect(find.text('Create plan'), findsNothing);
  });

  testWidgets('advanced filters omit Resource group', (WidgetTester tester) async {
    await _pumpSubscriptionsWorkspace(tester, repository: repository);

    final AppListTable<SubscriptionItem> table = tester
        .widget<AppListTable<SubscriptionItem>>(
          find.byType(AppListTable<SubscriptionItem>),
        );
    final List<AppSearchBarFilterGroup>? groups = table.search?.filterGroups;
    expect(groups, isNotNull);
    expect(
      groups!.any((AppSearchBarFilterGroup group) => group.label == 'Resource'),
      isFalse,
    );
  });

  testWidgets('Overview is metrics-only without worklist', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/subscriptions?panel=overview&resource=subscriptions',
    );

    expect(find.text('Active plans'), findsOneWidget);
    expect(find.text('Not subscribed'), findsOneWidget);
    expect(find.byType(AppListTable<SubscriptionItem>), findsNothing);
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
  });

  testWidgets('Plans panel shows nested resource tabs and Create plan', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(
      tester,
      repository: repository,
      initialLocation:
          '/subscriptions?panel=catalog&resource=subscription-plans',
    );

    expect(_toolbarPrimary('Create plan'), findsOneWidget);
    expect(find.text('Modules'), findsWidgets);
    expect(find.text('Pro'), findsWidgets);
  });

  testWidgets('detail cancel uses confirm without reason field', (
    WidgetTester tester,
  ) async {
    when(() => repository.cancelSubscription(any())).thenAnswer(
      (_) async => const Result<void>.success(null),
    );

    await _pumpSubscriptionsWorkspace(tester, repository: repository);

    await tester.tap(find.text('Acme Clinic').first);
    await tester.pumpAndSettle();

    expect(find.text('Cancel subscription'), findsOneWidget);
    expect(find.text('Print invoice'), findsNothing);

    await tester.tap(find.text('Cancel subscription'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel this subscription?'), findsNothing);
    expect(
      find.textContaining('Cancel this subscription?'),
      findsOneWidget,
    );
    expect(find.text('Reason'), findsNothing);
  });

  testWidgets('detail Activate remains distinct from New subscription', (
    WidgetTester tester,
  ) async {
    await _pumpSubscriptionsWorkspace(tester, repository: repository);

    await tester.tap(find.text('Beta Hospital').first);
    await tester.pumpAndSettle();

    expect(find.text('Activate'), findsOneWidget);
    expect(find.text('Activate subscription'), findsNothing);
    expect(find.text('New subscription'), findsNothing);
  });
}
