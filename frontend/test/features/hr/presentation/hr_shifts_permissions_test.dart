import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore_for_file: avoid_redundant_argument_values

class _MockHrRepository extends Mock implements HrRepository {}

const String _tenantUuid = '550e8400-e29b-41d4-a716-446655440000';

const HrOption _template = HrOption(
  value: 'SHI0000001',
  label: 'Day pattern',
  displayId: 'SHI0000001',
  extra: <String, Object?>{
    'shift_type': 'DAY',
    'facility_id': 'fac-1',
    'is_active': true,
  },
);

const HrWorkItem _rosterDraft = HrWorkItem(
  id: 'roster-1',
  displayId: 'RST-1',
  queue: HrQueue.rosterDrafts,
  status: 'DRAFT',
  periodLabel: 'Week 12',
  rosterId: 'roster-1',
);

const HrWorkItem _unassignedShift = HrWorkItem(
  id: 'shift-1',
  displayId: 'SHF-1',
  queue: HrQueue.unassignedShifts,
  status: 'OPEN',
  shiftType: 'DAY',
  shiftId: 'shift-1',
  staffName: 'Unassigned',
);

const HrWorkItem _swapRequest = HrWorkItem(
  id: 'swap-1',
  displayId: 'SWP-1',
  queue: HrQueue.swapRequests,
  status: 'REQUESTED',
  shiftType: 'NIGHT',
  shiftId: 'shift-2',
  staffName: 'Ada Swap',
);

