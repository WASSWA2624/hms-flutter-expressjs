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

const PharmacyOrderItem _cancelledLine = PharmacyOrderItem(
  id: 'item-cancelled-1',
  drugDisplayName: 'Ceftriaxone',
  quantityPrescribed: 2,
  quantityDispensed: 0,
  quantityRemaining: 2,
);

const PharmacyOrder _cancelledOrder = PharmacyOrder(
  id: 'order-cancelled',
  displayId: 'PHO-CANCELLED',
  patientDisplayName: 'Casey Cancelled',
  location: 'OUTPATIENT',
  status: 'CANCELLED',
  itemCount: 1,
  quantityPrescribedTotal: 2,
  items: <PharmacyOrderItem>[_cancelledLine],
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
    List<PharmacyOrder> items = const <PharmacyOrder>[_cancelledOrder];
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
          cancelledOrders: items.length,
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
  when(() => repository.loadOrderWorkflow(any())).thenAnswer(
    (_) async => Result<PharmacyOrderWorkflow>.success(
      PharmacyOrderWorkflow(
        order: _cancelledOrder,
        items: _cancelledOrder.items,
        nextActions: const PharmacyNextActions(),
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

AppListTable<PharmacyOrder> _cancelledTable(WidgetTester tester) {
  return tester.widget<AppListTable<PharmacyOrder>>(
    find.byType(AppListTable<PharmacyOrder>),
  );
}

Finder _catalogAction() => find.byWidgetPredicate(
  (Widget widget) =>
      widget is AppTabStrip &&
      widget.tabs.any((AppTabItem tab) => tab.label == 'Catalog and stock'),
);

Future<void> _pumpCancelledTab(
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
    initialLocation: '/pharmacy?section=cancelled',
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

  group('Cancelled tab gate reuses All-orders atoms', () {
    test('section tab/write requirements map to All-orders atoms', () {
      expect(
        identical(
          pharmacySectionTabRequirement(PharmacyDeskSection.cancelled),
          PharmacyAllOrdersAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          pharmacySectionWriteRequirement(PharmacyDeskSection.cancelled),
          PharmacyAllOrdersAtomPermissions.write,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyAllOrdersAtomPermissions.export,
          pharmacyWorkspaceExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PharmacyAllOrdersAtomPermissions.print,
          pharmacyWorkspacePrintRequirement,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing pharmacy:read hides Cancelled tab gate', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
      );
      expect(
        pharmacySectionTabRequirement(
          PharmacyDeskSection.cancelled,
        ).isAllowed(writeOnly),
        isFalse,
      );
      expect(
        pharmacyAllowedSections(writeOnly),
        isNot(contains(PharmacyDeskSection.cancelled)),
      );
    });
  });

  group('pharmacy Cancelled UI permission enforcement', () {
    late _MockPharmacyRepository repository;

    setUp(() {
      repository = _MockPharmacyRepository();
    });

    testWidgets(
      '∩ denial: read-only Cancelled keeps print path; write actions absent',
      (WidgetTester tester) async {
        await _pumpCancelledTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.pharmacyRead},
          ),
        );

        expect(_tab('Cancelled orders'), findsOneWidget);
        expect(_catalogAction(), findsOneWidget);
        expect(find.text('Casey Cancelled'), findsOneWidget);
        expect(find.text('Cancel order'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);

        await tester.tap(find.text('Casey Cancelled'));
        await tester.pumpAndSettle();

        final Finder dialog = find.byType(AppDialog);
        expect(dialog, findsOneWidget);
        expect(find.text('PRESCRIPTION DETAIL'), findsOneWidget);
        expect(
          find.descendant(of: dialog, matching: find.text('Cancel order')),
          findsNothing,
        );
        expect(
          find.descendant(of: dialog, matching: find.text('Print')),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'Cancelled toolbar: Filters/Settings/Close, ≤5 columns, danger tone, Export/Print gate',
      (WidgetTester tester) async {
        await _pumpCancelledTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.pharmacyRead,
              AppPermissions.pharmacyWrite,
            },
          ),
        );

        final AppListTable<PharmacyOrder> table = _cancelledTable(tester);
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
            (AppListTableColumn<PharmacyOrder> c) => c.id == 'items',
          ),
          isTrue,
        );
        expect(
          table.columns.any(
            (AppListTableColumn<PharmacyOrder> c) =>
                c.id == 'next_action' && c.alwaysVisible,
          ),
          isTrue,
        );
        expect(table.columnChoices, isNotEmpty);
        expect(table.columnVisibilityStorageKey, 'pharmacy_cancelled');

        final AppTabStrip strip = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        final AppTabItem cancelled = strip.tabs.firstWhere(
          (AppTabItem tab) => tab.label == 'Cancelled orders',
        );
        expect(cancelled.countTone, AppTabCountTone.danger);
        expect(cancelled.count, isNotNull);

        final List<AppSearchBarAction> trailing =
            table.search?.trailingActions ?? const <AppSearchBarAction>[];
        expect(trailing.last.label, 'Walk-in order');
        expect(find.byTooltip('Export'), findsNothing);
        expect(find.byTooltip('Print'), findsNothing);
      },
    );

    testWidgets(
      'Cancelled Export/Print present when evidence:export granted',
      (WidgetTester tester) async {
        await _pumpCancelledTab(
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

        final AppListTable<PharmacyOrder> table = _cancelledTable(tester);
        expect(table.canExport, isTrue);
        expect(table.canPrint, isTrue);
        expect(table.enablePrint, isTrue);
        expect(table.printLabel, 'Print');
        expect(find.byTooltip('Export'), findsOneWidget);
        expect(find.byTooltip('Print'), findsOneWidget);
      },
    );

    testWidgets('Cancelled desktop light theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpCancelledTab(
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
      expect(find.text('Casey Cancelled'), findsOneWidget);
    });

    testWidgets('Cancelled mobile dark theme keeps authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpCancelledTab(
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
      expect(find.textContaining('Casey'), findsAtLeastNWidgets(1));
    });
  });
}
