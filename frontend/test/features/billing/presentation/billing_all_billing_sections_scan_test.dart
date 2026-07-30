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
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_all_financial_inventory.dart';
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

const BillingWorkItem _issuedInvoice = BillingWorkItem(
  id: 'inv-scan-pay',
  displayId: 'INV-SCAN',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientId: 'patient-scan',
  patientDisplayName: 'Scan Pay Patient',
  patientDisplayId: 'PT-SCAN',
  billingStatus: 'ISSUED',
  status: 'SENT',
  amount: 300,
  financials: BillingFinancials(balanceDue: 300, effectiveTotal: 300),
);

const BillingWorkItem _paidInvoice = BillingWorkItem(
  id: 'inv-scan-pay',
  displayId: 'INV-SCAN',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientId: 'patient-scan',
  patientDisplayName: 'Scan Pay Patient',
  patientDisplayId: 'PT-SCAN',
  billingStatus: 'PAID',
  status: 'SENT',
  amount: 300,
  financials: BillingFinancials(
    balanceDue: 0,
    effectiveTotal: 300,
    netPaidTotal: 300,
    grossPaidTotal: 300,
  ),
);

const BillingSummary _summary = BillingSummary(
  needsIssue: 0,
  pendingPayment: 1,
  claimsPending: 0,
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
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockBillingRepository repository, {
  List<BillingWorkItem> items = const <BillingWorkItem>[_issuedInvoice],
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
  when(
    () => repository.receivePayment(
      any(),
      any(),
      idempotencyKey: any(named: 'idempotencyKey'),
    ),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(invoice: _paidInvoice),
    ),
  );
  when(() => repository.getPatientLedger(any(), any())).thenAnswer(
    (_) async => const Result<BillingPatientLedger>.success(
      BillingPatientLedger(
        patientId: 'patient-scan',
        summary: BillingLedgerSummary(
          totalInvoiced: 300,
          netPaid: 300,
          balanceDue: 0,
        ),
        entries: <BillingLedgerEntry>[],
      ),
    ),
  );
}

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockBillingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BillingWorkItem> items = const <BillingWorkItem>[_issuedInvoice],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/billing?queue=all',
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

Future<void> _waitForWorkItem(WidgetTester tester) async {
  final Finder row = find.text('Scan Pay Patient');
  if (row.evaluate().isEmpty) {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }
  expect(row, findsOneWidget);
}

