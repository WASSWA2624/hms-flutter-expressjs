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

const PharmacyDrug _drug = PharmacyDrug(
  id: 'drug-1',
  name: 'Amoxicillin',
  genericName: 'Amoxicillin',
  brandName: 'Amoxil',
  code: 'AMX500',
  form: 'Capsule',
  strength: '500 mg',
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
  when(() => repository.searchDrugs(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacyDrug>>.success(
      AppPage<PharmacyDrug>(
        items: <PharmacyDrug>[_drug],
        request: AppPageRequest(),
        totalItemCount: 1,
      ),
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

AppListTable<PharmacyDrug> _drugsTable(WidgetTester tester) {
  return tester.widget<AppListTable<PharmacyDrug>>(
    find.byType(AppListTable<PharmacyDrug>),
  );
}

Future<void> _pumpCatalogTab(
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
    initialLocation: '/pharmacy?section=catalog',
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

  group('PharmacyCatalogAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          PharmacyCatalogAtomPermissions.tab,
          pharmacyCatalogBrowseRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCatalogAtomPermissions.write,
          pharmacyCatalogWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCatalogAtomPermissions.export,
          pharmacyWorkspaceExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyCatalogAtomPermissions.print,
          pharmacyWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionTabRequirement(PharmacyDeskSection.catalog),
          PharmacyCatalogAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing pharmacy:read hides Catalog tab gate', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
      );
      expect(PharmacyCatalogAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(
        pharmacyAllowedSections(writeOnly),
        isNot(contains(PharmacyDeskSection.catalog)),
      );
    });
  });

  group('pharmacy Catalog UI permission enforcement', () {
    late _MockPharmacyRepository repository;

    setUp(() {
      repository = _MockPharmacyRepository();
    });

    testWidgets(
      '∩ denial: read-only Catalog keeps browse; write actions absent',
      (WidgetTester tester) async {
        await _pumpCatalogTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        expect(_tab('Catalog and stock'), findsOneWidget);
        expect(find.byType(PharmacyCatalogPanel), findsOneWidget);
        expect(find.text('Amoxicillin'), findsWidgets);
        expect(find.text('Create'), findsNothing);
        expect(find.text('Edit'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        final AppTabStrip strip = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        final AppTabItem catalog = strip.tabs.firstWhere(
          (AppTabItem tab) => tab.label == 'Catalog and stock',
        );
        expect(catalog.count, isNull);
        expect(catalog.countTone, AppTabCountTone.info);
      },
    );

    testWidgets(
      'Catalog Drugs toolbar: Filters/Settings/Close, ≤5 columns, Export/Print gate',
      (WidgetTester tester) async {
        await _pumpCatalogTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        final AppListTable<PharmacyDrug> table = _drugsTable(tester);
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
        expect(table.columnVisibilityStorageKey, 'pharmacy_catalog_drugs');
        expect(find.byTooltip('Export'), findsNothing);
        expect(find.byTooltip('Print'), findsNothing);
        expect(find.text('Create'), findsOneWidget);
      },
    );

    testWidgets(
      'Catalog Drugs Export/Print present when evidence:export granted',
      (WidgetTester tester) async {
        await _pumpCatalogTab(
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

        final AppListTable<PharmacyDrug> table = _drugsTable(tester);
        expect(table.canExport, isTrue);
        expect(table.canPrint, isTrue);
        expect(table.enablePrint, isTrue);
        expect(table.printLabel, 'Print');
        expect(find.byTooltip('Export'), findsOneWidget);
        expect(find.byTooltip('Print'), findsOneWidget);
      },
    );

    testWidgets('Catalog desktop light theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpCatalogTab(
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

    testWidgets('Catalog mobile dark theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpCatalogTab(
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
      expect(_tab('Catalog and stock'), findsOneWidget);
    });
  });
}
