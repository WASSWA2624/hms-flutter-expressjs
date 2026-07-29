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

const PharmacyOrder _readyOrder = PharmacyOrder(
  id: 'order-ready',
  displayId: 'PHO-READY',
  patientDisplayName: 'Noah Ready',
  location: 'OUTPATIENT',
  status: 'ORDERED',
  itemCount: 1,
  quantityPrescribedTotal: 24,
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
    List<PharmacyOrder> items = <PharmacyOrder>[_readyOrder, _unpaidOrder];
    if (query.pendingPayment == true) {
      items = items
          .where((PharmacyOrder order) => order.requiresPaymentBeforeDispense)
          .toList(growable: false);
    }
    return Result<PharmacyWorkbench>.success(
      PharmacyWorkbench(
        summary: PharmacyWorkbenchSummary(
          orderedQueue: 1,
          partiallyDispensedQueue: 0,
          pendingPaymentQueue: 1,
          dispensedOrders: 0,
          totalOrders: items.length,
        ),
        orders: AppPage<PharmacyOrder>(
          items: items,
          request: AppPageRequest(page: query.page, pageSize: query.pageSize),
          totalItems: items.length,
        ),
      ),
    );
  });
  when(() => repository.loadOrderWorkflow(any())).thenAnswer(
    (_) async => Result<PharmacyOrderWorkflow>.success(
      PharmacyOrderWorkflow(
        order: _readyOrder,
        nextActions: const PharmacyNextActions(canCancel: true),
      ),
    ),
  );
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

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabToolbarPrimary),
  matching: find.text(label),
);

Future<void> _pumpAllOrdersWorkspace(
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
    initialLocation: '/pharmacy?section=all',
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
      overrides: <Override>[
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

    test('All orders atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          PharmacyAllOrdersAtomPermissions.tab,
          pharmacyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyAllOrdersAtomPermissions.write,
          pharmacyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyAllOrdersAtomPermissions.dispense,
          pharmacyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyAllOrdersAtomPermissions.recordPayment,
          pharmacyRecordPaymentRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyAllOrdersAtomPermissions.catalogWrite,
          pharmacyCatalogWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyAllOrdersAtomPermissions.routeEntry,
          pharmacyWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyAllOrdersAtomPermissions.catalogEntry,
          pharmacyWorkspaceCatalogEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyAllOrdersAtomPermissions.controlledDrugAudit,
          pharmacyControlledDrugAuditRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionTabRequirement(PharmacyDeskSection.allOrders),
          PharmacyAllOrdersAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test(
      'All orders tab present for pharmacy:read; operations-only keeps sections',
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

        expect(canViewPharmacyAllOrdersTab(pharmacyReader), isTrue);
        expect(canViewPharmacyAllOrdersTab(operationsReader), isFalse);
        expect(
          pharmacyAllowedSections(pharmacyReader),
          contains(PharmacyDeskSection.allOrders),
        );
        expect(
          pharmacyAllowedSections(operationsReader),
          contains(PharmacyDeskSection.allOrders),
        );
        expect(canWritePharmacy(operationsReader), isFalse);
        expect(
          pharmacyFallbackSection(pharmacyReader),
          PharmacyDeskSection.queue,
        );
      },
    );
  });

  group('pharmacy All orders UI permission enforcement', () {
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
      'read-only All orders: catalog present; cancel next-action absent',
      (WidgetTester tester) async {
        await _pumpAllOrdersWorkspace(
          tester,
          repository: repository,
          accessPolicy: _policyFor(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        expect(_tab('All orders'), findsOneWidget);
        expect(_toolbarPrimary('Catalog and stock'), findsOneWidget);
        expect(find.text('Cancel order'), findsNothing);
        expect(find.text('Noah Ready'), findsOneWidget);
      },
    );

    testWidgets(
      'writer All orders: cancel next-action present (authorized mutate)',
      (WidgetTester tester) async {
        await _pumpAllOrdersWorkspace(
          tester,
          repository: repository,
          accessPolicy: _policyFor(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        expect(_tab('All orders'), findsOneWidget);
        expect(find.text('Cancel order'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'payment next-action absent without billing:write (nested cross-module)',
      (WidgetTester tester) async {
        await _pumpAllOrdersWorkspace(
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
        expect(find.text('Record payment'), findsNothing);
      },
    );

    testWidgets(
      'payment next-action present with billing:write ∩ billing-payments',
      (WidgetTester tester) async {
        await _pumpAllOrdersWorkspace(
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

        expect(find.text('Record payment'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('All orders desktop light theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpAllOrdersWorkspace(
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
      expect(_toolbarPrimary('Catalog and stock'), findsOneWidget);
    });

    testWidgets('All orders mobile dark theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpAllOrdersWorkspace(
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
      expect(find.text('Cancel order'), findsAtLeastNWidgets(1));
    });
  });
}
