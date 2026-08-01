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

const PharmacyOrderItem _readyLine = PharmacyOrderItem(
  id: 'item-ready-1',
  drugDisplayName: 'Paracetamol',
  quantityPrescribed: 24,
  quantityDispensed: 0,
  quantityRemaining: 24,
);

const PharmacyOrder _readyOrder = PharmacyOrder(
  id: 'order-ready',
  displayId: 'PHO-READY',
  patientDisplayName: 'Noah Ready',
  location: 'OUTPATIENT',
  status: 'ORDERED',
  itemCount: 1,
  quantityPrescribedTotal: 24,
  items: <PharmacyOrderItem>[_readyLine],
);

const PharmacyOrder _dispensedReadyOrder = PharmacyOrder(
  id: 'order-ready',
  displayId: 'PHO-READY',
  patientDisplayName: 'Noah Ready',
  location: 'OUTPATIENT',
  status: 'PARTIALLY_DISPENSED',
  itemCount: 1,
  quantityPrescribedTotal: 24,
  quantityDispensedTotal: 24,
  items: <PharmacyOrderItem>[
    PharmacyOrderItem(
      id: 'item-ready-1',
      drugDisplayName: 'Paracetamol',
      quantityPrescribed: 24,
      quantityDispensed: 24,
      quantityRemaining: 0,
    ),
  ],
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
  items: <PharmacyOrderItem>[
    PharmacyOrderItem(
      id: 'item-pay-1',
      drugDisplayName: 'Ibuprofen',
      quantityPrescribed: 5,
      quantityDispensed: 0,
      quantityRemaining: 5,
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
    _readyOrder,
    _unpaidOrder,
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
      orElse: () => _readyOrder,
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
          order: _dispensedReadyOrder,
          items: _dispensedReadyOrder.items,
        ),
        summary: const PharmacyWorkbenchSummary(
          orderedQueue: 0,
          totalOrders: 1,
        ),
      ),
    ),
  );
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

Finder _catalogAction() => find.byTooltip('Catalog and stock');

/// Ready worklist has a "Dispense" progress column; action labels live on
/// [AppButton] only.
Finder _actionLabel(String label) => find.descendant(
  of: find.byType(AppButton),
  matching: find.text(label),
);

