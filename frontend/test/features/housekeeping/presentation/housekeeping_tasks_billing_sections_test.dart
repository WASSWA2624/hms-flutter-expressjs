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
import 'package:hosspi_hms/features/housekeeping/presentation/housekeeping_tasks_billing_inventory.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

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
      value: 2,
    ),
    HousekeepingSummaryCard(
      id: 'completed_today',
      labelKey: 'completed_today',
      value: 1,
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

const AppModuleEntitlement _hkModule = AppModuleEntitlement(
  code: housekeepingFacilitiesMaintenanceModule,
  licenseStatus: 'ACTIVE',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<String> roles = const <String>['HOUSEKEEPING_MANAGER'],
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[_hkModule],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockHousekeepingRepository repository, {
  List<HousekeepingWorkItem> items = const <HousekeepingWorkItem>[
    _unassignedPending,
  ],
  Result<HousekeepingWorkspaceLoad>? failure,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (failure != null) {
      return failure;
    }
    final HousekeepingWorkspaceQuery query =
        invocation.positionalArguments.single as HousekeepingWorkspaceQuery;
    final List<HousekeepingWorkItem> scoped = items
        .where(
          (HousekeepingWorkItem item) => item.resource == query.resource,
        )
        .toList(growable: false);
    return Result<HousekeepingWorkspaceLoad>.success(
      HousekeepingWorkspaceLoad(
        overview: _overview,
        items: AppPage<HousekeepingWorkItem>(
          items: scoped,
          request: query.pageRequest,
          totalItemCount: scoped.length,
        ),
      ),
    );
  });
}

