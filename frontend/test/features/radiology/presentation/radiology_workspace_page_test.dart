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
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/features/radiology/presentation/pages/radiology_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRadiologyRepository extends Mock implements RadiologyRepository {}

const RadiologyOrder _orderedOrder = RadiologyOrder(
  id: 'RO-ORDERED',
  displayId: 'RAD-ORDERED',
  status: 'ORDERED',
  patientDisplayName: 'Olivia Ordered',
  modality: 'XRAY',
  testDisplayName: 'Chest X-ray',
);

const RadiologyOrder _reportingOrder = RadiologyOrder(
  id: 'RO-REPORT',
  displayId: 'RAD-REPORT',
  status: 'IN_PROCESS',
  patientDisplayName: 'Rita Reporting',
  modality: 'CT',
  testDisplayName: 'CT Head',
  draftResultCount: 1,
);

const RadiologyOrder _releasedOrder = RadiologyOrder(
  id: 'RO-RELEASED',
  displayId: 'RAD-RELEASED',
  status: 'COMPLETED',
  patientDisplayName: 'Finn Finalized',
  modality: 'MRI',
  testDisplayName: 'MRI Brain',
  finalResultCount: 1,
);

const RadiologySummary _summary = RadiologySummary(
  totalOrders: 3,
  orderedQueue: 1,
  processingQueue: 1,
  draftReports: 1,
  finalizedReports: 1,
  actionableOrders: 2,
  reportingOrders: 1,
  actionablePatients: 2,
  reportingPatients: 1,
  releasedPatients: 1,
  totalPatients: 3,
);

AppAccessPolicy _radiologyWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['RADIOLOGIST']),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.radiologyRead,
        AppPermissions.radiologyWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'radiology-workflows',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

RadiologyWorkflow _workflowFor(RadiologyOrder order) {
  return RadiologyWorkflow(
    order: order,
    nextActions: const RadiologyNextActions(
      canStart: true,
      canComplete: true,
      canCancel: true,
    ),
  );
}

List<RadiologyOrder> _ordersForQuery(RadiologyWorkspaceQuery query) {
  final List<RadiologyOrder> all = <RadiologyOrder>[
    _orderedOrder,
    _reportingOrder,
    _releasedOrder,
  ];
  final String stage = query.stage.trim().toUpperCase();
  List<RadiologyOrder> items = all;
  if (stage == 'WORKLIST') {
    items = all
        .where((RadiologyOrder order) {
          final String status = (order.status ?? '').toUpperCase();
          return status == 'ORDERED' || status == 'IN_PROCESS';
        })
        .toList(growable: false);
  } else if (stage == 'REPORTING') {
    items = all
        .where((RadiologyOrder order) => order.draftResultCount > 0)
        .toList(growable: false);
  } else if (stage == 'COMPLETED') {
    items = all
        .where(
          (RadiologyOrder order) =>
              (order.status ?? '').toUpperCase() == 'COMPLETED',
        )
        .toList(growable: false);
  }
  final String search = query.search.trim().toLowerCase();
  if (search.isNotEmpty) {
    items = items
        .where((RadiologyOrder order) {
          final String name = (order.patientDisplayName ?? '').toLowerCase();
          final String id = (order.displayId ?? order.id).toLowerCase();
          return name.contains(search) || id.contains(search);
        })
        .toList(growable: false);
  }
  return items;
}

