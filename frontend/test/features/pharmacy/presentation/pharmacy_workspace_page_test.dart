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
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPharmacyRepository extends Mock implements PharmacyRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

Finder _moreTabsButton() => find.descendant(
  of: find.byType(AppTabStrip),
  matching: find.byIcon(Icons.more_vert),
);

// With the full order + stock tab set, trailing tabs (e.g. All orders) overflow
// into the "More tabs" menu at the data-heavy max width; open it to reach them.
Future<void> _openMoreTabs(WidgetTester tester) async {
  await tester.tap(_moreTabsButton());
  await tester.pumpAndSettle();
}

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabToolbarPrimary),
  matching: find.text(label),
);

Finder _toolbarAction(String label) => find.descendant(
  of: find.byType(AppTabToolbarAction),
  matching: find.text(label),
);

/// Catalog browse is now the "Catalog and stock" desk tab. Presence is asserted
/// against the strip's tab model so it holds whether the tab renders as a
/// visible chip or an overflow menu entry.
Finder _catalogAction() => find.byWidgetPredicate(
  (Widget widget) =>
      widget is AppTabStrip &&
      widget.tabs.any((AppTabItem tab) => tab.label == 'Catalog and stock'),
);

/// Switches the workspace to the inline Catalog and stock section by driving the
/// desk tab callback directly (overflow-safe; the chip may be in the menu).
Future<void> _openCatalogSection(WidgetTester tester) async {
  final AppTabStrip strip = tester.widget<AppTabStrip>(find.byType(AppTabStrip));
  final AppTabItem catalogTab = strip.tabs.firstWhere(
    (AppTabItem tab) => tab.label == 'Catalog and stock',
  );
  strip.onTabTapped(catalogTab.id);
  await tester.pumpAndSettle();
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

const PharmacyOrder _partialOrder = PharmacyOrder(
  id: 'order-partial',
  displayId: 'PHO-PARTIAL',
  patientDisplayName: 'Amina Partial',
  location: 'OUTPATIENT',
  status: 'PARTIALLY_DISPENSED',
  itemCount: 2,
  quantityPrescribedTotal: 20,
  quantityDispensedTotal: 8,
);

const PharmacyOrder _completedOrder = PharmacyOrder(
  id: 'order-done',
  displayId: 'PHO-DONE',
  patientDisplayName: 'Brian Done',
  location: 'OUTPATIENT',
  status: 'DISPENSED',
  itemCount: 1,
  quantityPrescribedTotal: 10,
  quantityDispensedTotal: 10,
);

const PharmacyOrder _pendingPaymentOrder = PharmacyOrder(
  id: 'order-pay',
  displayId: 'PHO-PAY',
  patientDisplayName: 'Cathy Payment',
  location: 'OUTPATIENT',
  status: 'ORDERED',
  paymentStatus: 'PENDING',
  itemCount: 1,
  quantityPrescribedTotal: 5,
);

const List<PharmacyOrder> _allOrders = <PharmacyOrder>[
  _readyOrder,
  _partialOrder,
  _completedOrder,
  _pendingPaymentOrder,
];

const PharmacyInventoryWorkbench _inventoryWorkbench =
    PharmacyInventoryWorkbench(
      summary: PharmacyInventoryStockSummary(
        lowStockRows: 2,
        almostOutOfStockRows: 1,
        expiringSoonRows: 3,
      ),
      stocks: AppPage<PharmacyInventoryStock>(
        items: <PharmacyInventoryStock>[],
        request: AppPageRequest(),
      ),
    );

AppAccessPolicy _pharmacyWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['PHARMACIST']),
      permissions: <AppPermission>{
        AppPermissions.pharmacyRead,
        AppPermissions.pharmacyWrite,
        AppPermissions.billingRead,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'pharmacy-dispensing',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'billing-payments',
          licenseStatus: 'ACTIVE',
        ),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _pharmacyReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['VIEWER']),
      permissions: <AppPermission>{
        AppPermissions.pharmacyRead,
        AppPermissions.billingRead,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'pharmacy-dispensing',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'billing-payments',
          licenseStatus: 'ACTIVE',
        ),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubPharmacyRepository(_MockPharmacyRepository repository) {
  when(() => repository.loadWorkbench(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final PharmacyWorkbenchQuery query =
        invocation.positionalArguments.single as PharmacyWorkbenchQuery;
    List<PharmacyOrder> items = List<PharmacyOrder>.of(_allOrders);
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
          .where(
            (PharmacyOrder order) =>
                (order.effectivePaymentStatus ?? '').toUpperCase() == 'PENDING',
          )
          .toList(growable: false);
    }
    final String search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items
          .where((PharmacyOrder order) {
            final String haystack =
                '${order.patientDisplayName} ${order.displayId}'.toLowerCase();
            return haystack.contains(search);
          })
          .toList(growable: false);
    }
    return Result<PharmacyWorkbench>.success(
      PharmacyWorkbench(
        summary: const PharmacyWorkbenchSummary(
          totalOrders: 4,
          orderedQueue: 2,
          partiallyDispensedQueue: 1,
          dispensedOrders: 1,
          pendingPaymentQueue: 1,
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
    final PharmacyOrder order = _allOrders.firstWhere(
      (PharmacyOrder item) => item.id == orderId || item.displayId == orderId,
      orElse: () => _readyOrder,
    );
    return Result<PharmacyOrderWorkflow>.success(
      PharmacyOrderWorkflow(order: order),
    );
  });
  when(() => repository.searchDrugs(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacyDrug>>.success(
      AppPage<PharmacyDrug>(
        items: <PharmacyDrug>[
          PharmacyDrug(
            id: 'drug-1',
            name: 'Amoxicillin',
            genericName: 'Amoxicillin',
            brandName: 'Amoxil',
            code: 'AMX500',
            form: 'Capsule',
            strength: '500 mg',
          ),
        ],
        request: AppPageRequest(),
        totalItemCount: 1,
      ),
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

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockPharmacyRepository repository;
  final GoRouter router;
}

Future<_Harness> _pumpPharmacyWorkspace(
  WidgetTester tester, {
  required _MockPharmacyRepository repository,
  PharmacyWorkspaceQuery? initialQuery,
  String initialLocation = '/pharmacy',
  Size physicalSize = const Size(1440, 900),
  AppAccessPolicy? accessPolicy,
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
              initialQuery:
                  initialQuery ?? PharmacyWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Billing workspace'));
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
          accessPolicy ?? _pharmacyWritePolicy(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  return _Harness(repository: repository, router: router);
}

void main() {
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

  testWidgets('renders tab strip with catalog search action and no refresh', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppWorkspaceToolbar), findsNothing);
    expect(_tab('New orders'), findsOneWidget);
    expect(_tab('Partial'), findsOneWidget);
    expect(_tab('Pending payment'), findsOneWidget);
    expect(_tab('Completed orders'), findsOneWidget);
    // "All orders" and the stock tabs overflow into the More tabs menu here.
    expect(_moreTabsButton(), findsOneWidget);
    expect(find.text('Noah Ready'), findsOneWidget);
    expect(find.text('Amina Partial'), findsNothing);
    expect(_catalogAction(), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsNothing);
    expect(_toolbarAction('Low stock'), findsNothing);
    expect(_toolbarAction('Almost out'), findsNothing);
    expect(_toolbarAction('Expiring soon'), findsNothing);
    expect(_toolbarPrimary('Billing'), findsNothing);
    expect(_toolbarAction('Billing'), findsNothing);
  });

  testWidgets('switching tabs keeps catalog search action and omits refresh', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(_tab('Partial'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'in-progress');
    expect(find.text('Amina Partial'), findsOneWidget);
    expect(find.text('Noah Ready'), findsNothing);
    expect(_catalogAction(), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsNothing);

    await tester.tap(_tab('Completed orders'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'completed');
    expect(find.text('Brian Done'), findsOneWidget);
    expect(_catalogAction(), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsNothing);
  });

  testWidgets('deep link section=in-progress selects Partial tab', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
      initialLocation: '/pharmacy?section=in-progress',
      initialQuery: PharmacyWorkspaceQuery.fromUri(
        Uri.parse('/pharmacy?section=in-progress'),
      ),
    );

    expect(find.text('Amina Partial'), findsOneWidget);
    expect(find.text('Noah Ready'), findsNothing);
    expect(find.text('Brian Done'), findsNothing);
    expect(_catalogAction(), findsOneWidget);

    final List<Object?> captured = verify(
      () => repository.loadWorkbench(captureAny()),
    ).captured;
    expect(
      captured.any(
        (Object? query) =>
            (query as PharmacyWorkbenchQuery).status == 'PARTIALLY_DISPENSED',
      ),
      isTrue,
    );
  });

  testWidgets(
    'subsequent section deep link reapplies workbench filter and date range',
    (WidgetTester tester) async {
      final _Harness harness = await _pumpPharmacyWorkspace(
        tester,
        repository: repository,
        initialLocation: '/pharmacy?section=in-progress',
      );

      clearInteractions(repository);

      final DateTime from = DateTime(2026, 7, 31);
      final DateTime to = DateTime(2026, 8, 7);
      harness.router.go(
        Uri(
          path: '/pharmacy',
          queryParameters: <String, String>{
            'section': 'completed',
            'from': from.toUtc().toIso8601String(),
            'to': to.toUtc().toIso8601String(),
          },
        ).toString(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Brian Done'), findsOneWidget);
      expect(find.text('Amina Partial'), findsNothing);

      final List<Object?> captured = verify(
        () => repository.loadWorkbench(captureAny()),
      ).captured;
      expect(
        captured.any((Object? raw) {
          final PharmacyWorkbenchQuery query = raw as PharmacyWorkbenchQuery;
          return query.status == 'DISPENSED' &&
              query.todayOnly != true &&
              query.from != null &&
              query.to != null;
        }),
        isTrue,
      );
    },
  );

  testWidgets(
    'deep link section=pending-payment keeps catalog search action (not Billing)',
    (WidgetTester tester) async {
      await _pumpPharmacyWorkspace(
        tester,
        repository: repository,
        initialLocation: '/pharmacy?section=pending-payment',
        initialQuery: PharmacyWorkspaceQuery.fromUri(
          Uri.parse('/pharmacy?section=pending-payment'),
        ),
      );

      expect(find.text('Cathy Payment'), findsOneWidget);
      expect(_catalogAction(), findsOneWidget);
      expect(_toolbarPrimary('Catalog and stock'), findsNothing);
      expect(_toolbarPrimary('Billing'), findsNothing);
      expect(_toolbarAction('Catalog and stock'), findsNothing);
      expect(_toolbarAction('Refresh'), findsNothing);
    },
  );

  testWidgets('deep link section=inventory lands on inline catalog section', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
      initialLocation: '/pharmacy?section=inventory',
      initialQuery: PharmacyWorkspaceQuery.fromUri(
        Uri.parse('/pharmacy?section=inventory'),
      ),
    );

    // Legacy inventory deep link routes to the inline catalog section (no
    // dialog) on its nested Inventory tab.
    expect(find.byType(AppDialog), findsNothing);
    expect(find.byType(PharmacyCatalogPanel), findsOneWidget);
    expect(harness.router, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deep link orderId opens prescription detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
      initialLocation: '/pharmacy?orderId=order-ready',
      initialQuery: PharmacyWorkspaceQuery.fromUri(
        Uri.parse('/pharmacy?orderId=order-ready'),
      ),
    );

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('PRESCRIPTION DETAIL'), findsOneWidget);
    verify(() => repository.loadOrderWorkflow('order-ready')).called(1);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('PharmacyWorkspacePage opens inline catalog from desk tab', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    expect(find.text('Noah Ready'), findsOneWidget);
    expect(find.byType(AppWorkspaceToolbar), findsNothing);
    // Catalog is a desk tab now; the old search-bar toolbar action is gone.
    expect(_catalogAction(), findsOneWidget);
    expect(_toolbarPrimary('Catalog and stock'), findsNothing);
    expect(find.byType(PharmacyCatalogPanel), findsNothing);

    await _openCatalogSection(tester);

    // Renders inline (no dialog) and shows the nested catalog tables.
    expect(find.byType(AppDialog), findsNothing);
    expect(find.byType(PharmacyCatalogPanel), findsOneWidget);
    expect(find.text('Drugs'), findsWidgets);
    expect(find.text('Rooms'), findsOneWidget);
    expect(find.text('Storage layout'), findsNothing);
    expect(find.text('Generic name'), findsWidgets);
    expect(find.text('Generic (scientific) name'), findsNothing);
    expect(
      find.descendant(of: find.byType(AppListTableGrid), matching: find.text('Actions')),
      findsOneWidget,
    );
    expect(find.byIcon(AppActionIcons.export), findsOneWidget);
    // Add lives in the search trailing cluster (not an above-table toolbar).
    expect(find.byTooltip('Create drug'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PharmacyWorkspacePage returns from catalog to orders', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    await _openCatalogSection(tester);
    expect(find.byType(PharmacyCatalogPanel), findsOneWidget);

    final AppTabStrip strip = tester.widget<AppTabStrip>(
      find.byType(AppTabStrip),
    );
    final AppTabItem newOrdersTab = strip.tabs.firstWhere(
      (AppTabItem tab) => tab.label == 'New orders',
    );
    strip.onTabTapped(newOrdersTab.id);
    await tester.pumpAndSettle();

    expect(find.byType(PharmacyCatalogPanel), findsNothing);
    expect(find.text('Noah Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending payment tab shows billing, ordered_at, and status', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(_tab('Pending payment'));
    await tester.pumpAndSettle();

    expect(
      harness.router.state.uri.queryParameters['section'],
      'pending-payment',
    );
    expect(_catalogAction(), findsOneWidget);
    final Finder table = find.byType(AppListTableGrid);
    expect(
      find.descendant(of: table, matching: find.text('Ordered at')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.text('Payment')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: table, matching: find.text('Status')),
      findsOneWidget,
    );
    expect(find.text('Cathy Payment'), findsOneWidget);
  });

  testWidgets('ready queue table exposes at most five data columns', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    final AppListTable<PharmacyOrder> table = tester
        .widget<AppListTable<PharmacyOrder>>(
          find.byType(AppListTable<PharmacyOrder>),
        );
    expect(table.columns.length, lessThanOrEqualTo(5));
  });

  testWidgets('ready queue shows next action for ordered worklist row', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Cancel order'),
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('row next action opens cancel dialog without detail shell', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    await tester.tap(
      find
          .descendant(
            of: find.byType(AppListTableGrid),
            matching: find.text('Cancel order'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('PRESCRIPTION DETAIL'), findsNothing);
    expect(find.text('CANCEL PHARMACY ORDER'), findsOneWidget);
    verify(() => repository.loadOrderWorkflow(any())).called(1);
  });

  testWidgets('read-only users keep catalog; write next-action absent', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
      accessPolicy: _pharmacyReadOnlyPolicy(),
    );

    expect(_catalogAction(), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Cancel order'),
      ),
      findsNothing,
    );
  });

  testWidgets('mobile breakpoint uses list tiles with status and next action', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(390, 844),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppListTableGrid), findsNothing);
    expect(_toolbarAction('Refresh'), findsNothing);
    expect(find.textContaining('Noah'), findsAtLeastNWidgets(1));
    expect(find.text('Cancel order'), findsAtLeastNWidgets(1));
  });

  testWidgets('All orders tab shows every order and catalog search action', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
    );

    await _openMoreTabs(tester);
    await tester.tap(find.textContaining('All orders').last);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'all');
    expect(find.text('Noah Ready'), findsOneWidget);
    expect(find.text('Amina Partial'), findsOneWidget);
    expect(find.text('Brian Done'), findsOneWidget);
    expect(_catalogAction(), findsOneWidget);
    expect(_toolbarAction('Refresh'), findsNothing);
  });

  testWidgets('advanced filters omit queue status and pending payment groups', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    final AppListTable<PharmacyOrder> table = tester
        .widget<AppListTable<PharmacyOrder>>(
          find.byType(AppListTable<PharmacyOrder>),
        );
    expect(table.search?.advancedFilterTitle, 'Advanced filters');
    expect(
      table.search?.filterGroups.any(
        (AppSearchBarFilterGroup group) => group.key == 'status',
      ),
      isFalse,
    );
    expect(
      table.search?.filterGroups.any(
        (AppSearchBarFilterGroup group) => group.key == 'pending_payment',
      ),
      isFalse,
    );
    expect(
      table.search?.filterGroups.any(
        (AppSearchBarFilterGroup group) => group.key == 'location',
      ),
      isTrue,
    );
  });

  testWidgets(
    'detail shows only eligible writes and print; omits readiness chrome',
    (WidgetTester tester) async {
      await _pumpPharmacyWorkspace(tester, repository: repository);

      await tester.tap(find.text('Noah Ready'));
      await tester.pumpAndSettle();

      final Finder dialog = find.byType(AppDialog);
      expect(dialog, findsOneWidget);
      expect(find.text('PRESCRIPTION DETAIL'), findsOneWidget);
      expect(find.text('Pharmacy workflow readiness'), findsNothing);
      expect(
        find.descendant(of: dialog, matching: find.text('Cancel order')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Attest')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Return')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Print')),
        findsOneWidget,
      );
    },
  );

  testWidgets('read-only detail keeps print and hides write actions', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
      accessPolicy: _pharmacyReadOnlyPolicy(),
    );

    await tester.tap(find.text('Noah Ready'));
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
      findsOneWidget,
    );
  });
}
