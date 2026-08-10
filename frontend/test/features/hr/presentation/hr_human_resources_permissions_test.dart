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
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHrRepository extends Mock implements HrRepository {}

class _MockAccessAdminRepository extends Mock
    implements AccessAdminRepository {}

const String _tenantUuid = '550e8400-e29b-41d4-a716-446655440000';

const AccessAdminItem _user = AccessAdminItem(
  id: 'user-1',
  resource: AccessAdminResource.users,
  displayId: 'USR-1',
  title: 'Ada User',
  email: 'ada@example.com',
  status: 'ACTIVE',
);

const HrStaffProfile _staffNeedsDepartment = HrStaffProfile(
  id: 'staff-1',
  displayId: 'STF-1',
  staffNumber: 'EMP-1',
  userFullName: 'Ada Needs Dept',
  tenantId: _tenantUuid,
  status: 'ACTIVE',
);

const HrStaffProfile _staffComplete = HrStaffProfile(
  id: 'staff-2',
  displayId: 'STF-2',
  staffNumber: 'EMP-2',
  userFullName: 'Ben Complete',
  tenantId: _tenantUuid,
  departmentId: 'dept-1',
  departmentName: 'Emergency',
  position: 'Nurse',
  status: 'ACTIVE',
  compensations: <HrStaffCompensation>[
    HrStaffCompensation(
      id: 'comp-1',
      payType: 'SALARY',
      rate: 1000,
      currency: 'UGX',
    ),
  ],
);

const HrStaffDetail _staffCompleteDetail = HrStaffDetail(
  profile: _staffComplete,
  assignments: <HrStaffAssignment>[
    HrStaffAssignment(
      id: 'asg-1',
      departmentName: 'Emergency',
      isPrimary: true,
    ),
  ],
  availabilities: <HrStaffAvailability>[
    HrStaffAvailability(
      id: 'avail-1',
      dayOfWeek: 1,
      timeSlots: <HrAvailabilitySlot>[
        HrAvailabilitySlot(startTime: '08:00', endTime: '16:00'),
      ],
    ),
  ],
  shiftAssignments: <HrShiftAssignment>[
    HrShiftAssignment(
      id: 'shift-1',
      shiftType: 'DAY',
      shiftStatus: 'SCHEDULED',
    ),
  ],
  compensations: <HrStaffCompensation>[
    HrStaffCompensation(
      id: 'comp-1',
      payType: 'SALARY',
      rate: 1000,
      currency: 'UGX',
    ),
  ],
);

