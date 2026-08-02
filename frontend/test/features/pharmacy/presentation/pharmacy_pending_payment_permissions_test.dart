import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: pharmacyDispensingModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  List<String> roles = const <String>['PHARMACIST'],
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

List<AppModuleEntitlement> get _pharmacyAndBillingModules =>
    const <AppModuleEntitlement>[
      AppModuleEntitlement(
        code: pharmacyDispensingModule,
        licenseStatus: 'ACTIVE',
      ),
      AppModuleEntitlement(
        code: billingPaymentsModule,
        licenseStatus: 'ACTIVE',
      ),
    ];

AppAccessPolicy _pendingPaymentTabReadPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.pharmacyRead,
      AppPermissions.billingRead,
    },
    modules: _pharmacyAndBillingModules,
  );
}

AppAccessPolicy _pendingPaymentWriterPolicy({
  bool includeBillingWrite = false,
}) {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.pharmacyRead,
      AppPermissions.billingRead,
      AppPermissions.pharmacyWrite,
      if (includeBillingWrite) AppPermissions.billingWrite,
    },
    modules: _pharmacyAndBillingModules,
  );
}

const PharmacyOrderItem _unpaidLine = PharmacyOrderItem(
  id: 'item-pay-1',
  drugDisplayName: 'Ibuprofen',
  quantityPrescribed: 5,
  quantityDispensed: 0,
  quantityRemaining: 5,
  pharmacyUnitPrice: 12.5,
  pharmacyCurrency: 'UGX',
);

const PharmacyOrder _unpaidOrder = PharmacyOrder(
  id: 'order-pay',
  displayId: 'PHO-PAY',
  patientDisplayName: 'Cathy Payment',
  location: 'OUTPATIENT',
  status: 'ORDERED',
  paymentStatus: 'UNPAID',
  itemCount: 1,
  quantityPrescribedTotal: 5,
  items: <PharmacyOrderItem>[_unpaidLine],
);

const PharmacyOrder _paidOrder = PharmacyOrder(
  id: 'order-pay',
  displayId: 'PHO-PAY',
  patientDisplayName: 'Cathy Payment',
  location: 'OUTPATIENT',
  status: 'ORDERED',
  paymentStatus: 'PAID',
  itemCount: 1,
  quantityPrescribedTotal: 5,
  items: <PharmacyOrderItem>[_unpaidLine],
);

const PharmacyOrder _readyOrder = PharmacyOrder(
  id: 'order-ready',
  displayId: 'PHO-READY',
  patientDisplayName: 'Noah Ready',
  location: 'OUTPATIENT',
  status: 'ORDERED',
  itemCount: 1,
  quantityPrescribedTotal: 24,
  items: <PharmacyOrderItem>[
    PharmacyOrderItem(
      id: 'item-ready-1',
      drugDisplayName: 'Paracetamol',
      quantityPrescribed: 24,
      quantityDispensed: 0,
      quantityRemaining: 24,
    ),
  ],
);

const PharmacyInventoryWorkbench _inventoryWorkbench =
    PharmacyInventoryWorkbench(
      summary: PharmacyInventoryStockSummary(),
      stocks: AppPage<PharmacyInventoryStock>(
        items: <PharmacyInventoryStock>[],
        request: AppPageRequest(),
      ),
    );

class _MockPharmacyRepository extends Mock implements PharmacyRepository {}

