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
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHrRepository extends Mock implements HrRepository {}

const String _tenantUuid = '550e8400-e29b-41d4-a716-446655440000';

const HrAccessUser _accessUser = HrAccessUser(
  id: 'USR-1',
  displayId: 'USR-1',
  email: 'hr.admin@example.com',
  status: 'ACTIVE',
  profileName: 'HR Admin',
);

const HrUserRole _assignedRole = HrUserRole(
  id: 'ur-1',
  displayId: 'UR-1',
  backendIdentifier: 'ur-backend-1',
  roleId: 'role-nurse',
  roleName: 'Nurse',
);

const HrAccessUserDetail _accessUserDetail = HrAccessUserDetail(
  id: 'USR-1',
  displayId: 'USR-1',
  email: 'hr.admin@example.com',
  profileName: 'HR Admin',
  status: 'ACTIVE',
  userRoles: <HrUserRole>[_assignedRole],
);

const HrAccessRole _accessRole = HrAccessRole(
  id: 'role-1',
  displayId: 'ROLE-1',
  name: 'CUSTOM_ACCESS_ROLE',
  displayName: 'Custom Access Role',
  permissionCount: 2,
  userCount: 1,
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: hrRostersModule, licenseStatus: 'ACTIVE'),
  ],
  List<String> roles = const <String>['TENANT_ADMIN'],
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
  List<HrAccessUser> accessUsers = const <HrAccessUser>[_accessUser],
  List<HrAccessRole> accessRoles = const <HrAccessRole>[_accessRole],
  bool failAccessUsers = false,
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async =>
        const Result<HrWorkspaceOverview>.success(HrWorkspaceOverview()),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[
          HrStaffProfile(
            id: 'staff-1',
            displayId: 'STF-1',
            tenantId: _tenantUuid,
            status: 'ACTIVE',
          ),
        ],
        request: AppPageRequest(),
        totalItemCount: 1,
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
      AppPage<HrWorkItem>(
        items: <HrWorkItem>[],
        request: AppPageRequest(pageSize: 10),
      ),
    ),
  );
  if (failAccessUsers) {
    when(() => repository.listAccessUsers(any())).thenAnswer(
      (_) async => const Result<AppPage<HrAccessUser>>.failure(
        AppFailure.network(),
      ),
    );
  } else {
    when(() => repository.listAccessUsers(any())).thenAnswer(
      (_) async => Result<AppPage<HrAccessUser>>.success(
        AppPage<HrAccessUser>(
          items: accessUsers,
          request: const AppPageRequest(pageSize: 12),
          totalItemCount: accessUsers.length,
        ),
      ),
    );
  }
  when(() => repository.listAccessRoles(any())).thenAnswer(
    (_) async => Result<AppPage<HrAccessRole>>.success(
      AppPage<HrAccessRole>(
        items: accessRoles,
        request: const AppPageRequest(),
        totalItemCount: accessRoles.length,
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
  when(() => repository.listAllAccessPermissions(any())).thenAnswer(
    (_) async => const Result<List<HrAccessPermission>>.success(
      <HrAccessPermission>[],
    ),
  );
  when(() => repository.loadAccessUserDetail(any())).thenAnswer(
    (_) async => const Result<HrAccessUserDetail>.success(_accessUserDetail),
  );
  when(
    () => repository.listUserRoles(
      userId: any(named: 'userId'),
      tenantId: any(named: 'tenantId'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<List<HrUserRole>>.success(<HrUserRole>[_assignedRole]),
  );
  when(() => repository.revokeUserRole(any())).thenAnswer(
    (_) async => const Result<void>.success(null),
  );
}

Future<void> _pumpAccessTab(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required AppAccessPolicy accessPolicy,
  Size viewport = const Size(1280, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HrAccessUser> accessUsers = const <HrAccessUser>[_accessUser],
  bool failAccessUsers = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    accessUsers: accessUsers,
    failAccessUsers: failAccessUsers,
  );

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/hr?section=access',
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

void main() {
  late _MockHrRepository repository;

  setUpAll(() {
    registerFallbackValue(const HrStaffQuery());
    registerFallbackValue(const HrWorkItemsQuery());
    registerFallbackValue(const HrAccessQuery());
    registerFallbackValue(const HrStaffProfile(id: 'fallback'));
  });

  setUp(() {
    repository = _MockHrRepository();
  });

  group('HrManageUsersRolesAtomPermissions helpers', () {
    test('reuses feature requirements (no second vocabulary)', () {
      expect(
        identical(
          HrManageUsersRolesAtomPermissions.tab,
          hrAccessReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrManageUsersRolesAtomPermissions.create,
          hrAccessCreateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrManageUsersRolesAtomPermissions.createStaff,
          hrAccessCreateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrManageUsersRolesAtomPermissions.update,
          hrAccessUpdateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrManageUsersRolesAtomPermissions.editUser,
          hrAccessUpdateRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrManageUsersRolesAtomPermissions.delete,
          hrWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrManageUsersRolesAtomPermissions.removeRole,
          hrAccessDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          hrSectionRequirement(HrDeskSection.access),
          HrManageUsersRolesAtomPermissions.tab,
        ),
        isTrue,
      );
      // Nested cross-module rows are n/a on this tab.
      expect(HrManageUsersRolesAtomPermissions.nestedRead.anyPermissions, isEmpty);
      expect(
        HrManageUsersRolesAtomPermissions.nestedWrite.anyPermissions,
        isEmpty,
      );
      expect(HrManageUsersRolesAtomPermissions.nestedRead.isAllowed(_policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      )), isTrue);
    });

    test('∪ read: facility:admin + hr:read satisfies Access tab', () {
      final AppAccessPolicy facility = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.facilityAdmin,
        },
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(canReadHrAccess(facility), isTrue);
      expect(hrAccessReadRequirement.isAllowed(facility), isTrue);
      expect(HrManageUsersRolesAtomPermissions.tab.isAllowed(facility), isTrue);
      expect(canViewHrSection(facility, HrDeskSection.access), isTrue);
      expect(hrAllowedSections(facility).contains(HrDeskSection.access), isTrue);
    });

    test('∪ read: platform:admin + hr:read satisfies Access tab', () {
      // Session role SYSTEM_ADMIN canonicalizes to PLATFORM_ADMIN (elevated).
      final AppAccessPolicy system = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.platformAdmin,
        },
        roles: const <String>['SYSTEM_ADMIN'],
      );
      expect(canReadHrAccess(system), isTrue);
      expect(HrManageUsersRolesAtomPermissions.tab.isAllowed(system), isTrue);
      // Elevated actors satisfy create/delete helpers (isElevated bypass).
      expect(system.isElevated, isTrue);
      expect(canCreateHrAccess(system), isTrue);
      expect(canDeleteHrAccess(system), isTrue);

      // Permission-only platform:admin (no elevated role) still reads via ∪.
      final AppAccessPolicy systemPermOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.platformAdmin,
        },
        roles: const <String>['HR'],
      );
      expect(canReadHrAccess(systemPermOnly), isTrue);
      expect(systemPermOnly.isElevated, isFalse);
      expect(canCreateHrAccess(systemPermOnly), isFalse);
      expect(canDeleteHrAccess(systemPermOnly), isFalse);
    });

    test('∩ denial: hr:read without admin hides Access tab', () {
      final AppAccessPolicy hrOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
        roles: const <String>['HR'],
      );
      expect(canReadHr(hrOnly), isTrue);
      expect(canReadHrAccess(hrOnly), isFalse);
      expect(HrManageUsersRolesAtomPermissions.tab.isAllowed(hrOnly), isFalse);
      expect(canViewHrSection(hrOnly, HrDeskSection.access), isFalse);
      expect(hrAllowedSections(hrOnly).contains(HrDeskSection.access), isFalse);
    });

    test(
      'create ∩: facility-scoped hr:write allows Access mutations',
      () {
        final AppAccessPolicy tenantWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.tenantAdmin,
          },
        );
        final AppAccessPolicy facilityWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.facilityAdmin,
          },
          roles: const <String>['FACILITY_ADMIN'],
        );
        final AppAccessPolicy hrWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
          roles: const <String>['HR'],
        );
        final AppAccessPolicy tenantWithoutHrWrite = _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.tenantAdmin,
          },
        );

        expect(canCreateHrAccess(tenantWriter), isTrue);
        expect(canUpdateHrAccess(tenantWriter), isTrue);
        expect(canDeleteHrAccess(tenantWriter), isTrue);

        // Facility admin / HR with hr:write can mutate access within facility.
        expect(canReadHrAccess(facilityWriter), isTrue);
        expect(canDeleteHrAccess(facilityWriter), isTrue);
        expect(canCreateHrAccess(facilityWriter), isTrue);
        expect(canUpdateHrAccess(facilityWriter), isTrue);
        expect(canCreateHrAccess(hrWriter), isTrue);
        expect(canUpdateHrAccess(hrWriter), isTrue);
        expect(canDeleteHrAccess(hrWriter), isTrue);

        // hr:write is required for create/update/delete.
        expect(hrAccessCreateRequirement.isAllowed(tenantWithoutHrWrite), isFalse);
        expect(canCreateHrAccess(tenantWithoutHrWrite), isFalse);
      },
    );

    test('subscription strips Access UI without hr-rosters module', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.tenantAdmin,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(HrManageUsersRolesAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canCreateHrAccess(noModule), isFalse);
      expect(canWriteHrAccessPolicy(noModule), isFalse);
    });

    test('route entry catalog ∩ requires facility ABAC', () {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.tenantAdmin,
        },
        facilityId: null,
      );
      expect(HrManageUsersRolesAtomPermissions.tab.isAllowed(noFacility), isTrue);
      expect(
        HrManageUsersRolesAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
    });
  });

  testWidgets(
    '∪ allowance: Access tab + Create staff for tenant admin writer',
    (WidgetTester tester) async {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.tenantAdmin,
        },
      );

      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: policy,
      );

      expect(_tab('Manage staff and roles'), findsOneWidget);
      expect(find.text('HR Admin'), findsOneWidget);
      expect(find.text('Create staff'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
    },
  );

  testWidgets(
    '∩ denial: Access tab absent for hr:write without admin ∪',
    (WidgetTester tester) async {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
        roles: const <String>['HR'],
      );

      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: policy,
      );

      expect(_tab('Manage staff and roles'), findsNothing);
      expect(find.text('Create staff'), findsNothing);
      expect(find.byType(HrAccessWorkspacePanel), findsNothing);
      // Falls back to an authorized section (staff directory).
      expect(_tab('Staff members'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'facility ∪ + hr:write: Access create staff available (same write gate)',
    (WidgetTester tester) async {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.facilityAdmin,
        },
        roles: const <String>['FACILITY_ADMIN'],
      );

      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: policy,
      );

      expect(_tab('Manage staff and roles'), findsOneWidget);
      expect(find.text('HR Admin'), findsOneWidget);
      expect(find.text('Create staff'), findsOneWidget);
      expect(find.text('Create role'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'facility ∪ + hr:write: detail shows Edit staff account, Add role, Remove role',
    (WidgetTester tester) async {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.facilityAdmin,
        },
        roles: const <String>['FACILITY_ADMIN'],
      );

      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: policy,
      );

      await tester.tap(find.text('HR Admin'));
      await tester.pumpAndSettle();

      expect(find.text('Edit staff account'), findsOneWidget);
      expect(find.text('Add role'), findsOneWidget);
      expect(find.text('Remove role'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'tenant create ∩: detail Edit staff account present; Remove role present',
    (WidgetTester tester) async {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.tenantAdmin,
        },
      );

      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: policy,
      );

      await tester.tap(find.text('HR Admin'));
      await tester.pumpAndSettle();

      expect(find.text('Edit staff account'), findsOneWidget);
      expect(find.text('Add role'), findsOneWidget);
      expect(find.text('Remove role'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'admin ∪ without hr:write: read detail; mutate atoms absent',
    (WidgetTester tester) async {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.facilityAdmin,
        },
        roles: const <String>['FACILITY_ADMIN'],
      );

      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: policy,
      );

      expect(find.text('Create staff'), findsNothing);

      await tester.tap(find.text('HR Admin'));
      await tester.pumpAndSettle();

      expect(find.text('Edit staff account'), findsNothing);
      expect(find.text('Add role'), findsNothing);
      expect(find.text('Remove role'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'Create role present on Roles panel when create ∩ allowed',
    (WidgetTester tester) async {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.tenantAdmin,
        },
      );

      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: policy,
      );

      await tester.tap(find.text('Roles'));
      await tester.pumpAndSettle();

      expect(find.text('Create role'), findsOneWidget);
      expect(find.text('Custom Access Role'), findsOneWidget);
      expect(find.text('Create staff'), findsNothing);
    },
  );

  testWidgets(
    'authorized Create role dialog opens; Refresh syncs Access list',
    (WidgetTester tester) async {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.tenantAdmin,
        },
      );

      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: policy,
      );

      await tester.tap(find.text('Roles'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create role'));
      await tester.pumpAndSettle();
      expect(find.text('Role name'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      clearInteractions(repository);
      when(() => repository.listAccessRoles(any())).thenAnswer(
        (_) async => const Result<AppPage<HrAccessRole>>.success(
          AppPage<HrAccessRole>(
            items: <HrAccessRole>[_accessRole],
            request: AppPageRequest(),
            totalItemCount: 1,
          ),
        ),
      );

      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      verify(() => repository.listAccessRoles(any())).called(greaterThan(0));
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized empty / loading states remain observable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy policy = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.tenantAdmin,
      },
    );

    await _pumpAccessTab(
      tester,
      repository: repository,
      accessPolicy: policy,
      accessUsers: const <HrAccessUser>[],
    );

    expect(find.text('No staff accounts match your search.'), findsOneWidget);
    expect(find.text('Create staff'), findsOneWidget);
  });

  testWidgets('authorized error/retry surface remains observable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy policy = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.tenantAdmin,
      },
    );

    await _pumpAccessTab(
      tester,
      repository: repository,
      accessPolicy: policy,
      failAccessUsers: true,
    );

    expect(find.textContaining('Try again'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);

    when(() => repository.listAccessUsers(any())).thenAnswer(
      (_) async => const Result<AppPage<HrAccessUser>>.success(
        AppPage<HrAccessUser>(
          items: <HrAccessUser>[_accessUser],
          request: AppPageRequest(pageSize: 12),
          totalItemCount: 1,
        ),
      ),
    );
    await tester.tap(find.text('Try again').first);
    await tester.pumpAndSettle();

    expect(find.text('HR Admin'), findsOneWidget);
  });

  testWidgets('mobile + desktop viewports keep Access panel usable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy policy = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.tenantAdmin,
      },
    );

    // Representative compact tablet / large-phone width (tab strip overflow
    // chrome is out of scope for this permission scan).
    await _pumpAccessTab(
      tester,
      repository: repository,
      accessPolicy: policy,
      viewport: const Size(720, 900),
    );
    expect(find.text('HR Admin'), findsOneWidget);
    expect(find.text('Create staff'), findsOneWidget);

    await _pumpAccessTab(
      tester,
      repository: repository,
      accessPolicy: policy,
      viewport: const Size(1440, 900),
    );
    expect(find.text('HR Admin'), findsOneWidget);
    expect(find.text('Create staff'), findsOneWidget);
  });

  testWidgets('light and dark themes render Access tab without errors', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy policy = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.tenantAdmin,
      },
    );

    await _pumpAccessTab(
      tester,
      repository: repository,
      accessPolicy: policy,
      themeMode: ThemeMode.light,
    );
    expect(find.text('Create staff'), findsOneWidget);

    await _pumpAccessTab(
      tester,
      repository: repository,
      accessPolicy: policy,
      themeMode: ThemeMode.dark,
    );
    expect(find.text('Create staff'), findsOneWidget);
  });
}