Finder _searchAction(String label) => find.byTooltip(label);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AccessAdminWorkspaceData _usersData({
  bool canWrite = true,
  List<AccessAdminItem> items = const <AccessAdminItem>[_user],
}) {
  return AccessAdminWorkspaceData(
    permissions: AccessAdminWorkspacePermissions(
      canRead: true,
      canWrite: canWrite,
    ),
    lookups: const AccessAdminLookups(
      userStatuses: <String>['ACTIVE', 'INACTIVE'],
    ),
    items: items,
    page: AppPage<AccessAdminItem>(
      items: items,
      request: const AppPageRequest(pageSize: 25),
      totalItemCount: items.length,
    ),
    query: const AccessAdminWorkspaceQuery(
      resource: AccessAdminResource.users,
      includeDeleted: true,
      lean: true,
    ),
  );
}

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: hrRostersModule,
      licenseStatus: 'ACTIVE',
      planTierCode: 'PRO',
    ),
    AppModuleEntitlement(
      code: hrBillingPaymentsModule,
      licenseStatus: 'ACTIVE',
      planTierCode: 'PRO',
    ),
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
  List<HrStaffProfile> staff = const <HrStaffProfile>[_staffNeedsDepartment],
  HrStaffDetail? detail,
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async => const Result<HrWorkspaceOverview>.success(
      HrWorkspaceOverview(summary: HrWorkspaceSummary()),
    ),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: staff,
        request: const AppPageRequest(),
        totalItemCount: staff.length,
      ),
    ),
  );
  when(
    () => repository.loadReferenceData(
      facilityId: any(named: 'facilityId'),
      departmentId: any(named: 'departmentId'),
    ),
  ).thenAnswer(
    (_) async => const Result<HrReferenceData>.success(HrReferenceData()),
  );
  when(() => repository.listWorkItems(any())).thenAnswer(
    (_) async => const Result<AppPage<HrWorkItem>>.success(
      AppPage<HrWorkItem>(items: <HrWorkItem>[], request: AppPageRequest()),
    ),
  );
  when(() => repository.loadStaffDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final HrStaffProfile profile =
        invocation.positionalArguments.single as HrStaffProfile;
    return Result<HrStaffDetail>.success(
      detail ?? HrStaffDetail(profile: profile),
    );
  });
  when(() => repository.listAccessUsers(any())).thenAnswer(
    (_) async => const Result<AppPage<HrAccessUser>>.success(
      AppPage<HrAccessUser>(
        items: <HrAccessUser>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(() => repository.listAccessRoles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrAccessRole>>.success(
      AppPage<HrAccessRole>(
        items: <HrAccessRole>[],
        request: AppPageRequest(),
      ),
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
}

void _stubUsersWorkspace(
  _MockAccessAdminRepository repository, {
  bool canWrite = true,
  List<AccessAdminItem> items = const <AccessAdminItem>[_user],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => Result<AccessAdminWorkspaceData>.success(
      _usersData(canWrite: canWrite, items: items),
    ),
  );
}

Future<void> _pumpStaffTab(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required _MockAccessAdminRepository accessRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HrStaffProfile> staff = const <HrStaffProfile>[_staffNeedsDepartment],
  HrStaffDetail? detail,
  bool usersCanWrite = true,
  List<AccessAdminItem> users = const <AccessAdminItem>[_user],
  String initialLocation = '/hr?section=staff',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, staff: staff, detail: detail);
  _stubUsersWorkspace(accessRepository, canWrite: usersCanWrite, items: users);

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
        accessAdminRepositoryProvider.overrideWithValue(accessRepository),
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
  late _MockHrRepository repository;
  late _MockAccessAdminRepository accessRepository;

  setUpAll(() {
    registerFallbackValue(const HrStaffQuery());
    registerFallbackValue(const HrWorkItemsQuery());
    registerFallbackValue(const HrAccessQuery());
    registerFallbackValue(const HrStaffProfile(id: 'fallback'));
    registerFallbackValue(const AccessAdminWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockHrRepository();
    accessRepository = _MockAccessAdminRepository();
  });

  group('HrHumanResourcesAtomPermissions helpers', () {
    test('reuses hr read/write requirements (no second vocabulary)', () {
      expect(
        identical(HrHumanResourcesAtomPermissions.tab, hrReadRequirement),
        isTrue,
      );
      expect(
        identical(
          HrHumanResourcesAtomPermissions.addStaff,
          hrWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrHumanResourcesAtomPermissions.editStaff,
          hrWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrHumanResourcesAtomPermissions.nestedRosterWrite,
          hrRosterWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrHumanResourcesAtomPermissions.runPayroll,
          hrPayrollRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrHumanResourcesAtomPermissions.routeEntry,
          RouteAccessCatalog.hrEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          hrSectionRequirement(HrDeskSection.staffDirectory),
          HrHumanResourcesAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing hr:read hides Human resources tab requirement', () {
      final AppAccessPolicy none = _policy(permissions: <AppPermission>{});
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.hrWrite},
      );
      expect(HrHumanResourcesAtomPermissions.tab.isAllowed(none), isFalse);
      expect(HrHumanResourcesAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canReadHr(writeOnly), isFalse);
      expect(
        canViewHrSection(writeOnly, HrDeskSection.staffDirectory),
        isFalse,
      );
    });

    test('∩ presence: hr:read + module allows staff read atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );
      expect(HrHumanResourcesAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(HrHumanResourcesAtomPermissions.search.isAllowed(reader), isTrue);
      expect(HrHumanResourcesAtomPermissions.detail.isAllowed(reader), isTrue);
      expect(HrHumanResourcesAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        HrHumanResourcesAtomPermissions.addStaff.isAllowed(reader),
        isFalse,
      );
      expect(
        HrHumanResourcesAtomPermissions.runPayroll.isAllowed(reader),
        isFalse,
      );
    });

    test(
      '∪ allowance: roster:write alone unlocks nested roster staff actions',
      () {
        final AppAccessPolicy rosterWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.rosterWrite,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: hrRostersModule,
              licenseStatus: 'ACTIVE',
              planTierCode: 'PRO',
            ),
          ],
        );
        expect(
          rosterWriter.permissions.contains(AppPermissions.rosterWrite),
          isTrue,
          reason: 'plan caps should keep roster:write on PRO',
        );
        expect(
          HrHumanResourcesAtomPermissions.nestedRosterWrite.isAllowed(
            rosterWriter,
          ),
          isTrue,
        );
        expect(
          HrHumanResourcesAtomPermissions.addStaff.isAllowed(rosterWriter),
          isFalse,
        );
        expect(
          HrHumanResourcesAtomPermissions.editStaff.isAllowed(rosterWriter),
          isFalse,
        );
      },
    );

    test(
      '∩ denial: hr:write without financial:approve hides Run payroll',
      () {
        final AppAccessPolicy writerNoFinance = _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        );
        expect(
          HrHumanResourcesAtomPermissions.write.isAllowed(writerNoFinance),
          isTrue,
        );
        expect(
          HrHumanResourcesAtomPermissions.runPayroll.isAllowed(writerNoFinance),
          isFalse,
        );
      },
    );

    test('subscription strip: missing hr-rosters denies tab and write', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(HrHumanResourcesAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(HrHumanResourcesAtomPermissions.write.isAllowed(noModule), isFalse);
    });

    test('route entry catalog ∩ requires facility ABAC', () {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
        facilityId: null,
      );
      expect(HrHumanResourcesAtomPermissions.tab.isAllowed(noFacility), isTrue);
      expect(
        HrHumanResourcesAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
    });
  });

  testWidgets(
    'read-only ∩ denial: ManageUsersPanel visible; Create user / Staff actions absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );

      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: reader,
        usersCanWrite: false,
        staff: const <HrStaffProfile>[_staffNeedsDepartment],
        initialLocation: '/hr?section=staff&staff=STF-1',
      );

      expect(_tab('Staff members'), findsOneWidget);
      expect(find.byType(ManageUsersPanel), findsOneWidget);
      expect(find.text('Ada User'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(_searchAction('Create user'), findsNothing);
      expect(_searchAction('Add staff'), findsNothing);
      expect(find.text('Assign department'), findsNothing);
      expect(find.text('Review profile'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      expect(find.text('Staff actions'), findsNothing);
      expect(find.byTooltip('Edit staff'), findsNothing);
      expect(find.text('Revoke role'), findsNothing);
      expect(find.text('End assignment'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Create user, Staff actions, Manage payroll via staff deep-link',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.rosterWrite,
          AppPermissions.financialApprove,
        },
      );

      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: writer,
        staff: const <HrStaffProfile>[_staffComplete],
        detail: _staffCompleteDetail,
        initialLocation: '/hr?section=staff&staff=STF-2',
      );

      expect(find.byType(ManageUsersPanel), findsOneWidget);
      expect(_searchAction('Create user'), findsOneWidget);
      expect(_searchAction('Add staff'), findsNothing);
      expect(find.text('Review profile'), findsNothing);

      expect(find.text('Staff actions'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Change department'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Manage payroll'),
        ),
        findsOneWidget,
      );
      expect(find.text('Edit staff'), findsOneWidget);
    },
  );

  testWidgets(
    '∩ denial: hr:write without financial:approve hides Manage payroll in detail',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoFinance = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.rosterWrite,
        },
      );

      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: writerNoFinance,
        staff: const <HrStaffProfile>[_staffComplete],
        detail: _staffCompleteDetail,
        initialLocation: '/hr?section=staff&staff=STF-2',
      );

      expect(_searchAction('Create user'), findsOneWidget);

      expect(find.text('Staff actions'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Change department'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Manage payroll'),
        ),
        findsNothing,
      );
      expect(find.text('Run payroll'), findsNothing);
    },
  );

  testWidgets(
    '∪ roster:write shows Add roster without Create user',
    (WidgetTester tester) async {
      final AppAccessPolicy rosterWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.rosterWrite,
        },
      );

      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: rosterWriter,
        usersCanWrite: false,
        staff: const <HrStaffProfile>[_staffComplete],
        detail: _staffCompleteDetail,
        initialLocation: '/hr?section=staff&staff=STF-2',
      );

      expect(_searchAction('Create user'), findsNothing);
      expect(_searchAction('Add staff'), findsNothing);

      expect(find.text('Staff actions'), findsOneWidget);
      expect(find.text('Add roster'), findsOneWidget);
      expect(find.text('Record availability'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Assign department'),
        ),
        findsNothing,
      );
      expect(find.text('Manage payroll'), findsNothing);
      expect(find.text('Run payroll'), findsNothing);
      expect(find.byTooltip('Edit staff'), findsNothing);
    },
  );

  testWidgets(
    'write-only ∩ denial: catalog entry fails; staff chrome omitted',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.hrWrite},
      );
      expect(
        HrHumanResourcesAtomPermissions.routeEntry.isAllowed(writeOnly),
        isFalse,
      );
      expect(HrHumanResourcesAtomPermissions.tab.isAllowed(writeOnly), isFalse);

      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byType(ManageUsersPanel), findsNothing);
      expect(_searchAction('Create user'), findsNothing);
      expect(find.text('Ada User'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: missing hr-rosters denies Human resources chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );

      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byType(ManageUsersPanel), findsNothing);
      expect(_searchAction('Create user'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized empty users list keeps ManageUsersPanel chrome', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.hrRead},
    );

    await _pumpStaffTab(
      tester,
      repository: repository,
      accessRepository: accessRepository,
      accessPolicy: reader,
      usersCanWrite: false,
      users: const <AccessAdminItem>[],
      staff: const <HrStaffProfile>[],
    );

    expect(_tab('Staff members'), findsOneWidget);
    expect(find.byType(ManageUsersPanel), findsOneWidget);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('authorized desktop + light theme still shows users chrome', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
      },
    );

    await _pumpStaffTab(
      tester,
      repository: repository,
      accessRepository: accessRepository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.light,
    );

    expect(_tab('Staff members'), findsOneWidget);
    expect(find.byType(ManageUsersPanel), findsOneWidget);
    expect(_searchAction('Create user'), findsOneWidget);
    expect(find.textContaining('Ada'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('authorized mobile + dark theme still shows users chrome', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
      },
    );

    await _pumpStaffTab(
      tester,
      repository: repository,
      accessRepository: accessRepository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );

    expect(_tab('Staff members'), findsOneWidget);
    expect(find.byType(ManageUsersPanel), findsOneWidget);
    expect(find.byTooltip('Create user'), findsOneWidget);
    expect(find.textContaining('Ada'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('authorized search trailing Create user remains available', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
      },
    );

    await _pumpStaffTab(
      tester,
      repository: repository,
      accessRepository: accessRepository,
      accessPolicy: writer,
    );

    expect(find.byType(ManageUsersPanel), findsOneWidget);
    expect(find.byTooltip('Create user'), findsOneWidget);
    expect(find.byTooltip('Add staff'), findsNothing);
    expect(find.byTooltip('HR activity'), findsNothing);
  });

  testWidgets('post-mutation sync path: staff deep-link loads detail', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
      },
    );

    await _pumpStaffTab(
      tester,
      repository: repository,
      accessRepository: accessRepository,
      accessPolicy: writer,
      staff: const <HrStaffProfile>[_staffNeedsDepartment],
      initialLocation: '/hr?section=staff&staff=STF-1',
    );

    verify(() => repository.loadStaffDetail(any())).called(greaterThan(0));
    expect(find.byType(ManageUsersPanel), findsOneWidget);
  });
}
