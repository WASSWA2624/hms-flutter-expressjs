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
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/domain/repositories/claims_repository.dart';
import 'package:hosspi_hms/features/claims/presentation/pages/claims_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClaimsRepository extends Mock implements ClaimsRepository {}

const ClaimsQueueItem _pendingAuth = ClaimsQueueItem.authorization(
  PreAuthorizationRecord(
    id: 'auth-pending',
    displayId: 'AUTH-PENDING',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    status: 'PENDING',
    patientDisplayId: 'PT-AUTH',
    approvedAmount: 100,
  ),
);

const ClaimsQueueItem _approvedAuth = ClaimsQueueItem.authorization(
  PreAuthorizationRecord(
    id: 'auth-approved',
    displayId: 'AUTH-APPROVED',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    status: 'APPROVED',
    patientDisplayId: 'PT-AUTH-2',
    approvedAmount: 250,
  ),
);

const ClaimsQueueItem _submittedClaim = ClaimsQueueItem.claim(
  InsuranceClaimRecord(
    id: 'claim-sub',
    displayId: 'CLM-SUB',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    invoiceId: 'inv-1',
    invoiceDisplayId: 'INV-001',
    status: 'SUBMITTED',
    patientDisplayId: 'PT-CLAIM',
    claimAmount: 400,
  ),
);

const ClaimsQueueItem _paidClaim = ClaimsQueueItem.claim(
  InsuranceClaimRecord(
    id: 'claim-paid',
    displayId: 'CLM-PAID',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    invoiceId: 'inv-2',
    invoiceDisplayId: 'INV-002',
    status: 'PAID',
    patientDisplayId: 'PT-SETTLED',
    claimAmount: 500,
    settlementAmount: 450,
  ),
);

const List<ClaimsQueueItem> _allItems = <ClaimsQueueItem>[
  _pendingAuth,
  _approvedAuth,
  _submittedClaim,
  _paidClaim,
];

const ClaimsWorkspaceSummary _summary = ClaimsWorkspaceSummary(
  authorizationPendingCount: 1,
  authorizationApprovedCount: 1,
  submittedClaimsCount: 1,
  paidClosedCount: 1,
);

