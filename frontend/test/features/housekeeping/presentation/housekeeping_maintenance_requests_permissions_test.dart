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
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
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

const HousekeepingWorkItem _openRequest = HousekeepingWorkItem(
  id: 'HK-MR-1',
  displayId: 'MR-001',
  resource: HousekeepingResource.maintenanceRequests,
  title: 'Fix leaking tap',
  status: 'OPEN',
  roomLabel: 'Room 3A',
  facilityLabel: 'Main Campus',
  assetLabel: 'Tap-12',
);

const HousekeepingWorkItem _completedRequest = HousekeepingWorkItem(
  id: 'HK-MR-2',
  displayId: 'MR-002',
  resource: HousekeepingResource.maintenanceRequests,
  title: 'Fixed boiler',
  status: 'COMPLETED',
  roomLabel: 'Boiler room',
  facilityLabel: 'Main Campus',
  assetLabel: 'Boiler-1',
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
      value: 0,
    ),
    HousekeepingSummaryCard(
      id: 'open_requests',
      labelKey: 'open_requests',
      value: 1,
    ),
    HousekeepingSummaryCard(
      id: 'completed_today',
      labelKey: 'completed_today',
      value: 0,
    ),
    HousekeepingSummaryCard(
      id: 'overdue_requests',
      labelKey: 'overdue_requests',
      value: 0,
    ),
  ],
  lookups: HousekeepingLookups(
    facilities: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'FAC-1', label: 'Main Campus'),
    ],
    rooms: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'ROOM-1', label: 'Room 3A'),
    ],
    assets: <HousekeepingLookupOption>[
      HousekeepingLookupOption(id: 'ASSET-1', label: 'Tap-12'),
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
  List<HousekeepingWorkItem> items = const <HousekeepingWorkItem>[_openRequest],
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
    final List<HousekeepingWorkItem> pageItems =
        query.resource == HousekeepingResource.maintenanceRequests
        ? items
        : const <HousekeepingWorkItem>[];
    return Result<HousekeepingWorkspaceLoad>.success(
      HousekeepingWorkspaceLoad(
        overview: _overview,
        items: AppPage<HousekeepingWorkItem>(
          items: pageItems,
          request: query.pageRequest,
          totalItemCount: pageItems.length,
        ),
      ),
    );
  });
}

