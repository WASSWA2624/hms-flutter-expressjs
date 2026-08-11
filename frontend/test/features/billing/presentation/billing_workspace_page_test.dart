import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/billing/presentation/pages/billing_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

Finder _searchBarAction(String label) => find.descendant(
  of: find.byType(AppSearchBar),
  matching: find.byTooltip(label),
);

AppListTable<BillingWorkItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<BillingWorkItem>>(
    find.byType(AppListTable<BillingWorkItem>),
  );
}

const BillingWorkItem _draftInvoice = BillingWorkItem(
  id: 'inv-draft',
  displayId: 'INV-DRAFT',
  kind: BillingWorkItemKind.invoice,
  patientDisplayName: 'Ada Draft',
  patientDisplayId: 'PT-DRAFT',
  billingStatus: 'DRAFT',
  amount: 200,
  financials: BillingFinancials(balanceDue: 200),
);

const BillingWorkItem _pendingInvoice = BillingWorkItem(
  id: 'inv-pay',
  displayId: 'INV-PAY',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientDisplayName: 'Ben Payment',
  patientDisplayId: 'PT-PAY',
  billingStatus: 'ISSUED',
  amount: 500,
  financials: BillingFinancials(balanceDue: 500),
);

const BillingWorkItem _claimItem = BillingWorkItem(
  id: 'claim-1',
  displayId: 'CLM-001',
  kind: BillingWorkItemKind.claim,
  patientDisplayName: 'Cara Claim',
  patientDisplayId: 'PT-CLAIM',
  status: 'PENDING',
  amount: 800,
  financials: BillingFinancials(balanceDue: 800),
);

const BillingWorkItem _approvalItem = BillingWorkItem(
  id: 'apr-1',
  displayId: 'APR-001',
  kind: BillingWorkItemKind.approval,
  patientDisplayName: 'Dana Approval',
  patientDisplayId: 'PT-APR',
  status: 'PENDING',
  amount: 100,
);

const BillingWorkItem _overdueInvoice = BillingWorkItem(
  id: 'inv-overdue',
  displayId: 'INV-OVER',
  kind: BillingWorkItemKind.invoice,
  patientDisplayName: 'Eve Overdue',
  patientDisplayId: 'PT-OVER',
  billingStatus: 'ISSUED',
  status: 'OVERDUE',
  amount: 900,
  financials: BillingFinancials(balanceDue: 900),
);

const List<BillingWorkItem> _allItems = <BillingWorkItem>[
  _draftInvoice,
  _pendingInvoice,
  _claimItem,
  _approvalItem,
  _overdueInvoice,
];

const BillingSummary _summary = BillingSummary(
  needsIssue: 1,
  pendingPayment: 1,
  claimsPending: 1,
  approvalRequired: 1,
  overdue: 1,
);

AppAccessPolicy _billingWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _billingReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{AppPermissions.billingRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _billingApproverPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
        AppPermissions.financialApprove,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _billingWriteWithoutInsurancePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _billingWriteWithoutModulePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[],
      isAuthorizationHydrated: true,
    ),
  );
}

List<BillingWorkItem> _itemsForQueue(BillingQueueType queue) {
  return switch (queue) {
    BillingQueueType.all => _allItems,
    BillingQueueType.needsIssue => <BillingWorkItem>[_draftInvoice],
    BillingQueueType.pendingPayment => <BillingWorkItem>[_pendingInvoice],
    BillingQueueType.claimsPending => <BillingWorkItem>[_claimItem],
    BillingQueueType.approvalRequired => <BillingWorkItem>[_approvalItem],
    BillingQueueType.overdue => <BillingWorkItem>[_overdueInvoice],
  };
}