AppAccessPolicy _claimsWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['BILLING']),
      permissions: <AppPermission>{
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
        AppPermissions.financialApprove,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

List<ClaimsQueueItem> _itemsForQuery(ClaimsQueueQuery query) {
  List<ClaimsQueueItem> items = List<ClaimsQueueItem>.of(_allItems);
  final String? authStatus = preAuthorizationStatusForFilter(query.filter);
  final String? claimStatus = insuranceClaimStatusForFilter(query.filter);
  if (authStatus != null) {
    items = items
        .where(
          (ClaimsQueueItem item) =>
              item.isAuthorization && item.status.toUpperCase() == authStatus,
        )
        .toList(growable: false);
  } else if (claimStatus != null) {
    items = items
        .where(
          (ClaimsQueueItem item) =>
              item.isClaim && item.status.toUpperCase() == claimStatus,
        )
        .toList(growable: false);
  }
  final String search = query.search.trim().toLowerCase();
  if (search.isNotEmpty) {
    items = items
        .where((ClaimsQueueItem item) {
          final String haystack =
              '${item.displayId} ${item.patientDisplayId ?? ''} '
                      '${item.coveragePlanDisplayId} ${item.invoiceDisplayId ?? ''}'
                  .toLowerCase();
          return haystack.contains(search);
        })
        .toList(growable: false);
  }
  return items;
}

void _stubClaimsRepository(_MockClaimsRepository repository) {
  when(() => repository.listQueue(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final ClaimsQueueQuery query =
        invocation.positionalArguments.single as ClaimsQueueQuery;
    final List<ClaimsQueueItem> items = _itemsForQuery(query);
    return Result<AppPage<ClaimsQueueItem>>.success(
      AppPage<ClaimsQueueItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<ClaimsReferenceData>.success(ClaimsReferenceData()),
  );
  when(() => repository.loadWorkspaceSummary()).thenAnswer(
    (_) async => const Result<ClaimsWorkspaceSummary>.success(_summary),
  );
  when(() => repository.getDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final ClaimsQueueItem item =
        invocation.positionalArguments.single as ClaimsQueueItem;
    return Result<ClaimsQueueDetail>.success(
      ClaimsQueueDetail(
        item: item,
        authorization: item.authorization,
        claim: item.claim,
      ),
    );
  });
}

Future<_Harness> _pumpClaimsWorkspace(
  WidgetTester tester, {
  required _MockClaimsRepository repository,
  ClaimsWorkspaceQuery? initialQuery,
  String initialLocation = '/claims',
  Size physicalSize = const Size(1440, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubClaimsRepository(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/claims',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: ClaimsWorkspacePage(
              initialQuery:
                  initialQuery ?? ClaimsWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        claimsRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(_claimsWritePolicy()),
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

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockClaimsRepository repository;
  final GoRouter router;
}

AppListTable<ClaimsQueueItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<ClaimsQueueItem>>(
    find.byType(AppListTable<ClaimsQueueItem>),
  );
}

void main() {
  late _MockClaimsRepository repository;

  setUpAll(() {
    registerFallbackValue(const ClaimsQueueQuery());
    registerFallbackValue(
      const ClaimsQueueItem.authorization(
        PreAuthorizationRecord(
          id: 'fallback',
          displayId: 'FALLBACK',
          coveragePlanId: 'plan',
          coveragePlanDisplayId: 'PLAN',
          status: 'PENDING',
        ),
      ),
    );
  });

  setUp(() {
    repository = _MockClaimsRepository();
  });

  testWidgets('renders tab strip with section counts and authorization table', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('Authorizations'), findsWidgets);
    expect(find.textContaining('Active Claims'), findsWidgets);
    expect(find.textContaining('Settled'), findsWidgets);
    expect(find.textContaining('Insurance Setup'), findsWidgets);
    expect(find.text('AUTH-PENDING'), findsOneWidget);
    expect(find.byTooltip('Request authorization'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Patient'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Coverage'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Invoice'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Next action'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Update status'),
      ),
      findsOneWidget,
    );
    expect(_table(tester).search?.showAdvancedFilterButton, isFalse);
    expect(_table(tester).columnVisibilityTitle, 'Table Settings');
    expect(_table(tester).columns.length, 5);
  });

  testWidgets('switching tabs updates the section query parameter', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpClaimsWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.textContaining('Active Claims').first);
    await tester.pumpAndSettle();

    expect(
      harness.router.state.uri.queryParameters['section'],
      'active-claims',
    );
    expect(find.text('CLM-SUB'), findsOneWidget);
    expect(find.text('AUTH-PENDING'), findsNothing);
    expect(find.byTooltip('Prepare claim'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Invoice'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Next action'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Record response'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Amount'),
      ),
      findsNothing,
    );

    await tester.tap(find.textContaining('Settled').first);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'settled');
    expect(find.text('CLM-PAID'), findsOneWidget);
    expect(find.byTooltip('Prepare claim'), findsNothing);
    expect(find.byTooltip('Request authorization'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Settlement'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Invoice'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Next action'),
      ),
      findsNothing,
    );
  });

  testWidgets('deep link section=active-claims selects Active Claims tab', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpClaimsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/claims?section=active-claims',
      initialQuery: ClaimsWorkspaceQuery.fromUri(
        Uri.parse('/claims?section=active-claims'),
      ),
    );

    expect(
      harness.router.state.uri.queryParameters['section'],
      'active-claims',
    );
    expect(find.text('CLM-SUB'), findsOneWidget);
    expect(find.text('AUTH-PENDING'), findsNothing);
    expect(find.byTooltip('Prepare claim'), findsOneWidget);
  });

  testWidgets('default route lands on Authorizations without section param', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpClaimsWorkspace(
      tester,
      repository: repository,
    );

    expect(
      harness.router.state.uri.queryParameters.containsKey('section'),
      isFalse,
    );
    expect(find.text('AUTH-PENDING'), findsOneWidget);
    expect(find.byTooltip('Request authorization'), findsOneWidget);
  });

  testWidgets('Insurance Setup tab shows catalog actions on the panel', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpClaimsWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.textContaining('Insurance Setup').first);
    await tester.pumpAndSettle();

    expect(
      harness.router.state.uri.queryParameters['section'],
      'insurance-setup',
    );
    expect(find.byType(AppListTable<ClaimsQueueItem>), findsNothing);
    // Sole entry points live on the panel — not duplicated on the tab strip.
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.textContaining('Add company'),
      ),
      findsNothing,
    );
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.textContaining('Add company'), findsOneWidget);
    expect(find.textContaining('Add scheme'), findsOneWidget);
    expect(find.textContaining('Add offer'), findsOneWidget);
    expect(find.textContaining('Enroll patient'), findsOneWidget);
    expect(find.textContaining('Add price'), findsOneWidget);
    expect(find.textContaining('Insurer API'), findsOneWidget);
  });

  testWidgets('summary bar appears on Authorizations and applies sub-filter', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    expect(find.textContaining('Auth pending'), findsOneWidget);

    clearInteractions(repository);
    _stubClaimsRepository(repository);

    await tester.tap(find.textContaining('Auth pending').first);
    await tester.pumpAndSettle();

    final List<ClaimsQueueQuery> queries = verify(
      () => repository.listQueue(captureAny()),
    ).captured.cast<ClaimsQueueQuery>();
    expect(
      queries.any(
        (ClaimsQueueQuery query) =>
            query.filter == ClaimsQueueFilter.authorizationPending,
      ),
      isTrue,
    );
  });

  testWidgets(
    'Authorizations and Active Claims omit advanced filters and Refresh',
    (WidgetTester tester) async {
      await _pumpClaimsWorkspace(tester, repository: repository);

      expect(find.byTooltip('Refresh'), findsNothing);
      expect(find.textContaining('Filters'), findsNothing);
      expect(_table(tester).search?.showAdvancedFilterButton, isFalse);

      await tester.tap(find.textContaining('Active Claims').first);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Refresh'), findsNothing);
      expect(find.textContaining('Filters'), findsNothing);
      expect(_table(tester).search?.showAdvancedFilterButton, isFalse);
      // Redundant workload chips that duplicated Submitted / Approved are gone.
      expect(find.textContaining('Claims to submit'), findsNothing);
      expect(find.textContaining('Ready to settle'), findsNothing);
      expect(find.textContaining('Eligibility pending'), findsNothing);
    },
  );

  testWidgets('summary bar is hidden on Settled and Insurance Setup', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    await tester.tap(find.textContaining('Settled').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Auth pending'), findsNothing);
    expect(find.textContaining('Submitted'), findsNothing);

    await tester.tap(find.textContaining('Insurance Setup').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Auth pending'), findsNothing);
  });

  testWidgets('search filters visible queue rows', (WidgetTester tester) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    expect(find.text('AUTH-PENDING'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'NOMATCH');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('AUTH-PENDING'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'AUTH-PENDING');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('AUTH-PENDING'), findsWidgets);
  });

  testWidgets('Settled filter dialog opens with settled status choices', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    await tester.tap(find.textContaining('Settled').first);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Filters').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Claim paid'), findsWidgets);
    expect(find.textContaining('Authorization pending'), findsNothing);
  });

  testWidgets(
    'detail dialog shows one status-primary action, not parallel claim shortcuts',
    (WidgetTester tester) async {
      await _pumpClaimsWorkspace(tester, repository: repository);

      await tester.tap(find.textContaining('Active Claims').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('CLM-SUB'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Record response'), findsWidgets);
      expect(find.text('Sync insurer status'), findsOneWidget);
      // Parallel always-on shortcuts removed from the detail surface.
      expect(find.text('Submit claim'), findsNothing);
      expect(find.text('Close claim'), findsNothing);
    },
  );

  testWidgets('tapping a row opens the claims detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    await tester.tap(find.text('AUTH-PENDING'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    verify(() => repository.getDetail(any())).called(greaterThanOrEqualTo(1));
  });

  testWidgets('mobile breakpoint uses list tiles instead of data table', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('AUTH-PENDING'), findsOneWidget);
    expect(find.byTooltip('Request authorization'), findsOneWidget);
  });

  testWidgets('tab switch applies filter via repository', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    clearInteractions(repository);
    _stubClaimsRepository(repository);

    await tester.tap(find.textContaining('Active Claims').first);
    await tester.pumpAndSettle();

    final List<ClaimsQueueQuery> queries = verify(
      () => repository.listQueue(captureAny()),
    ).captured.cast<ClaimsQueueQuery>();
    expect(
      queries.any(
        (ClaimsQueueQuery query) =>
            query.filter == ClaimsQueueFilter.claimSubmitted,
      ),
      isTrue,
    );
  });
}
