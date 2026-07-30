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
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_critical_billing_inventory.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockLabRepository extends Mock implements LabRepository {}

const LabOrderItem _criticalItem = LabOrderItem(
  id: 'LAB-ITEM-CRIT-BILL-1',
  labOrderId: 'LAB-ORDER-CRIT-BILL-1',
  testDisplayName: 'Potassium',
  resultStatus: 'CRITICAL',
  resultValue: '7.2',
  resultId: 'RES-CRIT-BILL-1',
  status: 'RESULTS_ENTERED',
);

const LabOrderSummary _criticalPaidOrder = LabOrderSummary(
  id: 'LAB-ORDER-CRIT-BILL-1',
  displayId: 'LO-CRIT-BILL-1',
  status: 'RESULTS_ENTERED',
  patientDisplayName: 'Critical Billing Patient',
  patientId: 'PAT-CRIT-BILL-1',
  paymentStatus: 'PAID',
  billing: <String, Object?>{
    'payment_status': 'PAID',
    'total_amount': '55.00',
    'currency': 'USD',
  },
  items: <LabOrderItem>[_criticalItem],
);

const LabOrderSummary _criticalPendingOrder = LabOrderSummary(
  id: 'LAB-ORDER-CRIT-PEND-1',
  displayId: 'LO-CRIT-PEND-1',
  status: 'RESULTS_ENTERED',
  patientDisplayName: 'Critical Pending Patient',
  patientId: 'PAT-CRIT-PEND-1',
  paymentStatus: 'PENDING',
  billing: <String, Object?>{
    'payment_status': 'PENDING',
    'total_amount': '60.00',
    'currency': 'USD',
  },
  items: <LabOrderItem>[
    LabOrderItem(
      id: 'LAB-ITEM-CRIT-PEND-1',
      labOrderId: 'LAB-ORDER-CRIT-PEND-1',
      testDisplayName: 'Troponin',
      resultStatus: 'CRITICAL',
      resultValue: '2.1',
      status: 'RESULTS_ENTERED',
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
  List<LabOrderSummary> items = const <LabOrderSummary>[_criticalPaidOrder],
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
          criticalResults: scoped.length,
          totalPatients: items.length,
          criticalPatients: scoped.length,
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
        order: _criticalPaidOrder,
        nextActions: LabWorkflowNextActions(
          canEnterResult: true,
          canEnterAll: true,
          paymentStatus: 'PAID',
        ),
      ),
    );
  });
}

