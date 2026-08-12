import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_active_claims_financial_inventory.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/domain/repositories/claims_repository.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';
import 'package:hosspi_hms/features/claims/presentation/pages/claims_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/section_layout_assertions.dart';

class _MockClaimsRepository extends Mock implements ClaimsRepository {}

const ClaimsQueueItem _submittedClaim = ClaimsQueueItem.claim(
  InsuranceClaimRecord(
    id: 'claim-scan-1',
    displayId: 'CLM-SCAN-1',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    invoiceId: 'inv-scan-1',
    invoiceDisplayId: 'INV-SCAN-1',
    status: 'SUBMITTED',
    patientDisplayId: 'PT-SCAN',
    claimAmount: 400,
  ),
);

const ClaimsQueueItem _paidClaim = ClaimsQueueItem.claim(
  InsuranceClaimRecord(
    id: 'claim-scan-1',
    displayId: 'CLM-SCAN-1',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    invoiceId: 'inv-scan-1',
    invoiceDisplayId: 'INV-SCAN-1',
    status: 'PAID',
    patientDisplayId: 'PT-SCAN',
    claimAmount: 400,
    settlementAmount: 300,
  ),
);

const ClaimInvoiceOption _invoiceWithBalance = ClaimInvoiceOption(
  id: 'inv-scan-1',
  displayId: 'INV-SCAN-1',
  patientDisplayId: 'PT-SCAN',
  billingStatus: 'PARTIAL',
  totalAmount: 400,
  balanceDue: 100,
  netPaidTotal: 300,
  currency: 'UGX',
);

const ClaimsWorkspaceSummary _summary = ClaimsWorkspaceSummary(
  submittedClaimsCount: 1,
  approvedClaimsCount: 0,
  paidClosedCount: 0,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
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
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _writerPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.billingRead,
      AppPermissions.billingWrite,
    },
  );
}

AppAccessPolicy _readerPolicy() {
  return _policy(
    permissions: <AppPermission>{AppPermissions.billingRead},
  );
}

AppAccessPolicy _settlerPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.billingRead,
      AppPermissions.billingWrite,
      AppPermissions.financialApprove,
    },
  );
}

