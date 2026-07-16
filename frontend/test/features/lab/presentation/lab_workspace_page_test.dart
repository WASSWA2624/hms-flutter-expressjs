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
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLabRepository extends Mock implements LabRepository {}

const LabOrderSummary _orderedOrder = LabOrderSummary(
  id: 'LAB-ORDER-1',
  displayId: 'LO-1',
  status: 'ORDERED',
  patientDisplayName: 'Ann Ordered',
  patientId: 'PAT-1',
  paymentStatus: 'UNPAID',
);

const LabOrderSummary _completedOrder = LabOrderSummary(
  id: 'LAB-ORDER-2',
  displayId: 'LO-2',
  status: 'COMPLETED',
  patientDisplayName: 'Vera Verified',
  patientId: 'PAT-2',
  paymentStatus: 'PAID',
);

AppAccessPolicy _labWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['LAB_TECH']),
      permissions: <AppPermission>{
        AppPermissions.labRead,
        AppPermissions.labWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

LabWorkbenchBundle _workbenchFor(LabWorkbenchQuery query) {
  final List<LabOrderSummary> all = <LabOrderSummary>[
    _orderedOrder,
    _completedOrder,
  ];
  final List<LabOrderSummary> items = all
      .where(
        (LabOrderSummary order) => labOrderMatchesScope(order, query.scope),
      )
      .toList(growable: false);
  return LabWorkbenchBundle(
    summary: const LabWorkbenchSummary(
      totalOrders: 2,
      collectionQueue: 1,
      completedOrders: 1,
      totalPatients: 2,
      collectionPatients: 1,
      completedPatients: 1,
    ),
    worklist: AppPage<LabOrderSummary>(
      items: items,
      request: query.pageRequest,
      totalItemCount: items.length,
    ),
  );
}

void _stubWorkspace(_MockLabRepository repository) {
  when(() => repository.loadWorkbench(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final LabWorkbenchQuery query =
        invocation.positionalArguments.single as LabWorkbenchQuery;
    return Result<LabWorkbenchBundle>.success(_workbenchFor(query));
  });
  when(
    () => repository.listQcLogs(search: any(named: 'search')),
  ).thenAnswer((_) async => const Result<List<LabQcLog>>.success(<LabQcLog>[]));
  when(() => repository.loadOrderWorkflow(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String orderId = invocation.positionalArguments.single as String;
    final LabOrderSummary order = orderId == _completedOrder.id
        ? _completedOrder
        : _orderedOrder;
    return Result<LabOrderWorkflow>.success(LabOrderWorkflow(order: order));
  });
}

AppListTable<LabOrderSummary> _table(WidgetTester tester) {
  return tester.widget<AppListTable<LabOrderSummary>>(
    find.byType(AppListTable<LabOrderSummary>),
  );
}

Future<GoRouter> _pumpLabWorkspace(
  WidgetTester tester, {
  required _MockLabRepository repository,
  LabWorkspaceQuery? initialQuery,
  String initialLocation = '/lab',
  Size viewport = const Size(1440, 900),
  AppAccessPolicy? policy,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  _stubWorkspace(repository);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/lab',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: LabWorkspacePage(
              initialQuery:
                  initialQuery ?? LabWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        labRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy ?? _labWritePolicy()),
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

void main() {
  late _MockLabRepository repository;

  setUpAll(() {
    registerFallbackValue(const LabWorkbenchQuery());
  });

  setUp(() {
    repository = _MockLabRepository();
  });

  testWidgets('renders AppTabStrip with six section tabs and worklist table', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppWorkspaceToolbar), findsNothing);
    expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
    expect(find.textContaining('All'), findsWidgets);
    expect(find.textContaining('Awaiting results'), findsWidgets);
    expect(find.textContaining('Processing'), findsWidgets);
    expect(find.textContaining('Pending verification'), findsWidgets);
    expect(find.textContaining('Critical'), findsWidgets);
    expect(find.textContaining('Verified'), findsWidgets);
    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.byTooltip('Orders view'), findsOneWidget);
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
  });

  testWidgets('does not paint a dedicated laboratory title header', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(tester, repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );
    expect(find.text(l10n.labTitle), findsNothing);
  });

  testWidgets('switching tabs updates section query and toolbar actions', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpLabWorkspace(
      tester,
      repository: repository,
    );

    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);

    await tester.tap(find.textContaining('Processing').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'processing');
    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsNothing);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(_table(tester).columnVisibilityStorageKey, 'lab_processing');

    await tester.tap(find.textContaining('Verified').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'completed');
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(_table(tester).columnVisibilityStorageKey, 'lab_completed');
  });

  testWidgets('deep link section=critical selects Critical tab', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(
      tester,
      repository: repository,
      initialLocation: '/lab?section=critical',
      initialQuery: LabWorkspaceQuery.fromUri(
        Uri.parse('/lab?section=critical'),
      ),
    );

    final List<LabWorkbenchQuery> queries = verify(
      () => repository.loadWorkbench(captureAny()),
    ).captured.cast<LabWorkbenchQuery>();
    expect(
      queries.any((LabWorkbenchQuery q) => q.scope == LabQueueScope.critical),
      isTrue,
    );
    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsNothing);
    expect(_table(tester).columnVisibilityStorageKey, 'lab_critical');
  });

  testWidgets('read-only users keep view toggle and refresh toolbar actions', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy readOnly = AppAccessPolicy.fromSession(
      AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['LAB_VIEWER']),
        permissions: <AppPermission>{AppPermissions.labRead},
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
        ],
      ),
    );

    await _pumpLabWorkspace(tester, repository: repository, policy: readOnly);

    expect(find.byTooltip('Create Lab Order'), findsNothing);
    expect(find.byTooltip('Lab Configurations'), findsNothing);
    expect(find.byTooltip('Orders view'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });
}