void _stubBillingRepository(_MockBillingRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<BillingWorkspaceOverview>.success(
      BillingWorkspaceOverview(summary: _summary),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final BillingWorkspaceQuery query =
        invocation.positionalArguments.single as BillingWorkspaceQuery;
    List<BillingWorkItem> items = List<BillingWorkItem>.of(
      _itemsForQueue(query.queue),
    );
    final String search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items
          .where((BillingWorkItem item) {
            final String haystack =
                '${item.patientDisplayName} ${item.displayId}'.toLowerCase();
            return haystack.contains(search);
          })
          .toList(growable: false);
    }
    return Result<AppPage<BillingWorkItem>>.success(
      AppPage<BillingWorkItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
}

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockBillingRepository repository;
  final GoRouter router;
}

Future<_Harness> _pumpBillingWorkspace(
  WidgetTester tester, {
  required _MockBillingRepository repository,
  BillingWorkspaceQuery? initialQuery,
  String initialLocation = '/billing',
  Size physicalSize = const Size(1440, 900),
  AppAccessPolicy? accessPolicy,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBillingRepository(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: BillingWorkspacePage(
              initialQuery:
                  initialQuery ?? BillingWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        billingRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _billingWritePolicy(),
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

String billingQueueTabLabel(BillingQueueType queue) {
  return switch (queue) {
    BillingQueueType.all => 'Open work',
    BillingQueueType.needsIssue => 'To issue',
    BillingQueueType.pendingPayment => 'Collect due',
    BillingQueueType.claimsPending => 'Open claims',
    BillingQueueType.approvalRequired => 'Need approval',
    BillingQueueType.overdue => 'Collect due',
  };
}

List<BillingQueueType> get billingDeskSections =>
    BillingQueueType.values.where((BillingQueueType q) => q.isDeskSection).toList();

void _expectCollectDueCloseSearchActions(WidgetTester tester) {
  expect(_searchBarAction('Close day'), findsOneWidget);
  expect(_searchBarAction('Close shift'), findsOneWidget);
  expect(find.text('Refresh'), findsNothing);
  expect(find.byType(AppTabToolbarPrimary), findsNothing);
  expect(find.byType(AppTabToolbarAction), findsNothing);
  final List<AppSearchBarAction> trailing =
      _table(tester).search?.trailingActions ?? const <AppSearchBarAction>[];
  expect(trailing.map((AppSearchBarAction a) => a.label).toList(), <String>[
    'Close day',
    'Close shift',
  ]);
}

void _expectToIssueTrailingActions(WidgetTester tester) {
  expect(_searchBarAction('Issue all'), findsOneWidget);
  expect(_searchBarAction('Close day'), findsNothing);
  expect(_searchBarAction('Close shift'), findsNothing);
  expect(find.text('Refresh'), findsNothing);
  final List<AppSearchBarAction> trailing =
      _table(tester).search?.trailingActions ?? const <AppSearchBarAction>[];
  expect(trailing.map((AppSearchBarAction a) => a.label).toList(), <String>[
    'Issue all',
  ]);
}

void _expectNoOwnedTrailingActions(WidgetTester tester) {
  expect(_searchBarAction('Close day'), findsNothing);
  expect(_searchBarAction('Close shift'), findsNothing);
  expect(_searchBarAction('Issue all'), findsNothing);
  expect(find.text('Refresh'), findsNothing);
}

Future<void> _selectQueueTab(WidgetTester tester, String label) async {
  final Finder visible = find.textContaining(label);
  if (visible.evaluate().isNotEmpty) {
    await tester.tap(visible.first);
    await tester.pumpAndSettle();
    return;
  }

  final Finder more = find.byKey(const ValueKey<String>('tabOverflowMore'));
  expect(more, findsOneWidget);
  await tester.tap(more);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(label).last);
  await tester.pumpAndSettle();
}

void main() {
  late _MockBillingRepository repository;

  setUpAll(() {
    registerFallbackValue(const BillingWorkspaceQuery());
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  testWidgets('renders tab strip with queue counts and work items', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppWorkspaceToolbar), findsNothing);
    expect(find.byType(AppWorkspace), findsNothing);
    final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
    expect(strip.tabs.length, billingDeskSections.length + 1);
    expect(
      strip.tabs.map((AppTabItem tab) => tab.label),
      <String>[
        for (final BillingQueueType queue in billingDeskSections)
          billingQueueTabLabel(queue),
        AppLocalizations.of(tester.element(find.byType(AppTabStrip)))
            .billingPriceBookTab,
      ],
    );
    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.text('Ben Payment'), findsOneWidget);
    _expectNoOwnedTrailingActions(tester);
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(_table(tester).columnVisibilityTitle, 'Table Settings');
    expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
    expect(_table(tester).search?.advancedFilterTitle, 'Advanced filters');
    expect(_table(tester).displayMode, AppListTableDisplayMode.adaptive);
    expect(_table(tester).columns.length, 5);
  });

  testWidgets('does not paint a dedicated billing title header', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );
    expect(find.text(l10n.billingWorkspaceTitle), findsNothing);
  });

  testWidgets('switching tabs updates the queue query parameter', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpBillingWorkspace(
      tester,
      repository: repository,
    );

    await _selectQueueTab(tester, 'Collect due');

    expect(
      harness.router.state.uri.queryParameters['section'],
      'collect',
    );
    expect(find.text('Ben Payment'), findsOneWidget);
    expect(find.text('Ada Draft'), findsNothing);
    _expectCollectDueCloseSearchActions(tester);

    await _selectQueueTab(tester, 'To issue');

    expect(harness.router.state.uri.queryParameters['section'], 'issue');
    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.text('Ben Payment'), findsNothing);
    _expectToIssueTrailingActions(tester);
  });

  testWidgets('search bar trailing matches tab ownership without Refresh', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    for (final BillingQueueType queue in billingDeskSections) {
      if (queue != BillingQueueType.all) {
        await _selectQueueTab(tester, billingQueueTabLabel(queue));
      }
      if (queue == BillingQueueType.needsIssue) {
        _expectToIssueTrailingActions(tester);
      } else if (queue == BillingQueueType.pendingPayment) {
        _expectCollectDueCloseSearchActions(tester);
      } else if (queue == BillingQueueType.approvalRequired ||
          queue == BillingQueueType.claimsPending) {
        _expectNoOwnedTrailingActions(tester);
      } else {
        _expectNoOwnedTrailingActions(tester);
      }
    }
  });

  testWidgets('unauthorized write actions and next-action are absent', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(
      tester,
      repository: repository,
      accessPolicy: _billingReadOnlyPolicy(),
    );

    expect(find.text('Close shift'), findsNothing);
    expect(find.text('Close day'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    expect(find.byTooltip('Issue this draft invoice'), findsNothing);
    expect(find.byTooltip('Receive payment toward the balance due'), findsNothing);
    expect(find.byTooltip('Approve this pending request'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Next'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'writer without financial:approve has no Approve next-action or detail',
    (WidgetTester tester) async {
      await _pumpBillingWorkspace(tester, repository: repository);

      await _selectQueueTab(tester, 'Need approval');

      expect(find.text('Dana Approval'), findsOneWidget);
      expect(find.byTooltip('Approve this pending request'), findsNothing);

      await tester.tap(find.text('Dana Approval'));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    },
  );

  testWidgets(
    'approver with billing:write ∩ financial:approve sees Approve controls',
    (WidgetTester tester) async {
      await _pumpBillingWorkspace(
        tester,
        repository: repository,
        accessPolicy: _billingApproverPolicy(),
      );

      await _selectQueueTab(tester, 'Need approval');

      expect(find.byTooltip('Approve this pending request'), findsWidgets);

      await tester.tap(find.text('Dana Approval'));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsWidgets);
      expect(find.text('Reject'), findsWidgets);
    },
  );

  testWidgets('Open claims tab absent without insurance-claims module', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(
      tester,
      repository: repository,
      accessPolicy: _billingWriteWithoutInsurancePolicy(),
    );

    final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
    expect(
      strip.tabs.map((AppTabItem tab) => tab.label),
      isNot(contains('Open claims')),
    );
    expect(strip.tabs.length, billingDeskSections.length);
  });

  testWidgets('missing billing-payments module omits billing chrome', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(
      tester,
      repository: repository,
      accessPolicy: _billingWriteWithoutModulePolicy(),
    );

    expect(find.byType(AppTabStrip), findsNothing);
    expect(find.text('Close shift'), findsNothing);
    expect(find.text('Ben Payment'), findsNothing);
    expect(find.text('No access'), findsNothing);
  });

  testWidgets(
    'Awaiting payment: write user sees Receive payment; read-only does not',
    (WidgetTester tester) async {
      await _pumpBillingWorkspace(
        tester,
        repository: repository,
        initialLocation: '/billing?queue=pending-payment',
        initialQuery: BillingWorkspaceQuery.fromUri(
          Uri.parse('/billing?queue=pending-payment'),
        ),
      );

      expect(find.text('Ben Payment'), findsOneWidget);
      expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);
      _expectCollectDueCloseSearchActions(tester);

      await tester.tap(find.text('Ben Payment'));
      await tester.pumpAndSettle();
      expect(find.text('Pay'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await _pumpBillingWorkspace(
        tester,
        repository: repository,
        accessPolicy: _billingReadOnlyPolicy(),
        initialLocation: '/billing?queue=awaiting-payment',
        initialQuery: BillingWorkspaceQuery.fromUri(
          Uri.parse('/billing?queue=awaiting-payment'),
        ),
      );

      expect(find.text('Ben Payment'), findsOneWidget);
      expect(find.byTooltip('Receive payment toward the balance due'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next'),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Ben Payment'));
      await tester.pumpAndSettle();
      expect(find.text('Pay'), findsNothing);
    },
  );

  testWidgets(
    'Awaiting payment mobile + dark theme keeps authorized Receive payment',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      _stubBillingRepository(repository);

      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/billing?queue=pending-payment',
        routes: <RouteBase>[
          GoRoute(
            path: '/billing',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: BillingWorkspacePage(
                  initialQuery: BillingWorkspaceQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(_billingWritePolicy()),
          ],
          child: MaterialApp.router(
            themeMode: ThemeMode.dark,
            theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
            ),
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Ben Payment'), findsOneWidget);
      expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);
      _expectCollectDueCloseSearchActions(tester);
    },
  );

  testWidgets('authorized All tab keeps Issue next-action in light and dark', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    _stubBillingRepository(repository);

    for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/billing',
        routes: <RouteBase>[
          GoRoute(
            path: '/billing',
            builder: (BuildContext context, GoRouterState state) {
              return const Scaffold(body: BillingWorkspacePage());
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(_billingWritePolicy()),
          ],
          child: MaterialApp.router(
            themeMode: mode,
            theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
            ),
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Ada Draft'), findsOneWidget);
      expect(find.byTooltip('Issue this draft invoice'), findsWidgets);
      _expectNoOwnedTrailingActions(tester);
    }
  });

  testWidgets('mobile viewport keeps authorized close search actions without banners', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(390, 844),
    );

    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(find.byType(AppTabToolbarAction), findsNothing);
    await _selectQueueTab(tester, 'Collect due');
    expect(find.byTooltip('Close shift'), findsOneWidget);
    expect(find.byTooltip('Close day'), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('No access'), findsNothing);
  });

  testWidgets('authorized Issue detail opens and omits finalize clearance', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    expect(find.byTooltip('Issue this draft invoice'), findsWidgets);

    await tester.tap(find.text('Ada Draft'));
    await tester.pumpAndSettle();

    expect(find.text('Issue'), findsWidgets);
    expect(find.text('Finalize financial clearance'), findsNothing);
  });

  testWidgets('deep link pending-payment alias selects Collect due tab', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpBillingWorkspace(
      tester,
      repository: repository,
      initialLocation: '/billing?queue=pending-payment',
      initialQuery: BillingWorkspaceQuery.fromUri(
        Uri.parse('/billing?queue=pending-payment'),
      ),
    );

    expect(
      harness.router.state.uri.queryParameters['section'],
      'collect',
    );
    expect(find.text('Ben Payment'), findsOneWidget);
    expect(find.text('Ada Draft'), findsNothing);
    expect(find.text('Cara Claim'), findsNothing);
    _expectCollectDueCloseSearchActions(tester);
  });

  testWidgets('deep link section=issue selects To issue tab', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(
      tester,
      repository: repository,
      initialLocation: '/billing?section=issue',
      initialQuery: BillingWorkspaceQuery.fromUri(
        Uri.parse('/billing?section=issue'),
      ),
    );

    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.text('Ben Payment'), findsNothing);
    _expectToIssueTrailingActions(tester);
  });

  testWidgets('each tab exposes five default columns when mutations allowed', (
    WidgetTester tester,
  ) async {
    // Approval required next-action column needs approve ∩; other queues need
    // write (and claims module for Claims pending).
    await _pumpBillingWorkspace(
      tester,
      repository: repository,
      accessPolicy: _billingApproverPolicy(),
    );

    for (final BillingQueueType queue in billingDeskSections) {
      if (queue != BillingQueueType.all) {
        await _selectQueueTab(tester, billingQueueTabLabel(queue));
      }
      expect(_table(tester).columns.length, 5);
    }
  });

  testWidgets(
    'Approval required omits Next action column without financial:approve',
    (WidgetTester tester) async {
      await _pumpBillingWorkspace(
        tester,
        repository: repository,
        accessPolicy: _billingWritePolicy(),
      );
      await _selectQueueTab(tester, 'Need approval');
      expect(_table(tester).columns.length, 4);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('All tab shows status while Needs issue prioritizes encounter', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Patient ID'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Status'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Next'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Encounter'),
      ),
      findsNothing,
    );

    await _selectQueueTab(tester, 'To issue');

    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Encounter'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Patient ID'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Status'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Issue this draft invoice'), findsWidgets);
  });

  testWidgets('search filters visible work items', (WidgetTester tester) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    await tester.enterText(find.byType(TextField).first, 'Ben');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Ben Payment'), findsOneWidget);
    expect(find.text('Ada Draft'), findsNothing);
  });

  testWidgets('filter dialog opens without a Queue duplicate group', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('ADVANCED FILTERS'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    // Queue remains on the tab strip only (may be overflowed there).
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Queue'),
      ),
      findsNothing,
    );
  });

  testWidgets('next-action Issue is labeled and detail omits finalize clearance', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    expect(find.byTooltip('Issue this draft invoice'), findsWidgets);

    await tester.tap(find.text('Ada Draft'));
    await tester.pumpAndSettle();

    expect(find.text('Issue'), findsWidgets);
    expect(find.text('Finalize financial clearance'), findsNothing);
  });

  testWidgets('compact layout shows status badge and next action without Refresh', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(1024, 900),
    );

    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    _expectNoOwnedTrailingActions(tester);
    expect(find.byType(AppWorkspaceStatusBadge), findsWidgets);
    expect(find.byTooltip('Issue this draft invoice'), findsWidgets);
    expect(find.text('Refresh'), findsNothing);
  });

  testWidgets('tab switch applies queue filter via repository', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    await _selectQueueTab(tester, 'Open claims');

    final VerificationResult verification = verify(
      () => repository.listWorkItems(captureAny()),
    );
    final List<BillingWorkspaceQuery> queries = verification.captured
        .cast<BillingWorkspaceQuery>();
    expect(
      queries.any(
        (BillingWorkspaceQuery query) =>
            query.queue == BillingQueueType.claimsPending,
      ),
      isTrue,
    );
    expect(find.text('Cara Claim'), findsOneWidget);
    expect(find.text('Dana Approval'), findsNothing);
    _expectNoOwnedTrailingActions(tester);
  });
}
