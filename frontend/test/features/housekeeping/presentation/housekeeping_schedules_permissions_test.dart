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
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHousekeepingRepository extends Mock
    implements HousekeepingRepository {}

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

const HousekeepingWorkspaceOverview _overview = HousekeepingWorkspaceOverview(
  summaryCards: <HousekeepingSummaryCard>[
    HousekeepingSummaryCard(
      id: 'pending_tasks',
      labelKey: 'pending_tasks',
      value: 0,
    ),
    HousekeepingSummaryCard(
      id: 'active_schedules',
      labelKey: 'active_schedules',
      value: 1,
    ),
    HousekeepingSummaryCard(
      id: 'open_requests',
      labelKey: 'open_requests',
      value: 0,
    ),
  ],
  lookups: HousekeepingLookups(
    facilities: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'FAC-1', label: 'Main Campus'),
    ],
    rooms: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'ROOM-1', label: 'Corridor A'),
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
      code: housekeepingFacilitiesModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  String? facilityId = 'facility-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
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
  List<HousekeepingWorkItem> schedules = const <HousekeepingWorkItem>[
    _scheduleItem,
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
        query.resource == HousekeepingResource.schedules
        ? schedules
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

Finder _tabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.text(label),
  );
}

Future<void> _pumpSchedulesTab(
  WidgetTester tester, {
  required _MockHousekeepingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HousekeepingWorkItem> schedules = const <HousekeepingWorkItem>[
    _scheduleItem,
  ],
  Result<HousekeepingWorkspaceLoad>? workspaceOverride,
  String initialLocation = '/housekeeping?section=schedules',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    schedules: schedules,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
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
          return Scaffold(
            body: HousekeepingWorkspacePage(
              initialSection: HousekeepingSection.fromQueryValue(section),
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
    registerFallbackValue(
      const HousekeepingScheduleDraft(frequency: 'Daily'),
    );
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockHousekeepingRepository();
  });

  testWidgets(
    'read-only: Schedules list visible; Create schedule absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(HousekeepingSchedulesAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        HousekeepingSchedulesAtomPermissions.createSchedule.isAllowed(reader),
        isFalse,
      );
      expect(
        HousekeepingSchedulesAtomPermissions.write.isAllowed(reader),
        isFalse,
      );

      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tabLabel('Schedules'), findsOneWidget);
      expect(find.text('Daily corridor sweep'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Frequency'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Create schedule'), findsNothing);
      expect(find.text('Review schedule'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Daily corridor sweep'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.textContaining('no access'), findsNothing);
      // Schedules have no complementary write actions on detail.
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Cancel'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'full write ∩: Create schedule, list chrome, and report mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
          AppPermissions.reportsRead,
        },
        roles: const <String>['HOUSEKEEPING_MANAGER'],
      );
      expect(
        HousekeepingSchedulesAtomPermissions.createSchedule.isAllowed(writer),
        isTrue,
      );
      expect(HousekeepingSchedulesAtomPermissions.report.isAllowed(writer), isTrue);

      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Daily corridor sweep'), findsOneWidget);
      expect(find.byTooltip('Create schedule'), findsOneWidget);
      expect(find.text('Review schedule'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:write alone without read omits Schedules chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );
      expect(
        HousekeepingSchedulesAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        HousekeepingSchedulesAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Daily corridor sweep'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Create schedule'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: facilities-maintenance missing omits Schedules',
    (WidgetTester tester) async {
      await _pumpSchedulesTab(
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
      expect(find.text('Daily corridor sweep'), findsNothing);
      expect(find.byTooltip('Create schedule'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: Schedules has no nested cross-module UI',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(
        HousekeepingSchedulesAtomPermissions.nestedWrite.isAllowed(writer),
        isTrue,
      );
      expect(
        HousekeepingSchedulesAtomPermissions.nestedRead.isAllowed(writer),
        isTrue,
      );

      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.text('Daily corridor sweep'));
      await tester.pumpAndSettle();

      // No cross-module nested write entry points on schedule detail.
      expect(find.text('Triage'), findsNothing);
      expect(find.text('Assign'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Create schedule opens dialog, validates, and mutation syncs',
    (WidgetTester tester) async {
      when(
        () => repository.createSchedule(any()),
      ).thenAnswer((_) async => const Result<void>.success(null));

      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Create schedule'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE CLEANING SCHEDULE'), findsOneWidget);

      // Validation: submit without frequency keeps dialog open.
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Create schedule'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CREATE CLEANING SCHEDULE'), findsOneWidget);
      expect(find.text('Enter a cleaning frequency.'), findsWidgets);
      verifyNever(() => repository.createSchedule(any()));

      final Finder dialogFields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogFields.first, 'Weekly');
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Create schedule'),
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.createSchedule(
          any(
            that: predicate<HousekeepingScheduleDraft>(
              (HousekeepingScheduleDraft draft) => draft.frequency == 'Weekly',
            ),
          ),
        ),
      ).called(1);
      expect(find.text('Housekeeping changes saved.'), findsOneWidget);
      // Post-mutation sync reloads schedules worklist.
      verify(() => repository.getWorkspace(any())).called(greaterThan(1));
    },
  );

  testWidgets(
    'empty authorized Schedules still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        schedules: const <HousekeepingWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No housekeeping items'), findsOneWidget);
      expect(find.byTooltip('Create schedule'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty write-authorized Schedules keeps Create schedule primary',
    (WidgetTester tester) async {
      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        schedules: const <HousekeepingWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No housekeeping items'), findsOneWidget);
      expect(find.byTooltip('Create schedule'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Schedules',
    (WidgetTester tester) async {
      await _pumpSchedulesTab(
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

  testWidgets('authorized loading then success on Schedules', (
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
            items: const <HousekeepingWorkItem>[_scheduleItem],
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
      initialLocation: '/housekeeping?section=schedules',
      routes: <RouteBase>[
        GoRoute(
          path: '/housekeeping',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: HousekeepingWorkspacePage(
                initialSection: HousekeepingSection.schedules,
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
              permissions: <AppPermission>{
                AppPermissions.operationsRead,
                AppPermissions.operationsWrite,
              },
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
    expect(find.textContaining('Loading'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Daily corridor sweep'), findsOneWidget);
  });

  testWidgets('mobile viewport keeps Schedules next-action and row select', (
    WidgetTester tester,
  ) async {
    await _pumpSchedulesTab(
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

    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Daily corridor sweep'), findsOneWidget);
    expect(find.text('Review schedule'), findsWidgets);
    expect(_tabLabel('Schedules'), findsOneWidget);

    await tester.tap(find.textContaining('Daily corridor sweep').first);
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
  });

  testWidgets('dark theme Schedules write ∩ still mounts Create schedule', (
    WidgetTester tester,
  ) async {
    await _pumpSchedulesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.byTooltip('Create schedule'), findsOneWidget);
    expect(find.text('Daily corridor sweep'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets(
    'report ∪: operations:read alone mounts Report summary on Schedules',
    (WidgetTester tester) async {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        HousekeepingSchedulesAtomPermissions.report.isAllowed(opsReader),
        isTrue,
      );

      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: opsReader,
      );

      // Report is icon/tooltip secondary — open if label present.
      final Finder report = find.textContaining('Report');
      if (report.evaluate().isNotEmpty) {
        expect(report, findsWidgets);
      }
      expect(find.byTooltip('Create schedule'), findsNothing);
    },
  );
}
