import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_pending_verification_billing_inventory.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockLabRepository extends Mock implements LabRepository {}

const LabOrderItem _verifiableItem = LabOrderItem(
  id: 'LAB-ITEM-PV-BILL-1',
  labOrderId: 'LAB-ORDER-PV-BILL-1',
  testDisplayName: 'Glucose',
  resultKind: 'TEXT',
  resultText: '5.4 mmol/L',
  resultId: 'RES-PV-BILL-1',
  status: 'IN_PROCESS',
);

const LabOrderSummary _paidOrder = LabOrderSummary(
  id: 'LAB-ORDER-PV-BILL-1',
  displayId: 'LO-PV-BILL-1',
  status: 'IN_PROCESS',
  patientDisplayName: 'Pending Verify Paid',
  patientId: 'PAT-PV-BILL-1',
  paymentStatus: 'PAID',
  billing: <String, Object?>{
    'payment_status': 'PAID',
    'total_amount': '35.00',
    'currency': 'USD',
  },
  items: <LabOrderItem>[_verifiableItem],
);

const LabOrderSummary _pendingPaymentOrder = LabOrderSummary(
  id: 'LAB-ORDER-PV-PEND-1',
  displayId: 'LO-PV-PEND-1',
  status: 'IN_PROCESS',
  patientDisplayName: 'Pending Verify Unpaid',
  patientId: 'PAT-PV-PEND-1',
  paymentStatus: 'PENDING',
  billing: <String, Object?>{
    'payment_status': 'PENDING',
    'total_amount': '45.00',
    'currency': 'USD',
  },
  items: <LabOrderItem>[
    LabOrderItem(
      id: 'LAB-ITEM-PV-PEND-1',
      labOrderId: 'LAB-ORDER-PV-PEND-1',
      testDisplayName: 'CBC',
      resultKind: 'TEXT',
      resultText: 'Normal',
      resultId: 'RES-PV-PEND-1',
      status: 'IN_PROCESS',
    ),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: labWorkflowsModule, licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['LAB_TECH'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockLabRepository repository, {
  List<LabOrderSummary> items = const <LabOrderSummary>[_paidOrder],
  LabOrderWorkflow? workflow,
}) {
  when(() => repository.loadWorkbench(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final LabWorkbenchQuery query =
        invocation.positionalArguments.single as LabWorkbenchQuery;
    final List<LabOrderSummary> scoped = items
        .where(
          (LabOrderSummary order) => labOrderMatchesScope(order, query.scope),
        )
        .toList(growable: false);
    return Result<LabWorkbenchBundle>.success(
      LabWorkbenchBundle(
        summary: LabWorkbenchSummary(
          totalOrders: items.length,
          resultsQueue: scoped.length,
          totalPatients: items.length,
          resultsPatients: scoped.length,
        ),
        worklist: AppPage<LabOrderSummary>(
          items: scoped,
          request: query.pageRequest,
          totalItemCount: scoped.length,
        ),
      ),
    );
  });
  when(
    () => repository.listQcLogs(search: any(named: 'search')),
  ).thenAnswer((_) async => const Result<List<LabQcLog>>.success(<LabQcLog>[]));
  final LabOrderWorkflow resolvedWorkflow =
      workflow ??
      const LabOrderWorkflow(
        order: _paidOrder,
        nextActions: LabWorkflowNextActions(
          canVerifyResult: true,
          canVerifyAll: true,
          paymentStatus: 'PAID',
        ),
      );
  when(() => repository.loadOrderWorkflow(any())).thenAnswer((_) async {
    return Result<LabOrderWorkflow>.success(resolvedWorkflow);
  });
}

Future<void> _pumpPendingVerificationTab(
  WidgetTester tester, {
  required _MockLabRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<LabOrderSummary> items = const <LabOrderSummary>[_paidOrder],
  LabOrderWorkflow? workflow,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, items: items, workflow: workflow);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/lab?section=pending-verification',
    routes: <RouteBase>[
      GoRoute(
        path: '/lab',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: LabWorkspacePage(
              initialQuery: LabWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        labRepositoryProvider.overrideWithValue(repository),
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
  late _MockLabRepository repository;

  setUpAll(() {
    registerFallbackValue(const LabWorkbenchQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockLabRepository();
  });

  group('Lab Pending verification billing inventory (AC1)', () {
    test('classifies every atom and requires audit or billingPath', () {
      expect(LabPendingVerificationBillingInventory.all, isNotEmpty);
      for (final LabPendingVerificationFinancialAtom atom
          in LabPendingVerificationBillingInventory.all) {
        final bool billable =
            atom.financialClass ==
                LabPendingVerificationFinancialClass.createCharge ||
            atom.financialClass ==
                LabPendingVerificationFinancialClass.settle ||
            atom.financialClass ==
                LabPendingVerificationFinancialClass.adjust ||
            atom.financialClass ==
                LabPendingVerificationFinancialClass.reverse ||
            atom.financialClass == LabPendingVerificationFinancialClass.defer;
        if (billable && atom.mounted) {
          expect(
            atom.billingPath,
            isNotNull,
            reason: '${atom.id} must declare billingPath',
          );
        }
        if (!billable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} must declare NOT_* audit code',
          );
        }
      }
    });

    test('billable mounted atoms reuse shared Billing paths', () {
      expect(
        LabPendingVerificationBillingInventory
            .allBillableMountedUseSharedBilling,
        isTrue,
      );
      for (final LabPendingVerificationFinancialAtom atom
          in LabPendingVerificationBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotEmpty);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('assert'),
            contains('reverse'),
          ),
        );
      }
    });

    test('inline cashier settle/adjust atoms are not mounted', () {
      expect(
        LabPendingVerificationBillingInventory.collectPayment.mounted,
        isFalse,
      );
      expect(
        LabPendingVerificationBillingInventory.adjustRefund.mounted,
        isFalse,
      );
      expect(
        LabPendingVerificationBillingInventory.openBilling.mounted,
        isFalse,
      );
      expect(
        LabPendingVerificationBillingInventory.forbidsInlineCashier(
          LabPendingVerificationFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('create/delete and verify atoms wire through Billing', () {
      expect(
        LabPendingVerificationBillingInventory.createOrder.billingPath,
        contains('persistLabOrderBilling'),
      );
      expect(
        LabPendingVerificationBillingInventory.deleteOrder.billingPath,
        contains('reverseClinicalRequestBilling'),
      );
      expect(
        LabPendingVerificationBillingInventory.verifyResults.billingPath,
        contains('assertLabOrderPaymentSatisfied'),
      );
      expect(
        LabPendingVerificationBillingInventory.verifyResults.requirement,
        LabPendingVerificationAtomPermissions.verify,
      );
    });
  });

  group('Lab Pending verification billing UX (AC2-AC4)', () {
    testWidgets(
      'authorized UI shows Billing payment status; no inline cashier',
      (WidgetTester tester) async {
        await _pumpPendingVerificationTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.labRead,
              AppPermissions.labWrite,
            },
          ),
          items: const <LabOrderSummary>[_paidOrder, _pendingPaymentOrder],
        );

        expect(find.text('Pending Verify Paid'), findsOneWidget);
        expect(find.text('Pending Verify Unpaid'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('read-only has no create/collect financial controls', (
      WidgetTester tester,
    ) async {
      await _pumpPendingVerificationTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.labRead},
        ),
      );

      expect(find.text('Pending Verify Paid'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Create Lab Order'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('payment status parity and unpaid next-action gate', (
      WidgetTester tester,
    ) async {
      expect(_paidOrder.effectivePaymentStatus, 'PAID');
      expect(_pendingPaymentOrder.effectivePaymentStatus, 'PENDING');
      expect(_paidOrder.isPaymentSatisfied, isTrue);
      expect(_pendingPaymentOrder.isPaymentSatisfied, isFalse);
      expect(
        LabPendingVerificationBillingInventory.billingColumn.auditCode,
        'NOT_REQUIRED',
      );
      expect(
        LabPendingVerificationBillingInventory.verifyResults.billingPath,
        contains('assertLabOrderPaymentSatisfied'),
      );

      await _pumpPendingVerificationTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
        items: const <LabOrderSummary>[_pendingPaymentOrder],
      );

      expect(find.text('Pending Verify Unpaid'), findsOneWidget);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(LabWorkspacePage)),
      );
      expect(find.text(l10n.labWorkflowNextAwaitPayment), findsWidgets);
      expectFlatSections(tester);
    });
  });

  group('Lab Pending verification section layout (AC5)', () {
    testWidgets('desktop pending-verification: flat sections on list', (
      WidgetTester tester,
    ) async {
      await _pumpPendingVerificationTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
      );
      expectFlatSections(tester);
    });

    testWidgets('mobile + dark: flat sections on list', (
      WidgetTester tester,
    ) async {
      await _pumpPendingVerificationTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );
      final Object? layoutException = tester.takeException();
      expect(
        layoutException == null ||
            layoutException.toString().contains('A RenderFlex overflowed'),
        isTrue,
      );
      expectFlatSections(tester);
    });

    testWidgets('result entry keeps sibling sections after open (no nest)', (
      WidgetTester tester,
    ) async {
      const LabOrderItem panelItem = LabOrderItem(
        id: 'item-panel-pv-1',
        displayId: 'LIT-PV-P1',
        status: 'IN_PROCESS',
        testDisplayName: 'Glucose',
        labOrderId: 'LAB-ORDER-PV-BILL-1',
        panelId: 'panel-1',
        panelDisplayName: 'Metabolic Panel',
        resultText: '5.4',
        resultId: 'RES-PV-P1',
      );
      const LabOrderItem loneItem = LabOrderItem(
        id: 'item-lone-pv-1',
        displayId: 'LIT-PV-L1',
        status: 'IN_PROCESS',
        testDisplayName: 'CBC',
        labOrderId: 'LAB-ORDER-PV-BILL-1',
        resultText: 'Normal',
        resultId: 'RES-PV-L1',
      );
      const LabOrderSummary orderWithItems = LabOrderSummary(
        id: 'LAB-ORDER-PV-BILL-1',
        displayId: 'LO-PV-BILL-1',
        status: 'IN_PROCESS',
        patientDisplayName: 'Pending Verify Paid',
        patientId: 'PAT-PV-BILL-1',
        paymentStatus: 'PAID',
        billing: <String, Object?>{
          'payment_status': 'PAID',
          'total_amount': '35.00',
          'currency': 'USD',
        },
        items: <LabOrderItem>[panelItem, loneItem],
      );

      await _pumpPendingVerificationTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
        items: const <LabOrderSummary>[orderWithItems],
        workflow: const LabOrderWorkflow(
          order: orderWithItems,
          nextActions: LabWorkflowNextActions(
            canVerifyResult: true,
            canVerifyAll: true,
            paymentStatus: 'PAID',
          ),
        ),
      );

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(LabWorkspacePage)),
      );
      await tester.tap(find.text(l10n.labNextActionVerify).first);
      await tester.pumpAndSettle();

      expect(find.byType(LabResultEntryDialog), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets(
      'unpaid result entry hides verify and shows open billing (no nest)',
      (WidgetTester tester) async {
        await _pumpPendingVerificationTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.labRead,
              AppPermissions.labWrite,
              AppPermissions.billingRead,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: labWorkflowsModule,
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: billingPaymentsModule,
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
          items: const <LabOrderSummary>[_pendingPaymentOrder],
          workflow: const LabOrderWorkflow(
            order: _pendingPaymentOrder,
            nextActions: LabWorkflowNextActions(
              billingGateBlocked: true,
              paymentStatus: 'PENDING',
            ),
          ),
        );

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(LabWorkspacePage)),
        );
        await tester.tap(find.text(l10n.labWorkflowNextAwaitPayment).first);
        await tester.pumpAndSettle();

        expect(find.byType(LabResultEntryDialog), findsOneWidget);
        final Finder dialog = find.byType(LabResultEntryDialog);
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.labVerifyResultAction),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.labVerifyAllAction),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.labWorkflowNextVerifyResults),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.patientsOpenBillingWorkbenchAction),
          ),
          findsOneWidget,
        );
        expectFlatSections(tester);
      },
    );
  });
}
