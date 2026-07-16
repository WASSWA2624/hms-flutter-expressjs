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

List<HousekeepingWorkItem> _itemsForQuery(HousekeepingWorkspaceQuery query) {
  return switch (query.resource) {
    HousekeepingResource.tasks => const <HousekeepingWorkItem>[_taskItem],
    HousekeepingResource.schedules => const <HousekeepingWorkItem>[
      _scheduleItem,
    ],
    HousekeepingResource.maintenanceRequests => const <HousekeepingWorkItem>[
      _maintenanceItem,
    ],
  };
}

void _stubWorkspace(_MockHousekeepingRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final HousekeepingWorkspaceQuery query =
        invocation.positionalArguments.single as HousekeepingWorkspaceQuery;
    final List<HousekeepingWorkItem> items = _itemsForQuery(query);
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
        appAccessPolicyProvider.overrideWithValue(_housekeepingWritePolicy()),
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

Finder _tabLabel(String label, int count) {
  return find.text('$label ($count)');
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
    expect(_tabLabel('Tasks', 3), findsOneWidget);
    expect(_tabLabel('Schedules', 2), findsOneWidget);
    expect(_tabLabel('Maintenance requests', 1), findsOneWidget);
    expect(find.text('Create task'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Assignee'), findsOneWidget);
    expect(find.text('Due time'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    // Default visible column limit is 5; "Next action" is available via table settings.
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

    await tester.tap(_tabLabel('Schedules', 2));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'schedules');
    expect(find.text('Create schedule'), findsOneWidget);
    expect(find.text('Create task'), findsNothing);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Frequency'), findsOneWidget);
    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('End date'), findsOneWidget);
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

    expect(find.text('Request maintenance'), findsOneWidget);
    expect(find.text('Create task'), findsNothing);
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Asset'), findsOneWidget);
    expect(find.text('Reported'), findsOneWidget);
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

    expect(find.text('Create task'), findsOneWidget);

    await tester.tap(_tabLabel('Schedules', 2));
    await tester.pumpAndSettle();
    expect(find.text('Create schedule'), findsOneWidget);

    await tester.tap(_tabLabel('Maintenance requests', 1));
    await tester.pumpAndSettle();
    expect(find.text('Request maintenance'), findsOneWidget);
  });

  testWidgets('filter dialog excludes resource filter', (
    WidgetTester tester,
  ) async {
    await _pumpHousekeepingWorkspace(tester, repository: repository);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Queue'), findsWidgets);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Facility'), findsWidgets);
    expect(find.text('Room or bed'), findsWidgets);
    expect(find.text('Assignee'), findsWidgets);
    expect(find.text('Date'), findsWidgets);
    // Resource is selected via tabs, not the advanced filter dialog.
    expect(find.text('Resource'), findsNothing);
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
    expect(find.byType(AppListItemRow), findsWidgets);
    expect(find.text('Clean ward 2B'), findsOneWidget);
    expect(_tabLabel('Tasks', 3), findsOneWidget);
  });
}
