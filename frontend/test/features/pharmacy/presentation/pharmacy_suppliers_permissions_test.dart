import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_access.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_suppliers_panel.dart';
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

const PharmacySupplier _supplier = PharmacySupplier(
  id: 'supplier-1',
  name: 'Acme Pharma',
  location: 'Kampala',
  contactEmail: 'orders@acme.test',
  phone: '+256700000001',
);

class _MockPharmacyRepository extends Mock implements PharmacyRepository {}

void _stubPharmacyRepository(
  _MockPharmacyRepository repository, {
  List<PharmacySupplier> suppliers = const <PharmacySupplier>[_supplier],
}) {
  when(() => repository.loadWorkbench(any())).thenAnswer(
    (_) async => const Result<PharmacyWorkbench>.success(
      PharmacyWorkbench(
        summary: PharmacyWorkbenchSummary(totalOrders: 0),
        orders: AppPage<PharmacyOrder>(
          items: <PharmacyOrder>[],
          request: AppPageRequest(),
          totalItemCount: 0,
        ),
      ),
    ),
  );
  when(() => repository.listSuppliers(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final PharmacySupplierQuery query =
        invocation.positionalArguments.single as PharmacySupplierQuery;
    List<PharmacySupplier> items = List<PharmacySupplier>.of(suppliers);
    final String search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items
          .where((PharmacySupplier item) {
            final String haystack =
                '${item.name} ${item.location} ${item.contactEmail} ${item.phone}'
                    .toLowerCase();
            return haystack.contains(search);
          })
          .toList(growable: false);
    }
    return Result<AppPage<PharmacySupplier>>.success(
      AppPage<PharmacySupplier>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.searchDrugs(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacyDrug>>.success(
      AppPage<PharmacyDrug>(items: <PharmacyDrug>[], request: AppPageRequest()),
    ),
  );
  when(() => repository.getInventoryStock(any())).thenAnswer(
    (_) async => const Result<PharmacyInventoryWorkbench>.success(
      PharmacyInventoryWorkbench(
        summary: PharmacyInventoryStockSummary(),
        stocks: AppPage<PharmacyInventoryStock>(
          items: <PharmacyInventoryStock>[],
          request: AppPageRequest(),
        ),
      ),
    ),
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

AppListTable<PharmacySupplier> _suppliersTable(WidgetTester tester) {
  return tester.widget<AppListTable<PharmacySupplier>>(
    find.byType(AppListTable<PharmacySupplier>),
  );
}

Future<void> _pumpSuppliersTab(
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
    initialLocation: '/pharmacy?section=suppliers',
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
    registerFallbackValue(const PharmacySupplierQuery());
    registerFallbackValue('');
  });

  group('PharmacySuppliersAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          PharmacySuppliersAtomPermissions.tab,
          pharmacyCatalogBrowseRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacySuppliersAtomPermissions.write,
          pharmacyCatalogWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacySuppliersAtomPermissions.export,
          pharmacyWorkspaceExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacySuppliersAtomPermissions.print,
          pharmacyWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionTabRequirement(PharmacyDeskSection.suppliers),
          PharmacySuppliersAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing pharmacy:read hides Suppliers tab gate', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
      );
      expect(
        PharmacySuppliersAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        pharmacyAllowedSections(writeOnly),
        isNot(contains(PharmacyDeskSection.suppliers)),
      );
    });
  });

  group('pharmacy Suppliers UI permission enforcement', () {
    late _MockPharmacyRepository repository;

    setUp(() {
      repository = _MockPharmacyRepository();
    });

    testWidgets(
      '∩ denial: read-only Suppliers keeps browse; write actions absent',
      (WidgetTester tester) async {
        await _pumpSuppliersTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        expect(_tab('Suppliers'), findsOneWidget);
        expect(find.byType(PharmacySuppliersCatalogTab), findsOneWidget);
        expect(find.text('Acme Pharma'), findsOneWidget);
        expect(find.text('Create'), findsNothing);
        expect(find.text('Edit'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        final AppTabStrip strip = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        final AppTabItem suppliers = strip.tabs.firstWhere(
          (AppTabItem tab) => tab.label == 'Suppliers',
        );
        expect(suppliers.count, 1);
        expect(suppliers.countTone, AppTabCountTone.info);

        await tester.tap(find.text('Acme Pharma'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsOneWidget);
        expect(find.textContaining('Supplier'), findsAtLeastNWidgets(1));
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Edit'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text('Delete'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Suppliers toolbar: Filters/Settings/Close, ≤5 columns, info tone, Export/Print gate',
      (WidgetTester tester) async {
        await _pumpSuppliersTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        final AppListTable<PharmacySupplier> table = _suppliersTable(tester);
        expect(table.columnVisibilityLabel, 'Settings');
        expect(table.columnVisibilityCloseLabel, 'Close');
        expect(table.columnVisibilityApplyLabel, 'Apply columns');
        expect(table.columnVisibilityResetLabel, 'Reset columns');
        expect(table.search?.advancedFilterButtonLabel, 'Filters');
        expect(table.search?.advancedFilterTitle, 'Advanced filters');
        expect(table.search?.advancedFilterApplyLabel, 'Apply filters');
        expect(table.search?.advancedFilterResetLabel, 'Clear filters');
        expect(table.search?.advancedFilterCloseLabel, 'Close');
        expect(table.enablePrint, isTrue);
        expect(table.canExport, isFalse);
        expect(table.canPrint, isFalse);
        expect(table.printLabel, 'Print');
        expect(table.columns.length, 5);
        expect(
          table.columns.any(
            (AppListTableColumn<PharmacySupplier> c) =>
                c.id == 'actions' && c.alwaysVisible,
          ),
          isTrue,
        );
        expect(table.columnVisibilityStorageKey, 'pharmacy_catalog_suppliers');
        expect(find.byTooltip('Export'), findsNothing);
        expect(find.byTooltip('Print'), findsNothing);
        expect(find.text('Create'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
      },
    );

    testWidgets(
      'Suppliers Export/Print present when evidence:export granted',
      (WidgetTester tester) async {
        await _pumpSuppliersTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
              AppPermissions.evidenceExport,
            },
          ),
        );

        final AppListTable<PharmacySupplier> table = _suppliersTable(tester);
        expect(table.canExport, isTrue);
        expect(table.canPrint, isTrue);
        expect(table.enablePrint, isTrue);
        expect(table.printLabel, 'Print');
        expect(find.byTooltip('Export'), findsOneWidget);
        expect(find.byTooltip('Print'), findsOneWidget);
      },
    );

    testWidgets('Suppliers desktop light theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpSuppliersTab(
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
      expect(find.byType(PharmacySuppliersCatalogTab), findsOneWidget);
      expect(find.byType(AppListTableGrid), findsOneWidget);
      expect(find.text('Acme Pharma'), findsOneWidget);
    });

    testWidgets('Suppliers mobile dark theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpSuppliersTab(
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
      expect(find.byType(PharmacySuppliersCatalogTab), findsOneWidget);
      expect(find.byType(AppListTableGrid), findsNothing);
      expect(_tab('Suppliers'), findsOneWidget);
    });
  });
}
