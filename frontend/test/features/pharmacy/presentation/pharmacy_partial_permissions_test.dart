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

const PharmacyOrderItem _partialLine = PharmacyOrderItem(
  id: 'item-partial-1',
  drugDisplayName: 'Amoxicillin',
  quantityPrescribed: 20,
  quantityDispensed: 8,
  quantityRemaining: 12,
);

const PharmacyOrder _partialOrder = PharmacyOrder(
  id: 'order-partial',
  displayId: 'PHO-PARTIAL',
  patientDisplayName: 'Amina Partial',
  location: 'OUTPATIENT',
  status: 'PARTIALLY_DISPENSED',
  itemCount: 1,
  quantityPrescribedTotal: 20,
  quantityDispensedTotal: 8,
  items: <PharmacyOrderItem>[_partialLine],
);

const PharmacyOrder _continuedPartialOrder = PharmacyOrder(
  id: 'order-partial',
  displayId: 'PHO-PARTIAL',
  patientDisplayName: 'Amina Partial',
  location: 'OUTPATIENT',
  status: 'PARTIALLY_DISPENSED',
  itemCount: 1,
  quantityPrescribedTotal: 20,
  quantityDispensedTotal: 20,
  items: <PharmacyOrderItem>[
    PharmacyOrderItem(
      id: 'item-partial-1',
      drugDisplayName: 'Amoxicillin',
      quantityPrescribed: 20,
      quantityDispensed: 20,
      quantityRemaining: 0,
    ),
  ],
);

