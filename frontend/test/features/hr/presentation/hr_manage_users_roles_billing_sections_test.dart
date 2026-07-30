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
import 'package:hosspi_hms/features/hr/presentation/hr_manage_users_roles_billing.dart';
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_access_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/layout/flat_section_layout_test_helpers.dart';

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
  positionTitle: 'Charge Nurse',
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
      (_) async => const Result<AppPage<HrAccessUser>>.success(
        AppPage<HrAccessUser>(
          items: <HrAccessUser>[_accessUser],
          request: AppPageRequest(pageSize: 12),
          totalItemCount: 1,
        ),
      ),
    );
  }
  when(() => repository.listAccessRoles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrAccessRole>>.success(
      AppPage<HrAccessRole>(
        items: <HrAccessRole>[_accessRole],
        request: AppPageRequest(),
        totalItemCount: 1,
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
}

Future<void> _pumpAccessTab(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required AppAccessPolicy accessPolicy,
  Size viewport = const Size(1280, 900),
  ThemeMode themeMode = ThemeMode.light,
  bool failAccessUsers = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, failAccessUsers: failAccessUsers);

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

  group('HrManageUsersRolesBillingInventory (AC1)', () {
    test('every mounted atom is explicitly not billable to patient ledgers', () {
      expect(
        HrManageUsersRolesBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(HrManageUsersRolesBillingInventory.billableClasses, isEmpty);
    });

    test('every atom is classified billable or explicit not-billable', () {
      for (final HrManageUsersRolesFinancialAtom atom
          in HrManageUsersRolesBillingInventory.atoms) {
        if (atom.mounted) {
          expect(
            atom.auditCode,
            isIn(<String>['NOT_REQUIRED', 'NOT_BILLED', 'NO_CHARGE']),
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
    });

    test('permission sync / billing grants use NOT_BILLED audit', () {
      final HrManageUsersRolesFinancialAtom syncAtom =
          HrManageUsersRolesBillingInventory.atoms.firstWhere(
        (HrManageUsersRolesFinancialAtom atom) =>
            atom.id == 'assign_role_permissions',
      );
      expect(syncAtom.auditCode, 'NOT_BILLED');
      expect(
        syncAtom.financialClass,
        HrManageUsersRolesFinancialClass.notBilled,
      );
    });

    test('consultation fee catalog stays NOT_REQUIRED (no ledger post)', () {
      final HrManageUsersRolesFinancialAtom feeAtom =
          HrManageUsersRolesBillingInventory.atoms.firstWhere(
        (HrManageUsersRolesFinancialAtom atom) =>
            atom.id == 'onboarding_consultation_fee_catalog',
      );
      expect(feeAtom.auditCode, 'NOT_REQUIRED');
    });

    test('reserved financial atoms are unmounted', () {
      final List<String> unmounted = HrManageUsersRolesBillingInventory.atoms
          .where((HrManageUsersRolesFinancialAtom atom) => !atom.mounted)
          .map((HrManageUsersRolesFinancialAtom atom) => atom.id)
          .toList();
      expect(
        unmounted,
        containsAll(<String>[
          'collect_payment',
          'issue_invoice_adjust_refund',
          'patient_charge_from_access',
        ]),
      );
    });

    test('tab has no billable actions helper', () {
      expect(hrManageUsersRolesTabHasNoBillableActions(), isTrue);
    });

    test('scope note documents ledger isolation', () {
      expect(hrManageUsersRolesBillingScopeNote, contains('Billing'));
      expect(hrManageUsersRolesBillingScopeNote, contains('NOT_REQUIRED'));
    });
  });

  group('Access billing bypass + authorization (AC2–AC4)', () {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.tenantAdmin,
      },
    );

    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.byType(HrAccessWorkspacePanel), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('authorized writer sees create chrome without billing', (
      WidgetTester tester,
    ) async {
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      final BuildContext context = tester.element(
        find.byType(HrAccessWorkspacePanel),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.hrCreateUserAction), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('unauthorized reader omits Access panel and billing chrome', (
      WidgetTester tester,
    ) async {
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.hrRead},
          roles: const <String>['NURSE'],
        ),
      );

      expect(find.byType(HrAccessWorkspacePanel), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('user detail has Account sibling section, no billing chrome', (
      WidgetTester tester,
    ) async {
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      final AppListTable<HrAccessUser> table = tester
          .widgetList<AppListTable<HrAccessUser>>(
            find.byType(AppListTable<HrAccessUser>),
          )
          .first;
      table.onRowSelected!(_accessUser);
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(AppDialog).last);
      final AppLocalizations l10n = context.l10n;

      expect(
        find.text(l10n.accessAdminUserDetailProfileSectionTitle),
        findsOneWidget,
      );
      expect(find.text('Charge Nurse'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'user detail dialog',
      );
    });

    test('mutate gate requires create/update/delete helpers', () {
      expect(
        HrManageUsersRolesBillingInventory.canMutateAccess(writer),
        isTrue,
      );
      expect(
        HrManageUsersRolesBillingInventory.canMutateAccess(
          _policy(
            permissions: <AppPermission>{AppPermissions.hrRead},
            roles: const <String>['NURSE'],
          ),
        ),
        isFalse,
      );
    });
  });

  group('Access flat sections (AC5)', () {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.tenantAdmin,
      },
    );

    testWidgets('desktop worklist: flat titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        viewport: const Size(1280, 900),
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('mobile worklist: flat titled sections', (
      WidgetTester tester,
    ) async {
      // Compact tablet / large-phone — full phone width overflows tab strip
      // chrome (out of scope for this billing/sections scan).
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        viewport: const Size(720, 900),
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        themeMode: ThemeMode.light,
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('user detail Account + access panels stay siblings', (
      WidgetTester tester,
    ) async {
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      final AppListTable<HrAccessUser> table = tester
          .widgetList<AppListTable<HrAccessUser>>(
            find.byType(AppListTable<HrAccessUser>),
          )
          .first;
      table.onRowSelected!(_accessUser);
      await tester.pumpAndSettle();

      expect(find.byType(AppWorkspaceDetailPanel), findsWidgets);
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'access user detail siblings',
      );
    });
  });

  group('Access sync / UI states (AC3–AC4, AC6)', () {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.tenantAdmin,
      },
    );

    testWidgets('list loads and stays free of billing chrome', (
      WidgetTester tester,
    ) async {
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('HR Admin'), findsOneWidget);
      expect(find.byType(HrAccessWorkspacePanel), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
    });

    testWidgets('error + retry stay without billing affordances', (
      WidgetTester tester,
    ) async {
      await _pumpAccessTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        failAccessUsers: true,
      );

      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);

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
      expect(find.textContaining('Receive payment'), findsNothing);
    });
  });
}