void _stubPharmacyRepository(
  _MockPharmacyRepository repository, {
  List<PharmacyOrder> orders = const <PharmacyOrder>[_unpaidOrder, _readyOrder],
}) {
  when(() => repository.loadWorkbench(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final PharmacyWorkbenchQuery query =
        invocation.positionalArguments.single as PharmacyWorkbenchQuery;
    List<PharmacyOrder> items = List<PharmacyOrder>.of(orders);
    final String? status = query.status?.trim().toUpperCase();
    if (status != null && status.isNotEmpty) {
      items = items
          .where(
            (PharmacyOrder order) =>
                (order.status ?? '').toUpperCase() == status,
          )
          .toList(growable: false);
    }
    if (query.pendingPayment == true) {
      items = items
          .where((PharmacyOrder order) => order.requiresPaymentBeforeDispense)
          .toList(growable: false);
    }
    return Result<PharmacyWorkbench>.success(
      PharmacyWorkbench(
        summary: PharmacyWorkbenchSummary(
          orderedQueue: items
              .where(
                (PharmacyOrder order) =>
                    (order.status ?? '').toUpperCase() == 'ORDERED',
              )
              .length,
          totalOrders: items.length,
          pendingPaymentQueue: items
              .where((PharmacyOrder order) => order.requiresPaymentBeforeDispense)
              .length,
        ),
        orders: AppPage<PharmacyOrder>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      ),
    );
  });
  when(() => repository.loadOrderWorkflow(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String orderId = invocation.positionalArguments.single as String;
    final PharmacyOrder order = orders.firstWhere(
      (PharmacyOrder item) => item.id == orderId || item.displayId == orderId,
      orElse: () => _unpaidOrder,
    );
    return Result<PharmacyOrderWorkflow>.success(
      PharmacyOrderWorkflow(
        order: order,
        items: order.items,
        nextActions: PharmacyNextActions(
          canPrepareDispense: order.canPrepareDispense,
          canAttestDispense: order.canAttestDispense,
          canCancel: order.canCancel,
          canReturn: order.canReturn,
        ),
      ),
    );
  });
  when(() => repository.searchDrugs(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacyDrug>>.success(
      AppPage<PharmacyDrug>(items: <PharmacyDrug>[], request: AppPageRequest()),
    ),
  );
  when(() => repository.getInventoryStock(any())).thenAnswer(
    (_) async =>
        const Result<PharmacyInventoryWorkbench>.success(_inventoryWorkbench),
  );
  when(
    () => repository.loadStorageLayout(facilityId: any(named: 'facilityId')),
  ).thenAnswer(
    (_) async =>
        const Result<PharmacyStorageLayout>.success(PharmacyStorageLayout()),
  );
  when(() => repository.listFormularyItems(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacyFormularyItem>>.success(
      AppPage<PharmacyFormularyItem>(
        items: <PharmacyFormularyItem>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(() => repository.recordOrderBilling(any(), any())).thenAnswer(
    (_) async => Result<PharmacyOrderWorkflow>.success(
      PharmacyOrderWorkflow(
        order: _paidOrder,
        items: _paidOrder.items,
        nextActions: PharmacyNextActions(
          canPrepareDispense: _paidOrder.canPrepareDispense,
        ),
      ),
    ),
  );
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

/// Catalog browse is now the "Catalog and stock" desk tab (visible chip or
/// overflow entry); assert against the strip's tab model to stay overflow-safe.
Finder _catalogAction() => find.byWidgetPredicate(
  (Widget widget) =>
      widget is AppTabStrip &&
      widget.tabs.any((AppTabItem tab) => tab.label == 'Catalog and stock'),
);

Finder _actionLabel(String label) => find.descendant(
  of: find.byType(AppButton),
  matching: find.text(label),
);

Future<void> _pumpPendingPaymentTab(
  WidgetTester tester, {
  required _MockPharmacyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1280, 800),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/pharmacy?section=pending-payment',
    routes: <RouteBase>[
      GoRoute(
        path: '/pharmacy',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: PharmacyWorkspacePage(
              initialQuery: PharmacyWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pharmacyRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
      ],
      child: MaterialApp.router(
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
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
  setUpAll(() {
    registerFallbackValue(const PharmacyWorkbenchQuery());
    registerFallbackValue(const PharmacyDrugQuery());
    registerFallbackValue(const PharmacyFormularyQuery());
    registerFallbackValue(const PharmacyInventoryStockQuery());
    registerFallbackValue(<String, Object?>{});
  });

  group('PharmacyPendingPaymentAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.tab,
          pharmacyPendingPaymentReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.write,
          pharmacyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.dispense,
          pharmacyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.recordPayment,
          pharmacyRecordPaymentRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.billingStatus,
          pharmacyBillingStatusReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.nestedBillingWrite,
          pharmacyRecordPaymentRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.paymentSuccess,
          pharmacyRecordPaymentRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.catalogWrite,
          pharmacyCatalogWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.routeEntry,
          pharmacyWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.catalogEntry,
          pharmacyWorkspaceCatalogEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPendingPaymentAtomPermissions.controlledDrugAudit,
          pharmacyControlledDrugAuditRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionTabRequirement(PharmacyDeskSection.pendingPayment),
          PharmacyPendingPaymentAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacyRecordPaymentRequirement,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacyWorkspaceCatalogEntryRequirement,
          RouteAccessCatalog.pharmacyEntry,
        ),
        isTrue,
      );
    });

    test('atom map covers inventory verbs (AC1)', () {
      expect(PharmacyPendingPaymentAtomPermissions.tab, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.listChrome, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.search, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.filters, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.settings, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.pagination, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.empty, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.loading, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.retry, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.success, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.paymentSuccess, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.validation, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.paymentValidation, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.rowSelect, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.detail, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.nextAction, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.nextActionWrite, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.create, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.update, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.delete, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.dispense, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.attest, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.returnItems, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.cancelOrder, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.mapStock, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.priceSource, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.recordPayment, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.billingStatus, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.printInstructions, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.controlledDrugAudit, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.catalogBrowse, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.catalogWrite, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.nestedBillingWrite, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.nestedWrite, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.nestedRead, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.routeEntry, isNotNull);
      expect(PharmacyPendingPaymentAtomPermissions.catalogEntry, isNotNull);
    });

    test(
      '∩ denial: missing billing:read hides Pending payment tab gate',
      () {
        final AppAccessPolicy pharmacyOnly = _policy(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
        );
        final AppAccessPolicy billingOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          modules: _pharmacyAndBillingModules,
        );

        expect(
          PharmacyPendingPaymentAtomPermissions.tab.isAllowed(pharmacyOnly),
          isFalse,
        );
        expect(
          PharmacyPendingPaymentAtomPermissions.tab.isAllowed(billingOnly),
          isFalse,
        );
        expect(canViewPharmacyPendingPaymentTab(pharmacyOnly), isFalse);
        expect(
          pharmacyAllowedSections(pharmacyOnly),
          isNot(contains(PharmacyDeskSection.pendingPayment)),
        );
      },
    );

    test(
      '∩ full set: pharmacy:read + billing:read mounts tab; write needs '
      'pharmacy:write',
      () {
        final AppAccessPolicy reader = _pendingPaymentTabReadPolicy();
        final AppAccessPolicy writer = _pendingPaymentWriterPolicy();

        expect(
          PharmacyPendingPaymentAtomPermissions.tab.isAllowed(reader),
          isTrue,
        );
        expect(
          PharmacyPendingPaymentAtomPermissions.write.isAllowed(reader),
          isFalse,
        );
        expect(
          PharmacyPendingPaymentAtomPermissions.write.isAllowed(writer),
          isTrue,
        );
        expect(
          PharmacyPendingPaymentAtomPermissions.billingStatus.isAllowed(reader),
          isTrue,
        );
        expect(canViewPharmacyPendingPaymentTab(reader), isTrue);
        expect(
          pharmacyAllowedSections(reader),
          contains(PharmacyDeskSection.pendingPayment),
        );
      },
    );

    test(
      '∪ allowance: route entry allows operations:read without pharmacy:read',
      () {
        final AppAccessPolicy operationsReader = _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: pharmacyDispensingModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'facilities-maintenance',
              licenseStatus: 'ACTIVE',
            ),
          ],
          roles: const <String>['OPERATIONS'],
        );

        expect(
          PharmacyPendingPaymentAtomPermissions.routeEntry.isAllowed(
            operationsReader,
          ),
          isTrue,
        );
        expect(
          PharmacyPendingPaymentAtomPermissions.tab.isAllowed(operationsReader),
          isFalse,
        );
        expect(canEnterPharmacyWorkspace(operationsReader), isTrue);
        expect(
          pharmacyAllowedSections(operationsReader),
          contains(PharmacyDeskSection.pendingPayment),
        );
      },
    );

    test(
      'catalog write ∪ allows operations:write '
      '(source gate; matrix narrative ∩ pharmacy:write)',
      () {
        final AppAccessPolicy operationsWriter = _policy(
          permissions: <AppPermission>{AppPermissions.operationsWrite},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: pharmacyDispensingModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'facilities-maintenance',
              licenseStatus: 'ACTIVE',
            ),
          ],
          roles: const <String>['OPERATIONS'],
        );
        final AppAccessPolicy reader = _pendingPaymentTabReadPolicy();

        expect(
          PharmacyPendingPaymentAtomPermissions.catalogWrite.isAllowed(
            operationsWriter,
          ),
          isTrue,
        );
        expect(
          PharmacyPendingPaymentAtomPermissions.write.isAllowed(
            operationsWriter,
          ),
          isFalse,
        );
        expect(
          PharmacyPendingPaymentAtomPermissions.catalogWrite.isAllowed(reader),
          isFalse,
        );
      },
    );

    test('nested billing write ∩ denial without billing:write', () {
      final AppAccessPolicy pharmacyWriter = _pendingPaymentWriterPolicy();
      final AppAccessPolicy withBilling = _pendingPaymentWriterPolicy(
        includeBillingWrite: true,
      );

      expect(
        PharmacyPendingPaymentAtomPermissions.recordPayment.isAllowed(
          pharmacyWriter,
        ),
        isFalse,
      );
      expect(
        PharmacyPendingPaymentAtomPermissions.nestedBillingWrite.isAllowed(
          withBilling,
        ),
        isTrue,
      );
      expect(
        PharmacyPendingPaymentAtomPermissions.paymentSuccess.isAllowed(
          withBilling,
        ),
        isTrue,
      );
    });

    test('controlled-drug audit ∩ needs pharmacy:read + compliance:read', () {
      final AppAccessPolicy pharmacyOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
      );
      final AppAccessPolicy withCompliance = _policy(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.complianceRead,
        },
      );

      expect(
        PharmacyPendingPaymentAtomPermissions.controlledDrugAudit.isAllowed(
          pharmacyOnly,
        ),
        isFalse,
      );
      expect(
        PharmacyPendingPaymentAtomPermissions.controlledDrugAudit.isAllowed(
          withCompliance,
        ),
        isTrue,
      );
    });

    test(
      'subscription strips Pending payment without billing-payments module',
      () {
        final AppAccessPolicy noBillingModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.billingRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: pharmacyDispensingModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
        );

        expect(
          PharmacyPendingPaymentAtomPermissions.tab.isAllowed(noBillingModule),
          isFalse,
        );
        expect(canViewPharmacyPendingPaymentTab(noBillingModule), isFalse);
      },
    );

    test(
      'subscription strips Pending payment without pharmacy-dispensing',
      () {
        final AppAccessPolicy noPharmacyModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.billingRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: billingPaymentsModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
        );

        expect(
          PharmacyPendingPaymentAtomPermissions.tab.isAllowed(
            noPharmacyModule,
          ),
          isFalse,
        );
        expect(
          PharmacyPendingPaymentAtomPermissions.routeEntry.isAllowed(
            noPharmacyModule,
          ),
          isFalse,
        );
      },
    );
  });

  group('pharmacy Pending payment UI permission enforcement', () {
    late _MockPharmacyRepository repository;

    setUp(() {
      repository = _MockPharmacyRepository();
      _stubPharmacyRepository(repository);
    });

    testWidgets(
      '∩ denial: pharmacy:read without billing:read hides Pending payment '
      'tab and falls back',
      (WidgetTester tester) async {
        await _pumpPendingPaymentTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        expect(_tab('Pending payment'), findsNothing);
        expect(_tab('New orders'), findsOneWidget);
        expect(find.text('Payment'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'full read ∩: tab + Payment column present; write next-actions absent',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _pendingPaymentTabReadPolicy();
        expect(PharmacyPendingPaymentAtomPermissions.tab.isAllowed(reader), isTrue);
        expect(
          PharmacyPendingPaymentAtomPermissions.recordPayment.isAllowed(reader),
          isFalse,
        );

        await _pumpPendingPaymentTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tab('Pending payment'), findsOneWidget);
        expect(_catalogAction(), findsOneWidget);
        expect(find.text('Cathy Payment'), findsOneWidget);
        expect(find.text('Payment'), findsAtLeastNWidgets(1));
        expect(_actionLabel('Record payment'), findsNothing);
        expect(_actionLabel('Dispense'), findsNothing);
        expect(_actionLabel('Cancel order'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Cathy Payment'));
        await tester.pumpAndSettle();

        final Finder dialog = find.byType(AppDialog);
        expect(dialog, findsOneWidget);
        expect(find.text('PRESCRIPTION DETAIL'), findsOneWidget);
        expect(
          find.descendant(of: dialog, matching: find.text('Record payment')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialog,
            matching: find.text('Print instructions'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module: Record payment absent without billing:write',
      (WidgetTester tester) async {
        await _pumpPendingPaymentTab(
          tester,
          repository: repository,
          accessPolicy: _pendingPaymentWriterPolicy(),
        );

        expect(_tab('Pending payment'), findsOneWidget);
        expect(find.text('Cathy Payment'), findsOneWidget);
        expect(_actionLabel('Record payment'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'nested billing write ∩: Record payment mounts with billing:write',
      (WidgetTester tester) async {
        await _pumpPendingPaymentTab(
          tester,
          repository: repository,
          accessPolicy: _pendingPaymentWriterPolicy(includeBillingWrite: true),
        );

        expect(find.text('Cathy Payment'), findsOneWidget);
        expect(_actionLabel('Record payment'), findsAtLeastNWidgets(1));

        await tester.tap(find.text('Cathy Payment'));
        await tester.pumpAndSettle();

        final Finder dialog = find.byType(AppDialog);
        expect(
          find.descendant(of: dialog, matching: find.text('Record payment')),
          findsOneWidget,
        );
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'subscription strip: billing-payments missing omits Pending payment tab',
      (WidgetTester tester) async {
        await _pumpPendingPaymentTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.billingRead,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: pharmacyDispensingModule,
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        expect(_tab('Pending payment'), findsNothing);
        expect(_tab('New orders'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∪ route entry: operations:read keeps Pending payment chrome read-only',
      (WidgetTester tester) async {
        await _pumpPendingPaymentTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.operationsRead},
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: pharmacyDispensingModule,
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'facilities-maintenance',
                licenseStatus: 'ACTIVE',
              ),
            ],
            roles: const <String>['OPERATIONS'],
          ),
        );

        expect(_tab('Pending payment'), findsOneWidget);
        expect(find.text('Cathy Payment'), findsOneWidget);
        expect(_actionLabel('Record payment'), findsNothing);
        expect(_catalogAction(), findsNothing);
        // Payment column is billing-status chrome; absent without billing:read.
        expect(find.text('Payment'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'authorized empty Pending payment remains observable '
      '(no routine no-access)',
      (WidgetTester tester) async {
        _stubPharmacyRepository(
          repository,
          orders: const <PharmacyOrder>[],
        );

        await _pumpPendingPaymentTab(
          tester,
          repository: repository,
          accessPolicy: _pendingPaymentTabReadPolicy(),
        );

        expect(_tab('Pending payment'), findsOneWidget);
        expect(find.text('No pharmacy orders'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'authorized Record payment mutation syncs list and shows success snackbar',
      (WidgetTester tester) async {
        await _pumpPendingPaymentTab(
          tester,
          repository: repository,
          accessPolicy: _pendingPaymentWriterPolicy(includeBillingWrite: true),
        );

        await tester.tap(_actionLabel('Record payment').first);
        await tester.pumpAndSettle();

        expect(find.text('Request billing'), findsAtLeastNWidgets(1));

        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Done'),
          ),
        );
        await tester.pumpAndSettle();

        verify(
          () => repository.recordOrderBilling('order-pay', any()),
        ).called(1);
        expect(find.text('Pharmacy workflow updated.'), findsOneWidget);
        expect(find.text('Cathy Payment'), findsOneWidget);
      },
    );

    testWidgets(
      'Pending payment desktop light theme keeps authorized chrome',
      (WidgetTester tester) async {
        await _pumpPendingPaymentTab(
          tester,
          repository: repository,
          accessPolicy: _pendingPaymentWriterPolicy(includeBillingWrite: true),
          physicalSize: const Size(1280, 800),
          themeMode: ThemeMode.light,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(AppTabStrip), findsOneWidget);
        expect(find.byType(AppListTableGrid), findsOneWidget);
        expect(_catalogAction(), findsOneWidget);
        expect(find.text('Payment'), findsAtLeastNWidgets(1));
        expect(_actionLabel('Record payment'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'Pending payment mobile dark theme keeps authorized chrome',
      (WidgetTester tester) async {
        await _pumpPendingPaymentTab(
          tester,
          repository: repository,
          accessPolicy: _pendingPaymentWriterPolicy(includeBillingWrite: true),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(AppTabStrip), findsOneWidget);
        expect(find.byType(AppListTableGrid), findsNothing);
        expect(find.textContaining('Cathy'), findsAtLeastNWidgets(1));
        expect(_actionLabel('Record payment'), findsAtLeastNWidgets(1));
      },
    );
  });
}
