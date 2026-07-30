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
import 'package:hosspi_hms/features/lab/presentation/lab_all_billing_inventory.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_dialogs.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockLabRepository extends Mock implements LabRepository {}

const LabOrderSummary _allPaidOrder = LabOrderSummary(
  id: 'LAB-ORDER-ALL-BILL-1',
  displayId: 'LO-ALL-BILL-1',
  status: 'ORDERED',
  patientDisplayName: 'All Billing Patient',
  patientId: 'PAT-ALL-BILL-1',
  paymentStatus: 'PAID',
  billing: <String, Object?>{
    'payment_status': 'PAID',
    'total_amount': '25.00',
    'currency': 'USD',
  },
);

const LabOrderSummary _allPendingOrder = LabOrderSummary(
  id: 'LAB-ORDER-ALL-PEND-1',
  displayId: 'LO-ALL-PEND-1',
  status: 'ORDERED',
  patientDisplayName: 'Pending Payment Patient',
  patientId: 'PAT-ALL-PEND-1',
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
  List<LabOrderSummary> items = const <LabOrderSummary>[_allPaidOrder],
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
    return Result<LabOrderWorkflow>.success(
      workflow ??
          const LabOrderWorkflow(
            order: _allPaidOrder,
            nextActions: LabWorkflowNextActions(
              canCollect: true,
              paymentStatus: 'PAID',
            ),
          ),
    );
  });
}

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockLabRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<LabOrderSummary> items = const <LabOrderSummary>[_allPaidOrder],
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
    initialLocation: '/lab?section=all',
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

  group('Lab All financial inventory (AC1)', () {
    test('every financially relevant atom is inventoried and classified', () {
      expect(LabAllBillingInventory.all, isNotEmpty);
      expect(
        LabAllBillingInventory.all.map((LabAllFinancialAtom a) => a.id),
        containsAll(<String>[
          'tab',
          'create_lab_order',
          'delete_order',
          'review_billing',
          'bill_later_pending',
          'verify_release',
          'open_billing',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      expect(labAllBillingScopeNote, contains('clinical-request-billing'));
      for (final LabAllFinancialAtom atom in LabAllBillingInventory.all) {
        final bool billable =
            atom.financialClass == LabAllFinancialClass.createCharge ||
            atom.financialClass == LabAllFinancialClass.settle ||
            atom.financialClass == LabAllFinancialClass.adjust ||
            atom.financialClass == LabAllFinancialClass.reverse ||
            atom.financialClass == LabAllFinancialClass.defer;
        if (billable && atom.mounted) {
          expect(atom.billingPath, isNotNull, reason: atom.id);
        }
        if (!billable) {
          expect(atom.auditCode, isNotNull, reason: atom.id);
        }
      }
    });

    test('billable mounted atoms declare a Billing path (no bypass)', () {
      expect(LabAllBillingInventory.allBillableMountedUseSharedBilling, isTrue);
      for (final LabAllFinancialAtom atom
          in LabAllBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotNull, reason: atom.id);
        expect(
          LabAllBillingInventory.forbidsInlineCollection(atom.financialClass),
          isTrue,
        );
      }
    });

    test('cashier settle/adjust atoms are unmounted on All tab', () {
      expect(LabAllBillingInventory.collectPayment.mounted, isFalse);
      expect(LabAllBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        LabAllBillingInventory.createOrder.financialClass,
        LabAllFinancialClass.createCharge,
      );
    });

    test('lab workspace realtime includes billing events (AC3)', () {
      expect(RealtimeEventGroups.lab, containsAll(RealtimeEventGroups.billing));
    });
  });

  group('Lab All billing posting / parity (AC2–AC4)', () {
    test('create payload merges clinical-request billing (no bypass)', () {
      final ClinicalRequestBillingSubmit billing =
          buildPendingClinicalRequestBillingSubmit(
            options: const <ClinicalActionCatalogOption>[
              ClinicalActionCatalogOption(
                id: 'LBT-1',
                name: 'CBC',
                unitPrice: 15,
                currency: 'USD',
              ),
            ],
            catalogType: 'LAB_TEST',
            billingEntity: 'FACILITY',
          );
      final Map<String, Object?> payload = LabOrderContextInput(
        patientId: 'PAT-ALL-BILL-1',
        patientName: 'All Billing Patient',
        encounterId: 'ENC-1',
      ).toPayload(
        labTestIds: const <String>['LBT-1'],
        labPanelIds: const <String>[],
        billing: billing,
      );
      expect(payload['billing'], isA<Map<String, Object?>>());
      final Map<String, Object?> billingMap =
          payload['billing']! as Map<String, Object?>;
      expect(billingMap['payment_status'], 'PENDING');
      expect(billingMap['line_items'], isNotEmpty);
    });

    test('idempotent pending billing replay keeps payment_status PENDING', () {
      final ClinicalRequestBillingSubmit first =
          buildPendingClinicalRequestBillingSubmit(
            options: const <ClinicalActionCatalogOption>[
              ClinicalActionCatalogOption(
                id: 'LBT-1',
                name: 'CBC',
                unitPrice: 15,
                currency: 'USD',
              ),
            ],
            catalogType: 'LAB_TEST',
          );
      final ClinicalRequestBillingSubmit second =
          buildPendingClinicalRequestBillingSubmit(
            options: const <ClinicalActionCatalogOption>[
              ClinicalActionCatalogOption(
                id: 'LBT-1',
                name: 'CBC',
                unitPrice: 15,
                currency: 'USD',
              ),
            ],
            catalogType: 'LAB_TEST',
          );
      expect(first.toPayloadMap()['payment_status'], 'PENDING');
      expect(
        first.toPayloadMap()['payment_status'],
        second.toPayloadMap()['payment_status'],
      );
    });

    testWidgets(
      'unauthorized reader has no collect/adjust and no write billing chrome',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.labRead},
          ),
        );

        expect(find.text('All Billing Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('list chrome has no redundant cashier entry points', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
        items: const <LabOrderSummary>[_allPaidOrder, _allPendingOrder],
      );

      expect(find.text('All Billing Patient'), findsOneWidget);
      expect(find.text('Pending Payment Patient'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(_allPaidOrder.effectivePaymentStatus, 'PAID');
      expect(_allPendingOrder.effectivePaymentStatus, 'PENDING');
      expect(_allPendingOrder.isPaymentSatisfied, isFalse);
      expectFlatSections(tester);
    });
  });

  group('Lab All section layout (AC5)', () {
    testWidgets('desktop All: flat sections on list', (WidgetTester tester) async {
      await _pumpAllTab(
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
      await _pumpAllTab(
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

    testWidgets('result entry keeps sibling sections (no nest)', (
      WidgetTester tester,
    ) async {
      const LabOrderItem panelItem = LabOrderItem(
        id: 'item-panel-1',
        displayId: 'LIT-P1',
        status: 'ORDERED',
        testDisplayName: 'Glucose',
        labOrderId: 'LAB-ORDER-ALL-BILL-1',
        panelId: 'panel-1',
        panelDisplayName: 'Metabolic Panel',
      );
      const LabOrderItem loneItem = LabOrderItem(
        id: 'item-lone-1',
        displayId: 'LIT-L1',
        status: 'ORDERED',
        testDisplayName: 'CBC',
        labOrderId: 'LAB-ORDER-ALL-BILL-1',
      );
      const LabOrderSummary orderWithItems = LabOrderSummary(
        id: 'LAB-ORDER-ALL-BILL-1',
        displayId: 'LO-ALL-BILL-1',
        status: 'ORDERED',
        patientDisplayName: 'All Billing Patient',
        patientId: 'PAT-ALL-BILL-1',
        paymentStatus: 'PAID',
        billing: <String, Object?>{
          'payment_status': 'PAID',
          'total_amount': '25.00',
          'currency': 'USD',
        },
        items: <LabOrderItem>[panelItem, loneItem],
      );
      // Worklist row omits nested items so Next action stays "Enter result".
      const LabOrderSummary listOrder = LabOrderSummary(
        id: 'LAB-ORDER-ALL-BILL-1',
        displayId: 'LO-ALL-BILL-1',
        status: 'ORDERED',
        patientDisplayName: 'All Billing Patient',
        patientId: 'PAT-ALL-BILL-1',
        paymentStatus: 'PAID',
        billing: <String, Object?>{
          'payment_status': 'PAID',
          'total_amount': '25.00',
          'currency': 'USD',
        },
      );

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
        items: const <LabOrderSummary>[listOrder],
        workflow: const LabOrderWorkflow(
          order: orderWithItems,
          nextActions: LabWorkflowNextActions(
            canCollect: true,
            paymentStatus: 'PAID',
          ),
        ),
      );

      expect(find.text('All Billing Patient'), findsOneWidget);
      await tester.tap(find.text('All Billing Patient').first);
      await tester.pumpAndSettle();
      expect(find.byType(LabResultEntryDialog), findsOneWidget);
      expectFlatSections(tester);
    });
  });
}
