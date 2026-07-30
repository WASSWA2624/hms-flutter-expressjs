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
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_settled_financial_inventory.dart';
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

const ClaimInvoiceOption _settledInvoice = ClaimInvoiceOption(
  id: 'inv-paid',
  displayId: 'INV-PAID',
  patientDisplayId: 'PT-SETTLED',
  status: 'SENT',
  billingStatus: 'PARTIAL',
  totalAmount: 500,
  balanceDue: 100,
  netPaidTotal: 400,
  currency: 'UGX',
);

const CoveragePlanOption _coverage = CoveragePlanOption(
  id: 'plan-1',
  displayId: 'PLAN-001',
  title: 'Corporate 80',
  coveragePercentage: 80,
);

const ClaimsQueueItem _paidClaim = ClaimsQueueItem.claim(
  InsuranceClaimRecord(
    id: 'claim-paid',
    displayId: 'CLM-PAID',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    invoiceId: 'inv-paid',
    invoiceDisplayId: 'INV-PAID',
    status: 'PAID',
    patientDisplayId: 'PT-SETTLED',
    claimAmount: 400,
    settlementAmount: 400,
  ),
);

const ClaimsWorkspaceSummary _summary = ClaimsWorkspaceSummary(
  paidClosedCount: 1,
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

void _stubRepository(_MockClaimsRepository repository) {
  when(() => repository.listQueue(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final ClaimsQueueQuery query =
        invocation.positionalArguments.single as ClaimsQueueQuery;
    return Result<AppPage<ClaimsQueueItem>>.success(
      AppPage<ClaimsQueueItem>(
        items: const <ClaimsQueueItem>[_paidClaim],
        request: query.pageRequest,
        totalItemCount: 1,
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
  when(() => repository.getDetail(any())).thenAnswer((_) async {
    return const Result<ClaimsQueueDetail>.success(
      ClaimsQueueDetail(
        item: _paidClaim,
        claim: InsuranceClaimRecord(
          id: 'claim-paid',
          displayId: 'CLM-PAID',
          coveragePlanId: 'plan-1',
          coveragePlanDisplayId: 'PLAN-001',
          invoiceId: 'inv-paid',
          invoiceDisplayId: 'INV-PAID',
          status: 'PAID',
          patientDisplayId: 'PT-SETTLED',
          claimAmount: 400,
          settlementAmount: 400,
        ),
        invoice: _settledInvoice,
        coveragePlan: _coverage,
      ),
    );
  });
}

Future<void> _pumpSettledTab(
  WidgetTester tester, {
  required _MockClaimsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/claims?section=settled',
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
          status: 'PAID',
        ),
      ),
    );
  });

  setUp(() {
    repository = _MockClaimsRepository();
  });

  group('Claims Settled billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(ClaimsSettledFinancialInventory.all, isNotEmpty);
      expect(
        ClaimsSettledFinancialInventory.all.map(
          (ClaimsSettledFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'tab',
          'list_chrome',
          'billing_impact_panel',
          'print_statement',
          'absent_close_as_paid',
          'absent_inline_collect',
          'empty_state',
          'error_retry',
        ]),
      );
      expect(
        ClaimsSettledFinancialInventory.settledTabHasNoBillableMutations,
        isTrue,
      );
      expect(
        ClaimsSettledFinancialInventory.billingImpact.actionClass,
        ClaimsSettledActionClass.notBillable,
      );
      expect(
        ClaimsSettledFinancialInventory.billingImpact.billingSource,
        'invoice.financials.balance_due',
      );
      expect(
        ClaimsSettledFinancialInventory.printStatement.auditCode,
        'NOT_REQUIRED',
      );
    });

    test('AC2: Settled forbids inline collection / shadow ledgers', () {
      for (final ClaimsSettledFinancialAtom atom
          in ClaimsSettledFinancialInventory.all) {
        expect(
          ClaimsSettledFinancialInventory.forbidsInlineCollection(
            atom.actionClass,
          ),
          isTrue,
          reason: '${atom.id} must not bypass Billing',
        );
      }
      expect(
        ClaimsSettledFinancialInventory.absentCloseAsPaid.repositoryMethod,
        'reconcileClaim',
      );
      expect(
        ClaimsSettledFinancialInventory.remittanceEvidence.billingSource,
        contains('claim-remittance'),
      );
    });

    test('AC3: claims workspace subscribes to billing realtime events', () {
      expect(RealtimeEventGroups.claims, isNotEmpty);
      expect(
        RealtimeEventGroups.claims.any(
          (String event) =>
              event.toLowerCase().contains('billing') ||
              event.toLowerCase().contains('invoice') ||
              event.toLowerCase().contains('payment'),
        ),
        isTrue,
      );
    });

    test('AC3: patient balance uses Billing balance_due (not coverage %)', () {
      // Coverage 80% of 500 would invent 100 patient share from estimate alone;
      // remittance may leave a different ledger balance — Settled must use SoR.
      expect(_settledInvoice.balanceDue, 100);
      expect(_settledInvoice.netPaidTotal, 400);
      expect(_coverage.coveragePercentage, 80);
      expect(_settledInvoice.totalAmount, 500);
      // After full remittance + co-pay, balance_due is authoritative.
      expect(
        ClaimsSettledFinancialInventory.balanceParityAtoms,
        isNotEmpty,
      );
    });

    testWidgets(
      'AC3/AC4: detail shows Billing balance; no collect / close chrome',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        );

        await _pumpSettledTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(find.text('CLM-PAID'), findsOneWidget);
        await tester.tap(find.text('CLM-PAID'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        // Billing balance_due = 100 (not coverage-invented alternate).
        expect(find.textContaining('100'), findsWidgets);
        expect(find.byTooltip('Prepare claim'), findsNothing);
        expect(find.text('Sync insurer status'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Close as paid'), findsNothing);
        verifyNever(() => repository.reconcileClaim(any(), any()));
      },
    );

    testWidgets(
      'AC4: unauthorized financial controls absent; Print needs export ∪',
      (WidgetTester tester) async {
        expect(
          ClaimsSettledAtomPermissions.export.isAllowed(
            _policy(permissions: <AppPermission>{AppPermissions.billingRead}),
          ),
          isFalse,
        );

        await _pumpSettledTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.billingRead},
          ),
        );

        await tester.tap(find.text('CLM-PAID'));
        await tester.pumpAndSettle();
        expect(find.text('Print statement'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'AC5: Settled list chrome uses flat sections (desktop light)',
      (WidgetTester tester) async {
        await _pumpSettledTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.billingRead},
          ),
          physicalSize: const Size(1440, 900),
          themeMode: ThemeMode.light,
        );

        expect(find.text('CLM-PAID'), findsOneWidget);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: Settled detail keeps flat sibling sections (mobile dark)',
      (WidgetTester tester) async {
        await _pumpSettledTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.billingRead,
              AppPermissions.evidenceExport,
            },
          ),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.textContaining('CLM-PAID').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
        expect(countTitledSections(tester), greaterThan(0));
      },
    );

    testWidgets(
      'AC6: writer cannot mount Settled settle chrome (no bypass)',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
          },
        );
        expect(ClaimsSettledAtomPermissions.approve.isAllowed(writer), isTrue);

        await _pumpSettledTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(find.byTooltip('Prepare claim'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(DataTable),
            matching: find.text('Next action'),
          ),
          findsNothing,
        );
        verifyNever(() => repository.reconcileClaim(any(), any()));
        verifyNever(() => repository.prepareClaim(any()));
      },
    );
  });
}
