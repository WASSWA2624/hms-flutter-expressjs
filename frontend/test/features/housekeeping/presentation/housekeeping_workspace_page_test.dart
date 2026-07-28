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
import 'package:hosspi_hms/features/housekeeping/data/repositories/housekeeping_repository_impl.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/domain/repositories/housekeeping_repository.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHousekeepingRepository extends Mock
    implements HousekeepingRepository {}

const HousekeepingWorkItem _taskItem = HousekeepingWorkItem(
  id: 'HK-TASK-1',
  displayId: 'HT-001',
  resource: HousekeepingResource.tasks,
  title: 'Clean ward 2B',
  status: 'PENDING',
  roomLabel: 'Room 2B',
  facilityLabel: 'Main Campus',
  assigneeLabel: 'Asha Cleaner',
);

const HousekeepingWorkItem _assignedPendingTask = HousekeepingWorkItem(
  id: 'HK-TASK-2',
  displayId: 'HT-002',
  resource: HousekeepingResource.tasks,
  title: 'Clean ward 3C',
  status: 'PENDING',
  roomLabel: 'Room 3C',
  facilityLabel: 'Main Campus',
  assigneeId: 'STAFF-1',
  assigneeLabel: 'Asha Cleaner',
);

const HousekeepingWorkItem _inProgressTask = HousekeepingWorkItem(
  id: 'HK-TASK-3',
  displayId: 'HT-003',
  resource: HousekeepingResource.tasks,
  title: 'Clean ward 4D',
  status: 'IN_PROGRESS',
  roomLabel: 'Room 4D',
  facilityLabel: 'Main Campus',
  assigneeId: 'STAFF-1',
  assigneeLabel: 'Asha Cleaner',
);

const HousekeepingWorkItem _scheduleItem = HousekeepingWorkItem(
  id: 'HK-SCH-1',
  displayId: 'HS-001',
  resource: HousekeepingResource.schedules,
  title: 'Daily corridor sweep',
  subtitle: 'Daily',
  status: 'ACTIVE',
  roomLabel: 'Corridor A',
  facilityLabel: 'Main Campus',
);

const HousekeepingWorkItem _maintenanceItem = HousekeepingWorkItem(
  id: 'HK-MR-1',
  displayId: 'MR-001',
  resource: HousekeepingResource.maintenanceRequests,
  title: 'Fix leaking tap',
  status: 'OPEN',
  roomLabel: 'Room 3A',
  facilityLabel: 'Main Campus',
  assetLabel: 'Tap-12',
);

const HousekeepingWorkspaceOverview _overview = HousekeepingWorkspaceOverview(
  summaryCards: <HousekeepingSummaryCard>[
    HousekeepingSummaryCard(
      id: 'pending_tasks',
      labelKey: 'pending_tasks',
      value: 3,
    ),
    HousekeepingSummaryCard(
      id: 'active_schedules',
      labelKey: 'active_schedules',
      value: 2,
    ),
    HousekeepingSummaryCard(
      id: 'open_requests',
      labelKey: 'open_requests',
      value: 1,
    ),
  ],
  lookups: HousekeepingLookups(
    facilities: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'FAC-1', label: 'Main Campus'),
    ],
    rooms: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'ROOM-1', label: 'Room 2B'),
    ],
    assignees: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'STAFF-1', label: 'Asha Cleaner'),
    ],
  ),
);

AppAccessPolicy _housekeepingWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['HOUSEKEEPING_MANAGER']),
      permissions: <AppPermission>{
        AppPermissions.operationsRead,
        AppPermissions.operationsWrite,
        AppPermissions.reportsRead,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'facilities-maintenance',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

AppAccessPolicy _housekeepingReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['VIEWER']),
      permissions: <AppPermission>{AppPermissions.operationsRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'facilities-maintenance',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

List<HousekeepingWorkItem> _itemsForQuery(
  HousekeepingWorkspaceQuery query, {
  List<HousekeepingWorkItem>? taskItems,
}) {
  return switch (query.resource) {
    HousekeepingResource.tasks =>
      taskItems ?? const <HousekeepingWorkItem>[_taskItem],
    HousekeepingResource.schedules => const <HousekeepingWorkItem>[
      _scheduleItem,
    ],
    HousekeepingResource.maintenanceRequests => const <HousekeepingWorkItem>[
      _maintenanceItem,
    ],
  };
}

void _stubWorkspace(
  _MockHousekeepingRepository repository, {
  List<HousekeepingWorkItem>? taskItems,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final HousekeepingWorkspaceQuery query =
        invocation.positionalArguments.single as HousekeepingWorkspaceQuery;
    final List<HousekeepingWorkItem> items = _itemsForQuery(
      query,
      taskItems: taskItems,
    );
    final String search = query.search.trim().toLowerCase();
    final List<HousekeepingWorkItem> filtered = search.isEmpty
        ? items
        : items
              .where((HousekeepingWorkItem item) {
                return item.title.toLowerCase().contains(search) ||
                    item.effectiveDisplayId.toLowerCase().contains(search);
              })
              .toList(growable: false);
    return Result<HousekeepingWorkspaceLoad>.success(
      HousekeepingWorkspaceLoad(
        overview: _overview,
        items: AppPage<HousekeepingWorkItem>(
          items: filtered,
          request: query.pageRequest,
          totalItemCount: filtered.length,
        ),
      ),
    );
  });
}

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockHousekeepingRepository repository;
  final GoRouter router;
}

