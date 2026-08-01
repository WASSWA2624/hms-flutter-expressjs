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

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: pharmacyDispensingModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  List<String> roles = const <String>['PHARMACIST'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
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

const PharmacyOrder _unpaidOrder = PharmacyOrder(
  id: 'order-pay',
  displayId: 'PHO-PAY',
  patientDisplayName: 'Cathy Payment',
  location: 'OUTPATIENT',
  status: 'ORDERED',
  paymentStatus: 'UNPAID',
  itemCount: 1,
  quantityPrescribedTotal: 5,
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

void _stubPharmacyRepository(_MockPharmacyRepository repository) {
  when(() => repository.loadWorkbench(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final PharmacyWorkbenchQuery query =
        invocation.positionalArguments.single as PharmacyWorkbenchQuery;
    List<PharmacyOrder> items = <PharmacyOrder>[
      _readyOrder,
      _unpaidOrder,
      _partialOrder,
      _unpaidPartialOrder,
    ];
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
        summary: const PharmacyWorkbenchSummary(
          orderedQueue: 2,
          partiallyDispensedQueue: 2,
          pendingPaymentQueue: 2,
          dispensedOrders: 0,
          totalOrders: 4,
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
    final PharmacyOrder order =
        <PharmacyOrder>[
          _readyOrder,
          _unpaidOrder,
          _partialOrder,
          _unpaidPartialOrder,
        ].firstWhere(
          (PharmacyOrder item) =>
              item.id == orderId || item.displayId == orderId,
          orElse: () => _readyOrder,
        );
    return Result<PharmacyOrderWorkflow>.success(
      PharmacyOrderWorkflow(
        order: order,
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
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

Finder _catalogAction() => find.byTooltip('Catalog and stock');

/// Next-action / quick-action labels live on [AppButton]; table column headers
/// such as the Partial/Ready "Dispense" progress column do not.
Finder _actionLabel(String label) => find.descendant(
  of: find.byType(AppButton),
  matching: find.text(label),
);

Future<void> _pumpPharmacyWorkspace(
  WidgetTester tester, {
  required _MockPharmacyRepository repository,
  required AppAccessPolicy accessPolicy,
  required String initialLocation,
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
    initialLocation: initialLocation,
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

Future<void> _pumpPendingPaymentWorkspace(
  WidgetTester tester, {
  required _MockPharmacyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1280, 800),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return _pumpPharmacyWorkspace(
    tester,
    repository: repository,
    accessPolicy: accessPolicy,
    physicalSize: physicalSize,
    themeMode: themeMode,
    initialLocation: '/pharmacy?section=pending-payment',
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
  return _policyFor(
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
  return _policyFor(
    permissions: <AppPermission>{
      AppPermissions.pharmacyRead,
      AppPermissions.billingRead,
      AppPermissions.pharmacyWrite,
      if (includeBillingWrite) AppPermissions.billingWrite,
    },
    modules: _pharmacyAndBillingModules,
  );
}

Future<void> _pumpReadyWorkspace(
  WidgetTester tester, {
  required _MockPharmacyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1280, 800),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return _pumpPharmacyWorkspace(
    tester,
    repository: repository,
    accessPolicy: accessPolicy,
    physicalSize: physicalSize,
    themeMode: themeMode,
    initialLocation: '/pharmacy?section=ready',
  );
}

void main() {
  group('pharmacy access requirements', () {
    test('read ∩ needs pharmacy:read and pharmacy-dispensing', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
      );
      final AppAccessPolicy writerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
      );
      final AppAccessPolicy noModule = _policyFor(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
        modules: const <AppModuleEntitlement>[],
      );

      expect(pharmacyWorkspaceReadRequirement.isAllowed(reader), isTrue);
      expect(pharmacyWorkspaceReadRequirement.isAllowed(writerOnly), isFalse);
      expect(pharmacyWorkspaceReadRequirement.isAllowed(noModule), isFalse);
      expect(canReadPharmacy(reader), isTrue);
      expect(canReadPharmacy(writerOnly), isFalse);
    });

    test('write ∩ needs pharmacy:write and pharmacy-dispensing (matrix all-of)', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
      );
      final AppAccessPolicy writeWithoutModule = _policyFor(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
        modules: const <AppModuleEntitlement>[],
      );

      expect(pharmacyWorkspaceWriteRequirement.isAllowed(reader), isFalse);
      expect(pharmacyWorkspaceWriteRequirement.isAllowed(writer), isTrue);
      expect(
        pharmacyWorkspaceWriteRequirement.isAllowed(writeWithoutModule),
        isFalse,
      );
      expect(canWritePharmacy(writer), isTrue);
      expect(canWritePharmacy(reader), isFalse);
    });

    test(
      'route entry ∪ allows pharmacy:read | operations:read '
      '(matrix view ∩ remains pharmacy:read)',
      () {
        final AppAccessPolicy pharmacyReader = _policyFor(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
        );
        final AppAccessPolicy operationsReader = _policyFor(
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
        final AppAccessPolicy neither = _policyFor(
          permissions: <AppPermission>{AppPermissions.patientRead},
        );

        expect(
          pharmacyWorkspaceRouteEntryRequirement.isAllowed(pharmacyReader),
          isTrue,
        );
        expect(
          pharmacyWorkspaceRouteEntryRequirement.isAllowed(operationsReader),
          isTrue,
        );
        expect(
          pharmacyWorkspaceRouteEntryRequirement.isAllowed(neither),
          isFalse,
        );
        expect(canEnterPharmacyWorkspace(operationsReader), isTrue);
        expect(canReadPharmacy(operationsReader), isFalse);
        expect(canWritePharmacy(operationsReader), isFalse);
      },
    );

    test('catalog entry stays ∩ pharmacy:read (RouteAccessCatalog)', () {
      expect(
        identical(
          pharmacyWorkspaceCatalogEntryRequirement,
          RouteAccessCatalog.pharmacyEntry,
        ),
        isTrue,
      );
    });

    test(
      'record payment ∩ denial when billing:write missing '
      '(pharmacy:write alone insufficient)',
      () {
        final AppAccessPolicy pharmacyWriterOnly = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
          },
        );
        final AppAccessPolicy withBillingWrite = _policyFor(
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

        expect(canRecordPharmacyPayment(pharmacyWriterOnly), isFalse);
        expect(canRecordPharmacyPayment(withBillingWrite), isTrue);
        expect(
          identical(
            pharmacyRecordPaymentRequirement,
            billingWorkspaceWriteRequirement,
          ),
          isTrue,
        );
      },
    );

    test(
      'catalog write ∪ allows pharmacy:write | operations:write '
      '(source gate; matrix narrative ∩ pharmacy:write)',
      () {
        final AppAccessPolicy pharmacyWriter = _policyFor(
          permissions: <AppPermission>{AppPermissions.pharmacyWrite},
        );
        final AppAccessPolicy operationsWriter = _policyFor(
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
        final AppAccessPolicy reader = _policyFor(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
        );

        expect(canWritePharmacyCatalog(pharmacyWriter), isTrue);
        expect(canWritePharmacyCatalog(operationsWriter), isTrue);
        expect(canWritePharmacyCatalog(reader), isFalse);
        expect(canWritePharmacy(operationsWriter), isFalse);
      },
    );

    test('controlled-drug audit ∩ denial when compliance:read missing', () {
      final AppAccessPolicy pharmacyReader = _policyFor(
        permissions: <AppPermission>{AppPermissions.pharmacyRead},
      );
      final AppAccessPolicy withCompliance = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.complianceRead,
        },
      );

      expect(canViewPharmacyControlledDrugAudit(pharmacyReader), isFalse);
      expect(canViewPharmacyControlledDrugAudit(withCompliance), isTrue);
    });

    test('subscription strips write without pharmacy-dispensing module', () {
      final AppAccessPolicy writerNoModule = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.pharmacyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );

      expect(canWritePharmacy(writerNoModule), isFalse);
      expect(canReadPharmacy(writerNoModule), isFalse);
      expect(canEnterPharmacyWorkspace(writerNoModule), isFalse);
    });

    test('Ready atom map reuses feature *Requirement helpers', () {
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
          PharmacyReadyAtomPermissions.printInstructions,
          pharmacyPrintInstructionsRequirement,
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
          pharmacySectionTabRequirement(PharmacyDeskSection.queue),
          PharmacyReadyAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test(
      'Ready tab present for pharmacy:read; operations-only keeps Ready '
      '(route ∪ without pharmacy:read)',
      () {
        final AppAccessPolicy pharmacyReader = _policyFor(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
        );
        final AppAccessPolicy operationsReader = _policyFor(
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

        expect(canViewPharmacyReadyTab(pharmacyReader), isTrue);
        expect(canViewPharmacyReadyTab(operationsReader), isFalse);
        expect(
          pharmacyAllowedSections(pharmacyReader),
          contains(PharmacyDeskSection.queue),
        );
        expect(
          pharmacyAllowedSections(operationsReader),
          contains(PharmacyDeskSection.queue),
        );
        expect(canBrowsePharmacyCatalog(operationsReader), isFalse);
        expect(canWritePharmacy(operationsReader), isFalse);
        expect(
          pharmacyFallbackSection(pharmacyReader),
          PharmacyDeskSection.queue,
        );
      },
    );

    test('Partial atom map reuses feature *Requirement helpers', () {
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
          PharmacyPartialAtomPermissions.controlledDrugAudit,
          pharmacyControlledDrugAuditRequirement,
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
    });

    test(
      'Partial tab present for pharmacy:read; operations-only keeps Partial '
      '(route ∪ without pharmacy:read)',
      () {
        final AppAccessPolicy pharmacyReader = _policyFor(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
        );
        final AppAccessPolicy operationsReader = _policyFor(
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

        expect(canViewPharmacyPartialTab(pharmacyReader), isTrue);
        expect(canViewPharmacyPartialTab(operationsReader), isFalse);
        expect(
          pharmacyAllowedSections(pharmacyReader),
          contains(PharmacyDeskSection.inProgress),
        );
        expect(
          pharmacyAllowedSections(operationsReader),
          contains(PharmacyDeskSection.inProgress),
        );
        expect(canBrowsePharmacyCatalog(operationsReader), isFalse);
        expect(canWritePharmacy(operationsReader), isFalse);
      },
    );

    test(
      'Pending payment tab read ∩ needs pharmacy:read + billing:read '
      '(intersection denial without billing:read)',
      () {
        final AppAccessPolicy pharmacyOnly = _policyFor(
          permissions: <AppPermission>{AppPermissions.pharmacyRead},
        );
        final AppAccessPolicy billingOnly = _policyFor(
          permissions: <AppPermission>{AppPermissions.billingRead},
          modules: _pharmacyAndBillingModules,
        );
        final AppAccessPolicy both = _pendingPaymentTabReadPolicy();
        final AppAccessPolicy bothMissingBillingModule = _policyFor(
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

        expect(canViewPharmacyPendingPaymentTab(pharmacyOnly), isFalse);
        expect(canViewPharmacyPendingPaymentTab(billingOnly), isFalse);
        expect(canViewPharmacyPendingPaymentTab(both), isTrue);
        expect(
          canViewPharmacyPendingPaymentTab(bothMissingBillingModule),
          isFalse,
        );
        expect(
          pharmacyAllowedSections(pharmacyOnly),
          isNot(contains(PharmacyDeskSection.pendingPayment)),
        );
        expect(
          pharmacyAllowedSections(both),
          contains(PharmacyDeskSection.pendingPayment),
        );
      },
    );

    test('Pending payment atom map reuses feature *Requirement helpers', () {
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
          PharmacyPendingPaymentAtomPermissions.paymentSuccess,
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
    });

    test(
      'Pending payment route ∪ allows pharmacy:read | operations:read; '
      'catalog write ∪ allows pharmacy:write | operations:write',
      () {
        final AppAccessPolicy operationsReader = _policyFor(
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
        final AppAccessPolicy operationsWriter = _policyFor(
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

        expect(canEnterPharmacyWorkspace(operationsReader), isTrue);
        expect(canViewPharmacyPendingPaymentTab(operationsReader), isFalse);
        expect(
          pharmacyAllowedSections(operationsReader),
          contains(PharmacyDeskSection.pendingPayment),
        );
        expect(canWritePharmacyCatalog(operationsWriter), isTrue);
        expect(canWritePharmacy(operationsWriter), isFalse);
      },
    );
  });


  group('pharmacy Ready UI permission enforcement', () {
    late _MockPharmacyRepository repository;

    setUp(() {
      repository = _MockPharmacyRepository();
    });

    setUpAll(() {
      registerFallbackValue(const PharmacyWorkbenchQuery());
      registerFallbackValue(const PharmacyDrugQuery());
      registerFallbackValue(const PharmacyFormularyQuery());
      registerFallbackValue(const PharmacyInventoryStockQuery());
    });

    testWidgets(
      'read-only Ready: catalog present; dispense next-action absent '
      '(∩ pharmacy:write denial)',
      (WidgetTester tester) async {
        await _pumpReadyWorkspace(
          tester,
          repository: repository,
          accessPolicy: _policyFor(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        expect(_tab('New orders'), findsOneWidget);
        expect(_catalogAction(), findsOneWidget);
        expect(find.text('Noah Ready'), findsOneWidget);
        expect(_actionLabel('Dispense'), findsNothing);
      },
    );

    testWidgets(
      'writer Ready: dispense next-action present (authorized mutate)',
      (WidgetTester tester) async {
        await _pumpReadyWorkspace(
          tester,
          repository: repository,
          accessPolicy: _policyFor(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        expect(_tab('New orders'), findsOneWidget);
        expect(find.text('Noah Ready'), findsOneWidget);
        expect(_actionLabel('Dispense'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'Ready payment next-action absent without billing:write '
      '(nested cross-module)',
      (WidgetTester tester) async {
        await _pumpReadyWorkspace(
          tester,
          repository: repository,
          accessPolicy: _policyFor(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        expect(find.text('Cathy Payment'), findsOneWidget);
        expect(_actionLabel('Record payment'), findsNothing);
      },
    );

    testWidgets(
      'Ready payment next-action present with billing:write ∩ '
      'billing-payments (union-of-atoms via nested ∩)',
      (WidgetTester tester) async {
        await _pumpReadyWorkspace(
          tester,
          repository: repository,
          accessPolicy: _policyFor(
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
      'Ready catalog browse absent for operations-only route ∪ '
      '(∪ allowance keeps tab; ∩ pharmacy:read strips catalog)',
      (WidgetTester tester) async {
        await _pumpReadyWorkspace(
          tester,
          repository: repository,
          accessPolicy: _policyFor(
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

        expect(_tab('New orders'), findsOneWidget);
        expect(_catalogAction(), findsNothing);
        expect(_actionLabel('Dispense'), findsNothing);
      },
    );

    testWidgets('Ready desktop light theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpReadyWorkspace(
        tester,
        repository: repository,
        accessPolicy: _policyFor(
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
      await _pumpReadyWorkspace(
        tester,
        repository: repository,
        accessPolicy: _policyFor(
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

  group('pharmacy Pending payment UI permission enforcement', () {
    late _MockPharmacyRepository repository;

    setUp(() {
      repository = _MockPharmacyRepository();
    });

    setUpAll(() {
      registerFallbackValue(const PharmacyWorkbenchQuery());
      registerFallbackValue(const PharmacyDrugQuery());
      registerFallbackValue(const PharmacyFormularyQuery());
      registerFallbackValue(const PharmacyInventoryStockQuery());
    });

    testWidgets(
      'pharmacy:read without billing:read hides Pending payment tab '
      '(read ∩ denial) and falls back',
      (WidgetTester tester) async {
        await _pumpPendingPaymentWorkspace(
          tester,
          repository: repository,
          accessPolicy: _policyFor(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        expect(_tab('Pending payment'), findsNothing);
        expect(_tab('New orders'), findsOneWidget);
        // Payment column is Pending-payment chrome; not a Ready primary column.
        expect(find.text('Payment'), findsNothing);
      },
    );

    testWidgets(
      'Pending payment tab + Payment column present with pharmacy:read ∩ '
      'billing:read; write next-actions absent for readers',
      (WidgetTester tester) async {
        await _pumpPendingPaymentWorkspace(
          tester,
          repository: repository,
          accessPolicy: _pendingPaymentTabReadPolicy(),
        );

        expect(_tab('Pending payment'), findsOneWidget);
        expect(_catalogAction(), findsOneWidget);
        expect(find.text('Cathy Payment'), findsOneWidget);
        expect(find.text('Payment'), findsAtLeastNWidgets(1));
        expect(_actionLabel('Record payment'), findsNothing);
        expect(_actionLabel('Dispense'), findsNothing);
        expect(_actionLabel('Cancel order'), findsNothing);
      },
    );

    testWidgets(
      'Pending payment Record payment absent without billing:write '
      '(nested cross-module write ∩ denial)',
      (WidgetTester tester) async {
        await _pumpPendingPaymentWorkspace(
          tester,
          repository: repository,
          accessPolicy: _pendingPaymentWriterPolicy(),
        );

        expect(_tab('Pending payment'), findsOneWidget);
        expect(find.text('Cathy Payment'), findsOneWidget);
        expect(_actionLabel('Record payment'), findsNothing);
      },
    );

    testWidgets(
      'Pending payment Record payment present with billing:write ∩ '
      'billing-payments (authorized nested write)',
      (WidgetTester tester) async {
        await _pumpPendingPaymentWorkspace(
          tester,
          repository: repository,
          accessPolicy: _pendingPaymentWriterPolicy(includeBillingWrite: true),
        );

        expect(find.text('Cathy Payment'), findsOneWidget);
        expect(_actionLabel('Record payment'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'Pending payment catalog browse absent for operations-only route ∪ '
      '(no pharmacy:read)',
      (WidgetTester tester) async {
        await _pumpPendingPaymentWorkspace(
          tester,
          repository: repository,
          accessPolicy: _policyFor(
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
        expect(_catalogAction(), findsNothing);
        expect(_actionLabel('Record payment'), findsNothing);
        expect(find.text('Payment'), findsNothing);
      },
    );

    testWidgets(
      'Pending payment desktop light theme keeps authorized chrome',
      (WidgetTester tester) async {
        await _pumpPendingPaymentWorkspace(
          tester,
          repository: repository,
          accessPolicy: _pendingPaymentWriterPolicy(includeBillingWrite: true),
          physicalSize: const Size(1280, 800),
          themeMode: ThemeMode.light,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(AppTabStrip), findsOneWidget);
        expect(find.byType(DataTable), findsOneWidget);
        expect(_catalogAction(), findsOneWidget);
        expect(find.text('Payment'), findsAtLeastNWidgets(1));
        expect(_actionLabel('Record payment'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('Pending payment mobile dark theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpPendingPaymentWorkspace(
        tester,
        repository: repository,
        accessPolicy: _pendingPaymentWriterPolicy(includeBillingWrite: true),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
      expect(find.textContaining('Cathy'), findsAtLeastNWidgets(1));
      expect(_actionLabel('Record payment'), findsAtLeastNWidgets(1));
    });
  });
}
