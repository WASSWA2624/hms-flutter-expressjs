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
import 'package:hosspi_hms/features/housekeeping/presentation/housekeeping_schedules_billing_inventory.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

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
    initialLocation: '/housekeeping?section=schedules',
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

  group('Housekeeping Schedules financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        HousekeepingSchedulesBillingInventory.schedulesTabHasNoBillableActions,
        isTrue,
      );
      expect(
        HousekeepingSchedulesBillingInventory
            .allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(HousekeepingSchedulesBillingInventory.atoms, isNotEmpty);
      expect(
        HousekeepingSchedulesBillingInventory.billableClasses.every(
          (HousekeepingSchedulesFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(housekeepingSchedulesBillingScopeNote, contains('NOT_BILLED'));

      for (final HousekeepingSchedulesFinancialAtom atom
          in HousekeepingSchedulesBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<HousekeepingSchedulesFinancialClass>[
            HousekeepingSchedulesFinancialClass.notRequired,
            HousekeepingSchedulesFinancialClass.notBilled,
            HousekeepingSchedulesFinancialClass.noCharge,
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

    test('Create schedule primary stays NOT_BILLED', () {
      final HousekeepingSchedulesFinancialAtom primary =
          HousekeepingSchedulesBillingInventory.atoms.singleWhere(
            (HousekeepingSchedulesFinancialAtom atom) =>
                atom.id == 'create_schedule_primary',
          );
      expect(
        primary.financialClass,
        HousekeepingSchedulesFinancialClass.notBilled,
      );
      expect(primary.auditCode, 'NOT_BILLED');
      expect(primary.mounted, isTrue);
    });

    test('Review schedule next-action stays NOT_REQUIRED', () {
      final HousekeepingSchedulesFinancialAtom review =
          HousekeepingSchedulesBillingInventory.atoms.singleWhere(
            (HousekeepingSchedulesFinancialAtom atom) =>
                atom.id == 'next_action_review',
          );
      expect(
        review.financialClass,
        HousekeepingSchedulesFinancialClass.notRequired,
      );
      expect(review.auditCode, 'NOT_REQUIRED');
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        HousekeepingSchedulesBillingInventory.atoms
            .singleWhere(
              (HousekeepingSchedulesFinancialAtom atom) =>
                  atom.id == 'patient_billable_room_turnover_surcharge',
            )
            .mounted,
        isFalse,
      );
      expect(
        HousekeepingSchedulesBillingInventory.atoms
            .singleWhere(
              (HousekeepingSchedulesFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        HousekeepingSchedulesBillingInventory.atoms
            .singleWhere(
              (HousekeepingSchedulesFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(housekeepingSchedulesBillingScopeNote, contains('Billing'));
    });
  });

  group('Housekeeping Schedules billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpSchedulesTab(
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
      expect(find.text('Daily corridor sweep'), findsOneWidget);
      expect(find.byTooltip('Create schedule'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
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
      );

      await tester.tap(find.text('Daily corridor sweep'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.byType(AppCollapsibleSection), findsWidgets);
      // Schedules have no complementary write Quick actions section.
      expect(find.text('Quick actions'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot collect or adjust', (
      WidgetTester tester,
    ) async {
      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
      );

      expect(find.byTooltip('Create schedule'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);

      await tester.tap(find.text('Daily corridor sweep'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'Create schedule mutation syncs without billing gate',
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
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Balance due'), findsNothing);
        expectFlatSections(tester);

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

        verify(() => repository.createSchedule(any())).called(1);
        expect(find.text('Housekeeping changes saved.'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Invoice'), findsNothing);
        verify(() => repository.getWorkspace(any())).called(greaterThan(1));
      },
    );
  });

  group('Housekeeping Schedules section layout (AC5)', () {
    testWidgets('desktop Schedules: flat sections on list + detail', (
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
        physicalSize: const Size(1920, 1200),
      );

      expectFlatSections(tester);

      await tester.tap(find.text('Daily corridor sweep'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Schedules: flat sections', (WidgetTester tester) async {
      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
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
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('Daily corridor sweep'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
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
      await tester.tap(find.text('Daily corridor sweep'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('Create schedule dialog: flat sections', (
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
      );

      await tester.tap(find.byTooltip('Create schedule'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Housekeeping Schedules sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        schedules: const <HousekeepingWorkItem>[],
      );

      expect(find.text('No housekeeping items'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpSchedulesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        workspaceOverride: const Result<HousekeepingWorkspaceLoad>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    test('inventory reuses shared financial class vocabulary', () {
      expect(
        HousekeepingSchedulesBillingInventory.atoms.any(
          (HousekeepingSchedulesFinancialAtom atom) =>
              atom.financialClass ==
              HousekeepingSchedulesFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        HousekeepingSchedulesAtomPermissions.tab,
        isNotNull,
      );
      expect(
        HousekeepingSchedulesAtomPermissions.createSchedule,
        isNotNull,
      );
    });
  });
}
