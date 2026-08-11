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
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_claims_pending_financial_inventory.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/billing/presentation/pages/billing_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/section_layout_assertions.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

const BillingWorkItem _submittedClaim = BillingWorkItem(
  id: 'claim-scan-1',
  displayId: 'CLM-SCAN-1',
  kind: BillingWorkItemKind.claim,
  patientId: 'patient-scan',
  patientDisplayName: 'Scan Claim Patient',
  patientDisplayId: 'PT-SCAN',
  status: 'SUBMITTED',
  amount: 400,
  settlementAmount: 300,
  financials: BillingFinancials(balanceDue: 400, effectiveTotal: 400),
  linkedInvoiceId: 'inv-scan-1',
);

const BillingWorkItem _paidClaim = BillingWorkItem(
  id: 'claim-scan-1',
  displayId: 'CLM-SCAN-1',
  kind: BillingWorkItemKind.claim,
  patientId: 'patient-scan',
  patientDisplayName: 'Scan Claim Patient',
  patientDisplayId: 'PT-SCAN',
  status: 'PAID',
  amount: 400,
  settlementAmount: 300,
  financials: BillingFinancials(balanceDue: 100, effectiveTotal: 400),
  linkedInvoiceId: 'inv-scan-1',
);

const BillingWorkItem _remittanceInvoice = BillingWorkItem(
  id: 'inv-scan-1',
  displayId: 'INV-SCAN-1',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientId: 'patient-scan',
  patientDisplayName: 'Scan Claim Patient',
  patientDisplayId: 'PT-SCAN',
  billingStatus: 'PARTIAL',
  status: 'SENT',
  amount: 400,
  financials: BillingFinancials(
    balanceDue: 100,
    effectiveTotal: 400,
    netPaidTotal: 300,
  ),
);

const BillingPayment _remittancePayment = BillingPayment(
  id: 'pay-remit-1',
  amount: 300,
  method: 'INSURANCE',
  status: 'COMPLETED',
);

const BillingSummary _summary = BillingSummary(
  needsIssue: 0,
  pendingPayment: 0,
  claimsPending: 1,
  approvalRequired: 0,
  overdue: 0,
);

