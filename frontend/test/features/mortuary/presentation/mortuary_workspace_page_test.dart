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
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

const MortuaryWorkspaceItem _caseItem = MortuaryWorkspaceItem(
  id: 'case-1',
  displayId: 'MOR-001',
  status: 'IN_STORAGE',
  identificationStatus: 'VERIFIED',
  billingStatus: 'SETTLED',
  deceasedProfileLabel: 'Amina K.',
);

AppAccessPolicy _mortuaryReadPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['MORTUARY_STAFF'],
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.mortuaryRead,
        AppPermissions.mortuaryWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'mortuary', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

MortuaryWorkspacePayload _payload(MortuaryWorkspaceQuery query) {
  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: const <MortuaryWorkspaceItem>[_caseItem],
      request: query.pageRequest,
      totalItemCount: 1,
    ),
    lookups: const MortuaryLookupData(),
    summary: const <MortuarySummaryItem>[
      MortuarySummaryItem(id: 'total_cases', value: 1),
      MortuarySummaryItem(id: 'in_storage', value: 1),
      MortuarySummaryItem(id: 'identification_pending', value: 1),
      MortuarySummaryItem(id: 'release_ready', value: 1),
      MortuarySummaryItem(id: 'unsettled_billing', value: 1),
    ],
    queues: const <MortuaryQueueSummary>[
      MortuaryQueueSummary(
        queue: mortuaryQueueIdentificationPending,
        count: 1,
        panel: mortuaryPanelIntake,
        resource: mortuaryResourceCases,
      ),
      MortuaryQueueSummary(
        queue: mortuaryQueueStorageExceptions,
        count: 1,
        panel: mortuaryPanelStorage,
        resource: mortuaryResourceStorageAssignments,
      ),
      MortuaryQueueSummary(
        queue: mortuaryQueueReleaseReady,
        count: 1,
        panel: mortuaryPanelRelease,
        resource: mortuaryResourceReleaseAuthorisations,
      ),
      MortuaryQueueSummary(
        queue: mortuaryQueueUnsettledBilling,
        count: 1,
        panel: mortuaryPanelRelease,
        resource: mortuaryResourceBillableEvents,
      ),
      MortuaryQueueSummary(
        queue: mortuaryQueuePostMortemPending,
        count: 1,
        panel: mortuaryPanelReporting,
        resource: mortuaryResourcePostMortemRequests,
      ),
    ],
    panels: const <MortuaryPanelSummary>[
      MortuaryPanelSummary(
        id: mortuaryPanelOverview,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelIntake,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelStorage,
        count: 0,
        defaultResource: mortuaryResourceStorageAssignments,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelCustody,
        count: 0,
        defaultResource: mortuaryResourceCustodyEvents,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelRelease,
        count: 1,
        defaultResource: mortuaryResourceReleaseAuthorisations,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelReporting,
        count: 1,
        defaultResource: mortuaryResourcePostMortemRequests,
      ),
    ],
    filters: query,
    lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
  );
}

void _stubWorkspace(_MockMortuaryRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final MortuaryWorkspaceQuery query =
        invocation.positionalArguments.single as MortuaryWorkspaceQuery;
    return Result<MortuaryWorkspacePayload>.success(_payload(query));
  });
  when(
    () => repository.getItem(
      resource: any(named: 'resource'),
      id: any(named: 'id'),
      baseQuery: any(named: 'baseQuery'),
    ),
  ).thenAnswer(
    (_) async => const Result<MortuaryWorkspaceItem>.success(_caseItem),
  );
}

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockMortuaryRepository repository;
  final GoRouter router;
}

