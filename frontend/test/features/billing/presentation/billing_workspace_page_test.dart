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

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabToolbarPrimary),
  matching: find.text(label),
);

Finder _toolbarAction(String label) => find.descendant(
  of: find.byType(AppTabToolbarAction),
  matching: find.text(label),
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
      user: const AuthUserProfile(roles: <String>['BILLING']),
      permissions: <AppPermission>{
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
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
        appAccessPolicyProvider.overrideWithValue(_billingWritePolicy()),
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
    expect(find.textContaining('All billing work items'), findsWidgets);
    expect(find.textContaining('Needs issue'), findsWidgets);
    expect(find.textContaining('Awaiting payment'), findsWidgets);
    expect(find.textContaining('Claims pending'), findsWidgets);
    expect(find.textContaining('Approval required'), findsWidgets);
    expect(find.textContaining('Overdue'), findsWidgets);
    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.text('Ben Payment'), findsOneWidget);
    expect(_toolbarPrimary('Close shift'), findsOneWidget);
    expect(_toolbarAction('Close day'), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsOneWidget);
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
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

    await tester.tap(find.textContaining('Awaiting payment').first);
    await tester.pumpAndSettle();

    expect(
      harness.router.state.uri.queryParameters['queue'],
      'pending-payment',
    );
    expect(find.text('Ben Payment'), findsOneWidget);
    expect(find.text('Ada Draft'), findsNothing);
    expect(_toolbarPrimary('Close shift'), findsOneWidget);
    expect(_toolbarAction('Close day'), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsOneWidget);

    await tester.tap(find.textContaining('Needs issue').first);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['queue'], 'needs-issue');
    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.text('Ben Payment'), findsNothing);
    expect(_toolbarPrimary('Refresh'), findsOneWidget);
    expect(_toolbarAction('Close shift'), findsOneWidget);
    expect(_toolbarAction('Close day'), findsOneWidget);
    expect(_toolbarPrimary('Close shift'), findsNothing);
  });

  testWidgets('toolbar primary changes across All, Needs issue, and Overdue', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    expect(_toolbarPrimary('Close shift'), findsOneWidget);
    expect(_toolbarAction('Close day'), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsOneWidget);

    await tester.tap(find.textContaining('Needs issue').first);
    await tester.pumpAndSettle();

    expect(_toolbarPrimary('Refresh'), findsOneWidget);
    expect(_toolbarAction('Close shift'), findsOneWidget);
    expect(_toolbarAction('Close day'), findsOneWidget);

    await tester.tap(find.textContaining('Overdue').first);
    await tester.pumpAndSettle();

    expect(_toolbarPrimary('Close day'), findsOneWidget);
    expect(_toolbarAction('Close shift'), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsOneWidget);
    expect(_toolbarPrimary('Close shift'), findsNothing);
    expect(_toolbarPrimary('Refresh'), findsNothing);
  });

  testWidgets('deep link queue=pending-payment selects Awaiting Payment tab', (
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
      harness.router.state.uri.queryParameters['queue'],
      'pending-payment',
    );
    expect(find.text('Ben Payment'), findsOneWidget);
    expect(find.text('Ada Draft'), findsNothing);
    expect(find.text('Cara Claim'), findsNothing);
    expect(_toolbarPrimary('Close shift'), findsOneWidget);
    expect(_toolbarAction('Close day'), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsOneWidget);
  });

  testWidgets('deep link queue=needs-issue selects Needs Issue tab', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(
      tester,
      repository: repository,
      initialLocation: '/billing?queue=needs-issue',
      initialQuery: BillingWorkspaceQuery.fromUri(
        Uri.parse('/billing?queue=needs-issue'),
      ),
    );

    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.text('Ben Payment'), findsNothing);
    expect(_toolbarPrimary('Refresh'), findsOneWidget);
    expect(_toolbarAction('Close shift'), findsOneWidget);
    expect(_toolbarAction('Close day'), findsOneWidget);
  });

  testWidgets('All tab shows full columns while Needs Issue is draft-focused', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Patient ID'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Status'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Encounter'),
      ),
      findsNothing,
    );

    await tester.tap(find.textContaining('Needs issue').first);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Encounter'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Patient ID'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Status'),
      ),
      findsNothing,
    );
  });

  testWidgets('search filters visible work items', (WidgetTester tester) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    await tester.enterText(find.byType(TextField).first, 'Ben');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Ben Payment'), findsOneWidget);
    expect(find.text('Ada Draft'), findsNothing);
  });

  testWidgets('filter dialog opens from Filters button', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    await tester.tap(find.text('Filters').first);
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsWidgets);
  });

  testWidgets('mobile breakpoint uses list tiles instead of data table', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(_toolbarPrimary('Close shift'), findsOneWidget);
  });

  testWidgets('tab switch applies queue filter via repository', (
    WidgetTester tester,
  ) async {
    await _pumpBillingWorkspace(tester, repository: repository);

    await tester.tap(find.textContaining('Claims pending').first);
    await tester.pumpAndSettle();

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
    expect(_toolbarPrimary('Refresh'), findsOneWidget);
    expect(_toolbarAction('Close shift'), findsOneWidget);
    expect(_toolbarAction('Close day'), findsOneWidget);
  });
}