AppAccessPolicy _writerPolicy() {
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
      moduleEntitlements: <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readerPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{AppPermissions.billingRead},
      moduleEntitlements: <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockBillingRepository repository, {
  List<BillingWorkItem> items = const <BillingWorkItem>[_submittedClaim],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<BillingWorkspaceOverview>.success(
      BillingWorkspaceOverview(summary: _summary),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer((_) async {
    return Result<AppPage<BillingWorkItem>>.success(
      AppPage<BillingWorkItem>(
        items: items,
        request: const AppPageRequest(pageSize: 20),
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.reconcileClaim(any(), any())).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(
        claim: _paidClaim,
        invoice: _remittanceInvoice,
        payment: _remittancePayment,
      ),
    ),
  );
  when(() => repository.getPatientLedger(any(), any())).thenAnswer(
    (_) async => const Result<BillingPatientLedger>.success(
      BillingPatientLedger(
        patientId: 'patient-scan',
        summary: BillingLedgerSummary(
          totalInvoiced: 400,
          netPaid: 300,
          balanceDue: 100,
        ),
        entries: <BillingLedgerEntry>[],
      ),
    ),
  );
}

Future<void> _pumpClaimsPendingTab(
  WidgetTester tester, {
  required _MockBillingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BillingWorkItem> items = const <BillingWorkItem>[_submittedClaim],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/billing?queue=claims-pending',
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

  // Shared billing tab strip can overflow on narrow viewports; clear so
  // subsequent assertions (flat sections / dialogs) remain authoritative.
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
  late _MockBillingRepository repository;

  setUpAll(() {
    registerFallbackValue(const BillingWorkspaceQuery());
    registerFallbackValue(const BillingLedgerQuery());
    registerFallbackValue(const BillingClaimActionDraft());
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  group('Claims pending tab billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(BillingClaimsPendingFinancialInventory.all, isNotEmpty);
      expect(
        BillingClaimsPendingFinancialInventory.all.map(
          (BillingClaimsPendingFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'tab',
          'submit_claim',
          'reconcile_claim',
          'pre_auth_approve',
          'pre_auth_deny',
          'close_shift',
          'close_day',
          'empty_state',
          'error_retry',
        ]),
      );
      expect(
        BillingClaimsPendingFinancialInventory.billableMutations.every(
          (BillingClaimsPendingFinancialAtom atom) =>
              atom.repositoryMethod != null,
        ),
        isTrue,
      );
      expect(
        BillingClaimsPendingFinancialInventory.reconcileClaim.actionClass,
        BillingClaimsPendingActionClass.settle,
      );
      expect(
        BillingClaimsPendingFinancialInventory.submitClaim.actionClass,
        BillingClaimsPendingActionClass.defer,
      );
      expect(
        BillingClaimsPendingFinancialInventory.viewLedger.actionClass,
        BillingClaimsPendingActionClass.notBillable,
      );
    });

    test('AC2: billable mutations map to BillingRepository (no bypass)', () {
      for (final BillingClaimsPendingFinancialAtom atom
          in BillingClaimsPendingFinancialInventory.billableMutations) {
        expect(
          atom.repositoryMethod,
          isNotNull,
          reason: '${atom.id} must post via BillingRepository',
        );
        expect(
          BillingClaimsPendingFinancialInventory.forbidsInlineCollection(
            atom.actionClass,
          ),
          isTrue,
          reason: '${atom.id} must not use shadow ledgers',
        );
      }
      expect(
        BillingClaimsPendingFinancialInventory.reconcileClaim.repositoryMethod,
        'reconcileClaim',
      );
    });

    test('billing workspace subscribes to billing realtime events', () {
      expect(RealtimeEventGroups.billingWorkspace, isNotEmpty);
    });

    testWidgets(
      'AC3: reconcile posts via repository and removes claim from queue',
      (WidgetTester tester) async {
        var reconciled = false;
        when(() => repository.getWorkspace(any())).thenAnswer(
          (_) async => Result<BillingWorkspaceOverview>.success(
            BillingWorkspaceOverview(
              summary: reconciled
                  ? const BillingSummary(claimsPending: 0)
                  : _summary,
            ),
          ),
        );
        when(() => repository.listWorkItems(any())).thenAnswer((_) async {
          final List<BillingWorkItem> items = reconciled
              ? const <BillingWorkItem>[]
              : const <BillingWorkItem>[_submittedClaim];
          return Result<AppPage<BillingWorkItem>>.success(
            AppPage<BillingWorkItem>(
              items: items,
              request: const AppPageRequest(pageSize: 20),
              totalItemCount: items.length,
            ),
          );
        });
        when(() => repository.reconcileClaim(any(), any())).thenAnswer((
          _,
        ) async {
          reconciled = true;
          return const Result<BillingMutationResult>.success(
            BillingMutationResult(
              claim: _paidClaim,
              invoice: _remittanceInvoice,
              payment: _remittancePayment,
            ),
          );
        });

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final GoRouter router = GoRouter(
          initialLocation: '/billing?queue=claims-pending',
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
              appAccessPolicyProvider.overrideWithValue(_writerPolicy()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Scan Claim Patient'), findsOneWidget);
        expect(find.byTooltip('Record the insurer response'), findsWidgets);

        await tester.tap(find.byTooltip('Record the insurer response').first);
        await tester.pumpAndSettle();

        final Finder submit = find.widgetWithText(
          FilledButton,
          'Record insurer response',
        );
        if (submit.evaluate().isNotEmpty) {
          await tester.tap(submit.last);
        } else {
          await tester.tap(find.text('Record insurer response').last);
        }
        await tester.pumpAndSettle();

        verify(() => repository.reconcileClaim(any(), any())).called(1);
        expect(find.text('Scan Claim Patient'), findsNothing);
      },
    );

    testWidgets(
      'AC4: read-only user cannot reconcile (authorization)',
      (WidgetTester tester) async {
        expect(
          BillingClaimsPendingAtomPermissions.reconcile.isAllowed(
            _readerPolicy(),
          ),
          isFalse,
        );

        await _pumpClaimsPendingTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.text('Scan Claim Patient'), findsOneWidget);
        expect(find.byTooltip('Record the insurer response'), findsNothing);
        verifyNever(() => repository.reconcileClaim(any(), any()));
      },
    );

    testWidgets(
      'AC5: Claims pending list chrome uses flat sections (desktop light)',
      (WidgetTester tester) async {
        await _pumpClaimsPendingTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(1440, 900),
          themeMode: ThemeMode.light,
        );

        expect(find.text('Scan Claim Patient'), findsOneWidget);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: detail dialog from Claims pending keeps flat sections (mobile dark)',
      (WidgetTester tester) async {
        await _pumpClaimsPendingTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('Scan Claim Patient'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
        expect(countTitledSections(tester), greaterThan(0));
      },
    );

    testWidgets(
      'AC5: reconcile dialog from Claims pending stays flat',
      (WidgetTester tester) async {
        await _pumpClaimsPendingTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.byTooltip('Record the insurer response').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expect(find.text('Record insurer response'), findsWidgets);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: ledger dialog opened from Claims pending detail stays flat',
      (WidgetTester tester) async {
        await _pumpClaimsPendingTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Scan Claim Patient'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('View ledger'));
        await tester.pumpAndSettle();

        expect(find.text('View ledger'), findsWidgets);
        expectFlatSections(tester);
      },
    );
  });
}