Future<void> _pumpMaintenanceTab(
  WidgetTester tester, {
  required _MockHousekeepingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HousekeepingWorkItem> items = const <HousekeepingWorkItem>[_openRequest],
  Result<HousekeepingWorkspaceLoad>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    items: items,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/housekeeping?section=maintenance',
    routes: <RouteBase>[
      GoRoute(
        path: '/housekeeping',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: HousekeepingWorkspacePage(
              initialSection: HousekeepingSection.maintenance,
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

Finder _tabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.text(label),
  );
}

void main() {
  late _MockHousekeepingRepository repository;

  setUpAll(() {
    registerFallbackValue(const HousekeepingWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(
      const HousekeepingMaintenanceRequestDraft(
        status: 'OPEN',
        description: 'leak',
      ),
    );
    registerFallbackValue(
      const HousekeepingMaintenanceTriageDraft(status: 'IN_PROGRESS'),
    );
  });

  setUp(() {
    repository = _MockHousekeepingRepository();
  });

  test('reuses feature *Requirement helpers (no second vocabulary)', () {
    expect(
      identical(
        HousekeepingMaintenanceRequestsAtomPermissions.tab,
        housekeepingWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        HousekeepingMaintenanceRequestsAtomPermissions.write,
        housekeepingWorkspaceManageRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        HousekeepingMaintenanceRequestsAtomPermissions.routeEntry,
        RouteAccessCatalog.housekeepingEntry,
      ),
      isTrue,
    );
    expect(
      identical(
        HousekeepingMaintenanceRequestsAtomPermissions.report,
        housekeepingWorkspaceReportRequirement,
      ),
      isTrue,
    );
  });

  test('atom map covers inventory verbs (AC1)', () {
    expect(HousekeepingMaintenanceRequestsAtomPermissions.tab, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.listChrome, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.search, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.filters, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.settings, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.empty, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.loading, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.retry, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.rowSelect, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.detail, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.nextAction, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.create, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.update, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.delete, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.triage, isNotNull);
    expect(
      HousekeepingMaintenanceRequestsAtomPermissions.completeRequest,
      isNotNull,
    );
    expect(
      HousekeepingMaintenanceRequestsAtomPermissions.cancelRequest,
      isNotNull,
    );
    expect(
      HousekeepingMaintenanceRequestsAtomPermissions.requestMaintenance,
      isNotNull,
    );
    expect(HousekeepingMaintenanceRequestsAtomPermissions.report, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.nestedWrite, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.nestedRead, isNotNull);
    expect(HousekeepingMaintenanceRequestsAtomPermissions.routeEntry, isNotNull);
  });

  testWidgets(
    'read-only ∩ denial: list visible; Request maintenance / Triage / detail writes absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.triage.isAllowed(reader),
        isFalse,
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        HousekeepingCapabilities.fromPolicy(reader).canUpdateTasks,
        isFalse,
      );

      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Fix leaking tap'), findsOneWidget);
      expect(_tabLabel('Maintenance requests'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Request maintenance'), findsNothing);
      expect(find.text('Triage handoff'), findsNothing);
      expect(find.text('View details'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Triage'), findsNothing);
      expect(find.text('Complete request'), findsNothing);
      expect(find.text('Cancel request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full manage ∩: Request maintenance, Triage next-action, detail writes mount',
    (WidgetTester tester) async {
      final AppAccessPolicy manager = _policy(
        roles: const <String>['HOUSEKEEPING_MANAGER'],
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
          AppPermissions.reportsRead,
        },
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.write.isAllowed(manager),
        isTrue,
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.triage.isAllowed(
          manager,
        ),
        isTrue,
      );
      expect(
        HousekeepingCapabilities.fromPolicy(manager).canUpdateTasks,
        isTrue,
      );

      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: manager,
      );

      expect(find.text('Fix leaking tap'), findsOneWidget);
      expect(find.byTooltip('Request maintenance'), findsOneWidget);
      expect(find.byType(AppReportActionButton), findsOneWidget);
      expect(find.text('Triage handoff'), findsWidgets);

      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();

      // Triage is the row next-action — omitted from complementary detail writes.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Triage'),
        ),
        findsNothing,
      );
      expect(find.text('Complete request'), findsOneWidget);
      expect(find.text('Cancel request'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:write alone without operations:read omits Maintenance chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.routeEntry.isAllowed(
          writeOnly,
        ),
        isTrue,
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Fix leaking tap'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Request maintenance'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'report ∪: operations:read alone (without reports:read) mounts Report summary',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.report.isAllowed(reader),
        isTrue,
      );

      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.byType(AppReportActionButton), findsOneWidget);
    },
  );

  testWidgets(
    'source canUpdateTasks: housekeeper without write mounts Request maintenance; Triage absent',
    (WidgetTester tester) async {
      // Matrix create ∩ write; source Request maintenance uses canUpdateTasks
      // (manage OR housekeeper + read) — keep source mapping.
      final AppAccessPolicy housekeeper = _policy(
        roles: const <String>['HOUSE_KEEPER'],
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.housekeepingRead,
        },
      );
      final HousekeepingCapabilities caps =
          HousekeepingCapabilities.fromPolicy(housekeeper);
      expect(caps.canManage, isFalse);
      expect(caps.canUpdateTasks, isTrue);
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.triage.isAllowed(
          housekeeper,
        ),
        isFalse,
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.requestMaintenance
            .isAllowed(housekeeper),
        isFalse,
      );

      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: housekeeper,
      );

      expect(find.byTooltip('Request maintenance'), findsOneWidget);
      expect(find.text('Triage handoff'), findsNothing);
      expect(find.text('View details'), findsWidgets);

      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();

      expect(find.text('Complete request'), findsNothing);
      expect(find.text('Cancel request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: facilities-maintenance missing omits Maintenance chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );

      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Fix leaking tap'), findsNothing);
      expect(find.byTooltip('Request maintenance'), findsNothing);
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
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.tab.isAllowed(
          noFacility,
        ),
        isTrue,
      );
      expect(
        HousekeepingMaintenanceRequestsAtomPermissions.routeEntry.isAllowed(
          noFacility,
        ),
        isFalse,
      );
      expect(canEnterHousekeepingWorkspace(noFacility), isFalse);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: no extra nested module chrome on Maintenance',
    (WidgetTester tester) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();

      // Nested cross-module rows are _(n/a)_ — no billing/clinical nested panels.
      expect(find.textContaining('Billing'), findsNothing);
      expect(find.textContaining('Clinical'), findsNothing);
      expect(find.text('Complete request'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized Request maintenance opens dialog; validation keeps it open',
    (WidgetTester tester) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Request maintenance'));
      await tester.pumpAndSettle();

      expect(find.text('REQUEST MAINTENANCE'), findsOneWidget);

      await tester.tap(find.text('Create request'));
      await tester.pumpAndSettle();

      // Required description empty — dialog stays; no mutation.
      expect(find.text('REQUEST MAINTENANCE'), findsOneWidget);
      verifyNever(() => repository.createMaintenanceRequest(any()));
    },
  );

  testWidgets(
    'authorized Triage next-action opens dialog and mutation syncs list',
    (WidgetTester tester) async {
      final HousekeepingWorkItem triaged = _openRequest.copyWith(
        status: 'IN_PROGRESS',
      );
      when(() => repository.triageMaintenanceRequest(any(), any())).thenAnswer(
        (_) async => Result<HousekeepingWorkItem>.success(triaged),
      );

      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.text('Triage handoff').first);
      await tester.pumpAndSettle();

      expect(find.text('TRIAGE MAINTENANCE HANDOFF'), findsOneWidget);

      await tester.tap(find.text('Triage maintenance request'));
      await tester.pumpAndSettle();

      verify(
        () => repository.triageMaintenanceRequest('HK-MR-1', any()),
      ).called(1);
      expect(find.text('Housekeeping changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized Complete request from detail mutates and shows snackbar',
    (WidgetTester tester) async {
      when(() => repository.updateMaintenanceRequest(any(), any())).thenAnswer(
        (_) async => const Result<void>.success(null),
      );

      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Complete request'));
      await tester.pumpAndSettle();

      verify(
        () => repository.updateMaintenanceRequest(
          'HK-MR-1',
          any(
            that: predicate<Map<String, Object?>>(
              (Map<String, Object?> payload) =>
                  payload['status'] == 'COMPLETED',
            ),
          ),
        ),
      ).called(1);
      expect(find.text('Housekeeping changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized Cancel request confirms then mutates and syncs',
    (WidgetTester tester) async {
      when(() => repository.updateMaintenanceRequest(any(), any())).thenAnswer(
        (_) async => const Result<void>.success(null),
      );

      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.text('Fix leaking tap'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();

      // Confirm dialog must appear before mutation (inventory keeps confirm).
      expect(find.byType(AppDialog), findsAtLeastNWidgets(2));
      await tester.tap(
        find
            .descendant(
              of: find.byType(AppDialog),
              matching: find.text('Cancel request'),
            )
            .last,
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.updateMaintenanceRequest(
          'HK-MR-1',
          any(
            that: predicate<Map<String, Object?>>(
              (Map<String, Object?> payload) =>
                  payload['status'] == 'CANCELLED',
            ),
          ),
        ),
      ).called(1);
      expect(find.text('Housekeeping changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'terminal row: No action needed; detail writes absent',
    (WidgetTester tester) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        items: const <HousekeepingWorkItem>[_completedRequest],
      );

      expect(find.text('Fixed boiler'), findsOneWidget);
      expect(find.text('No action needed'), findsWidgets);
      expect(find.text('Triage handoff'), findsNothing);

      await tester.tap(find.text('Fixed boiler'));
      await tester.pumpAndSettle();

      expect(find.text('Complete request'), findsNothing);
      expect(find.text('Cancel request'), findsNothing);
    },
  );

  testWidgets(
    'empty authorized Maintenance queue still shows Request maintenance when allowed',
    (WidgetTester tester) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        items: const <HousekeepingWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byTooltip('Request maintenance'), findsOneWidget);
      expect(find.text('No housekeeping items'), findsOneWidget);
    },
  );

  testWidgets(
    'error/retry surface remains for authorized Maintenance users',
    (WidgetTester tester) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        workspaceOverride: const Result<HousekeepingWorkspaceLoad>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.byType(AppFailureStateView), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'mobile viewport: next-action and row select remain reachable',
    (WidgetTester tester) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        physicalSize: const Size(390, 844),
      );

      expect(find.byType(AppListTableMobileItem), findsWidgets);
      expect(find.textContaining('Fix leaking tap'), findsOneWidget);
      expect(find.text('Triage handoff'), findsWidgets);
      expect(_tabLabel('Maintenance requests'), findsOneWidget);
    },
  );

  testWidgets(
    'dark theme: authorized Maintenance chrome still mounts',
    (WidgetTester tester) async {
      await _pumpMaintenanceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['HOUSEKEEPING_MANAGER'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
            AppPermissions.reportsRead,
          },
        ),
        themeMode: ThemeMode.dark,
      );

      expect(find.byTooltip('Request maintenance'), findsOneWidget);
      expect(find.byType(AppReportActionButton), findsOneWidget);
      expect(find.text('Fix leaking tap'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}