Future<void> _pumpCriticalTab(
  WidgetTester tester, {
  required _MockLabRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<LabOrderSummary> items = const <LabOrderSummary>[_criticalPaidOrder],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/lab?section=critical',
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

  group('Lab Critical billing inventory (AC1)', () {
    test('classifies every atom and requires audit or billingPath', () {
      expect(LabCriticalBillingInventory.all, isNotEmpty);
      expect(
        LabCriticalBillingInventory.all.map(
          (LabCriticalFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab_navigate',
          'create_lab_order',
          'detail_delete_order',
          'workflow_collect_sample',
          'workflow_save_enter_results',
          'critical_notify',
          'acknowledge_critical',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      expect(labCriticalBillingScopeNote, contains('clinical-request-billing'));

      for (final LabCriticalFinancialAtom atom
          in LabCriticalBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass == LabCriticalFinancialClass.createCharge ||
            atom.financialClass == LabCriticalFinancialClass.settle ||
            atom.financialClass == LabCriticalFinancialClass.adjust ||
            atom.financialClass == LabCriticalFinancialClass.reverse ||
            atom.financialClass == LabCriticalFinancialClass.defer;
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
        LabCriticalBillingInventory.allBillableMountedUseSharedBilling,
        isTrue,
      );
      for (final LabCriticalFinancialAtom atom
          in LabCriticalBillingInventory.billableMounted) {
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
      expect(LabCriticalBillingInventory.collectPayment.mounted, isFalse);
      expect(LabCriticalBillingInventory.adjustRefund.mounted, isFalse);
      expect(LabCriticalBillingInventory.openBilling.mounted, isTrue);
      expect(LabCriticalBillingInventory.criticalNotify.mounted, isFalse);
      expect(LabCriticalBillingInventory.acknowledge.mounted, isFalse);
      expect(
        LabCriticalBillingInventory.forbidsInlineCashier(
          LabCriticalFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('create/delete order atoms post through clinical-request-billing', () {
      expect(
        LabCriticalBillingInventory.createOrder.billingPath,
        contains('persistLabOrderBilling'),
      );
      expect(
        LabCriticalBillingInventory.deleteOrder.billingPath,
        contains('reverseClinicalRequestBilling'),
      );
      expect(
        LabCriticalBillingInventory.criticalNotify.financialClass,
        LabCriticalFinancialClass.notBilled,
      );
      expect(
        LabCriticalBillingInventory.criticalNotify.auditCode,
        'NOT_BILLED',
      );
    });
  });

  group('Lab Critical billing UX (AC2-AC4)', () {
    test('workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.lab,
        containsAll(RealtimeEventGroups.billing),
      );
      expect(
        RealtimeEventGroups.lab,
        contains('diagnostic.lab_result_critical'),
      );
    });

    testWidgets(
      'authorized UI shows Billing payment status; no inline cashier',
      (WidgetTester tester) async {
        await _pumpCriticalTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.labRead,
              AppPermissions.labWrite,
            },
          ),
          items: const <LabOrderSummary>[
            _criticalPaidOrder,
            _criticalPendingOrder,
          ],
        );

        expect(find.text('Critical Billing Patient'), findsOneWidget);
        expect(find.text('Critical Pending Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('read-only has no create/collect financial controls', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.labRead},
        ),
      );

      expect(find.text('Critical Billing Patient'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Create Lab Order'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('payment status parity uses Billing-backed fields', (
      WidgetTester tester,
    ) async {
      expect(_criticalPaidOrder.effectivePaymentStatus, 'PAID');
      expect(_criticalPendingOrder.effectivePaymentStatus, 'PENDING');
      expect(_criticalPaidOrder.isPaymentSatisfied, isTrue);
      expect(_criticalPendingOrder.isPaymentSatisfied, isFalse);
      expect(_criticalPaidOrder.hasCriticalResult, isTrue);
      expect(
        LabCriticalBillingInventory.billingColumn.auditCode,
        'NOT_REQUIRED',
      );
      expect(
        LabCriticalBillingInventory.collectSample.billingPath,
        contains('assertLabOrderPaymentSatisfied'),
      );
      expect(LabCriticalBillingInventory.saveResults.billingPath, isNull);
      expect(
        LabCriticalBillingInventory.saveResults.financialClass,
        LabCriticalFinancialClass.notBilled,
      );

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
        items: const <LabOrderSummary>[_criticalPendingOrder],
      );

      expect(find.text('Critical Pending Patient'), findsOneWidget);
      expectFlatSections(tester);
    });
  });

  group('Lab Critical section layout (AC5)', () {
    testWidgets('desktop critical: flat sections on list', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );
      expectFlatSections(tester);
    });

    testWidgets('mobile + dark: flat sections on list', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
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

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
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

    testWidgets('result entry dialog keeps sibling sections (no nest)', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      _stubWorkspace(repository);

      when(() => repository.loadOrderWorkflow(any())).thenAnswer((_) async {
        return const Result<LabOrderWorkflow>.success(
          LabOrderWorkflow(
            order: _criticalPaidOrder,
            nextActions: LabWorkflowNextActions(
              canEnterResult: true,
              canEnterAll: true,
              paymentStatus: 'PAID',
            ),
          ),
        );
      });

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            labRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(
              _policy(
                permissions: <AppPermission>{
                  AppPermissions.labRead,
                  AppPermissions.labWrite,
                },
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: LabResultEntryDialog(canMutate: true),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expectFlatSections(tester);
    });
  });
}
