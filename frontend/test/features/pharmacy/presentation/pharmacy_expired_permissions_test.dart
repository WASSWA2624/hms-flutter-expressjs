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
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart';
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

final PharmacyInventoryStock _expiredStock = PharmacyInventoryStock(
  id: 'stock-expired-1',
  displayId: 'STK-EXP-1',
  inventoryItem: const PharmacyInventoryItem(
    id: 'item-exp-1',
    name: 'Metronidazole syrup',
    sku: 'MET100',
  ),
  quantity: 4,
  reorderLevel: 2,
  stockStatus: 'IN_STOCK',
  nextExpiry: DateTime.utc(2025, 1, 1),
  expiryAlertStatus: 'EXPIRED',
  batchCount: 1,
);

class _MockPharmacyRepository extends Mock implements PharmacyRepository {}

void _stubPharmacyRepository(_MockPharmacyRepository repository) {
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
  when(() => repository.getInventoryStock(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final PharmacyInventoryStockQuery query =
        invocation.positionalArguments.single as PharmacyInventoryStockQuery;
    List<PharmacyInventoryStock> items = <PharmacyInventoryStock>[
      _expiredStock,
    ];
    final String search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items
          .where((PharmacyInventoryStock item) {
            final String haystack =
                '${item.inventoryItem?.name} ${item.inventoryItem?.sku}'
                    .toLowerCase();
            return haystack.contains(search);
          })
          .toList(growable: false);
    }
    return Result<PharmacyInventoryWorkbench>.success(
      PharmacyInventoryWorkbench(
        summary: PharmacyInventoryStockSummary(expiredRows: items.length),
        stocks: AppPage<PharmacyInventoryStock>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      ),
    );
  });
  when(() => repository.searchDrugs(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacyDrug>>.success(
      AppPage<PharmacyDrug>(items: <PharmacyDrug>[], request: AppPageRequest()),
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
  when(() => repository.listSuppliers(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacySupplier>>.success(
      AppPage<PharmacySupplier>(
        items: <PharmacySupplier>[],
        request: AppPageRequest(),
        totalItemCount: 0,
      ),
    ),
  );
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppListTable<PharmacyInventoryStock> _inventoryTable(WidgetTester tester) {
  return tester.widget<AppListTable<PharmacyInventoryStock>>(
    find.byType(AppListTable<PharmacyInventoryStock>),
  );
}

Future<void> _pumpExpiredTab(
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
    initialLocation: '/pharmacy?section=expired',
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

  group('PharmacyExpiredAtomPermissions helpers', () {
    test('reuses catalog browse/write/export helpers', () {
      expect(
        identical(
          PharmacyExpiredAtomPermissions.tab,
          pharmacyCatalogBrowseRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyExpiredAtomPermissions.write,
          pharmacyCatalogWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyExpiredAtomPermissions.export,
          pharmacyWorkspaceExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyExpiredAtomPermissions.print,
          pharmacyWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionTabRequirement(PharmacyDeskSection.expired),
          PharmacyExpiredAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing pharmacy:read hides Expired tab gate', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
      );
      expect(PharmacyExpiredAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(
        pharmacyAllowedSections(writeOnly),
        isNot(contains(PharmacyDeskSection.expired)),
      );
    });
  });

  group('pharmacy Expired UI permission enforcement', () {
    late _MockPharmacyRepository repository;

    setUp(() {
      repository = _MockPharmacyRepository();
    });

    testWidgets(
      '∩ denial: read-only Expired keeps browse; write actions absent',
      (WidgetTester tester) async {
        await _pumpExpiredTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        expect(_tab('Expired'), findsOneWidget);
        expect(find.byType(PharmacyCatalogPanel), findsOneWidget);
        expect(find.textContaining('Metronidazole'), findsAtLeastNWidgets(1));
        expect(find.text('Adjust'), findsNothing);
        expect(find.text('Clear'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        final AppTabStrip strip = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        final AppTabItem expired = strip.tabs.firstWhere(
          (AppTabItem tab) => tab.label == 'Expired',
        );
        expect(expired.countTone, AppTabCountTone.danger);
        expect(expired.count, isNotNull);

        final List<Object?> captured = verify(
          () => repository.getInventoryStock(captureAny()),
        ).captured;
        expect(
          captured.any(
            (Object? query) =>
                (query as PharmacyInventoryStockQuery).expiredOnly == true,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'Expired toolbar: Filters/Settings/Close, ≤5 columns, Export/Print gate',
      (WidgetTester tester) async {
        await _pumpExpiredTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        final AppListTable<PharmacyInventoryStock> table =
            _inventoryTable(tester);
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
        expect(table.columnChoices, isNotEmpty);
        expect(table.columnVisibilityStorageKey, 'pharmacy_catalog_inventory');
        expect(find.byTooltip('Export'), findsNothing);
        expect(find.byTooltip('Print'), findsNothing);
        expect(find.text('Adjust'), findsOneWidget);
      },
    );

    testWidgets(
      'Expired Export/Print present when evidence:export granted',
      (WidgetTester tester) async {
        await _pumpExpiredTab(
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

        final AppListTable<PharmacyInventoryStock> table =
            _inventoryTable(tester);
        expect(table.canExport, isTrue);
        expect(table.canPrint, isTrue);
        expect(table.enablePrint, isTrue);
        expect(table.printLabel, 'Print');
        expect(find.byTooltip('Export'), findsOneWidget);
        expect(find.byTooltip('Print'), findsOneWidget);
      },
    );

    testWidgets('Expired desktop light theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpExpiredTab(
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
      expect(find.byType(PharmacyCatalogPanel), findsOneWidget);
      expect(find.byType(AppListTableGrid), findsOneWidget);
    });

    testWidgets('Expired mobile dark theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpExpiredTab(
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
      expect(find.byType(PharmacyCatalogPanel), findsOneWidget);
      expect(find.byType(AppListTableGrid), findsNothing);
      expect(_tab('Expired'), findsOneWidget);
    });
  });
}