const PharmacyOrder _unpaidPartialOrder = PharmacyOrder(
  id: 'order-partial-pay',
  displayId: 'PHO-PARTIAL-PAY',
  patientDisplayName: 'Omar Partial Pay',
  location: 'OUTPATIENT',
  status: 'PARTIALLY_DISPENSED',
  paymentStatus: 'UNPAID',
  itemCount: 1,
  quantityPrescribedTotal: 10,
  quantityDispensedTotal: 4,
  items: <PharmacyOrderItem>[
    PharmacyOrderItem(
      id: 'item-partial-pay-1',
      drugDisplayName: 'Ibuprofen',
      quantityPrescribed: 10,
      quantityDispensed: 4,
      quantityRemaining: 6,
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
  List<PharmacyOrder> orders = const <PharmacyOrder>[
    _partialOrder,
    _unpaidPartialOrder,
  ],
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
          partiallyDispensedQueue: items
              .where(
                (PharmacyOrder order) =>
                    (order.status ?? '').toUpperCase() ==
                    'PARTIALLY_DISPENSED',
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
      orElse: () => _partialOrder,
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
  when(
    () => repository.prepareDispense(
      orderId: any(named: 'orderId'),
      items: any(named: 'items'),
      dispenseBatchRef: any(named: 'dispenseBatchRef'),
      statement: any(named: 'statement'),
      reason: any(named: 'reason'),
    ),
  ).thenAnswer(
    (_) async => Result<PharmacyMutationResult>.success(
      PharmacyMutationResult(
        workflow: PharmacyOrderWorkflow(
          order: _continuedPartialOrder,
          items: _continuedPartialOrder.items,
        ),
        summary: const PharmacyWorkbenchSummary(
          partiallyDispensedQueue: 1,
          totalOrders: 1,
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

/// Next-action labels live on [AppButton]; Partial "Dispense" progress column
/// headers do not.
Finder _actionLabel(String label) => find.descendant(
  of: find.byType(AppButton),
  matching: find.text(label),
);

Future<void> _pumpPartialTab(
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
    initialLocation: '/pharmacy?section=partial',
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
    registerFallbackValue(const PharmacyInventoryStockQuery());
    registerFallbackValue(const PharmacyDrugQuery());
    registerFallbackValue(const PharmacyFormularyQuery());
    registerFallbackValue(const <PharmacyDispenseLineInput>[]);
    registerFallbackValue('');
  });

  group('PharmacyPartialAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          PharmacyPartialAtomPermissions.tab,
          pharmacyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPartialAtomPermissions.write,
          pharmacyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPartialAtomPermissions.dispense,
          pharmacyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPartialAtomPermissions.recordPayment,
          pharmacyRecordPaymentRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPartialAtomPermissions.catalogWrite,
          pharmacyCatalogWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPartialAtomPermissions.routeEntry,
          pharmacyWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPartialAtomPermissions.catalogEntry,
          pharmacyWorkspaceCatalogEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPartialAtomPermissions.controlledDrugAudit,
          pharmacyControlledDrugAuditRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPartialAtomPermissions.printInstructions,
          pharmacyPrintInstructionsRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyPartialAtomPermissions.dispenseProgress,
          pharmacyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionTabRequirement(PharmacyDeskSection.inProgress),
          PharmacyPartialAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionWriteRequirement(PharmacyDeskSection.inProgress),
          PharmacyPartialAtomPermissions.write,
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
      expect(PharmacyPartialAtomPermissions.tab, isNotNull);
      expect(PharmacyPartialAtomPermissions.listChrome, isNotNull);
      expect(PharmacyPartialAtomPermissions.search, isNotNull);
      expect(PharmacyPartialAtomPermissions.filters, isNotNull);
      expect(PharmacyPartialAtomPermissions.settings, isNotNull);
      expect(PharmacyPartialAtomPermissions.pagination, isNotNull);
      expect(PharmacyPartialAtomPermissions.dispenseProgress, isNotNull);
      expect(PharmacyPartialAtomPermissions.empty, isNotNull);
      expect(PharmacyPartialAtomPermissions.loading, isNotNull);
      expect(PharmacyPartialAtomPermissions.retry, isNotNull);
      expect(PharmacyPartialAtomPermissions.success, isNotNull);
      expect(PharmacyPartialAtomPermissions.validation, isNotNull);
      expect(PharmacyPartialAtomPermissions.rowSelect, isNotNull);
      expect(PharmacyPartialAtomPermissions.detail, isNotNull);
      expect(PharmacyPartialAtomPermissions.nextAction, isNotNull);
      expect(PharmacyPartialAtomPermissions.nextActionWrite, isNotNull);
      expect(PharmacyPartialAtomPermissions.create, isNotNull);
      expect(PharmacyPartialAtomPermissions.update, isNotNull);
      expect(PharmacyPartialAtomPermissions.delete, isNotNull);
      expect(PharmacyPartialAtomPermissions.dispense, isNotNull);
      expect(PharmacyPartialAtomPermissions.attest, isNotNull);
      expect(PharmacyPartialAtomPermissions.returnItems, isNotNull);
      expect(PharmacyPartialAtomPermissions.cancelOrder, isNotNull);
      expect(PharmacyPartialAtomPermissions.mapStock, isNotNull);
      expect(PharmacyPartialAtomPermissions.priceSource, isNotNull);
      expect(PharmacyPartialAtomPermissions.recordPayment, isNotNull);
      expect(PharmacyPartialAtomPermissions.billingStatus, isNotNull);
      expect(PharmacyPartialAtomPermissions.printInstructions, isNotNull);
      expect(PharmacyPartialAtomPermissions.controlledDrugAudit, isNotNull);
      expect(PharmacyPartialAtomPermissions.catalogBrowse, isNotNull);
      expect(PharmacyPartialAtomPermissions.catalogWrite, isNotNull);
      expect(PharmacyPartialAtomPermissions.nestedBillingWrite, isNotNull);
      expect(PharmacyPartialAtomPermissions.nestedWrite, isNotNull);
      expect(PharmacyPartialAtomPermissions.nestedRead, isNotNull);
      expect(PharmacyPartialAtomPermissions.routeEntry, isNotNull);
      expect(PharmacyPartialAtomPermissions.catalogEntry, isNotNull);
    });

    test('∩ denial: missing pharmacy:read hides Partial tab gate', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
      );
      expect(PharmacyPartialAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(
        PharmacyPartialAtomPermissions.write.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        PharmacyPartialAtomPermissions.loading.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        PharmacyPartialAtomPermissions.routeEntry.isAllowed(writeOnly),
        isFalse,
      );
      expect(canViewPharmacyPartialTab(writeOnly), isFalse);
    });

    test('∩ full set: pharmacy:read + write mounts read and mutate atoms', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
      );
      expect(PharmacyPartialAtomPermissions.tab.isAllowed(writer), isTrue);
      expect(PharmacyPartialAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        PharmacyPartialAtomPermissions.dispense.isAllowed(writer),
        isTrue,
      );
      expect(
        PharmacyPartialAtomPermissions.success.isAllowed(writer),
        isTrue,
      );
      expect(canViewPharmacyPartialTab(writer), isTrue);
      expect(
        pharmacyAllowedSections(writer),
        contains(PharmacyDeskSection.inProgress),
      );
    });

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
          PharmacyPartialAtomPermissions.routeEntry.isAllowed(
            operationsReader,
          ),
          isTrue,
        );
        expect(
          PharmacyPartialAtomPermissions.tab.isAllowed(operationsReader),
          isFalse,
        );
        expect(
          PharmacyPartialAtomPermissions.write.isAllowed(operationsReader),
          isFalse,
        );
        expect(
          PharmacyPartialAtomPermissions.catalogBrowse.isAllowed(
            operationsReader,
          ),
          isFalse,
        );
        expect(canEnterPharmacyWorkspace(operationsReader), isTrue);
        expect(
          pharmacyAllowedSections(operationsReader),
          contains(PharmacyDeskSection.inProgress),
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
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
        );

        expect(
          PharmacyPartialAtomPermissions.catalogWrite.isAllowed(
            operationsWriter,
          ),
          isTrue,
        );
        expect(
          PharmacyPartialAtomPermissions.write.isAllowed(operationsWriter),
          isFalse,
        );
        expect(
          PharmacyPartialAtomPermissions.catalogWrite.isAllowed(reader),
          isFalse,
        );
      },
    );

    test('nested billing write ∩ denial without billing:write', () {
      final AppAccessPolicy pharmacyWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
      );
      final AppAccessPolicy withBilling = _policy(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
          AppPermissions.billingWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: pharmacyDispensingModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: billingPaymentsModule,
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      expect(
        PharmacyPartialAtomPermissions.recordPayment.isAllowed(
          pharmacyWriter,
        ),
        isFalse,
      );
      expect(
        PharmacyPartialAtomPermissions.nestedBillingWrite.isAllowed(
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
        PharmacyPartialAtomPermissions.controlledDrugAudit.isAllowed(
          pharmacyOnly,
        ),
        isFalse,
      );
      expect(
        PharmacyPartialAtomPermissions.controlledDrugAudit.isAllowed(
          withCompliance,
        ),
        isTrue,
      );
    });

    test('subscription strips Partial without pharmacy-dispensing', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );

      expect(PharmacyPartialAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        PharmacyPartialAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(
        PharmacyPartialAtomPermissions.routeEntry.isAllowed(noModule),
        isFalse,
      );
      expect(canViewPharmacyPartialTab(noModule), isFalse);
    });
  });

  group('pharmacy Partial UI permission enforcement', () {
    late _MockPharmacyRepository repository;

    setUp(() {
      repository = _MockPharmacyRepository();
      _stubPharmacyRepository(repository);
    });

    testWidgets(
      '∩ denial: read-only Partial keeps catalog/print path; Dispense absent',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
        );
        expect(PharmacyPartialAtomPermissions.tab.isAllowed(reader), isTrue);
        expect(
          PharmacyPartialAtomPermissions.dispense.isAllowed(reader),
          isFalse,
        );

        await _pumpPartialTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tab('Partial'), findsOneWidget);
        expect(_catalogAction(), findsOneWidget);
        expect(find.text('Amina Partial'), findsOneWidget);
        expect(_actionLabel('Dispense'), findsNothing);
        expect(_actionLabel('Cancel order'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Amina Partial'));
        await tester.pumpAndSettle();

        final Finder dialog = find.byType(AppDialog);
        expect(dialog, findsOneWidget);
        expect(find.text('PRESCRIPTION DETAIL'), findsOneWidget);
        expect(
          find.descendant(of: dialog, matching: find.text('Dispense')),
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
      'full write ∩: Dispense next-action and detail Dispense mount',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
          },
        );
        expect(
          PharmacyPartialAtomPermissions.dispense.isAllowed(writer),
          isTrue,
        );

        await _pumpPartialTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(find.text('Amina Partial'), findsOneWidget);
        expect(_actionLabel('Dispense'), findsAtLeastNWidgets(1));

        await tester.tap(find.text('Amina Partial'));
        await tester.pumpAndSettle();

        final Finder dialog = find.byType(AppDialog);
        expect(
          find.descendant(of: dialog, matching: find.text('Dispense')),
          findsOneWidget,
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
        await _pumpPartialTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        expect(find.text('Omar Partial Pay'), findsOneWidget);
        expect(_actionLabel('Record payment'), findsNothing);
        expect(_actionLabel('Dispense'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'nested billing write ∩: Record payment mounts with billing:write',
      (WidgetTester tester) async {
        await _pumpPartialTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
              AppPermissions.billingWrite,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: pharmacyDispensingModule,
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: billingPaymentsModule,
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        expect(_actionLabel('Record payment'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'subscription strip: pharmacy-dispensing missing omits Partial chrome',
      (WidgetTester tester) async {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
          },
          modules: const <AppModuleEntitlement>[],
        );

        await _pumpPartialTab(
          tester,
          repository: repository,
          accessPolicy: noModule,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Amina Partial'), findsNothing);
        expect(_actionLabel('Dispense'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∪ route entry: operations:read keeps Partial chrome read-only',
      (WidgetTester tester) async {
        await _pumpPartialTab(
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

        expect(_tab('Partial'), findsOneWidget);
        expect(find.text('Amina Partial'), findsOneWidget);
        expect(_actionLabel('Dispense'), findsNothing);
        expect(_catalogAction(), findsNothing);
      },
    );

    testWidgets(
      'authorized empty Partial remains observable (no routine no-access)',
      (WidgetTester tester) async {
        repository = _MockPharmacyRepository();
        _stubPharmacyRepository(
          repository,
          orders: const <PharmacyOrder>[],
        );

        await _pumpPartialTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        expect(_tab('Partial'), findsOneWidget);
        expect(find.text('No pharmacy orders'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'authorized Dispense opens dialog; zero qty keeps validation open',
      (WidgetTester tester) async {
        await _pumpPartialTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        await tester.tap(_actionLabel('Dispense').first);
        await tester.pumpAndSettle();

        expect(find.text('Prepare dispense'), findsAtLeastNWidgets(1));

        final Finder qtyField = find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(qtyField.last, '0');
        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Prepare dispense'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Prepare dispense'), findsAtLeastNWidgets(1));
        verifyNever(
          () => repository.prepareDispense(
            orderId: any(named: 'orderId'),
            items: any(named: 'items'),
            dispenseBatchRef: any(named: 'dispenseBatchRef'),
            statement: any(named: 'statement'),
            reason: any(named: 'reason'),
          ),
        );
      },
    );

    testWidgets(
      'authorized Dispense mutation syncs list and shows success snackbar',
      (WidgetTester tester) async {
        await _pumpPartialTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        await tester.tap(_actionLabel('Dispense').first);
        await tester.pumpAndSettle();

        expect(find.text('Prepare dispense'), findsAtLeastNWidgets(1));

        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Prepare dispense'),
          ),
        );
        await tester.pumpAndSettle();

        verify(
          () => repository.prepareDispense(
            orderId: 'order-partial',
            items: any(named: 'items'),
            dispenseBatchRef: any(named: 'dispenseBatchRef'),
            statement: any(named: 'statement'),
            reason: any(named: 'reason'),
          ),
        ).called(1);
        expect(find.text('Pharmacy workflow updated.'), findsOneWidget);
        expect(find.text('Amina Partial'), findsOneWidget);
      },
    );

    testWidgets('Partial desktop light theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpPartialTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
          },
        ),
        physicalSize: const Size(1280, 800),
        themeMode: ThemeMode.light,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppListTableGrid), findsOneWidget);
      expect(_catalogAction(), findsOneWidget);
      expect(_actionLabel('Dispense'), findsAtLeastNWidgets(1));
    });

    testWidgets('Partial mobile dark theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpPartialTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
          },
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppListTableGrid), findsNothing);
      expect(find.textContaining('Amina'), findsAtLeastNWidgets(1));
      expect(_actionLabel('Dispense'), findsAtLeastNWidgets(1));
    });
  });
}