Future<void> _pumpTasks(
  WidgetTester tester, {
  required _MockHousekeepingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HousekeepingWorkItem> items = const <HousekeepingWorkItem>[
    _unassignedPending,
  ],
  Result<HousekeepingWorkspaceLoad>? failure,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, items: items, failure: failure);

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
              initialSection: HousekeepingSection.fromQueryValue(
                state.uri.queryParameters['section'],
              ),
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
    registerFallbackValue(const HousekeepingTaskDraft(status: 'PENDING'));
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockHousekeepingRepository();
  });

  group('Housekeeping Tasks financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        HousekeepingTasksBillingInventory.tasksTabHasNoBillableActions,
        isTrue,
      );
      expect(
        HousekeepingTasksBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(HousekeepingTasksBillingInventory.atoms, isNotEmpty);
      expect(
        HousekeepingTasksBillingInventory.billableClasses.every(
          (HousekeepingTasksFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(housekeepingTasksBillingScopeNote, contains('NOT_BILLED'));

      for (final HousekeepingTasksFinancialAtom atom
          in HousekeepingTasksBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<HousekeepingTasksFinancialClass>[
            HousekeepingTasksFinancialClass.notRequired,
            HousekeepingTasksFinancialClass.notBilled,
            HousekeepingTasksFinancialClass.noCharge,
          ]),
          reason: atom.id,
        );
        expect(
          atom.auditCode,
          isIn(<String>['NOT_REQUIRED', 'NOT_BILLED', 'NO_CHARGE']),
          reason: atom.id,
        );
      }
    });

    test('Create task primary stays NOT_BILLED', () {
      final HousekeepingTasksFinancialAtom primary =
          HousekeepingTasksBillingInventory.atoms.singleWhere(
            (HousekeepingTasksFinancialAtom atom) =>
                atom.id == 'create_task_primary',
          );
      expect(
        primary.financialClass,
        HousekeepingTasksFinancialClass.notBilled,
      );
      expect(primary.auditCode, 'NOT_BILLED');
      expect(primary.mounted, isTrue);
    });

    test('Assign / Start / Complete next-actions stay NOT_BILLED', () {
      for (final String id in <String>[
        'next_action_assign',
        'next_action_start',
        'next_action_complete',
      ]) {
        final HousekeepingTasksFinancialAtom atom =
            HousekeepingTasksBillingInventory.atoms.singleWhere(
              (HousekeepingTasksFinancialAtom entry) => entry.id == id,
            );
        expect(
          atom.financialClass,
          HousekeepingTasksFinancialClass.notBilled,
          reason: id,
        );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
      }
    });

    test('unmounted surcharge + settle atoms document Billing system of record', () {
      expect(
        HousekeepingTasksBillingInventory.atoms
            .singleWhere(
              (HousekeepingTasksFinancialAtom atom) =>
                  atom.id == 'patient_billable_room_turnover_surcharge',
            )
            .mounted,
        isFalse,
      );
      expect(
        HousekeepingTasksBillingInventory.atoms
            .singleWhere(
              (HousekeepingTasksFinancialAtom atom) =>
                  atom.id == 'private_room_cleaning_surcharge',
            )
            .billingPath,
        contains('housekeeping-billing'),
      );
      expect(
        HousekeepingTasksBillingInventory.atoms
            .singleWhere(
              (HousekeepingTasksFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(housekeepingTasksBillingScopeNote, contains('Billing'));
    });
  });

  group('Housekeeping Tasks billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpTasks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
            AppPermissions.reportsRead,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.text('Clean ward 2B'), findsOneWidget);
      expect(find.byTooltip('Create task'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpTasks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        items: const <HousekeepingWorkItem>[_assignedPending],
      );

      await tester.tap(find.text('Clean ward 3C'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.textContaining('Task details'), findsWidgets);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot collect or adjust', (
      WidgetTester tester,
    ) async {
      await _pumpTasks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          roles: const <String>['VIEWER'],
        ),
      );

      await tester.tap(find.text('Clean ward 2B'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Create task'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('Complete mutation syncs without cashier UX', (
      WidgetTester tester,
    ) async {
      when(() => repository.updateTask(any(), any())).thenAnswer(
        (_) async => const Result<HousekeepingWorkItem>.success(_inProgress),
      );

      await _pumpTasks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        items: const <HousekeepingWorkItem>[_inProgress],
      );

      expect(find.text('Complete'), findsWidgets);
      await tester.tap(find.text('Complete').first);
      await tester.pumpAndSettle();

      verify(() => repository.updateTask(any(), any())).called(1);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Invoice'), findsNothing);
    });

    testWidgets('Create task dialog has no billing affordances', (
      WidgetTester tester,
    ) async {
      await _pumpTasks(
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

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expectFlatSections(tester);
      verifyNever(() => repository.createTask(any()));
    });
  });

  group('Housekeeping Tasks section layout (AC5)', () {
    testWidgets('desktop Tasks: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpTasks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
        items: const <HousekeepingWorkItem>[_assignedPending],
      );

      expectFlatSections(tester);

      await tester.tap(find.text('Clean ward 3C'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Tasks: flat sections', (WidgetTester tester) async {
      await _pumpTasks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          roles: const <String>['VIEWER'],
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpTasks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        themeMode: ThemeMode.light,
        items: const <HousekeepingWorkItem>[_assignedPending],
      );
      await tester.tap(find.text('Clean ward 3C'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpTasks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        themeMode: ThemeMode.dark,
        items: const <HousekeepingWorkItem>[_assignedPending],
      );
      await tester.tap(find.text('Clean ward 3C'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('Create task dialog: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpTasks(
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
      expectFlatSections(tester);
    });
  });

  group('Housekeeping Tasks sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpTasks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          roles: const <String>['VIEWER'],
        ),
        items: const <HousekeepingWorkItem>[],
      );

      expect(find.text('Tasks'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpTasks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          roles: const <String>['VIEWER'],
        ),
        failure: const Result<HousekeepingWorkspaceLoad>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    test('inventory reuses shared financial class vocabulary', () {
      expect(
        HousekeepingTasksBillingInventory.atoms.any(
          (HousekeepingTasksFinancialAtom atom) =>
              atom.financialClass ==
              HousekeepingTasksFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        HousekeepingTasksAtomPermissions.tab,
        isNotNull,
      );
      expect(
        HousekeepingTasksAtomPermissions.createTask,
        isNotNull,
      );
    });
  });
}