Future<void> _pumpReadyTab(
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
    initialLocation: '/pharmacy?section=ready',
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

  group('PharmacyReadyAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          PharmacyReadyAtomPermissions.tab,
          pharmacyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyReadyAtomPermissions.write,
          pharmacyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyReadyAtomPermissions.dispense,
          pharmacyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyReadyAtomPermissions.recordPayment,
          pharmacyRecordPaymentRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyReadyAtomPermissions.catalogWrite,
          pharmacyCatalogWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyReadyAtomPermissions.routeEntry,
          pharmacyWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyReadyAtomPermissions.catalogEntry,
          pharmacyWorkspaceCatalogEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyReadyAtomPermissions.controlledDrugAudit,
          pharmacyControlledDrugAuditRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyReadyAtomPermissions.printInstructions,
          pharmacyPrintInstructionsRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyReadyAtomPermissions.dispenseProgress,
          pharmacyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionTabRequirement(PharmacyDeskSection.queue),
          PharmacyReadyAtomPermissions.tab,
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
      expect(PharmacyReadyAtomPermissions.tab, isNotNull);
      expect(PharmacyReadyAtomPermissions.listChrome, isNotNull);
      expect(PharmacyReadyAtomPermissions.search, isNotNull);
      expect(PharmacyReadyAtomPermissions.filters, isNotNull);
      expect(PharmacyReadyAtomPermissions.settings, isNotNull);
      expect(PharmacyReadyAtomPermissions.pagination, isNotNull);
      expect(PharmacyReadyAtomPermissions.dispenseProgress, isNotNull);
      expect(PharmacyReadyAtomPermissions.empty, isNotNull);
      expect(PharmacyReadyAtomPermissions.loading, isNotNull);
      expect(PharmacyReadyAtomPermissions.retry, isNotNull);
      expect(PharmacyReadyAtomPermissions.success, isNotNull);
      expect(PharmacyReadyAtomPermissions.validation, isNotNull);
      expect(PharmacyReadyAtomPermissions.rowSelect, isNotNull);
      expect(PharmacyReadyAtomPermissions.detail, isNotNull);
      expect(PharmacyReadyAtomPermissions.nextAction, isNotNull);
      expect(PharmacyReadyAtomPermissions.nextActionWrite, isNotNull);
      expect(PharmacyReadyAtomPermissions.create, isNotNull);
      expect(PharmacyReadyAtomPermissions.update, isNotNull);
      expect(PharmacyReadyAtomPermissions.delete, isNotNull);
      expect(PharmacyReadyAtomPermissions.dispense, isNotNull);
      expect(PharmacyReadyAtomPermissions.attest, isNotNull);
      expect(PharmacyReadyAtomPermissions.returnItems, isNotNull);
      expect(PharmacyReadyAtomPermissions.cancelOrder, isNotNull);
      expect(PharmacyReadyAtomPermissions.mapStock, isNotNull);
      expect(PharmacyReadyAtomPermissions.priceSource, isNotNull);
      expect(PharmacyReadyAtomPermissions.recordPayment, isNotNull);
      expect(PharmacyReadyAtomPermissions.billingStatus, isNotNull);
      expect(PharmacyReadyAtomPermissions.printInstructions, isNotNull);
      expect(PharmacyReadyAtomPermissions.controlledDrugAudit, isNotNull);
      expect(PharmacyReadyAtomPermissions.catalogBrowse, isNotNull);
      expect(PharmacyReadyAtomPermissions.catalogWrite, isNotNull);
      expect(PharmacyReadyAtomPermissions.nestedBillingWrite, isNotNull);
      expect(PharmacyReadyAtomPermissions.nestedWrite, isNotNull);
      expect(PharmacyReadyAtomPermissions.nestedRead, isNotNull);
      expect(PharmacyReadyAtomPermissions.routeEntry, isNotNull);
      expect(PharmacyReadyAtomPermissions.catalogEntry, isNotNull);
    });

    test('∩ denial: missing pharmacy:read hides Ready tab gate', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
      );
      expect(PharmacyReadyAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(PharmacyReadyAtomPermissions.write.isAllowed(writeOnly), isTrue);
      expect(
        PharmacyReadyAtomPermissions.loading.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        PharmacyReadyAtomPermissions.routeEntry.isAllowed(writeOnly),
        isFalse,
      );
      expect(canViewPharmacyReadyTab(writeOnly), isFalse);
    });

    test('∩ full set: pharmacy:read + write mounts read and mutate atoms', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
      );
      expect(PharmacyReadyAtomPermissions.tab.isAllowed(writer), isTrue);
      expect(PharmacyReadyAtomPermissions.write.isAllowed(writer), isTrue);
      expect(PharmacyReadyAtomPermissions.dispense.isAllowed(writer), isTrue);
      expect(PharmacyReadyAtomPermissions.success.isAllowed(writer), isTrue);
      expect(canViewPharmacyReadyTab(writer), isTrue);
      expect(
        pharmacyAllowedSections(writer),
        contains(PharmacyDeskSection.queue),
      );
      expect(pharmacyFallbackSection(writer), PharmacyDeskSection.queue);
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
          PharmacyReadyAtomPermissions.routeEntry.isAllowed(operationsReader),
          isTrue,
        );
        expect(
          PharmacyReadyAtomPermissions.tab.isAllowed(operationsReader),
          isFalse,
        );
        expect(
          PharmacyReadyAtomPermissions.write.isAllowed(operationsReader),
          isFalse,
        );
        expect(canEnterPharmacyWorkspace(operationsReader), isTrue);
        expect(
          pharmacyAllowedSections(operationsReader),
          contains(PharmacyDeskSection.queue),
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
          PharmacyReadyAtomPermissions.catalogWrite.isAllowed(operationsWriter),
          isTrue,
        );
        expect(
          PharmacyReadyAtomPermissions.write.isAllowed(operationsWriter),
          isFalse,
        );
        expect(
          PharmacyReadyAtomPermissions.catalogWrite.isAllowed(reader),
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
        PharmacyReadyAtomPermissions.recordPayment.isAllowed(pharmacyWriter),
        isFalse,
      );
      expect(
        PharmacyReadyAtomPermissions.nestedBillingWrite.isAllowed(withBilling),
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
        PharmacyReadyAtomPermissions.controlledDrugAudit.isAllowed(
          pharmacyOnly,
        ),
        isFalse,
      );
      expect(
        PharmacyReadyAtomPermissions.controlledDrugAudit.isAllowed(
          withCompliance,
        ),
        isTrue,
      );
    });

    test('subscription strips Ready without pharmacy-dispensing', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );

      expect(PharmacyReadyAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(PharmacyReadyAtomPermissions.write.isAllowed(noModule), isFalse);
      expect(
        PharmacyReadyAtomPermissions.routeEntry.isAllowed(noModule),
        isFalse,
      );
      expect(canViewPharmacyReadyTab(noModule), isFalse);
    });
  });

  group('pharmacy Ready UI permission enforcement', () {
    late _MockPharmacyRepository repository;

    setUp(() {
      repository = _MockPharmacyRepository();
      _stubPharmacyRepository(repository);
    });

    testWidgets(
      '∩ denial: read-only Ready keeps catalog/print path; Dispense absent',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
        );
        expect(PharmacyReadyAtomPermissions.tab.isAllowed(reader), isTrue);
        expect(
          PharmacyReadyAtomPermissions.dispense.isAllowed(reader),
          isFalse,
        );

        await _pumpReadyTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tab('Ready'), findsOneWidget);
        expect(_catalogAction(), findsOneWidget);
        expect(find.text('Noah Ready'), findsOneWidget);
        expect(_actionLabel('Dispense'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Noah Ready'));
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
          PharmacyReadyAtomPermissions.dispense.isAllowed(writer),
          isTrue,
        );

        await _pumpReadyTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(find.text('Noah Ready'), findsOneWidget);
        expect(_actionLabel('Dispense'), findsAtLeastNWidgets(1));

        await tester.tap(find.text('Noah Ready'));
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
        await _pumpReadyTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        expect(find.text('Cathy Payment'), findsOneWidget);
        expect(_actionLabel('Record payment'), findsNothing);
        expect(_actionLabel('Dispense'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'nested billing write ∩: Record payment mounts with billing:write',
      (WidgetTester tester) async {
        await _pumpReadyTab(
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
      'subscription strip: pharmacy-dispensing missing omits Ready chrome',
      (WidgetTester tester) async {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
          },
          modules: const <AppModuleEntitlement>[],
        );

        await _pumpReadyTab(
          tester,
          repository: repository,
          accessPolicy: noModule,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Noah Ready'), findsNothing);
        expect(_actionLabel('Dispense'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∪ route entry: operations:read keeps Ready chrome read-only',
      (WidgetTester tester) async {
        await _pumpReadyTab(
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

        expect(_tab('Ready'), findsOneWidget);
        expect(find.text('Noah Ready'), findsOneWidget);
        expect(_actionLabel('Dispense'), findsNothing);
        expect(_catalogAction(), findsNothing);
      },
    );

    testWidgets(
      'authorized empty Ready remains observable (no routine no-access)',
      (WidgetTester tester) async {
        _stubPharmacyRepository(
          repository,
          orders: const <PharmacyOrder>[],
        );

        await _pumpReadyTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        expect(_tab('Ready'), findsOneWidget);
        expect(find.text('No pharmacy orders'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'authorized Dispense opens dialog; zero qty keeps validation open',
      (WidgetTester tester) async {
        await _pumpReadyTab(
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
        await _pumpReadyTab(
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
            orderId: 'order-ready',
            items: any(named: 'items'),
            dispenseBatchRef: any(named: 'dispenseBatchRef'),
            statement: any(named: 'statement'),
            reason: any(named: 'reason'),
          ),
        ).called(1);
        expect(find.text('Pharmacy workflow updated.'), findsOneWidget);
        expect(find.text('Noah Ready'), findsOneWidget);
      },
    );

    testWidgets('Ready desktop light theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpReadyTab(
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
      expect(find.byType(DataTable), findsOneWidget);
      expect(_catalogAction(), findsOneWidget);
      expect(_actionLabel('Dispense'), findsAtLeastNWidgets(1));
    });

    testWidgets('Ready mobile dark theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpReadyTab(
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
      expect(find.byType(DataTable), findsNothing);
      expect(find.textContaining('Noah'), findsAtLeastNWidgets(1));
      expect(_actionLabel('Dispense'), findsAtLeastNWidgets(1));
    });
  });
}