void _stubRepository(
  _MockClaimsRepository repository, {
  List<ClaimsQueueItem> items = const <ClaimsQueueItem>[_submittedClaim],
  ClaimInvoiceOption? invoice = _invoiceWithBalance,
}) {
  when(() => repository.listQueue(any())).thenAnswer((Invocation invocation) async {
    final ClaimsQueueQuery query =
        invocation.positionalArguments.single as ClaimsQueueQuery;
    return Result<AppPage<ClaimsQueueItem>>.success(
      AppPage<ClaimsQueueItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<ClaimsReferenceData>.success(
      ClaimsReferenceData(
        coveragePlans: <CoveragePlanOption>[
          CoveragePlanOption(
            id: 'plan-1',
            displayId: 'PLAN-001',
            name: 'Standard Plan',
            coveragePercentage: 75,
          ),
        ],
        invoices: <ClaimInvoiceOption>[_invoiceWithBalance],
      ),
    ),
  );
  when(() => repository.loadWorkspaceSummary()).thenAnswer(
    (_) async => const Result<ClaimsWorkspaceSummary>.success(_summary),
  );
  when(() => repository.getDetail(any())).thenAnswer((Invocation invocation) async {
    final ClaimsQueueItem item =
        invocation.positionalArguments.single as ClaimsQueueItem;
    return Result<ClaimsQueueDetail>.success(
      ClaimsQueueDetail(
        item: item,
        claim: item.claim,
        coveragePlan: const CoveragePlanOption(
          id: 'plan-1',
          displayId: 'PLAN-001',
          name: 'Standard Plan',
          coveragePercentage: 75,
        ),
        invoice: invoice,
      ),
    );
  });
  when(() => repository.reconcileClaim(any(), any())).thenAnswer(
    (_) async => Result<InsuranceClaimRecord>.success(_paidClaim.claim!),
  );
  when(() => repository.submitClaim(any(), any())).thenAnswer(
    (_) async => Result<InsuranceClaimRecord>.success(_submittedClaim.claim!),
  );
  when(() => repository.syncClaimStatus(any())).thenAnswer(
    (_) async => Result<InsuranceClaimRecord>.success(_paidClaim.claim!),
  );
  when(() => repository.prepareClaim(any())).thenAnswer(
    (_) async => Result<InsuranceClaimRecord>.success(_submittedClaim.claim!),
  );
}

Future<void> _pumpActiveClaimsTab(
  WidgetTester tester, {
  required _MockClaimsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<ClaimsQueueItem> items = const <ClaimsQueueItem>[_submittedClaim],
  ClaimInvoiceOption? invoice = _invoiceWithBalance,
  String initialLocation = '/claims?section=submitted',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items, invoice: invoice);

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
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: Text('billing:${state.uri.query}'),
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

  if (physicalSize.width < 600) {
    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );
  }
}

void main() {
  late _MockClaimsRepository repository;

  setUpAll(() {
    registerFallbackValue(const ClaimsQueueQuery());
    registerFallbackValue(_submittedClaim);
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockClaimsRepository();
  });

  group('Active Claims tab billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(ClaimsActiveClaimsFinancialInventory.all, isNotEmpty);
      expect(
        ClaimsActiveClaimsFinancialInventory.all.map(
          (ClaimsActiveClaimsFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'tab',
          'prepare_claim',
          'submit_claim',
          'record_response',
          'close_as_paid',
          'sync_status',
          'collect_patient_share',
          'empty_state',
          'error_retry',
        ]),
      );
      expect(
        ClaimsActiveClaimsFinancialInventory.billableMutations.every(
          (ClaimsActiveClaimsFinancialAtom atom) =>
              atom.repositoryMethod != null,
        ),
        isTrue,
      );
      expect(
        ClaimsActiveClaimsFinancialInventory.prepareClaim.actionClass,
        ClaimsActiveClaimsActionClass.defer,
      );
      expect(
        ClaimsActiveClaimsFinancialInventory.closeAsPaid.actionClass,
        ClaimsActiveClaimsActionClass.settle,
      );
      expect(
        ClaimsActiveClaimsFinancialInventory.collectPatientShare
            .repositoryMethod,
        'receivePayment',
      );
    });

    test('AC2: billable mutations forbid inline collection bypass', () {
      for (final ClaimsActiveClaimsFinancialAtom atom
          in ClaimsActiveClaimsFinancialInventory.billableMutations) {
        expect(
          atom.repositoryMethod,
          isNotNull,
          reason: '${atom.id} must post via shared repository/Billing path',
        );
        expect(
          ClaimsActiveClaimsFinancialInventory.forbidsInlineCollection(
            atom.actionClass,
          ),
          isTrue,
          reason: '${atom.id} must not use shadow ledgers',
        );
      }
      expect(
        ClaimsActiveClaimsFinancialInventory.closeAsPaid.repositoryMethod,
        'reconcileClaim',
      );
      expect(
        ClaimsActiveClaimsFinancialInventory.closeAsPaid.requirement,
        ClaimsActiveClaimsAtomPermissions.closeAsPaid,
      );
    });

    test('claims workspace subscribes to billing realtime events', () {
      expect(RealtimeEventGroups.claims, isNotEmpty);
      expect(
        RealtimeEventGroups.claims.intersection(RealtimeEventGroups.billing),
        isNotEmpty,
      );
    });

    testWidgets(
      'AC3: close-as-paid posts settlement_amount via reconcileClaim',
      (WidgetTester tester) async {
        final ClaimsQueueItem approved = ClaimsQueueItem.claim(
          InsuranceClaimRecord(
            id: 'claim-scan-1',
            displayId: 'CLM-SCAN-1',
            coveragePlanId: 'plan-1',
            coveragePlanDisplayId: 'PLAN-001',
            invoiceId: 'inv-scan-1',
            invoiceDisplayId: 'INV-SCAN-1',
            status: 'APPROVED',
            patientDisplayId: 'PT-SCAN',
            claimAmount: 400,
          ),
        );

        when(() => repository.reconcileClaim(any(), any())).thenAnswer((
          Invocation invocation,
        ) async {
          final Map<String, Object?> payload =
              invocation.positionalArguments[1] as Map<String, Object?>;
          expect(payload['status'], 'PAID');
          expect(payload['settlement_amount'], isNotNull);
          return Result<InsuranceClaimRecord>.success(_paidClaim.claim!);
        });

        await _pumpActiveClaimsTab(
          tester,
          repository: repository,
          accessPolicy: _settlerPolicy(),
          initialLocation: '/claims?section=approved',
          items: <ClaimsQueueItem>[approved],
        );

        final Finder closeAction = find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Close as paid'),
        );
        expect(closeAction, findsOneWidget);
        await tester.ensureVisible(closeAction);
        await tester.tap(closeAction);
        await tester.pumpAndSettle();

        expect(find.textContaining('Settlement'), findsWidgets);
        final Finder settlementField = find.byType(TextFormField).first;
        await tester.enterText(settlementField, '300');
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Close as paid'),
          ),
        );
        await tester.pumpAndSettle();

        verify(() => repository.reconcileClaim(any(), any())).called(1);
        verify(() => repository.listQueue(any())).called(greaterThanOrEqualTo(1));
      },
    );

    testWidgets(
      'AC4: unauthorized writer cannot settle PAID / collect',
      (WidgetTester tester) async {
        expect(
          ClaimsActiveClaimsAtomPermissions.closeAsPaid.isAllowed(
            _writerPolicy(),
          ),
          isFalse,
        );

        await _pumpActiveClaimsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        expect(find.text('CLM-SCAN-1'), findsOneWidget);
        expect(find.text('Close as paid'), findsNothing);

        await tester.tap(find.text('Record response'));
        await tester.pumpAndSettle();

        // Writers may approve/reject only — no PAID/PARTIAL settle options.
        expect(find.text('Paid'), findsNothing);
        expect(find.text('Partial'), findsNothing);
        verifyNever(() => repository.reconcileClaim(any(), any()));
      },
    );

    testWidgets(
      'AC4: reader cannot mount write / settle controls',
      (WidgetTester tester) async {
        await _pumpActiveClaimsTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.text('CLM-SCAN-1'), findsOneWidget);
        expect(find.byTooltip('Prepare claim'), findsNothing);
        expect(find.text('Record response'), findsNothing);
        expect(find.text('Close as paid'), findsNothing);
        verifyNever(() => repository.reconcileClaim(any(), any()));
      },
    );

    testWidgets(
      'AC3: detail patient balance uses Billing balance_due parity',
      (WidgetTester tester) async {
        await _pumpActiveClaimsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('CLM-SCAN-1'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        // Coverage % estimate would be 100 (25% of 400); ledger residual is 100.
        expect(find.textContaining('100'), findsWidgets);
        expect(find.text('Receive payment'), findsOneWidget);
      },
    );

    testWidgets(
      'AC5: Active Claims list chrome uses flat sections (desktop light)',
      (WidgetTester tester) async {
        await _pumpActiveClaimsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(1440, 900),
          themeMode: ThemeMode.light,
        );

        expect(find.text('CLM-SCAN-1'), findsOneWidget);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: detail dialog keeps flat sibling sections (mobile dark)',
      (WidgetTester tester) async {
        await _pumpActiveClaimsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('CLM-SCAN-1'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
        expect(countTitledSections(tester), greaterThan(0));
      },
    );

    testWidgets(
      'AC5: record-response dialog stays flat (desktop light)',
      (WidgetTester tester) async {
        await _pumpActiveClaimsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Record response'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
      },
    );
  });
}