Finder _searchAction(String label) => find.byTooltip(label);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: hrRostersModule, licenseStatus: 'ACTIVE'),
  ],
  List<String> roles = const <String>['HR'],
  String? facilityId = 'facility-1',
  String? tenantId = _tenantUuid,
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
  _MockHrRepository repository, {
  List<HrWorkItem> workItems = const <HrWorkItem>[_rosterDraft],
  List<HrOption> templates = const <HrOption>[_template],
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async => const Result<HrWorkspaceOverview>.success(
      HrWorkspaceOverview(
        summary: HrWorkspaceSummary(draftRosters: 1, unassignedShifts: 1),
      ),
    ),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(
    () => repository.loadReferenceData(
      facilityId: any(named: 'facilityId'),
      departmentId: any(named: 'departmentId'),
    ),
  ).thenAnswer(
    (_) async => Result<HrReferenceData>.success(
      HrReferenceData(
        shiftTemplates: templates,
        facilities: const <HrOption>[
          HrOption(value: 'fac-1', label: 'Main'),
        ],
        shiftTypes: const <HrOption>[HrOption(value: 'DAY', label: 'DAY')],
      ),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final HrWorkItemsQuery query =
        invocation.positionalArguments.single as HrWorkItemsQuery;
    final List<HrWorkItem> items = workItems
        .where((HrWorkItem item) => item.queue == query.queue)
        .toList(growable: false);
    return Result<AppPage<HrWorkItem>>.success(
      AppPage<HrWorkItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.listAccessUsers(any())).thenAnswer(
    (_) async => const Result<AppPage<HrAccessUser>>.success(
      AppPage<HrAccessUser>(items: <HrAccessUser>[], request: AppPageRequest()),
    ),
  );
  when(() => repository.listAccessRoles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrAccessRole>>.success(
      AppPage<HrAccessRole>(items: <HrAccessRole>[], request: AppPageRequest()),
    ),
  );
  when(() => repository.listAccessPermissions(any())).thenAnswer(
    (_) async => const Result<AppPage<HrAccessPermission>>.success(
      AppPage<HrAccessPermission>(
        items: <HrAccessPermission>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(
    () => repository.deleteShiftTemplate(any()),
  ).thenAnswer((_) async => const Result<Object?>.success(null));
  when(
    () => repository.createShiftTemplate(any()),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
  when(
    () => repository.updateShiftTemplate(any(), any()),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
  when(
    () => repository.publishRoster(
      any(),
      notifyStaff: any(named: 'notifyStaff'),
      allowPartialPublish: any(named: 'allowPartialPublish'),
      publishNote: any(named: 'publishNote'),
    ),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
  when(
    () => repository.overrideShift(
      any(),
      staffProfileId: any(named: 'staffProfileId'),
      reason: any(named: 'reason'),
    ),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
  when(
    () => repository.approveSwap(any(), reason: any(named: 'reason')),
  ).thenAnswer((_) async => const Result<Object?>.success(null));
}

Future<void> _pumpShiftsTab(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required AppAccessPolicy accessPolicy,
  List<HrWorkItem> workItems = const <HrWorkItem>[_rosterDraft],
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/hr?section=shifts',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, workItems: workItems);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/hr',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: HrWorkspacePage(
              initialQuery: HrWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hrRepositoryProvider.overrideWithValue(repository),
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

Future<void> _openScheduleTemplates(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required AppAccessPolicy accessPolicy,
}) async {
  await _pumpShiftsTab(
    tester,
    repository: repository,
    accessPolicy: accessPolicy,
  );
  await tester.tap(_searchAction('Create roster template'));
  await tester.pumpAndSettle();
}

void main() {
  late _MockHrRepository repository;

  setUpAll(() {
    registerFallbackValue(const HrStaffQuery());
    registerFallbackValue(const HrWorkItemsQuery());
    registerFallbackValue(const HrAccessQuery());
    registerFallbackValue(const HrStaffProfile(id: 'fallback'));
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockHrRepository();
  });

  group('HrShiftsAtomPermissions helpers', () {
    test('reuses Shifts ∩ roster helpers (no second vocabulary)', () {
      expect(
        identical(HrShiftsAtomPermissions.tab, hrReadRequirement),
        isTrue,
      );
      expect(
        identical(
          HrShiftsAtomPermissions.scheduleTemplates,
          hrShiftsRosterWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(HrShiftsAtomPermissions.create, hrShiftsRosterWriteRequirement),
        isTrue,
      );
      expect(
        identical(HrShiftsAtomPermissions.update, hrShiftsRosterWriteRequirement),
        isTrue,
      );
      expect(
        identical(HrShiftsAtomPermissions.delete, hrWriteRequirement),
        isTrue,
      );
      expect(
        identical(
          HrShiftsAtomPermissions.publishRoster,
          hrShiftsRosterPublishRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrShiftsAtomPermissions.approveSwap,
          hrShiftsRosterApproveRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrShiftsAtomPermissions.nestedWrite,
          hrRosterNestedWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrShiftsAtomPermissions.routeEntry,
          RouteAccessCatalog.hrEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          hrSectionRequirement(HrDeskSection.shiftRoster),
          HrShiftsAtomPermissions.tab,
        ),
        isTrue,
      );
      // Staff-detail source ∪ remains distinct from Shifts matrix ∩.
      expect(
        identical(hrRosterWriteRequirement, hrShiftsRosterWriteRequirement),
        isFalse,
      );
    });

    test('∩ denial: hr:write alone does not unlock create/update/publish', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );
      final AppAccessPolicy hrWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
      );
      expect(HrShiftsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(HrShiftsAtomPermissions.scheduleTemplates.isAllowed(reader), isFalse);
      expect(HrShiftsAtomPermissions.create.isAllowed(hrWriter), isFalse);
      expect(HrShiftsAtomPermissions.update.isAllowed(hrWriter), isFalse);
      expect(HrShiftsAtomPermissions.overrideShift.isAllowed(hrWriter), isFalse);
      expect(HrShiftsAtomPermissions.delete.isAllowed(hrWriter), isTrue);
      expect(HrShiftsAtomPermissions.publishRoster.isAllowed(hrWriter), isFalse);
      expect(HrShiftsAtomPermissions.approveSwap.isAllowed(hrWriter), isFalse);
      // Source staff-detail ∪ still allows roster write via hr:write.
      expect(hrRosterWriteRequirement.isAllowed(hrWriter), isTrue);
    });

    test('∩ presence: roster:write unlocks create/update without hr:write', () {
      final AppAccessPolicy rosterWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterWrite,
        },
      );
      expect(
        HrShiftsAtomPermissions.scheduleTemplates.isAllowed(rosterWriter),
        isTrue,
      );
      expect(HrShiftsAtomPermissions.create.isAllowed(rosterWriter), isTrue);
      expect(HrShiftsAtomPermissions.delete.isAllowed(rosterWriter), isFalse);
      expect(
        HrShiftsAtomPermissions.publishRoster.isAllowed(rosterWriter),
        isFalse,
      );
    });

    test('∪ nested: publish or approve alone unlocks nested write row', () {
      final AppAccessPolicy publisher = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterPublish,
        },
      );
      final AppAccessPolicy approver = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterApprove,
        },
      );
      expect(HrShiftsAtomPermissions.nestedWrite.isAllowed(publisher), isTrue);
      expect(HrShiftsAtomPermissions.publishRoster.isAllowed(publisher), isTrue);
      expect(HrShiftsAtomPermissions.approveSwap.isAllowed(publisher), isFalse);
      expect(HrShiftsAtomPermissions.nestedWrite.isAllowed(approver), isTrue);
      expect(HrShiftsAtomPermissions.approveSwap.isAllowed(approver), isTrue);
      expect(HrShiftsAtomPermissions.publishRoster.isAllowed(approver), isFalse);
    });

    test('subscription strips Shifts when hr-rosters module inactive', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterWrite,
          AppPermissions.rosterPublish,
          AppPermissions.rosterApprove,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(HrShiftsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        HrShiftsAtomPermissions.scheduleTemplates.isAllowed(noModule),
        isFalse,
      );
      expect(HrShiftsAtomPermissions.nestedWrite.isAllowed(noModule), isFalse);
      expect(canEnterHrWorkspace(noModule), isFalse);
    });

    test('ABAC facility strip: route entry requires facility context', () {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterWrite,
        },
        facilityId: null,
      );
      expect(HrShiftsAtomPermissions.tab.isAllowed(noFacility), isTrue);
      expect(HrShiftsAtomPermissions.routeEntry.isAllowed(noFacility), isFalse);
      expect(canEnterHrWorkspace(noFacility), isFalse);
    });
  });

  testWidgets(
    'read-only: Shifts list chrome visible; Create roster template absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );

      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Roster templates'), findsOneWidget);
      expect(_searchAction('Create roster template'), findsNothing);
      expect(find.text('Publish roster'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byTooltip('Filters'), findsOneWidget);
    },
  );

  testWidgets(
    '∩ denial: hr:write alone hides Create roster template and Publish',
    (WidgetTester tester) async {
      final AppAccessPolicy hrWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
      );

      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: hrWriter,
      );

      expect(_tab('Roster templates'), findsOneWidget);
      expect(_searchAction('Create roster template'), findsNothing);
      expect(find.text('Publish roster'), findsNothing);
      expect(find.text('Override shift'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'roster:write ∩: Create roster template mounts; Edit/Delete actions visible',
    (WidgetTester tester) async {
      final AppAccessPolicy rosterWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterWrite,
        },
      );

      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: rosterWriter,
        workItems: const <HrWorkItem>[_rosterDraft],
      );

      expect(_searchAction('Create roster template'), findsOneWidget);
      expect(find.text('Publish roster'), findsNothing);
      expect(find.text('Edit'), findsWidgets);
      expect(find.text('Delete'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'roster:publish alone does not show list Edit/Delete or Publish',
    (WidgetTester tester) async {
      final AppAccessPolicy publisher = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterPublish,
        },
      );

      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: publisher,
        workItems: const <HrWorkItem>[_rosterDraft],
      );

      expect(_searchAction('Create roster template'), findsNothing);
      expect(find.text('Publish roster'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ allowance: roster:approve alone shows Approve swap next-action',
    (WidgetTester tester) async {
      final AppAccessPolicy approver = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterApprove,
        },
      );

      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: approver,
        workItems: const <HrWorkItem>[_swapRequest],
        // Swap belongs on Leave; queue wins over a conflicting section.
        initialLocation: '/hr?section=swap-requests&queue=SWAP_REQUESTS',
      );

      expect(_searchAction('Create roster template'), findsNothing);
      expect(find.text('Approve swap'), findsWidgets);
      expect(find.text('Publish roster'), findsNothing);
    },
  );

  testWidgets(
    'override next-action requires roster:write; absent for read-only',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );
      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        workItems: const <HrWorkItem>[_unassignedShift],
        initialLocation: '/hr?section=shifts&queue=UNASSIGNED_SHIFTS',
      );

      expect(find.text('Override shift'), findsNothing);

      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.rosterWrite,
          },
        ),
        workItems: const <HrWorkItem>[_unassignedShift],
        initialLocation: '/hr?section=shifts&queue=UNASSIGNED_SHIFTS',
      );
      expect(find.text('Override shift'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module write absent without publish/approve',
    (WidgetTester tester) async {
      final AppAccessPolicy rosterOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterWrite,
        },
      );

      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: rosterOnly,
        workItems: const <HrWorkItem>[_rosterDraft],
      );

      expect(find.text('Publish roster'), findsNothing);
      expect(find.text('Approve swap'), findsNothing);

      when(() => repository.getRoster(any())).thenAnswer(
        (_) async => const Result<Map<String, Object?>>.success(
          <String, Object?>{
            'name': 'Week 12',
            'status': 'DRAFT',
            'is_recurring': false,
            'human_friendly_id': 'RST-1001',
            'staff': <Object?>[],
          },
        ),
      );

      // Roster row title uses periodLabel ("Week 12").
      await tester.tap(find.text('Week 12').first);
      await tester.pumpAndSettle();

      expect(find.text('Publish roster'), findsNothing);
      expect(find.text('Edit'), findsWidgets);
      expect(find.text('Print'), findsWidgets);
      expect(find.text('Assigned staff'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'create roster dialog mounts with roster:write',
    (WidgetTester tester) async {
      final AppAccessPolicy rosterOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterWrite,
        },
      );

      when(() => repository.createRoster(any())).thenAnswer(
        (_) async => const Result<Object?>.success(null),
      );

      await _openScheduleTemplates(
        tester,
        repository: repository,
        accessPolicy: rosterOnly,
      );

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Template details'), findsWidgets);
      expect(find.text('Recurring'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Edit action opens edit dialog for roster writers',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterWrite,
        },
      );

      when(() => repository.getRoster(any())).thenAnswer(
        (_) async => const Result<Map<String, Object?>>.success(
          <String, Object?>{
            'name': 'Week 12',
            'status': 'DRAFT',
            'is_recurring': false,
            'human_friendly_id': 'RST-1001',
            'staff': <Object?>[],
          },
        ),
      );

      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        workItems: const <HrWorkItem>[_rosterDraft],
      );

      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.textContaining('EDIT ROSTER TEMPLATE'), findsWidgets);
      expect(find.text('Template details'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
      verify(() => repository.getRoster(any())).called(greaterThan(0));
    },
  );

  testWidgets(
    'subscription strip: missing hr-rosters hides Shifts chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterWrite,
          AppPermissions.rosterPublish,
        },
        modules: const <AppModuleEntitlement>[],
      );

      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(_tab('Roster templates'), findsNothing);
      expect(_searchAction('Create roster template'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('mobile + dark: read chrome and write gate still hold', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy rosterWriter = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.rosterWrite,
      },
    );

    await _pumpShiftsTab(
      tester,
      repository: repository,
      accessPolicy: rosterWriter,
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );

    expect(_tab('Roster templates'), findsOneWidget);
    // Compact widths hide toolbar labels; tooltip remains the stable atom.
    expect(find.byTooltip('Create roster template'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);

    await _pumpShiftsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      ),
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );
    expect(find.byTooltip('Create roster template'), findsNothing);
  });

  testWidgets('desktop light: empty queue without HR activity secondary', (
    WidgetTester tester,
  ) async {
    await _pumpShiftsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      ),
      workItems: const <HrWorkItem>[],
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.light,
    );

    expect(_tab('Roster templates'), findsOneWidget);
    expect(find.byTooltip('HR activity'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets(
    'without hr:read, Shifts tab requirement fails (strip collapses)',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrWrite,
          AppPermissions.rosterWrite,
        },
      );
      expect(HrShiftsAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(
        canViewHrSection(writeOnly, HrDeskSection.shiftRoster),
        isFalse,
      );

      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(_tab('Roster templates'), findsNothing);
      expect(_searchAction('Create roster template'), findsNothing);
    },
  );
}