Future<_Harness> _pumpHousekeepingWorkspace(
  WidgetTester tester, {
  required _MockHousekeepingRepository repository,
  HousekeepingSection? initialSection,
  String initialSearch = '',
  String initialLocation = '/housekeeping',
  Size viewport = const Size(1440, 900),
  AppAccessPolicy? accessPolicy,
  List<HousekeepingWorkItem>? taskItems,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, taskItems: taskItems);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/housekeeping',
        builder: (BuildContext context, GoRouterState state) {
          final String? section = state.uri.queryParameters['section'];
          final String? search = state.uri.queryParameters['search'];
          return Scaffold(
            body: HousekeepingWorkspacePage(
              initialSection:
                  initialSection ?? HousekeepingSection.fromQueryValue(section),
              initialSearch: initialSearch.isNotEmpty
                  ? initialSearch
                  : (search ?? ''),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        housekeepingRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _housekeepingWritePolicy(),
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

Finder _tabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.text(label),
  );
}

AppListTable<HousekeepingWorkItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<HousekeepingWorkItem>>(
    find.byType(AppListTable<HousekeepingWorkItem>),
  );
}

void main() {
  late _MockHousekeepingRepository repository;

  setUpAll(() {
    registerFallbackValue(const HousekeepingWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockHousekeepingRepository();
  });

  testWidgets('renders tab strip, task columns, and create task action', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppListTable<HousekeepingWorkItem>), findsOneWidget);
    expect(_tabLabel('Tasks'), findsOneWidget);
    expect(_tabLabel('Schedules'), findsOneWidget);
    expect(_tabLabel('Maintenance requests'), findsOneWidget);
    expect(find.byTooltip('Create task'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Assignee'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.text('Due time'), findsNothing);
    expect(_table(tester).columns.length, 5);
    expect(
      _table(tester).columns.any(
        (AppListTableColumn<HousekeepingWorkItem> column) =>
            column.id == 'next_action' && column.alwaysVisible,
      ),
      isTrue,
    );
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(_table(tester).columnVisibilityTitle, 'Table Settings');
    expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
    expect(_table(tester).search?.advancedFilterTitle, 'Advanced filters');
    expect(find.text('Clean ward 2B'), findsOneWidget);
  });

  testWidgets('switching tabs updates URL and loads section resource', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHousekeepingWorkspace(
      tester,
      repository: repository,
    );
    clearInteractions(repository);
    _stubWorkspace(repository);

    await tester.tap(_tabLabel('Schedules'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'schedules');
    expect(find.byTooltip('Create schedule'), findsOneWidget);
    expect(find.byTooltip('Create task'), findsNothing);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Frequency'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.text('Start date'), findsNothing);
    expect(find.text('End date'), findsNothing);
    expect(_table(tester).columns.length, 5);
    expect(find.text('Daily corridor sweep'), findsOneWidget);

    final List<HousekeepingWorkspaceQuery> queries = verify(
      () => repository.getWorkspace(captureAny()),
    ).captured.cast<HousekeepingWorkspaceQuery>();
    expect(
      queries.any(
        (HousekeepingWorkspaceQuery q) =>
            q.resource == HousekeepingResource.schedules,
      ),
      isTrue,
    );
  });

  testWidgets('deep link section=maintenance selects Maintenance tab', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(
      tester,
      repository: repository,
      initialLocation: '/housekeeping?section=maintenance',
      initialSection: HousekeepingSection.maintenance,
    );

    expect(find.byTooltip('Request maintenance'), findsOneWidget);
    expect(find.byTooltip('Create task'), findsNothing);
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Asset'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.text('Reported'), findsNothing);
    expect(_table(tester).columns.length, 5);
    expect(find.text('Fix leaking tap'), findsOneWidget);

    final List<HousekeepingWorkspaceQuery> queries = verify(
      () => repository.getWorkspace(captureAny()),
    ).captured.cast<HousekeepingWorkspaceQuery>();
    expect(
      queries.any(
        (HousekeepingWorkspaceQuery q) =>
            q.resource == HousekeepingResource.maintenanceRequests,
      ),
      isTrue,
    );
  });

  testWidgets('primary action changes per tab', (WidgetTester tester) async {
    await _pumpHousekeepingWorkspace(tester, repository: repository);

    expect(find.byTooltip('Create task'), findsOneWidget);

    await tester.tap(_tabLabel('Schedules'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Create schedule'), findsOneWidget);

    await tester.tap(_tabLabel('Maintenance requests'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Request maintenance'), findsOneWidget);
  });

  testWidgets('filter dialog excludes resource filter', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(tester, repository: repository);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('ADVANCED FILTERS'), findsOneWidget);
    expect(find.text('Queue'), findsWidgets);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Facility'), findsWidgets);
    expect(find.text('Room or bed'), findsWidgets);
    expect(find.text('Assignee'), findsWidgets);
    expect(find.text('Date'), findsWidgets);
    // Resource is selected via tabs, not the advanced filter dialog.
    expect(find.text('Resource'), findsNothing);
  });

  testWidgets('settings opens table settings dialog', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(tester, repository: repository);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('TABLE SETTINGS'), findsOneWidget);
  });

  testWidgets('next action opens assign dialog for unassigned task', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(tester, repository: repository);

    await tester.tap(find.text('Assign staff or team'));
    await tester.pumpAndSettle();

    expect(find.text('ASSIGN HOUSEKEEPING TASK'), findsOneWidget);
  });

  testWidgets('next action starts assigned pending task without confirm', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.updateTask(any(), any()),
    ).thenAnswer((_) async => const Result<void>.success(null));

    await _pumpHousekeepingWorkspace(
      tester,
      repository: repository,
      taskItems: const <HousekeepingWorkItem>[_assignedPendingTask],
    );

    await tester.tap(find.text('Start cleaning'));
    await tester.pumpAndSettle();

    expect(find.text('START CLEANING'), findsNothing);
    expect(find.text('Mark this housekeeping task as in progress.'), findsNothing);
    verify(
      () => repository.updateTask(
        'HK-TASK-2',
        any(
          that: predicate<Map<String, Object?>>(
            (Map<String, Object?> payload) =>
                payload['status'] == 'IN_PROGRESS',
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('next action completes in-progress task without confirm', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.updateTask(any(), any()),
    ).thenAnswer((_) async => const Result<void>.success(null));

    await _pumpHousekeepingWorkspace(
      tester,
      repository: repository,
      taskItems: const <HousekeepingWorkItem>[_inProgressTask],
    );

    await tester.tap(find.text('Complete cleaning'));
    await tester.pumpAndSettle();

    expect(find.text('COMPLETE CLEANING'), findsNothing);
    verify(
      () => repository.updateTask(
        'HK-TASK-3',
        any(
          that: predicate<Map<String, Object?>>(
            (Map<String, Object?> payload) =>
                payload['status'] == 'COMPLETED',
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('detail omits assign when it is the row next action', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(tester, repository: repository);

    await tester.tap(find.text('Clean ward 2B'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    expect(find.text('Mark ready'), findsNothing);
    expect(find.text('Readiness'), findsNothing);
    // Assign is the next-action primary — not duplicated in detail.
    expect(
      find.descendant(of: find.byType(AppDialog), matching: find.text('Assign')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(AppDialog), matching: find.text('Cancel')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(AppDialog), matching: find.text('Start')),
      findsOneWidget,
    );
  });

  testWidgets('unauthorized create and write next-actions are absent', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(
      tester,
      repository: repository,
      accessPolicy: _housekeepingReadOnlyPolicy(),
    );

    expect(find.byTooltip('Create task'), findsNothing);
    expect(find.text('Assign staff or team'), findsNothing);
    expect(find.text('View details'), findsWidgets);
  });

  testWidgets('maintenance next action opens triage; detail omits triage', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(
      tester,
      repository: repository,
      initialLocation: '/housekeeping?section=maintenance',
      initialSection: HousekeepingSection.maintenance,
    );

    await tester.tap(find.text('Fix leaking tap'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Triage'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Complete request'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('search submits applySearch to repository', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(tester, repository: repository);
    clearInteractions(repository);
    _stubWorkspace(repository);

    await tester.enterText(find.byType(TextField).first, 'ward');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final List<HousekeepingWorkspaceQuery> queries = verify(
      () => repository.getWorkspace(captureAny()),
    ).captured.cast<HousekeepingWorkspaceQuery>();
    expect(
      queries.any((HousekeepingWorkspaceQuery q) => q.search == 'ward'),
      isTrue,
    );
  });

  testWidgets('row selection opens task detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(tester, repository: repository);

    await tester.tap(find.text('Clean ward 2B'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
  });

  testWidgets('narrow viewport uses mobile item cards', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(
      tester,
      repository: repository,
      viewport: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Clean ward 2B'), findsOneWidget);
    expect(find.text('Assign staff or team'), findsWidgets);
    expect(_tabLabel('Tasks'), findsOneWidget);
  });
}
