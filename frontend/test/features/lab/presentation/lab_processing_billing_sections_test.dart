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
import 'package:hosspi_hms/features/lab/presentation/lab_processing_billing_inventory.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockLabRepository extends Mock implements LabRepository {}

const LabSample _processingSample = LabSample(
  id: 'LAB-SAMP-PROC-BILL-1',
  displayId: 'S-PROC-BILL-1',
  status: 'RECEIVED',
);

const LabOrderSummary _processingPaidOrder = LabOrderSummary(
  id: 'LAB-ORDER-PROC-BILL-1',
  displayId: 'LO-PROC-BILL-1',
  status: 'IN_PROCESS',
  patientDisplayName: 'Processing Billing Patient',
  patientId: 'PAT-PROC-BILL-1',
  paymentStatus: 'PAID',
  billing: <String, Object?>{
    'payment_status': 'PAID',
    'total_amount': '35.00',
    'currency': 'USD',
  },
  samples: <LabSample>[_processingSample],
);

const LabOrderSummary _processingPendingOrder = LabOrderSummary(
  id: 'LAB-ORDER-PROC-PEND-1',
  displayId: 'LO-PROC-PEND-1',
  status: 'IN_PROCESS',
  patientDisplayName: 'Processing Pending Patient',
  patientId: 'PAT-PROC-PEND-1',
  paymentStatus: 'PENDING',
  billing: <String, Object?>{
    'payment_status': 'PENDING',
    'total_amount': '45.00',
    'currency': 'USD',
  },
  samples: <LabSample>[
    LabSample(
      id: 'LAB-SAMP-PROC-PEND-1',
      displayId: 'S-PROC-PEND-1',
      status: 'RECEIVED',
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
  List<LabOrderSummary> items = const <LabOrderSummary>[_processingPaidOrder],
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
          processingQueue: scoped.length,
          totalPatients: items.length,
          processingPatients: scoped.length,
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
        order: _processingPaidOrder,
        nextActions: LabWorkflowNextActions(
          canReceiveSample: false,
          paymentStatus: 'PAID',
        ),
      ),
    );
  });
}

Future<void> _pumpProcessingTab(
  WidgetTester tester, {
  required _MockLabRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<LabOrderSummary> items = const <LabOrderSummary>[_processingPaidOrder],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/lab?section=processing',
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

  group('Lab Processing billing inventory (AC1)', () {
    test('classifies every atom and requires audit or billingPath', () {
      expect(LabProcessingBillingInventory.all, isNotEmpty);
      expect(
        LabProcessingBillingInventory.all.map(
          (LabProcessingFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab_navigate',
          'create_lab_order',
          'detail_delete_order',
          'workflow_collect_sample',
          'workflow_receive_sample',
          'workflow_save_enter_results',
          'result_entry_save_submit',
          'open_billing',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      expect(labProcessingBillingScopeNote, contains('clinical-request-billing'));
      expect(labProcessingBillingScopeNote, contains('IN_PROCESS'));

      for (final LabProcessingFinancialAtom atom
          in LabProcessingBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass == LabProcessingFinancialClass.createCharge ||
            atom.financialClass == LabProcessingFinancialClass.settle ||
            atom.financialClass == LabProcessingFinancialClass.adjust ||
            atom.financialClass == LabProcessingFinancialClass.reverse ||
            atom.financialClass == LabProcessingFinancialClass.defer;
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
        LabProcessingBillingInventory.allBillableMountedUseSharedBilling,
        isTrue,
      );
      for (final LabProcessingFinancialAtom atom
          in LabProcessingBillingInventory.billableMounted) {
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
      expect(LabProcessingBillingInventory.collectPayment.mounted, isFalse);
      expect(LabProcessingBillingInventory.adjustRefund.mounted, isFalse);
      expect(LabProcessingBillingInventory.openBilling.mounted, isTrue);
      expect(
        LabProcessingBillingInventory.forbidsInlineCashier(
          LabProcessingFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        LabProcessingBillingInventory.forbidsInlineCashier(
          LabProcessingFinancialClass.adjust,
        ),
        isTrue,
      );
    });

    test('create/delete order atoms post through clinical-request-billing', () {
      expect(
        LabProcessingBillingInventory.createOrder.billingPath,
        contains('persistLabOrderBilling'),
      );
      expect(
        LabProcessingBillingInventory.deleteOrder.billingPath,
        contains('reverseClinicalRequestBilling'),
      );
      expect(
        LabProcessingBillingInventory.receiveSample.financialClass,
        LabProcessingFinancialClass.defer,
      );
      expect(
        LabProcessingBillingInventory.enterResults.financialClass,
        LabProcessingFinancialClass.notBilled,
      );
      expect(
        LabProcessingBillingInventory.enterResults.auditCode,
        'NOT_BILLED',
      );
    });
  });

  group('Lab Processing billing UX (AC2-AC4)', () {
    test('workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.lab,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'authorized UI shows Billing payment status; no inline cashier',
      (WidgetTester tester) async {
        await _pumpProcessingTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.labRead,
              AppPermissions.labWrite,
            },
          ),
          items: const <LabOrderSummary>[
            _processingPaidOrder,
            _processingPendingOrder,
          ],
        );

        expect(find.text('Processing Billing Patient'), findsOneWidget);
        expect(find.text('Processing Pending Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('read-only has no create/collect financial controls', (
      WidgetTester tester,
    ) async {
      await _pumpProcessingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.labRead},
        ),
      );

      expect(find.text('Processing Billing Patient'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Create Lab Order'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('payment status parity uses Billing-backed fields', (
      WidgetTester tester,
    ) async {
      expect(_processingPaidOrder.effectivePaymentStatus, 'PAID');
      expect(_processingPendingOrder.effectivePaymentStatus, 'PENDING');
      expect(_processingPaidOrder.isPaymentSatisfied, isTrue);
      expect(_processingPendingOrder.isPaymentSatisfied, isFalse);
      expect(
        LabProcessingBillingInventory.billingColumn.auditCode,
        'NOT_REQUIRED',
      );
      expect(
        LabProcessingBillingInventory.collectSample.billingPath,
        contains('assertLabOrderPaymentSatisfied'),
      );
      expect(
        LabProcessingBillingInventory.receiveSample.billingPath,
        contains('assertLabOrderPaymentSatisfied'),
      );
      expect(
        LabProcessingBillingInventory.saveResults.billingPath,
        contains('assertLabOrderPaymentSatisfied'),
      );

      await _pumpProcessingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
        items: const <LabOrderSummary>[_processingPendingOrder],
      );

      expect(find.text('Processing Pending Patient'), findsOneWidget);
      expectFlatSections(tester);
    });
  });

  group('Lab Processing section layout (AC5)', () {
    testWidgets('desktop processing: flat sections on list', (
      WidgetTester tester,
    ) async {
      await _pumpProcessingTab(
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
      await _pumpProcessingTab(
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
      await _pumpProcessingTab(
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
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      _stubWorkspace(repository);

      when(() => repository.loadOrderWorkflow(any())).thenAnswer((_) async {
        return const Result<LabOrderWorkflow>.success(
          LabOrderWorkflow(
            order: _processingPaidOrder,
            nextActions: LabWorkflowNextActions(
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
