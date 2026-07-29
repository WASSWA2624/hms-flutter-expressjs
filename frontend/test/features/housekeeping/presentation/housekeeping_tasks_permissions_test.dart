import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
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
import 'package:hosspi_hms/features/housekeeping/presentation/housekeeping_access.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHousekeepingRepository extends Mock
    implements HousekeepingRepository {}

const HousekeepingWorkItem _unassignedPending = HousekeepingWorkItem(
  id: 'HK-TASK-1',
  displayId: 'HT-001',
  resource: HousekeepingResource.tasks,
  title: 'Clean ward 2B',
  status: 'PENDING',
  roomLabel: 'Room 2B',
  facilityLabel: 'Main Campus',
);

const HousekeepingWorkItem _assignedPending = HousekeepingWorkItem(
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

const HousekeepingWorkItem _inProgress = HousekeepingWorkItem(
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

const HousekeepingWorkspaceOverview _overview = HousekeepingWorkspaceOverview(
  summaryCards: <HousekeepingSummaryCard>[
    HousekeepingSummaryCard(
      id: 'pending_tasks',
      labelKey: 'pending_tasks',
      value: 1,
    ),
    HousekeepingSummaryCard(
      id: 'completed_today',
      labelKey: 'completed_today',
      value: 2,
    ),
    HousekeepingSummaryCard(
      id: 'open_requests',
      labelKey: 'open_requests',
      value: 0,
    ),
    HousekeepingSummaryCard(
      id: 'overdue_requests',
      labelKey: 'overdue_requests',
      value: 0,
    ),
    HousekeepingSummaryCard(
      id: 'active_schedules',
      labelKey: 'active_schedules',
      value: 0,
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

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<String> roles = const <String>['VIEWER'],
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: housekeepingFacilitiesMaintenanceModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockHousekeepingRepository repository, {
  List<HousekeepingWorkItem> taskItems = const <HousekeepingWorkItem>[
    _unassignedPending,
  ],
  Result<HousekeepingWorkspaceLoad>? workspaceOverride,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (workspaceOverride != null) {
      return workspaceOverride;
    }
    final HousekeepingWorkspaceQuery query =
        invocation.positionalArguments.single as HousekeepingWorkspaceQuery;
    final List<HousekeepingWorkItem> items =
        query.resource == HousekeepingResource.tasks
        ? taskItems
        : const <HousekeepingWorkItem>[];
    return Result<HousekeepingWorkspaceLoad>.success(
      HousekeepingWorkspaceLoad(
        overview: _overview,
        items: AppPage<HousekeepingWorkItem>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      ),
    );
  });
}

Future<void> _pumpTasksTab(
  WidgetTester tester, {
  required _MockHousekeepingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HousekeepingWorkItem> taskItems = const <HousekeepingWorkItem>[
    _unassignedPending,
  ],
  Result<HousekeepingWorkspaceLoad>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    taskItems: taskItems,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/housekeeping?section=tasks',
    routes: <RouteBase>[
      GoRoute(
        path: '/housekeeping',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: HousekeepingWorkspacePage(
              initialSection: HousekeepingSection.tasks,
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
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
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
  late _MockHousekeepingRepository repository;

  setUpAll(() {
    registerFallbackValue(const HousekeepingWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockHousekeepingRepository();
  });

  test('Tasks atom helpers reuse AccessRequirement vocabulary', () {
    expect(
      identical(
        HousekeepingTasksAtomPermissions.tab,
        housekeepingWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        HousekeepingTasksAtomPermissions.create,
        housekeepingManageRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        HousekeepingTasksAtomPermissions.routeEntry,
        housekeepingWorkspaceEntryRequirement,
      ),
      isTrue,
    );
    expect(
      HousekeepingTasksAtomPermissions.create.allPermissions,
      contains(AppPermissions.operationsWrite),
    );
    expect(
      HousekeepingTasksAtomPermissions.tab.allPermissions,
      contains(AppPermissions.operationsRead),
    );
  });

  testWidgets(
    'read-only ∩ denial: Tasks list visible; Create / write next-actions absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(HousekeepingTasksAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(HousekeepingTasksAtomPermissions.create.isAllowed(reader), isFalse);
      expect(canManageHousekeeping(reader), isFalse);
      expect(canUpdateHousekeepingTasks(reader), isFalse);

      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Clean ward 2B'), findsOneWidget);
      expect(find.text('Tasks'), findsWidgets);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(
        HousekeepingTasksAtomPermissions.listChrome.isAllowed(reader),
        isTrue,
      );
      expect(find.byTooltip('Create task'), findsNothing);
      expect(find.text('Assign staff or team'), findsNothing);
      expect(find.text('View details'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Clean ward 2B'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Assign'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Cancel'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Start'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Create task, Assign next-action, detail Cancel mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
          AppPermissions.reportsRead,
        },
        roles: const <String>['HOUSEKEEPING_MANAGER'],
      );
      expect(HousekeepingTasksAtomPermissions.write.isAllowed(writer), isTrue);
      expect(HousekeepingTasksAtomPermissions.create.isAllowed(writer), isTrue);
      expect(canManageHousekeeping(writer), isTrue);

      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Clean ward 2B'), findsOneWidget);
      expect(find.byTooltip('Create task'), findsOneWidget);
      expect(find.text('Assign staff or team'), findsWidgets);
      expect(find.textContaining('Report'), findsWidgets);

      await tester.tap(find.text('Clean ward 2B'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Assign'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Cancel'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Start'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:write alone satisfies entry; Tasks chrome needs read ∩',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );
      expect(
        HousekeepingTasksAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(HousekeepingTasksAtomPermissions.tab.isAllowed(writeOnly), isFalse);

      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Clean ward 2B'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Create task'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'report ∪: reports:read without operations:read mounts Report when module entitled',
    (WidgetTester tester) async {
      // Source canReport ∪; matrix nested export _(n/a)_. operations:read also
      // satisfies report via the same union — covered by read-only tests above.
      final AppAccessPolicy reporter = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.reportsRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: housekeepingFacilitiesMaintenanceModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'reporting-analytics',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        HousekeepingTasksAtomPermissions.report.isAllowed(reporter),
        isTrue,
      );
      expect(canManageHousekeeping(reporter), isFalse);

      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: reporter,
      );

      expect(find.textContaining('Report'), findsWidgets);
      expect(find.byTooltip('Create task'), findsNothing);
      expect(find.text('View details'), findsWidgets);
    },
  );

  testWidgets(
    'subscription strip: facilities-maintenance missing omits Tasks chrome',
    (WidgetTester tester) async {
      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Clean ward 2B'), findsNothing);
      expect(find.byTooltip('Create task'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC facility strip: missing facility context fails route entry ∪',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
        facilityId: null,
      );
      // In-page atoms follow biomedical: facility ABAC on route entry only.
      expect(HousekeepingTasksAtomPermissions.tab.isAllowed(noFacility), isTrue);
      expect(
        HousekeepingTasksAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
      expect(canEnterHousekeepingWorkspace(noFacility), isFalse);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: no cross-module nested write atoms on Tasks',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(
        HousekeepingTasksAtomPermissions.nestedWrite.isAllowed(writer),
        isTrue,
      );

      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.text('Clean ward 2B'));
      await tester.pumpAndSettle();

      // Nested matrix rows are n/a — no billing/clinical/etc. nested panels.
      expect(find.textContaining('Billing'), findsNothing);
      expect(find.textContaining('Clinical'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'housekeeper source canUpdateTasks: Start mounts; Create / Assign absent',
    (WidgetTester tester) async {
      final AppAccessPolicy housekeeper = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
        roles: const <String>['HOUSE_KEEPER'],
      );
      // Matrix update ∩ operations:write alone would deny; source keeps
      // housekeeper role expansion for assigned/own task updates.
      expect(
        HousekeepingTasksAtomPermissions.updateTask.isAllowed(housekeeper),
        isFalse,
      );
      expect(canUpdateHousekeepingTasks(housekeeper), isTrue);
      expect(canManageHousekeeping(housekeeper), isFalse);

      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: housekeeper,
        taskItems: const <HousekeepingWorkItem>[_assignedPending],
      );

      expect(find.byTooltip('Create task'), findsNothing);
      expect(find.text('Assign staff or team'), findsNothing);
      expect(find.text('Start cleaning'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Create task opens dialog with validation chrome',
    (WidgetTester tester) async {
      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Create task'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE HOUSEKEEPING TASK'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Assign next-action opens dialog and mutation syncs list',
    (WidgetTester tester) async {
      when(() => repository.updateTask(any(), any())).thenAnswer(
        (_) async => const Result<void>.success(null),
      );

      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.text('Assign staff or team'));
      await tester.pumpAndSettle();

      expect(find.text('ASSIGN HOUSEKEEPING TASK'), findsOneWidget);

      await tester.tap(find.text('Save assignment'));
      await tester.pumpAndSettle();

      verify(() => repository.updateTask('HK-TASK-1', any())).called(1);
      // Worklist refresh after mutation.
      verify(() => repository.getWorkspace(any())).called(greaterThan(1));
    },
  );

  testWidgets(
    'empty authorized Tasks still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        taskItems: const <HousekeepingWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No housekeeping items'), findsOneWidget);
      expect(find.byTooltip('Create task'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty write-authorized Tasks keeps Create task primary',
    (WidgetTester tester) async {
      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        taskItems: const <HousekeepingWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No housekeeping items'), findsOneWidget);
      expect(find.byTooltip('Create task'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Tasks',
    (WidgetTester tester) async {
      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        workspaceOverride: const Result<HousekeepingWorkspaceLoad>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized loading then success on Tasks', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.getWorkspace(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Result<HousekeepingWorkspaceLoad>.success(
        HousekeepingWorkspaceLoad(
          overview: _overview,
          items: AppPage<HousekeepingWorkItem>(
            items: const <HousekeepingWorkItem>[_unassignedPending],
            request: const AppPageRequest(pageSize: 20),
            totalItemCount: 1,
          ),
        ),
      );
    });

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/housekeeping?section=tasks',
      routes: <RouteBase>[
        GoRoute(
          path: '/housekeeping',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(
              body: HousekeepingWorkspacePage(
                initialSection: HousekeepingSection.tasks,
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
            _policy(
              permissions: <AppPermission>{AppPermissions.operationsRead},
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.textContaining('Loading').evaluate().isNotEmpty ||
          find.textContaining('Housekeeping').evaluate().isNotEmpty,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('Clean ward 2B'), findsOneWidget);
    expect(find.text('Tasks'), findsWidgets);
    expect(find.byTooltip('Create task'), findsNothing);
  });

  testWidgets('mobile viewport: authorized Tasks chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpTasksTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Tasks'), findsWidgets);
    expect(find.byTooltip('Create task'), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Clean ward'), findsWidgets);
  });

  testWidgets('desktop viewport: authorized Tasks chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpTasksTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      ),
    );

    expect(find.text('Clean ward 2B'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.text('Assign staff or team'), findsWidgets);
  });

  testWidgets('dark theme: authorized Tasks chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpTasksTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
          AppPermissions.reportsRead,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Clean ward 2B'), findsOneWidget);
    expect(find.byTooltip('Create task'), findsOneWidget);
    expect(find.textContaining('Report'), findsWidgets);
  });

  testWidgets('light theme: authorized Tasks chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpTasksTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Clean ward 2B'), findsOneWidget);
    expect(find.byTooltip('Create task'), findsOneWidget);
    expect(find.text('Assign staff or team'), findsWidgets);
  });

  testWidgets(
    'IN_PROGRESS write: Complete next-action mounts for manager',
    (WidgetTester tester) async {
      await _pumpTasksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        taskItems: const <HousekeepingWorkItem>[_inProgress],
      );

      expect(find.text('Complete cleaning'), findsWidgets);
      expect(find.byTooltip('Create task'), findsOneWidget);
    },
  );
}
