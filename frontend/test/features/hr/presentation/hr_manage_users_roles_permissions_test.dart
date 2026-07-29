import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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
  when(() => repository.listAccessUsers(any())).thenAnswer(
    (_) async => Result<AppPage<HrAccessUser>>.success(
      AppPage<HrAccessUser>(
        items: accessUsers,
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: accessUsers.length,
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
  when(() => repository.listAllAccessPermissions(any())).thenAnswer(
    (_) async => const Result<List<HrAccessPermission>>.success(
      <HrAccessPermission>[],
    ),
  );
}

Future<void> _pumpAccessTab(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required AppAccessPolicy accessPolicy,
  Size viewport = const Size(1280, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HrAccessUser> accessUsers = const <HrAccessUser>[_accessUser],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, accessUsers: accessUsers);

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
          HrManageUsersRolesAtomPermissions.update,
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
          HrManageUsersRolesAtomPermissions.delete,
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
      'create ∩: source hr:write ∩ matrix tenant:admin (noted mapping)',
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
        final AppAccessPolicy tenantWithoutHrWrite = _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.tenantAdmin,
          },
        );

        expect(canCreateHrAccess(tenantWriter), isTrue);
        expect(canUpdateHrAccess(tenantWriter), isTrue);
        expect(canDeleteHrAccess(tenantWriter), isTrue);

        // Facility admin can read ∪ and delete ∩ hr:write, but create needs
        // matrix ∩ tenant:admin (intersected with source hr:write).
        expect(canReadHrAccess(facilityWriter), isTrue);
        expect(canDeleteHrAccess(facilityWriter), isTrue);
        expect(canCreateHrAccess(facilityWriter), isFalse);
        expect(canUpdateHrAccess(facilityWriter), isFalse);

        // Matrix create alone is insufficient without source hr:write.
        expect(hrAccessCreateRequirement.isAllowed(tenantWithoutHrWrite), isTrue);
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

      expect(_tab('Manage users and roles'), findsOneWidget);
      expect(find.text('HR Admin'), findsOneWidget);
      expect(find.text('Create staff'), findsOneWidget);
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

      expect(_tab('Manage users and roles'), findsNothing);
      expect(find.text('Create staff'), findsNothing);
      expect(find.byType(HrAccessWorkspacePanel), findsNothing);
      // Falls back to an authorized section (staff directory).
      expect(_tab('Human resources'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'facility ∪ read shows panel; create ∩ tenant:admin absent',
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

      expect(_tab('Manage users and roles'), findsOneWidget);
      expect(find.text('HR Admin'), findsOneWidget);
      expect(find.text('Create staff'), findsNothing);
      expect(find.text('Create role'), findsNothing);
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