Future<_Harness> _pumpMortuaryWorkspace(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  MortuaryRouteQuery? initialQuery,
  String initialLocation = '/mortuary',
  Size viewport = const Size(1440, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/mortuary',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: MortuaryWorkspacePage(
              initialQuery:
                  initialQuery ?? MortuaryRouteQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mortuaryRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(_mortuaryReadPolicy()),
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

AppListTable<MortuaryWorkspaceItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<MortuaryWorkspaceItem>>(
    find.byType(AppListTable<MortuaryWorkspaceItem>),
  );
}

void main() {
  late _MockMortuaryRepository repository;

  setUpAll(() {
    registerFallbackValue(const MortuaryWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockMortuaryRepository();
  });

  testWidgets('renders tab strip with all six panel tabs', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Intake'), findsWidgets);
    expect(find.text('Storage'), findsWidgets);
    expect(find.text('Custody'), findsWidgets);
    expect(find.text('Release'), findsWidgets);
    expect(find.text('Reports'), findsWidgets);
  });

  testWidgets('tab strip has no mutation primary or Refresh', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(tester, repository: repository);

    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Receive case'),
      ),
      findsNothing,
    );
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
  });

  testWidgets('intake tab has no disabled receive-case primary', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(tester, repository: repository);

    await tester.tap(find.text('Intake').first);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Receive case'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Assign storage'),
      ),
      findsNothing,
    );
  });

  testWidgets('storage tab has no disabled assign-storage primary', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(tester, repository: repository);

    await tester.tap(find.text('Storage').first);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Assign storage'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Receive case'),
      ),
      findsNothing,
    );
  });

  testWidgets('table chrome exposes Filters and Settings only', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(tester, repository: repository);

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(_table(tester).columnVisibilityTitle, 'Table Settings');
    expect(_table(tester).columnVisibilityStorageKey, 'mortuary_overview');
    expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
    expect(_table(tester).search?.advancedFilterTitle, 'Advanced filters');
    expect(_table(tester).columns.length, 5);
    expect(
      _table(tester).columns.any(
        (AppListTableColumn<MortuaryWorkspaceItem> column) =>
            column.id == 'next_action' && column.alwaysVisible,
      ),
      isTrue,
    );
    expect(find.text('Deceased'), findsOneWidget);
    expect(find.text('Case'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(
      _table(tester).columns.any(
        (AppListTableColumn<MortuaryWorkspaceItem> column) =>
            column.id == 'storage',
      ),
      isFalse,
    );
    expect(
      _table(tester).columns.any(
        (AppListTableColumn<MortuaryWorkspaceItem> column) =>
            column.id == 'date',
      ),
      isFalse,
    );
  });

  testWidgets('storage tab shows five panel-specific default columns', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(tester, repository: repository);

    await tester.tap(find.text('Storage').first);
    await tester.pumpAndSettle();

    expect(_table(tester).columnVisibilityStorageKey, 'mortuary_storage');
    expect(_table(tester).columns.length, 5);
    expect(
      _table(tester).columns.map(
        (AppListTableColumn<MortuaryWorkspaceItem> column) => column.id,
      ),
      <String>['deceased', 'storage', 'status', 'date', 'next_action'],
    );
    expect(
      _table(tester).columns.any(
        (AppListTableColumn<MortuaryWorkspaceItem> column) =>
            column.id == 'source',
      ),
      isFalse,
    );
  });

  testWidgets('row select opens detail dialog', (WidgetTester tester) async {
    await _pumpMortuaryWorkspace(tester, repository: repository);

    final AppListTable<MortuaryWorkspaceItem> table = _table(tester);
    expect(table.onRowSelected, isNotNull);
    table.onRowSelected!(_caseItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('CASE DETAIL'), findsOneWidget);
    expect(find.text('Actions unavailable'), findsNothing);
    verify(
      () => repository.getItem(
        resource: any(named: 'resource'),
        id: any(named: 'id'),
        baseQuery: any(named: 'baseQuery'),
      ),
    ).called(1);
  });

  testWidgets('next action is guidance text, not a detail button', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(tester, repository: repository);

    expect(find.text('Assign storage'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Assign storage'),
        matching: find.byType(TextButton),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Assign storage'));
    await tester.pumpAndSettle();
    expect(find.text('CASE DETAIL'), findsNothing);
  });

  testWidgets('mobile viewport keeps tab strip and worklist chrome', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(
      tester,
      repository: repository,
      viewport: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
  });

  testWidgets('filter dialog excludes panel filter group', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(tester, repository: repository);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Resource'), findsWidgets);
    expect(find.text('Queue'), findsWidgets);
    expect(find.text('Panel'), findsNothing);
  });

  testWidgets('switching tabs updates URL panel query', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpMortuaryWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.text('Storage').first);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['panel'], 'storage');

    final List<MortuaryWorkspaceQuery> queries = verify(
      () => repository.getWorkspace(captureAny()),
    ).captured.cast<MortuaryWorkspaceQuery>();
    expect(
      queries.any(
        (MortuaryWorkspaceQuery q) => q.panel == mortuaryPanelStorage,
      ),
      isTrue,
    );
  });

  testWidgets('deep link panel=release selects Release tab', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(
      tester,
      repository: repository,
      initialLocation: '/mortuary?panel=release',
      initialQuery: MortuaryRouteQuery.fromUri(
        Uri.parse('/mortuary?panel=release'),
      ),
    );

    final AppTabStrip strip = tester.widget<AppTabStrip>(
      find.byType(AppTabStrip),
    );
    expect(strip.selectedId, mortuaryPanelRelease);
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Approve release'),
      ),
      findsNothing,
    );

    final List<MortuaryWorkspaceQuery> queries = verify(
      () => repository.getWorkspace(captureAny()),
    ).captured.cast<MortuaryWorkspaceQuery>();
    expect(
      queries.any(
        (MortuaryWorkspaceQuery q) => q.panel == mortuaryPanelRelease,
      ),
      isTrue,
    );
  });

  testWidgets('AppTabStrip renders on narrow mobile viewport', (
    WidgetTester tester,
  ) async {
    await _pumpMortuaryWorkspace(
      tester,
      repository: repository,
      viewport: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
  });
}