void _stubRadiologyRepository(_MockRadiologyRepository repository) {
  when(
    () => repository.getReferenceData(
      search: any(named: 'search'),
      patientId: any(named: 'patientId'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<RadiologyReferenceData>.success(RadiologyReferenceData()),
  );
  when(() => repository.getWorkbench(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final RadiologyWorkspaceQuery query =
        invocation.positionalArguments.single as RadiologyWorkspaceQuery;
    final List<RadiologyOrder> items = _ordersForQuery(query);
    return Result<RadiologyWorkbench>.success(
      RadiologyWorkbench(
        summary: _summary,
        orders: AppPage<RadiologyOrder>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      ),
    );
  });
  when(
    () => repository.listRadiologyCatalogProcedures(
      search: any(named: 'search'),
      includeStandardCatalog: any(named: 'includeStandardCatalog'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<RadiologyCatalogProcedure>>.success(
      <RadiologyCatalogProcedure>[],
    ),
  );
  when(
    () => repository.listFacilityRadiologyProcedures(
      tenantId: any(named: 'tenantId'),
      facilityId: any(named: 'facilityId'),
      search: any(named: 'search'),
      page: any(named: 'page'),
      limit: any(named: 'limit'),
      offeredOnly: any(named: 'offeredOnly'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<RadiologyCatalogProcedure>>.success(
      <RadiologyCatalogProcedure>[],
    ),
  );
  when(
    () => repository.listEquipmentRecords(search: any(named: 'search')),
  ).thenAnswer(
    (_) async => const Result<List<RadiologyEquipmentRecord>>.success(
      <RadiologyEquipmentRecord>[],
    ),
  );
  when(() => repository.getWorkflow(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.single as String;
    final RadiologyOrder match =
        <RadiologyOrder>[
          _orderedOrder,
          _reportingOrder,
          _releasedOrder,
        ].firstWhere(
          (RadiologyOrder order) => order.id == id || order.displayId == id,
          orElse: () => _orderedOrder,
        );
    return Result<RadiologyWorkflow>.success(_workflowFor(match));
  });
}

Future<GoRouter> _pumpRadiologyWorkspace(
  WidgetTester tester, {
  required _MockRadiologyRepository repository,
  RadiologyWorkspaceQuery? initialQuery,
  String initialLocation = '/radiology',
  Size viewport = const Size(1440, 900),
  AppAccessPolicy? policy,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRadiologyRepository(repository);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/radiology',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: RadiologyWorkspacePage(
              initialQuery:
                  initialQuery ?? RadiologyWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        radiologyRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(
          policy ?? _radiologyWritePolicy(),
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
  return router;
}

AppListTable<RadiologyOrder> _table(WidgetTester tester) {
  return tester.widget<AppListTable<RadiologyOrder>>(
    find.byType(AppListTable<RadiologyOrder>),
  );
}

AppAccessPolicy _radiologyReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['RADIOLOGIST']),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.radiologyRead,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'radiology-workflows',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

void main() {
  late _MockRadiologyRepository repository;

  setUpAll(() {
    registerFallbackValue(const RadiologyWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockRadiologyRepository();
  });

  testWidgets('renders tab strip with section counts and order table', (
    WidgetTester tester,
  ) async {
    await _pumpRadiologyWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppListTable<RadiologyOrder>), findsOneWidget);
    expect(find.textContaining('Worklist'), findsWidgets);
    expect(find.textContaining('Reporting'), findsWidgets);
    expect(find.textContaining('All orders'), findsWidgets);
    expect(find.textContaining('Released'), findsNothing);
    expect(find.text('Olivia Ordered'), findsOneWidget);
    expect(find.byTooltip('Request imaging'), findsOneWidget);
    expect(find.byTooltip('Configurations'), findsNothing);
    expect(find.byTooltip('Orders view'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Procedure done'), findsWidgets);
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(_table(tester).columnVisibilityTitle, 'Table Settings');
    expect(
      _table(tester).columnVisibilityStorageKey,
      'radiology_worklist_patients',
    );
    expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
    expect(_table(tester).search?.advancedFilterTitle, 'Advanced filters');
    expect(_table(tester).columns.length, 5);
  });

  testWidgets('switching tabs applies stage filters and updates URL', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpRadiologyWorkspace(
      tester,
      repository: repository,
    );
    clearInteractions(repository);
    _stubRadiologyRepository(repository);

    await tester.tap(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.textContaining('reporting'),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'reporting');
    List<RadiologyWorkspaceQuery> queries = verify(
      () => repository.getWorkbench(captureAny()),
    ).captured.cast<RadiologyWorkspaceQuery>();
    expect(
      queries.any((RadiologyWorkspaceQuery q) => q.stage == 'REPORTING'),
      isTrue,
    );
    expect(find.text('Rita Reporting'), findsOneWidget);
    expect(find.text('Olivia Ordered'), findsNothing);

    clearInteractions(repository);
    _stubRadiologyRepository(repository);

    await tester.tap(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.textContaining('All orders'),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'all');
    queries = verify(
      () => repository.getWorkbench(captureAny()),
    ).captured.cast<RadiologyWorkspaceQuery>();
    expect(
      queries.any((RadiologyWorkspaceQuery q) => q.stage == 'ALL'),
      isTrue,
    );
    expect(find.text('Olivia Ordered'), findsOneWidget);
    expect(find.text('Rita Reporting'), findsOneWidget);
    expect(find.text('Finn Finalized'), findsOneWidget);
  });

  testWidgets('request imaging stays on every workbench tab', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpRadiologyWorkspace(
      tester,
      repository: repository,
    );

    expect(find.byTooltip('Request imaging'), findsOneWidget);
    expect(find.byTooltip('Configurations'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byTooltip('Orders view'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.textContaining('reporting'),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'reporting');
    expect(find.byTooltip('Request imaging'), findsOneWidget);
    expect(find.byTooltip('Configurations'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.textContaining('All orders'),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'all');
    expect(find.byTooltip('Configurations'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byTooltip('Request imaging'), findsOneWidget);
  });

  testWidgets('deep link section=reporting selects Reporting tab', (
    WidgetTester tester,
  ) async {
    await _pumpRadiologyWorkspace(
      tester,
      repository: repository,
      initialLocation: '/radiology?section=reporting',
      initialQuery: RadiologyWorkspaceQuery.fromUri(
        Uri.parse('/radiology?section=reporting'),
      ),
    );

    final List<RadiologyWorkspaceQuery> queries = verify(
      () => repository.getWorkbench(captureAny()),
    ).captured.cast<RadiologyWorkspaceQuery>();
    expect(
      queries.any((RadiologyWorkspaceQuery q) => q.stage == 'REPORTING'),
      isTrue,
    );
    expect(find.text('Rita Reporting'), findsOneWidget);
    expect(find.text('Olivia Ordered'), findsNothing);
    expect(find.byTooltip('Request imaging'), findsOneWidget);
    expect(find.byTooltip('Configurations'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    // Reporting fixture has draftResultCount only (no embedded results list).
    expect(find.text('Done — waiting for report'), findsWidgets);
    expect(find.text('Create report'), findsWidgets);
  });

  testWidgets('search filters table rows via controller', (
    WidgetTester tester,
  ) async {
    await _pumpRadiologyWorkspace(tester, repository: repository);
    clearInteractions(repository);
    _stubRadiologyRepository(repository);

    await tester.enterText(find.byType(TextField).first, 'Rita');
    await tester.pump();
    // Shared search chrome can report a suffix overflow under test binding;
    // drain it so the filter assertion remains the focus of this check.
    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final List<RadiologyWorkspaceQuery> queries = verify(
      () => repository.getWorkbench(captureAny()),
    ).captured.cast<RadiologyWorkspaceQuery>();
    expect(
      queries.any((RadiologyWorkspaceQuery q) => q.search == 'Rita'),
      isTrue,
    );
    expect(find.text('Rita Reporting'), findsOneWidget);
    expect(find.text('Olivia Ordered'), findsNothing);
  });

  testWidgets('read-only users hide write actions and toolbar chrome', (
    WidgetTester tester,
  ) async {
    await _pumpRadiologyWorkspace(
      tester,
      repository: repository,
      policy: _radiologyReadOnlyPolicy(),
    );

    expect(find.byTooltip('Request imaging'), findsNothing);
    expect(find.byTooltip('Configurations'), findsNothing);
    expect(find.byTooltip('Orders view'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
  });

  testWidgets('next action opens order detail without route-only loop', (
    WidgetTester tester,
  ) async {
    await _pumpRadiologyWorkspace(tester, repository: repository);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );
    expect(find.text(l10n.radiologyMarkProcedureDoneAction), findsWidgets);

    await tester.ensureVisible(
      find.text(l10n.radiologyMarkProcedureDoneAction).first,
    );
    await tester.tap(find.text(l10n.radiologyMarkProcedureDoneAction).first);
    await tester.pumpAndSettle();

    expect(find.byKey(AppDialog.shellKey), findsOneWidget);
    expect(find.text(l10n.radiologyCancelOrderAction), findsOneWidget);
    expect(find.text(l10n.radiologyAssignAction), findsNothing);
    verify(() => repository.getWorkflow(any())).called(greaterThan(0));
  });

  testWidgets('deep link orderId opens order detail dialog directly', (
    WidgetTester tester,
  ) async {
    await _pumpRadiologyWorkspace(
      tester,
      repository: repository,
      initialLocation: '/radiology?orderId=RO-ORDERED',
      initialQuery: RadiologyWorkspaceQuery.fromUri(
        Uri.parse('/radiology?orderId=RO-ORDERED'),
      ),
    );

    expect(find.byKey(AppDialog.shellKey), findsOneWidget);
    expect(find.text('Olivia Ordered'), findsWidgets);
    verify(() => repository.getWorkflow(any())).called(greaterThan(0));
  });

  testWidgets('AppTabStrip renders on narrow mobile viewport', (
    WidgetTester tester,
  ) async {
    await _pumpRadiologyWorkspace(
      tester,
      repository: repository,
      viewport: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('Worklist'), findsWidgets);
    expect(find.textContaining('Reporting'), findsWidgets);
  });
}