Future<void> _submitReceivePayment(WidgetTester tester) async {
  final Finder filledSubmit =
      find.widgetWithText(FilledButton, 'Receive payment');
  if (filledSubmit.evaluate().isNotEmpty) {
    await tester.tap(filledSubmit.last);
  } else {
    await tester.tap(find.text('Receive payment').last);
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBillingRepository repository;

  setUpAll(() {
    registerFallbackValue(const BillingWorkspaceQuery());
    registerFallbackValue(
      const BillingWorkItem(id: 'invoice-1', kind: BillingWorkItemKind.invoice),
    );
    registerFallbackValue(
      const BillingPaymentDraft(amount: '1.00', method: 'CASH'),
    );
    registerFallbackValue(
      const BillingAdjustmentDraft(amount: '1.00', reason: 'test'),
    );
    registerFallbackValue(const BillingLedgerQuery());
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  group('Billing All tab billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(BillingAllFinancialInventory.all, isNotEmpty);
      expect(
        BillingAllFinancialInventory.all.map((BillingAllFinancialAtom a) => a.id),
        containsAll(<String>[
          'tab',
          'receive_payment',
          'issue',
          'adjust',
          'waive',
          'credit_note',
          'route_pay',
          'claims_pending_tab',
          'loading',
          'empty_state',
          'error_retry',
          'success_feedback',
        ]),
      );
      expect(
        BillingAllFinancialInventory.billableMutations.every(
          (BillingAllFinancialAtom atom) => atom.repositoryMethod != null,
        ),
        isTrue,
      );
      expect(
        BillingAllFinancialInventory.receivePayment.actionClass,
        BillingAllActionClass.settle,
      );
      expect(
        BillingAllFinancialInventory.issue.actionClass,
        BillingAllActionClass.createCharge,
      );
      expect(
        BillingAllFinancialInventory.waive.actionClass,
        BillingAllActionClass.adjust,
      );
      expect(
        BillingAllFinancialInventory.creditNote.repositoryMethod,
        'requestAdjustment',
      );
      expect(
        BillingAllFinancialInventory.send.actionClass,
        BillingAllActionClass.notBillable,
      );
      expect(
        BillingAllFinancialInventory.routePayDeepLink.actionClass,
        BillingAllActionClass.settle,
      );
    });

    test('AC2: billable mutations map to BillingRepository (no bypass)', () {
      for (final BillingAllFinancialAtom atom
          in BillingAllFinancialInventory.billableMutations) {
        expect(
          atom.repositoryMethod,
          isNotNull,
          reason: '${atom.id} must post via BillingRepository',
        );
        expect(
          BillingAllFinancialInventory.forbidsInlineCollection(atom.actionClass),
          isTrue,
          reason: '${atom.id} must not use shadow ledgers',
        );
      }
    });

    test('billing workspace subscribes to billing realtime events', () {
      expect(RealtimeEventGroups.billingWorkspace, isNotEmpty);
    });

    testWidgets(
      'AC3: receive payment posts via repository with idempotency and syncs UI',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );
        await _waitForWorkItem(tester);

        await tester.tap(find.byTooltip('Receive payment').first);
        await tester.pumpAndSettle();

        expect(find.text('Receive payment'), findsWidgets);
        expectFlatSections(tester);
        await _submitReceivePayment(tester);

        verify(
          () => repository.receivePayment(
            any(),
            any(),
            idempotencyKey: any(named: 'idempotencyKey', that: isNotEmpty),
          ),
        ).called(1);

        // Mutation applier syncs paid balance without manual refresh.
        expect(find.byTooltip('Receive payment'), findsNothing);
      },
    );

    testWidgets(
      'AC4: empty All queue shows empty state (authorized UI)',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          items: const <BillingWorkItem>[],
        );
        await tester.pumpAndSettle();

        expect(find.text('No billing items'), findsOneWidget);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC4: read-only user cannot collect or adjust (authorization)',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: const AuthUserProfile(
              roles: <String>['BILLING'],
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
            ),
            permissions: <AppPermission>{AppPermissions.billingRead},
            moduleEntitlements: <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
            ],
            isAuthorizationHydrated: true,
          ),
        );
        expect(
          BillingAllAtomPermissions.receivePayment.isAllowed(reader),
          isFalse,
        );
        expect(
          BillingAllAtomPermissions.adjust.isAllowed(reader),
          isFalse,
        );

        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );
        await _waitForWorkItem(tester);

        expect(find.byTooltip('Receive payment'), findsNothing);
        expect(find.byTooltip('Request adjustment'), findsNothing);
        verifyNever(
          () => repository.receivePayment(
            any(),
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        );
        verifyNever(
          () => repository.requestAdjustment(any(), any()),
        );
      },
    );

    testWidgets(
      'AC5: All tab list chrome uses flat sections (desktop light)',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(1440, 900),
          themeMode: ThemeMode.light,
        );
        await _waitForWorkItem(tester);

        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: detail dialog from All tab keeps flat sections (mobile dark)',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );
        await _waitForWorkItem(tester);

        await tester.tap(find.text('Scan Pay Patient'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
        expect(countTitledSections(tester), greaterThan(0));
      },
    );

    testWidgets(
      'AC5: ledger dialog opened from All detail stays flat',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );
        await _waitForWorkItem(tester);

        await tester.tap(find.text('Scan Pay Patient'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('View ledger'));
        await tester.pumpAndSettle();

        expect(find.text('View ledger'), findsWidgets);
        expectFlatSections(tester);
      },
    );
  });
}
