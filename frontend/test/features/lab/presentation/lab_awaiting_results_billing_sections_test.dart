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
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_awaiting_results_billing_inventory.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockLabRepository extends Mock implements LabRepository {}

const LabOrderSummary _awaitingPaidOrder = LabOrderSummary(
  id: 'LAB-ORDER-AWAIT-BILL-1',
  displayId: 'LO-AWAIT-BILL-1',
  status: 'ORDERED',
  patientDisplayName: 'Billing Awaiting Patient',
  patientId: 'PAT-AWAIT-BILL-1',
  paymentStatus: 'PAID',
  billing: <String, Object?>{
    'payment_status': 'PAID',
    'total_amount': '25.00',
    'currency': 'USD',
  },
);

const LabOrderSummary _awaitingPendingOrder = LabOrderSummary(
  id: 'LAB-ORDER-AWAIT-PEND-1',
  displayId: 'LO-AWAIT-PEND-1',
  status: 'ORDERED',
  patientDisplayName: 'Pending Payment Patient',
  patientId: 'PAT-AWAIT-PEND-1',
  paymentStatus: 'PENDING',
  billing: <String, Object?>{
    'payment_status': 'PENDING',
    'total_amount': '40.00',
    'currency': 'USD',
  },
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
  List<LabOrderSummary> items = const <LabOrderSummary>[_awaitingPaidOrder],
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
          collectionQueue: scoped.length,
          totalPatients: items.length,
          collectionPatients: scoped.length,
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
  when(() => repository.loadOrderWorkflow(any())).thenAnswer((_) async {
    return const Result<LabOrderWorkflow>.success(
      LabOrderWorkflow(
        order: _awaitingPaidOrder,
        nextActions: LabWorkflowNextActions(
          canCollect: true,
          paymentStatus: 'PAID',
        ),
      ),
    );
  });
}

