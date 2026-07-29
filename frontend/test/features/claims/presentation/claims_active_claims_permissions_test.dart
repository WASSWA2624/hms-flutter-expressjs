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
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/domain/repositories/claims_repository.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';
import 'package:hosspi_hms/features/claims/presentation/pages/claims_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClaimsRepository extends Mock implements ClaimsRepository {}

const ClaimsQueueItem _draftClaim = ClaimsQueueItem.claim(
  InsuranceClaimRecord(
    id: 'claim-draft',
    displayId: 'CLM-DRAFT',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    invoiceId: 'inv-0',
    invoiceDisplayId: 'INV-000',
    status: 'DRAFT',
    patientDisplayId: 'PT-DRAFT',
    claimAmount: 200,
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

const ClaimsWorkspaceSummary _summary = ClaimsWorkspaceSummary(
  authorizationPendingCount: 1,
  authorizationApprovedCount: 0,
  submittedClaimsCount: 1,
  approvedClaimsCount: 1,
  paidClosedCount: 0,
  partialClaimsCount: 0,
  rejectedResubmissionCount: 0,
);

const ClaimsReferenceData _referenceData = ClaimsReferenceData(
  coveragePlans: <CoveragePlanOption>[
    CoveragePlanOption(
      id: 'plan-1',
      displayId: 'PLAN-001',
      name: 'Standard Plan',
    ),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

List<ClaimsQueueItem> _itemsForQuery(
  ClaimsQueueQuery query, {
  List<ClaimsQueueItem>? allItems,
}) {
  final List<ClaimsQueueItem> all = allItems ??
      <ClaimsQueueItem>[
        _pendingAuth,
        _draftClaim,
        _submittedClaim,
        _approvedClaim,
      ];
  List<ClaimsQueueItem> items = List<ClaimsQueueItem>.of(all);
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
  return items;
}

void _stubRepository(
  _MockClaimsRepository repository, {
  List<ClaimsQueueItem>? allItems,
  ClaimsWorkspaceSummary summary = _summary,
  Result<AppPage<ClaimsQueueItem>>? queueOverride,
}) {
  when(() => repository.listQueue(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (queueOverride != null) {
      return queueOverride;
    }
    final ClaimsQueueQuery query =
        invocation.positionalArguments.single as ClaimsQueueQuery;
    final List<ClaimsQueueItem> items = _itemsForQuery(
      query,
      allItems: allItems,
    );
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
        const Result<ClaimsReferenceData>.success(_referenceData),
  );
  when(() => repository.loadWorkspaceSummary()).thenAnswer(
    (_) async => Result<ClaimsWorkspaceSummary>.success(summary),
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
  when(() => repository.syncClaimStatus(any())).thenAnswer(
    (_) async => Result<InsuranceClaimRecord>.success(_submittedClaim.claim!),
  );
  when(() => repository.submitClaim(any(), any())).thenAnswer(
    (_) async => Result<InsuranceClaimRecord>.success(_submittedClaim.claim!),
  );
  when(() => repository.reconcileClaim(any(), any())).thenAnswer(
    (_) async => Result<InsuranceClaimRecord>.success(_approvedClaim.claim!),
  );
}

Future<void> _pumpActiveClaimsTab(
  WidgetTester tester, {
  required _MockClaimsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/claims?section=active-claims',
  List<ClaimsQueueItem>? allItems,
  ClaimsWorkspaceSummary summary = _summary,
  Result<AppPage<ClaimsQueueItem>>? queueOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    allItems: allItems,
    summary: summary,
    queueOverride: queueOverride,
  );

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
              initialQuery: ClaimsWorkspaceQuery.fromUri(state.uri),
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
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  late _MockClaimsRepository repository;

  setUpAll(() {
    registerFallbackValue(const ClaimsQueueQuery());
    registerFallbackValue(
      const ClaimsQueueItem.claim(
        InsuranceClaimRecord(
          id: 'fallback',
          displayId: 'FALLBACK',
          coveragePlanId: 'plan',
          coveragePlanDisplayId: 'PLAN',
          invoiceId: 'inv',
          invoiceDisplayId: 'INV',
          status: 'SUBMITTED',
        ),
      ),
    );
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockClaimsRepository();
  });

  testWidgets(
    'read-only ∩: Active Claims list visible; mutate atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(ClaimsActiveClaimsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ClaimsActiveClaimsAtomPermissions.prepare.isAllowed(reader),
        isFalse,
      );
      expect(
        ClaimsActiveClaimsAtomPermissions.closeAsPaid.isAllowed(reader),
        isFalse,
      );

      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('CLM-SUB'), findsOneWidget);
      expect(find.textContaining('Active Claims'), findsWidgets);
      expect(find.byTooltip('Prepare claim'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.text('Record response'), findsNothing);
      expect(find.text('Close as paid'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('CLM-SUB'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Sync insurer status'), findsNothing);
      expect(find.text('Print statement'), findsOneWidget);
    },
  );

  testWidgets(
    'full write ∩: Prepare claim + Record response mount; Close as paid absent',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(ClaimsActiveClaimsAtomPermissions.prepare.isAllowed(writer), isTrue);
      expect(
        ClaimsActiveClaimsAtomPermissions.closeAsPaid.isAllowed(writer),
        isFalse,
      );

      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.byTooltip('Prepare claim'), findsOneWidget);
      expect(find.text('CLM-SUB'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Record response'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('CLM-SUB'));
      await tester.pumpAndSettle();
      expect(find.text('Sync insurer status'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Approved (').first);
      await tester.pumpAndSettle();

      expect(find.text('CLM-APPROVED'), findsOneWidget);
      expect(find.text('Close as paid'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: financial:approve alone is allowed entry; tab needs read ∩',
    (WidgetTester tester) async {
      final AppAccessPolicy approveOnly = _policy(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );
      expect(
        ClaimsActiveClaimsAtomPermissions.routeEntry.isAllowed(approveOnly),
        isTrue,
      );
      expect(
        ClaimsActiveClaimsAtomPermissions.tab.isAllowed(approveOnly),
        isFalse,
      );

      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: approveOnly,
      );

      // Without billing:read the Active Claims section is stripped from the strip.
      expect(find.textContaining('Active Claims'), findsNothing);
      expect(find.byTooltip('Prepare claim'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'read ∩ + financial:approve ∪ action: Close as paid present, Prepare absent',
    (WidgetTester tester) async {
      final AppAccessPolicy settler = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.financialApprove,
        },
      );
      expect(ClaimsActiveClaimsAtomPermissions.tab.isAllowed(settler), isTrue);
      expect(
        ClaimsActiveClaimsAtomPermissions.closeAsPaid.isAllowed(settler),
        isTrue,
      );
      expect(
        ClaimsActiveClaimsAtomPermissions.prepare.isAllowed(settler),
        isFalse,
      );

      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: settler,
      );

      expect(find.byTooltip('Prepare claim'), findsNothing);
      expect(find.textContaining('Active Claims'), findsWidgets);

      await tester.tap(find.textContaining('Approved (').first);
      await tester.pumpAndSettle();

      expect(find.text('CLM-APPROVED'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Close as paid'),
        ),
        findsOneWidget,
      );
      expect(find.text('Record response'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: insurance-claims missing omits Active Claims chrome',
    (WidgetTester tester) async {
      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('CLM-SUB'), findsNothing);
      expect(find.byTooltip('Prepare claim'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized next-action opens mutation and refreshes queue (sync)',
    (WidgetTester tester) async {
      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      clearInteractions(repository);
      _stubRepository(repository);

      final Finder nextAction = find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Record response'),
      );
      expect(nextAction, findsOneWidget);
      await tester.ensureVisible(nextAction);
      await tester.tap(nextAction);
      await tester.pumpAndSettle();

      expect(find.text('RECORD PAYER RESPONSE'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Record response'),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => repository.reconcileClaim(any(), any())).called(1);
      verify(() => repository.listQueue(any())).called(greaterThanOrEqualTo(1));
    },
  );

  testWidgets('empty queue state remains for authorized reader', (
    WidgetTester tester,
  ) async {
    when(() => repository.listQueue(any())).thenAnswer((
      Invocation invocation,
    ) async {
      final ClaimsQueueQuery query =
          invocation.positionalArguments.single as ClaimsQueueQuery;
      return Result<AppPage<ClaimsQueueItem>>.success(
        AppPage<ClaimsQueueItem>(
          items: const <ClaimsQueueItem>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
      );
    });
    when(() => repository.loadReferenceData()).thenAnswer(
      (_) async =>
          const Result<ClaimsReferenceData>.success(ClaimsReferenceData()),
    );
    when(() => repository.loadWorkspaceSummary()).thenAnswer(
      (_) async => const Result<ClaimsWorkspaceSummary>.success(
        ClaimsWorkspaceSummary(),
      ),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/claims?section=active-claims',
      routes: <RouteBase>[
        GoRoute(
          path: '/claims',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: ClaimsWorkspacePage(
                initialQuery: ClaimsWorkspaceQuery.fromUri(state.uri),
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
            _policy(permissions: <AppPermission>{AppPermissions.billingRead}),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Active Claims'), findsWidgets);
    expect(find.byTooltip('Prepare claim'), findsNothing);
    // Empty panel copy from claimsEmptyQueueTitle / body.
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('mobile viewport keeps authorized claim row + next-action', (
    WidgetTester tester,
  ) async {
    await _pumpActiveClaimsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('CLM-SUB'), findsOneWidget);
    expect(find.byTooltip('Prepare claim'), findsOneWidget);
    expect(find.byTooltip('Record response'), findsOneWidget);
  });

  testWidgets('desktop viewport shows Prepare claim + Next action column', (
    WidgetTester tester,
  ) async {
    await _pumpActiveClaimsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.financialApprove,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.byTooltip('Prepare claim'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Next action'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('dark theme: authorized Active Claims chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpActiveClaimsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('CLM-SUB'), findsOneWidget);
    expect(find.byTooltip('Prepare claim'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets(
    'deep link action=prepare-claim opens dialog only when write ∩ allowed',
    (WidgetTester tester) async {
      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
        initialLocation: '/claims?section=active-claims&action=prepare-claim',
      );

      expect(find.text('PREPARE CLAIM'), findsNothing);
      expect(find.byTooltip('Prepare claim'), findsNothing);
    },
  );

  testWidgets(
    'deep link action=prepare-claim opens prepare dialog for writer',
    (WidgetTester tester) async {
      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        initialLocation: '/claims?section=active-claims&action=prepare-claim',
      );

      // Dialog title is uppercased by AppDialog.
      expect(find.textContaining('PREPARE'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module _(n/a)_: Active Claims Print stays read ∩ (not Settled export ∪)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      // Matrix nested rows are n/a — Print uses document/read ∩, not export ∪.
      expect(
        ClaimsActiveClaimsAtomPermissions.document.isAllowed(reader),
        isTrue,
      );
      expect(
        claimsDetailPrintRequirement(
          ClaimsDeskSection.activeClaims,
        ).isAllowed(reader),
        isTrue,
      );
      expect(
        ClaimsSettledAtomPermissions.export.isAllowed(reader),
        isFalse,
      );

      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      await tester.tap(find.text('CLM-SUB'));
      await tester.pumpAndSettle();
      expect(find.text('Print statement'), findsOneWidget);
      expect(find.text('Sync insurer status'), findsNothing);
    },
  );

  testWidgets(
    'write ∩ + financial:approve: Prepare and Close as paid both present',
    (WidgetTester tester) async {
      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
          },
        ),
      );

      expect(find.byTooltip('Prepare claim'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Record response'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.textContaining('Approved (').first);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Close as paid'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Submit claim next-action mounts for draft when write ∩ allowed',
    (WidgetTester tester) async {
      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        // Bypass default Submitted filter so DRAFT rows remain visible.
        queueOverride: Result<AppPage<ClaimsQueueItem>>.success(
          AppPage<ClaimsQueueItem>(
            items: const <ClaimsQueueItem>[_draftClaim],
            request: const AppPageRequest(pageSize: 20),
            totalItemCount: 1,
          ),
        ),
      );

      expect(find.text('CLM-DRAFT'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Submit claim'),
        ),
        findsOneWidget,
      );
      expect(
        ClaimsActiveClaimsAtomPermissions.submit.isAllowed(
          _policy(
            permissions: <AppPermission>{
              AppPermissions.billingRead,
              AppPermissions.billingWrite,
            },
          ),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'detail Sync insurer status mutates and refreshes queue (sync)',
    (WidgetTester tester) async {
      await _pumpActiveClaimsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(find.text('CLM-SUB'));
      await tester.pumpAndSettle();
      expect(find.text('Sync insurer status'), findsOneWidget);

      clearInteractions(repository);
      _stubRepository(repository);

      await tester.tap(find.text('Sync insurer status'));
      await tester.pumpAndSettle();

      verify(() => repository.syncClaimStatus(any())).called(1);
      verify(() => repository.listQueue(any())).called(greaterThanOrEqualTo(1));
    },
  );

  testWidgets('authorized load error exposes retry', (WidgetTester tester) async {
    when(() => repository.listQueue(any())).thenAnswer(
      (_) async => const Result<AppPage<ClaimsQueueItem>>.failure(
        AppFailure.unexpected(),
      ),
    );
    when(() => repository.loadReferenceData()).thenAnswer(
      (_) async =>
          const Result<ClaimsReferenceData>.success(_referenceData),
    );
    when(() => repository.loadWorkspaceSummary()).thenAnswer(
      (_) async => const Result<ClaimsWorkspaceSummary>.success(_summary),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/claims?section=active-claims',
      routes: <RouteBase>[
        GoRoute(
          path: '/claims',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: ClaimsWorkspacePage(
                initialQuery: ClaimsWorkspaceQuery.fromUri(state.uri),
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
            _policy(
              permissions: <AppPermission>{
                AppPermissions.billingRead,
                AppPermissions.billingWrite,
              },
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Try again'), findsWidgets);
  });

  testWidgets('mobile viewport: read-only omits next-action trailing', (
    WidgetTester tester,
  ) async {
    await _pumpActiveClaimsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      ),
      physicalSize: const Size(390, 844),
    );

    expect(find.textContaining('CLM-SUB'), findsOneWidget);
    expect(find.byTooltip('Prepare claim'), findsNothing);
    expect(find.byTooltip('Record response'), findsNothing);
  });

  testWidgets('light theme: authorized Active Claims chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpActiveClaimsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('CLM-SUB'), findsOneWidget);
    expect(find.byTooltip('Prepare claim'), findsOneWidget);
    expect(find.textContaining('Submitted ('), findsWidgets);
  });

  testWidgets('summary chips remain for authorized reader (read chrome)', (
    WidgetTester tester,
  ) async {
    await _pumpActiveClaimsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      ),
    );

    expect(find.textContaining('Submitted ('), findsWidgets);
    expect(find.textContaining('Approved ('), findsWidgets);
    expect(find.byTooltip('Prepare claim'), findsNothing);
  });
}
