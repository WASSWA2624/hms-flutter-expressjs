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

const ClaimsQueueItem _approvedClaim = ClaimsQueueItem.claim(
  InsuranceClaimRecord(
    id: 'claim-approved',
    displayId: 'CLM-APPROVED',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    invoiceId: 'inv-3',
    invoiceDisplayId: 'INV-003',
    status: 'APPROVED',
    patientDisplayId: 'PT-APPROVED',
    claimAmount: 350,
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
  _approvedClaim,
  _paidClaim,
];

const ClaimsWorkspaceSummary _summary = ClaimsWorkspaceSummary(
  authorizationPendingCount: 1,
  authorizationApprovedCount: 1,
  submittedClaimsCount: 1,
  approvedClaimsCount: 1,
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

AppAccessPolicy _claimsReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['BILLING']),
      permissions: <AppPermission>{AppPermissions.billingRead},
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
    final int start = query.pageRequest.offset.clamp(0, items.length);
    final int end = (start + query.pageRequest.pageSize).clamp(0, items.length);
    return Result<AppPage<ClaimsQueueItem>>.success(
      AppPage<ClaimsQueueItem>(
        items: items.sublist(start, end),
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
  Size physicalSize = const Size(1600, 900),
  AppAccessPolicy? accessPolicy,
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
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _claimsWritePolicy(),
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

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockClaimsRepository repository;
  final GoRouter router;
}

/// Selects a claims strip tab, opening the overflow More menu when needed.
Future<void> _selectClaimsTab(WidgetTester tester, String label) async {
  final Finder visible = find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.text(label),
  );
  if (visible.evaluate().isNotEmpty) {
    await tester.ensureVisible(visible.first);
    await tester.tap(visible.first);
    await tester.pumpAndSettle();
    return;
  }

  final Finder more = find.byKey(const ValueKey<String>('tabOverflowMore'));
  expect(more, findsOneWidget, reason: 'Expected overflow More for "$label"');
  await tester.tap(more);
  await tester.pumpAndSettle();
  final Finder menuItem = find.textContaining(label);
  expect(menuItem, findsWidgets, reason: 'Missing overflow item "$label"');
  await tester.tap(menuItem.last);
  await tester.pumpAndSettle();
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

  testWidgets('renders tab strip with independent leaf tabs and auth table', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    final AppTabStrip strip = tester.widget<AppTabStrip>(
      find.byType(AppTabStrip),
    );
    expect(
      strip.tabs.map((AppTabItem tab) => tab.id).toList(growable: false),
      <String>[
        ClaimsDeskSection.authPending.name,
        ClaimsDeskSection.authApproved.name,
        ClaimsDeskSection.authDenied.name,
        ClaimsDeskSection.authExpired.name,
        ClaimsDeskSection.submitted.name,
        ClaimsDeskSection.approved.name,
        ClaimsDeskSection.partialClaims.name,
        ClaimsDeskSection.claimRejected.name,
        ClaimsDeskSection.settled.name,
        ClaimsDeskSection.insuranceSetup.name,
      ],
    );
    expect(
      strip.tabs.map((AppTabItem tab) => tab.label),
      containsAll(<String>[
        'Auth pending',
        'Auth approved',
        'Authorization denied',
        'Authorization expired',
        'Submitted',
        'Approved',
        'Partial claims',
        'Claim rejected',
        'Settled',
        'Insurance Setup',
      ]),
    );
    expect(find.textContaining('Authorizations'), findsNothing);
    expect(find.textContaining('Active Claims'), findsNothing);
    expect(find.text('AUTH-PENDING'), findsOneWidget);
    expect(find.byTooltip('Request authorization'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.byTooltip('Request authorization'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Patient'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Coverage'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Invoice'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Next action'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Update status'),
      ),
      findsOneWidget,
    );
    // Sibling-tab statuses are strip tabs — Advanced filters omitted on leaves.
    expect(_table(tester).search?.showAdvancedFilterButton, isFalse);
    expect(_table(tester).columnVisibilityTitle, 'Table Settings');
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(_table(tester).enableExport, isTrue);
    expect(_table(tester).canExport, isFalse);
    expect(_table(tester).enablePrint, isTrue);
    expect(_table(tester).canPrint, isFalse);
    expect(_table(tester).printLabel, 'Print');
    expect(_table(tester).search?.enableDateFilter, isFalse);
    expect(_table(tester).columns.length, 5);
  });

  testWidgets('switching tabs updates the section query parameter', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpClaimsWorkspace(
      tester,
      repository: repository,
    );

    await _selectClaimsTab(tester, 'Submitted');

    expect(
      harness.router.state.uri.queryParameters['section'],
      'submitted',
    );
    expect(find.text('CLM-SUB'), findsOneWidget);
    expect(find.text('AUTH-PENDING'), findsNothing);
    expect(find.byTooltip('Prepare claim'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.byTooltip('Prepare claim'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Invoice'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Next action'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Record response'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Amount'),
      ),
      findsNothing,
    );

    await _selectClaimsTab(tester, 'Settled');

    expect(harness.router.state.uri.queryParameters['section'], 'settled');
    expect(find.text('CLM-PAID'), findsOneWidget);
    expect(find.byTooltip('Prepare claim'), findsNothing);
    expect(find.byTooltip('Request authorization'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Settlement'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Invoice'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Next action'),
      ),
      findsNothing,
    );
  });

  testWidgets('deep link section=active-claims selects Submitted leaf', (
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

    expect(find.text('CLM-SUB'), findsOneWidget);
    expect(find.text('AUTH-PENDING'), findsNothing);
    expect(find.byTooltip('Prepare claim'), findsOneWidget);
    expect(
      harness.router.state.uri.queryParameters['section'],
      anyOf('active-claims', 'submitted'),
    );
  });

  testWidgets('deep link section=authorizations selects Auth pending leaf', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/claims?section=authorizations',
      initialQuery: ClaimsWorkspaceQuery.fromUri(
        Uri.parse('/claims?section=authorizations'),
      ),
    );

    expect(find.text('AUTH-PENDING'), findsOneWidget);
    expect(find.byTooltip('Request authorization'), findsOneWidget);
  });

  testWidgets('default route lands on Auth pending without section param', (
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

    await _selectClaimsTab(tester, 'Insurance Setup');

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

  testWidgets('Auth pending strip tab loads authorizationPending filter', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    expect(find.textContaining('Auth pending'), findsWidgets);
    expect(find.byType(ActionChip), findsNothing);

    clearInteractions(repository);
    _stubClaimsRepository(repository);

    await _selectClaimsTab(tester, 'Auth approved');
    await _selectClaimsTab(tester, 'Auth pending');

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
    'leaf queues omit status Advanced filters; Settled keeps Filters',
    (WidgetTester tester) async {
      await _pumpClaimsWorkspace(tester, repository: repository);

      expect(find.byTooltip('Refresh'), findsNothing);
      expect(_table(tester).search?.showAdvancedFilterButton, isFalse);
      // Product exception: ClaimsQueueQuery / work-items API have no date range.
      expect(_table(tester).search?.enableDateFilter, isFalse);

      await _selectClaimsTab(tester, 'Submitted');

      expect(find.byTooltip('Refresh'), findsNothing);
      expect(_table(tester).search?.showAdvancedFilterButton, isFalse);
      expect(_table(tester).search?.enableDateFilter, isFalse);
      expect(find.textContaining('Claims to submit'), findsNothing);
      expect(find.textContaining('Ready to settle'), findsNothing);
      expect(find.textContaining('Eligibility pending'), findsNothing);

      await _selectClaimsTab(tester, 'Settled');
      expect(_table(tester).search?.showAdvancedFilterButton, isTrue);
    },
  );

  testWidgets('export/print toolbar present when evidence:export granted', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(
      tester,
      repository: repository,
      accessPolicy: AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['BILLING']),
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
            AppPermissions.evidenceExport,
          },
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'insurance-claims',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      ),
    );

    expect(_table(tester).canExport, isTrue);
    expect(_table(tester).enablePrint, isTrue);
    expect(_table(tester).canPrint, isTrue);
    expect(_table(tester).printLabel, 'Print');
    expect(find.byTooltip('Export'), findsOneWidget);
    expect(find.byTooltip('Print'), findsOneWidget);
  });

  testWidgets('active tab badge uses filtered total when search narrows', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    final AppTabStrip stripBefore = tester.widget<AppTabStrip>(
      find.byType(AppTabStrip),
    );
    final AppTabItem authBefore = stripBefore.tabs.firstWhere(
      (AppTabItem tab) => tab.id == ClaimsDeskSection.authPending.name,
    );
    expect(authBefore.count, 1);

    await tester.enterText(find.byType(TextField).first, 'AUTH-PENDING');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final AppTabStrip stripAfter = tester.widget<AppTabStrip>(
      find.byType(AppTabStrip),
    );
    final AppTabItem authAfter = stripAfter.tabs.firstWhere(
      (AppTabItem tab) => tab.id == ClaimsDeskSection.authPending.name,
    );
    expect(authAfter.count, 1);
  });

  testWidgets('Insurance Setup omits tab count chrome', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    final AppTabStrip strip = tester.widget<AppTabStrip>(
      find.byType(AppTabStrip),
    );
    final AppTabItem setup = strip.tabs.firstWhere(
      (AppTabItem tab) => tab.id == ClaimsDeskSection.insuranceSetup.name,
    );
    expect(setup.count, isNull);
  });

  testWidgets('nested summary chips stay absent across Settled and Setup', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    expect(find.byType(ActionChip), findsNothing);

    await _selectClaimsTab(tester, 'Settled');
    expect(find.byType(ActionChip), findsNothing);
    // Leaf tabs remain on the primary strip.
    expect(find.textContaining('Auth pending'), findsWidgets);

    await _selectClaimsTab(tester, 'Insurance Setup');
    expect(find.byType(ActionChip), findsNothing);
    expect(find.byTooltip('Request authorization'), findsNothing);
    expect(find.byTooltip('Prepare claim'), findsNothing);
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

    await _selectClaimsTab(tester, 'Settled');

    await tester.tap(find.textContaining('Filters').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Claim paid'), findsWidgets);
    expect(find.textContaining('Authorization pending'), findsNothing);
  });

  testWidgets(
    'detail dialog omits status-primary writes owned by next-action',
    (WidgetTester tester) async {
      await _pumpClaimsWorkspace(tester, repository: repository);

      await _selectClaimsTab(tester, 'Submitted');

      await tester.tap(find.text('CLM-SUB'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      // Sync remains detail-only; status-primary lives on next-action only.
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Sync insurer status'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Record response'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Submit claim'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Close as paid'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Update status'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'authorization detail omits Update status; next-action owns the write',
    (WidgetTester tester) async {
      await _pumpClaimsWorkspace(tester, repository: repository);

      await tester.tap(find.text('AUTH-PENDING'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Update status'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Sync insurer status'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Print'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'next-action opens mutation dialog without a detail fetch',
    (WidgetTester tester) async {
      await _pumpClaimsWorkspace(tester, repository: repository);

      clearInteractions(repository);
      _stubClaimsRepository(repository);

      final Finder nextAction = find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Update status'),
      );
      expect(nextAction, findsOneWidget);
      await tester.ensureVisible(nextAction);
      await tester.tap(nextAction);
      await tester.pumpAndSettle();

      // AppDialog uppercases plain Text titles.
      expect(find.text('UPDATE AUTHORIZATION STATUS'), findsOneWidget);
      verifyNever(() => repository.getDetail(any()));
    },
  );

  testWidgets(
    'Close as paid skips restated payer-response status select',
    (WidgetTester tester) async {
      await _pumpClaimsWorkspace(tester, repository: repository);

      await _selectClaimsTab(tester, 'Submitted');
      await _selectClaimsTab(tester, 'Approved');

      expect(find.text('CLM-APPROVED'), findsOneWidget);
      final Finder closeAction = find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Close as paid'),
      );
      expect(closeAction, findsOneWidget);
      await tester.ensureVisible(closeAction);
      await tester.tap(closeAction);
      await tester.pumpAndSettle();

      expect(find.text('CLOSE CLAIM'), findsOneWidget);
      // Status was chosen by next-action — dialog collects notes only.
      expect(find.text('Payer response'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Close as paid'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('unauthorized write and setup actions are absent', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(
      tester,
      repository: repository,
      accessPolicy: _claimsReadOnlyPolicy(),
    );

    expect(find.byTooltip('Request authorization'), findsNothing);
    expect(find.byTooltip('Update status'), findsNothing);

    await _selectClaimsTab(tester, 'Insurance Setup');
    expect(find.textContaining('Add company'), findsNothing);
    expect(find.textContaining('Add scheme'), findsNothing);
  });

  testWidgets('tapping a row opens the claims detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    await tester.tap(find.text('AUTH-PENDING'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    verify(() => repository.getDetail(any())).called(greaterThanOrEqualTo(1));
  });

  testWidgets('mobile breakpoint uses list tiles with next-action trailing', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(AppListTableGrid), findsNothing);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('AUTH-PENDING'), findsOneWidget);
    expect(find.byTooltip('Request authorization'), findsOneWidget);
    // Narrow trailing is icon-only; tooltip carries the next-action label.
    expect(find.byTooltip('Update status'), findsOneWidget);
  });

  testWidgets(
    'mobile next-action opens mutation without opening detail first',
    (WidgetTester tester) async {
      await _pumpClaimsWorkspace(
        tester,
        repository: repository,
        physicalSize: const Size(390, 844),
      );

      clearInteractions(repository);
      _stubClaimsRepository(repository);

      await tester.tap(find.byTooltip('Update status'));
      await tester.pumpAndSettle();

      expect(find.text('UPDATE AUTHORIZATION STATUS'), findsOneWidget);
      verifyNever(() => repository.getDetail(any()));
    },
  );

  testWidgets('tab switch applies filter via repository', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsWorkspace(tester, repository: repository);

    clearInteractions(repository);
    _stubClaimsRepository(repository);

    await _selectClaimsTab(tester, 'Submitted');

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

  testWidgets(
    'matching-dataset loader returns the full applied-query set',
    (WidgetTester tester) async {
      await _pumpClaimsWorkspace(tester, repository: repository);
      final AppListTable<ClaimsQueueItem> table = _table(tester);
      expect(table.loadMatchingItems, isNotNull);
      final List<ClaimsQueueItem> matching = await table.loadMatchingItems!();
      expect(matching.length, table.page?.totalItemCount ?? matching.length);
      expect(
        matching.length,
        greaterThanOrEqualTo(table.page?.items.length ?? 0),
      );
    },
  );
}