Future<void> _pumpAwaitingResultsTab(
  WidgetTester tester, {
  required _MockLabRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<LabOrderSummary> items = const <LabOrderSummary>[_awaitingPaidOrder],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/lab?section=awaiting-results',
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

  group('Lab Awaiting results billing inventory (AC1)', () {
    test('classifies every atom and requires audit or billingPath', () {
      expect(LabAwaitingResultsBillingInventory.all, isNotEmpty);
      for (final LabAwaitingResultsFinancialAtom atom
          in LabAwaitingResultsBillingInventory.all) {
        final bool billable =
            atom.financialClass ==
                LabAwaitingResultsFinancialClass.createCharge ||
            atom.financialClass == LabAwaitingResultsFinancialClass.settle ||
            atom.financialClass == LabAwaitingResultsFinancialClass.adjust ||
            atom.financialClass == LabAwaitingResultsFinancialClass.reverse ||
            atom.financialClass == LabAwaitingResultsFinancialClass.defer;
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
        LabAwaitingResultsBillingInventory.allBillableMountedUseSharedBilling,
        isTrue,
      );
      for (final LabAwaitingResultsFinancialAtom atom
          in LabAwaitingResultsBillingInventory.billableMounted) {
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
      expect(LabAwaitingResultsBillingInventory.collectPayment.mounted, isFalse);
      expect(LabAwaitingResultsBillingInventory.adjustRefund.mounted, isFalse);
      expect(LabAwaitingResultsBillingInventory.openBilling.mounted, isFalse);
      expect(
        LabAwaitingResultsBillingInventory.createAdditionalOrder.mounted,
        isFalse,
      );
      expect(LabAwaitingResultsBillingInventory.editOrder.mounted, isFalse);
      expect(
        LabAwaitingResultsBillingInventory.forbidsInlineCashier(
          LabAwaitingResultsFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('create/delete order atoms post through clinical-request-billing', () {
      expect(
        LabAwaitingResultsBillingInventory.createOrder.billingPath,
        contains('persistLabOrderBilling'),
      );
      expect(
        LabAwaitingResultsBillingInventory.deleteOrder.billingPath,
        contains('reverseClinicalRequestBilling'),
      );
    });
  });

  group('Lab Awaiting results billing UX (AC2-AC4)', () {
    testWidgets(
      'authorized UI shows Billing payment status; no inline cashier',
      (WidgetTester tester) async {
        await _pumpAwaitingResultsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.labRead,
              AppPermissions.labWrite,
            },
          ),
          items: const <LabOrderSummary>[
            _awaitingPaidOrder,
            _awaitingPendingOrder,
          ],
        );

        expect(find.text('Billing Awaiting Patient'), findsOneWidget);
        expect(find.text('Pending Payment Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('read-only has no create/collect financial controls', (
      WidgetTester tester,
    ) async {
      await _pumpAwaitingResultsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.labRead},
        ),
      );

      expect(find.text('Billing Awaiting Patient'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('payment status parity uses Billing-backed fields', (
      WidgetTester tester,
    ) async {
      expect(_awaitingPaidOrder.effectivePaymentStatus, 'PAID');
      expect(_awaitingPendingOrder.effectivePaymentStatus, 'PENDING');
      expect(
        LabAwaitingResultsBillingInventory.billingColumn.auditCode,
        'NOT_REQUIRED',
      );
      expect(
        LabAwaitingResultsBillingInventory.collectSample.billingPath,
        contains('assertLabOrderPaymentSatisfied'),
      );
      expect(LabAwaitingResultsBillingInventory.saveResults.billingPath, isNull);
      expect(
        LabAwaitingResultsBillingInventory.saveResults.financialClass,
        LabAwaitingResultsFinancialClass.notBilled,
      );

      await _pumpAwaitingResultsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
        items: const <LabOrderSummary>[_awaitingPendingOrder],
      );

      expect(find.text('Pending Payment Patient'), findsOneWidget);
      expectFlatSections(tester);
    });
  });

  group('Lab Awaiting results section layout (AC5)', () {
    testWidgets('desktop awaiting-results: flat sections on list', (
      WidgetTester tester,
    ) async {
      await _pumpAwaitingResultsTab(
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
      await _pumpAwaitingResultsTab(
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
      expectFlatSections(tester);
    });

    testWidgets('result entry keeps sibling sections after open (no nest)', (
      WidgetTester tester,
    ) async {
      const LabOrderItem panelItem = LabOrderItem(
        id: 'item-panel-1',
        displayId: 'LIT-P1',
        status: 'ORDERED',
        testDisplayName: 'Glucose',
        labOrderId: 'LAB-ORDER-AWAIT-BILL-1',
        panelId: 'panel-1',
        panelDisplayName: 'Metabolic Panel',
      );
      const LabOrderItem loneItem = LabOrderItem(
        id: 'item-lone-1',
        displayId: 'LIT-L1',
        status: 'ORDERED',
        testDisplayName: 'CBC',
        labOrderId: 'LAB-ORDER-AWAIT-BILL-1',
      );
      const LabOrderSummary orderWithItems = LabOrderSummary(
        id: 'LAB-ORDER-AWAIT-BILL-1',
        displayId: 'LO-AWAIT-BILL-1',
        status: 'ORDERED',
        patientDisplayName: 'Billing Awaiting Patient',
        patientId: 'PAT-AWAIT-BILL-1',
        paymentStatus: 'PAID',
        billing: <String, Object?>{
          'payment_status': 'PAID',
          'total_amount': '25.00',
          'currency': 'USD',
        },
        items: <LabOrderItem>[panelItem, loneItem],
      );

      when(() => repository.loadOrderWorkflow(any())).thenAnswer((_) async {
        return const Result<LabOrderWorkflow>.success(
          LabOrderWorkflow(
            order: orderWithItems,
            nextActions: LabWorkflowNextActions(
              canCollect: true,
              paymentStatus: 'PAID',
            ),
          ),
        );
      });

      await _pumpAwaitingResultsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
        items: const <LabOrderSummary>[orderWithItems],
      );

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(LabWorkspacePage)),
      );
      await tester.tap(find.text(l10n.labNextActionEnterResult).first);
      await tester.pumpAndSettle();

      expect(find.byType(LabResultEntryDialog), findsOneWidget);
      expectFlatSections(tester);
    });
  });
}
