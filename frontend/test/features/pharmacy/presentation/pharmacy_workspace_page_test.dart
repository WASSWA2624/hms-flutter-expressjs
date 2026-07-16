import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPharmacyRepository extends Mock implements PharmacyRepository {}

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
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'pharmacy-dispensing',
          licenseStatus: 'ACTIVE',
        ),
      ],
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
        appAccessPolicyProvider.overrideWithValue(_pharmacyWritePolicy()),
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

  testWidgets('renders tab strip with section counts and ready queue', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Partial'), findsOneWidget);
    expect(find.text('Pending payment'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('All orders'), findsOneWidget);
    expect(find.text('Noah Ready'), findsOneWidget);
    expect(find.text('Amina Partial'), findsNothing);
    expect(find.textContaining('Dispense'), findsWidgets);
    // Inventory alerts live in the toolbar overflow (showsNotifications).
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('All orders'), findsOneWidget);
  });

  testWidgets('switching tabs updates URL and applies filter', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.text('Partial'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'in-progress');
    expect(find.text('Amina Partial'), findsOneWidget);
    expect(find.text('Noah Ready'), findsNothing);
    expect(find.textContaining('Dispense'), findsWidgets);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'completed');
    expect(find.text('Brian Done'), findsOneWidget);
    expect(find.textContaining('Catalog and stock'), findsWidgets);
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

  testWidgets('deep link section=inventory opens catalog dialog', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
      initialLocation: '/pharmacy?section=inventory',
      initialQuery: PharmacyWorkspaceQuery.fromUri(
        Uri.parse('/pharmacy?section=inventory'),
      ),
    );

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('CATALOG AND STOCK'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('PharmacyWorkspacePage opens catalog from overflow action', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    expect(find.text('Noah Ready'), findsOneWidget);
    expect(find.text('Catalog and stock'), findsWidgets);

    await tester.tap(find.text('Catalog and stock').first);
    await tester.pumpAndSettle();

    expect(find.text('CATALOG AND STOCK'), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    expect(find.text('Noah Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PharmacyWorkspacePage catalog dialog closes with escape', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    await tester.tap(find.text('Catalog and stock').first);
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    expect(find.text('Pharmacy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending payment tab shows ordered_at column by default', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(tester, repository: repository);

    await tester.tap(find.text('Pending payment'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Ordered at'),
      ),
      findsOneWidget,
    );
    expect(find.text('Cathy Payment'), findsOneWidget);
  });

  testWidgets('mobile breakpoint uses list tiles instead of data table', (
    WidgetTester tester,
  ) async {
    await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Noah Ready'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets('All orders tab shows every order and catalog primary action', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpPharmacyWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.text('All orders'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'all');
    expect(find.text('Noah Ready'), findsOneWidget);
    expect(find.text('Amina Partial'), findsOneWidget);
    expect(find.text('Brian Done'), findsOneWidget);
    expect(find.textContaining('Catalog and stock'), findsWidgets);
  });
}
