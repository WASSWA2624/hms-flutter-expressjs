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

const PharmacyOrderItem _dispensedItem = PharmacyOrderItem(
  id: 'item-done',
  drugDisplayName: 'Amoxicillin 500mg',
  quantityPrescribed: 10,
  quantityDispensed: 10,
  quantityRemaining: 0,
);

const PharmacyOrder _completedOrder = PharmacyOrder(
  id: 'order-done',
  displayId: 'PHO-DONE',
  patientDisplayName: 'Dana Done',
  location: 'OUTPATIENT',
  status: 'DISPENSED',
  itemCount: 1,
  quantityPrescribedTotal: 10,
  quantityDispensedTotal: 10,
  items: <PharmacyOrderItem>[_dispensedItem],
);

const PharmacyOrder _returnedOrder = PharmacyOrder(
  id: 'order-done',
  displayId: 'PHO-DONE',
  patientDisplayName: 'Dana Done',
  location: 'OUTPATIENT',
  status: 'DISPENSED',
  itemCount: 1,
  quantityPrescribedTotal: 10,
  quantityDispensedTotal: 8,
  quantityReturnedTotal: 2,
  items: <PharmacyOrderItem>[
    PharmacyOrderItem(
      id: 'item-done',
      drugDisplayName: 'Amoxicillin 500mg',
      quantityPrescribed: 10,
      quantityDispensed: 8,
      quantityReturned: 2,
      quantityRemaining: 0,
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
  List<PharmacyOrder> completedOrders = const <PharmacyOrder>[_completedOrder],
}) {
  when(() => repository.loadWorkbench(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final PharmacyWorkbenchQuery query =
        invocation.positionalArguments.single as PharmacyWorkbenchQuery;
    List<PharmacyOrder> items = List<PharmacyOrder>.of(completedOrders);
    final String? status = query.status?.trim().toUpperCase();
    if (status != null && status.isNotEmpty) {
      items = items
          .where(
            (PharmacyOrder order) =>
                (order.status ?? '').toUpperCase() == status,
          )
          .toList(growable: false);
    }
    return Result<PharmacyWorkbench>.success(
      PharmacyWorkbench(
        summary: PharmacyWorkbenchSummary(
          dispensedOrders: items.length,
          totalOrders: items.length,
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
    final PharmacyOrder order = completedOrders.firstWhere(
      (PharmacyOrder item) => item.id == orderId || item.displayId == orderId,
      orElse: () => _completedOrder,
    );
    return Result<PharmacyOrderWorkflow>.success(
      PharmacyOrderWorkflow(
        order: order,
        items: order.items,
        nextActions: PharmacyNextActions(canReturn: order.canReturn),
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
    () => repository.returnDispense(
      orderId: any(named: 'orderId'),
      items: any(named: 'items'),
      reason: any(named: 'reason'),
      notes: any(named: 'notes'),
    ),
  ).thenAnswer(
    (_) async => Result<PharmacyMutationResult>.success(
      PharmacyMutationResult(
        workflow: PharmacyOrderWorkflow(
          order: _returnedOrder,
          items: _returnedOrder.items,
        ),
        summary: const PharmacyWorkbenchSummary(dispensedOrders: 1),
      ),
    ),
  );
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabToolbarPrimary),
  matching: find.text(label),
);

Future<void> _pumpCompletedTab(
  WidgetTester tester, {
  required _MockPharmacyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1280, 800),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubPharmacyRepository(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/pharmacy?section=completed',
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
    registerFallbackValue(const <PharmacyReturnLineInput>[]);
    registerFallbackValue('');
  });

  group('PharmacyCompletedAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          PharmacyCompletedAtomPermissions.tab,
          pharmacyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCompletedAtomPermissions.write,
          pharmacyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCompletedAtomPermissions.returnItems,
          pharmacyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCompletedAtomPermissions.recordPayment,
          pharmacyRecordPaymentRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCompletedAtomPermissions.catalogWrite,
          pharmacyCatalogWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCompletedAtomPermissions.routeEntry,
          pharmacyWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCompletedAtomPermissions.catalogEntry,
          pharmacyWorkspaceCatalogEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCompletedAtomPermissions.controlledDrugAudit,
          pharmacyControlledDrugAuditRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCompletedAtomPermissions.printInstructions,
          pharmacyPrintInstructionsRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCompletedAtomPermissions.dispenseProgress,
          pharmacyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCompletedAtomPermissions.billingStatus,
          pharmacyBillingStatusReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionTabRequirement(PharmacyDeskSection.completed),
          PharmacyCompletedAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionWriteRequirement(PharmacyDeskSection.completed),
          PharmacyCompletedAtomPermissions.write,
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
      expect(PharmacyCompletedAtomPermissions.tab, isNotNull);
      expect(PharmacyCompletedAtomPermissions.listChrome, isNotNull);
      expect(PharmacyCompletedAtomPermissions.search, isNotNull);
      expect(PharmacyCompletedAtomPermissions.filters, isNotNull);
      expect(PharmacyCompletedAtomPermissions.settings, isNotNull);
      expect(PharmacyCompletedAtomPermissions.pagination, isNotNull);
      expect(PharmacyCompletedAtomPermissions.dispenseProgress, isNotNull);
      expect(PharmacyCompletedAtomPermissions.empty, isNotNull);
      expect(PharmacyCompletedAtomPermissions.loading, isNotNull);
      expect(PharmacyCompletedAtomPermissions.retry, isNotNull);
      expect(PharmacyCompletedAtomPermissions.success, isNotNull);
      expect(PharmacyCompletedAtomPermissions.validation, isNotNull);
      expect(PharmacyCompletedAtomPermissions.rowSelect, isNotNull);
      expect(PharmacyCompletedAtomPermissions.detail, isNotNull);
      expect(PharmacyCompletedAtomPermissions.nextAction, isNotNull);
      expect(PharmacyCompletedAtomPermissions.nextActionWrite, isNotNull);
      expect(PharmacyCompletedAtomPermissions.create, isNotNull);
      expect(PharmacyCompletedAtomPermissions.update, isNotNull);
      expect(PharmacyCompletedAtomPermissions.delete, isNotNull);
      expect(PharmacyCompletedAtomPermissions.dispense, isNotNull);
      expect(PharmacyCompletedAtomPermissions.attest, isNotNull);
      expect(PharmacyCompletedAtomPermissions.returnItems, isNotNull);
      expect(PharmacyCompletedAtomPermissions.cancelOrder, isNotNull);
      expect(PharmacyCompletedAtomPermissions.mapStock, isNotNull);
      expect(PharmacyCompletedAtomPermissions.priceSource, isNotNull);
      expect(PharmacyCompletedAtomPermissions.recordPayment, isNotNull);
      expect(PharmacyCompletedAtomPermissions.billingStatus, isNotNull);
      expect(PharmacyCompletedAtomPermissions.printInstructions, isNotNull);
      expect(PharmacyCompletedAtomPermissions.controlledDrugAudit, isNotNull);
      expect(PharmacyCompletedAtomPermissions.catalogBrowse, isNotNull);
      expect(PharmacyCompletedAtomPermissions.catalogWrite, isNotNull);
      expect(PharmacyCompletedAtomPermissions.nestedBillingWrite, isNotNull);
      expect(PharmacyCompletedAtomPermissions.nestedWrite, isNotNull);
      expect(PharmacyCompletedAtomPermissions.nestedRead, isNotNull);
      expect(PharmacyCompletedAtomPermissions.routeEntry, isNotNull);
      expect(PharmacyCompletedAtomPermissions.catalogEntry, isNotNull);
    });

    test('∩ denial: missing pharmacy:read hides Completed tab gate', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
      );
      expect(PharmacyCompletedAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(
        PharmacyCompletedAtomPermissions.write.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        PharmacyCompletedAtomPermissions.loading.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        PharmacyCompletedAtomPermissions.routeEntry.isAllowed(writeOnly),
        isFalse,
      );
      expect(canViewPharmacyCompletedTab(writeOnly), isFalse);
    });

    test('∩ full set: pharmacy:read + write mounts read and mutate atoms', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
      );
      expect(PharmacyCompletedAtomPermissions.tab.isAllowed(writer), isTrue);
      expect(PharmacyCompletedAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        PharmacyCompletedAtomPermissions.returnItems.isAllowed(writer),
        isTrue,
      );
      expect(
        PharmacyCompletedAtomPermissions.success.isAllowed(writer),
        isTrue,
      );
      expect(canViewPharmacyCompletedTab(writer), isTrue);
      expect(
        pharmacyAllowedSections(writer),
        contains(PharmacyDeskSection.completed),
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
          PharmacyCompletedAtomPermissions.routeEntry.isAllowed(
            operationsReader,
          ),
          isTrue,
        );
        expect(
          PharmacyCompletedAtomPermissions.tab.isAllowed(operationsReader),
          isFalse,
        );
        expect(
          PharmacyCompletedAtomPermissions.write.isAllowed(operationsReader),
          isFalse,
        );
        expect(canEnterPharmacyWorkspace(operationsReader), isTrue);
        expect(
          pharmacyAllowedSections(operationsReader),
          contains(PharmacyDeskSection.completed),
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
          PharmacyCompletedAtomPermissions.catalogWrite.isAllowed(
            operationsWriter,
          ),
          isTrue,
        );
        expect(
          PharmacyCompletedAtomPermissions.write.isAllowed(operationsWriter),
          isFalse,
        );
        expect(
          PharmacyCompletedAtomPermissions.catalogWrite.isAllowed(reader),
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
        PharmacyCompletedAtomPermissions.recordPayment.isAllowed(
          pharmacyWriter,
        ),
        isFalse,
      );
      expect(
        PharmacyCompletedAtomPermissions.nestedBillingWrite.isAllowed(
          withBilling,
        ),
        isTrue,
      );
    });

    test('billing status ∩ denial without billing:read', () {
      final AppAccessPolicy pharmacyOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
      );
      final AppAccessPolicy withBillingRead = _policy(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.billingRead,
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
        PharmacyCompletedAtomPermissions.billingStatus.isAllowed(pharmacyOnly),
        isFalse,
      );
      expect(
        PharmacyCompletedAtomPermissions.billingStatus.isAllowed(
          withBillingRead,
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
        PharmacyCompletedAtomPermissions.controlledDrugAudit.isAllowed(
          pharmacyOnly,
        ),
        isFalse,
      );
      expect(
        PharmacyCompletedAtomPermissions.controlledDrugAudit.isAllowed(
          withCompliance,
        ),
        isTrue,
      );
    });

    test('subscription strips Completed without pharmacy-dispensing', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );

      expect(PharmacyCompletedAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        PharmacyCompletedAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(
        PharmacyCompletedAtomPermissions.routeEntry.isAllowed(noModule),
        isFalse,
      );
      expect(canViewPharmacyCompletedTab(noModule), isFalse);
    });
  });

  group('pharmacy Completed UI permission enforcement', () {
    late _MockPharmacyRepository repository;

    setUp(() {
      repository = _MockPharmacyRepository();
    });

    testWidgets(
      '∩ denial: read-only Completed keeps catalog/print path; Return absent',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
        );
        expect(PharmacyCompletedAtomPermissions.tab.isAllowed(reader), isTrue);
        expect(
          PharmacyCompletedAtomPermissions.returnItems.isAllowed(reader),
          isFalse,
        );

        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(_tab('Completed'), findsOneWidget);
        expect(_toolbarPrimary('Catalog and stock'), findsOneWidget);
        expect(find.text('Dana Done'), findsOneWidget);
        expect(find.text('Return'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Dana Done'));
        await tester.pumpAndSettle();

        final Finder dialog = find.byType(AppDialog);
        expect(dialog, findsOneWidget);
        expect(find.text('PRESCRIPTION DETAIL'), findsOneWidget);
        expect(
          find.descendant(of: dialog, matching: find.text('Return')),
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
      'full write ∩: Return next-action and detail Return mount',
      (WidgetTester tester) async {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
          },
        );
        expect(
          PharmacyCompletedAtomPermissions.returnItems.isAllowed(writer),
          isTrue,
        );

        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: writer,
        );

        expect(find.text('Dana Done'), findsOneWidget);
        expect(find.text('Return'), findsAtLeastNWidgets(1));

        await tester.tap(find.text('Dana Done'));
        await tester.pumpAndSettle();

        final Finder dialog = find.byType(AppDialog);
        expect(
          find.descendant(of: dialog, matching: find.text('Return')),
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
      'nested cross-module matrix _(n/a)_: no billing chrome on Completed list',
      (WidgetTester tester) async {
        await _pumpCompletedTab(
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

        expect(find.text('Dana Done'), findsOneWidget);
        expect(find.text('Record payment'), findsNothing);
        expect(find.text('Return'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'billing status ∩ denial: Payment clearance absent in Completed detail',
      (WidgetTester tester) async {
        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        await tester.tap(find.text('Dana Done'));
        await tester.pumpAndSettle();

        final Finder dialog = find.byType(AppDialog);
        expect(dialog, findsOneWidget);

        final Finder showMore = find.descendant(
          of: dialog,
          matching: find.byIcon(Icons.expand_more),
        );
        if (showMore.evaluate().isNotEmpty) {
          await tester.tap(showMore);
          await tester.pumpAndSettle();
        }

        expect(
          find.descendant(
            of: dialog,
            matching: find.text('Payment clearance: '),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialog,
            matching: find.textContaining('Amount due'),
          ),
          findsNothing,
        );
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'billing status ∩ full set: Payment clearance mounts in Completed detail',
      (WidgetTester tester) async {
        await _pumpCompletedTab(
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
              AppModuleEntitlement(
                code: billingPaymentsModule,
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        await tester.tap(find.text('Dana Done'));
        await tester.pumpAndSettle();

        final Finder dialog = find.byType(AppDialog);
        expect(dialog, findsOneWidget);

        await tester.tap(
          find.descendant(of: dialog, matching: find.byIcon(Icons.expand_more)),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: dialog,
            matching: find.text('Payment clearance: '),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'subscription strip: pharmacy-dispensing missing omits Completed chrome',
      (WidgetTester tester) async {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
          },
          modules: const <AppModuleEntitlement>[],
        );

        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: noModule,
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.text('Dana Done'), findsNothing);
        expect(find.text('Return'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∪ route entry: operations:read keeps Completed chrome read-only '
      '(catalog browse ∩ pharmacy:read strips Catalog primary)',
      (WidgetTester tester) async {
        await _pumpCompletedTab(
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

        expect(_tab('Completed'), findsOneWidget);
        expect(find.text('Dana Done'), findsOneWidget);
        expect(find.text('Return'), findsNothing);
        expect(_toolbarPrimary('Catalog and stock'), findsNothing);
      },
    );

    testWidgets(
      'authorized empty Completed remains observable (no routine no-access)',
      (WidgetTester tester) async {
        repository = _MockPharmacyRepository();
        _stubPharmacyRepository(
          repository,
          completedOrders: const <PharmacyOrder>[],
        );

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final GoRouter router = GoRouter(
          initialLocation: '/pharmacy?section=completed',
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
              appAccessPolicyProvider.overrideWithValue(
                _policy(
                  permissions: <AppPermission>{AppPermissions.pharmacyRead},
                ),
              ),
            ],
            child: MaterialApp.router(
              theme: ThemeData.light(useMaterial3: true),
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(_tab('Completed'), findsOneWidget);
        expect(find.text('No pharmacy orders'), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'authorized Return opens dialog; empty selection keeps validation open',
      (WidgetTester tester) async {
        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        await tester.tap(find.text('Dana Done'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Return'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('RETURN MEDICINES'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Return'),
          ).last,
        );
        await tester.pumpAndSettle();

        expect(find.text('RETURN MEDICINES'), findsOneWidget);
        verifyNever(
          () => repository.returnDispense(
            orderId: any(named: 'orderId'),
            items: any(named: 'items'),
            reason: any(named: 'reason'),
            notes: any(named: 'notes'),
          ),
        );
      },
    );

    testWidgets(
      'authorized Return mutation syncs list and shows success snackbar',
      (WidgetTester tester) async {
        await _pumpCompletedTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        await tester.tap(
          find
              .descendant(
                of: find.byType(DataTable),
                matching: find.text('Return'),
              )
              .first,
        );
        await tester.pumpAndSettle();

        expect(find.text('RETURN MEDICINES'), findsOneWidget);
        verify(() => repository.loadOrderWorkflow('order-done')).called(1);

        // Reason is the first text field; notes is the second.
        final Finder returnFields = find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(returnFields.at(0), 'Patient returned unused pack');

        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Edit'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('EDIT RETURN LINE'), findsOneWidget);
        final Finder editFields = find.descendant(
          of: find.byType(AppDialog).last,
          matching: find.byType(TextField),
        );
        await tester.enterText(editFields.first, '2');
        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog).last,
            matching: find.text('Save'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.widgetWithText(AppButton, 'Return'),
          ),
        );
        await tester.pumpAndSettle();

        verify(
          () => repository.returnDispense(
            orderId: 'order-done',
            items: any(named: 'items'),
            reason: 'Patient returned unused pack',
            notes: any(named: 'notes'),
          ),
        ).called(1);
        expect(find.text('Pharmacy workflow updated.'), findsOneWidget);
        expect(find.text('Dana Done'), findsOneWidget);
      },
    );

    testWidgets('Completed desktop light theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpCompletedTab(
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
      expect(_toolbarPrimary('Catalog and stock'), findsOneWidget);
      expect(find.text('Return'), findsAtLeastNWidgets(1));
    });

    testWidgets('Completed mobile dark theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpCompletedTab(
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
      expect(find.textContaining('Dana'), findsAtLeastNWidgets(1));
      expect(find.text('Return'), findsAtLeastNWidgets(1));
    });
  });
}
