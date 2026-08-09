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
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_human_resources_billing_inventory.dart';
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

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

const HrStaffProfile _staff = HrStaffProfile(
  id: 'staff-1',
  displayId: 'STF-1',
  staffNumber: 'EMP-1',
  userFullName: 'Ada Staff',
  tenantId: _tenantUuid,
  departmentId: 'dept-1',
  departmentName: 'Emergency',
  position: 'Nurse',
  status: 'ACTIVE',
  consultationFee: 25000,
  consultationCurrency: 'UGX',
  compensations: <HrStaffCompensation>[
    HrStaffCompensation(
      id: 'comp-1',
      payType: 'SALARY',
      rate: 1000,
      currency: 'UGX',
    ),
  ],
);

const HrStaffDetail _staffDetail = HrStaffDetail(
  profile: _staff,
  assignments: <HrStaffAssignment>[
    HrStaffAssignment(
      id: 'asg-1',
      departmentName: 'Emergency',
      isPrimary: true,
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
    AppModuleEntitlement(code: hrRostersModule, licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(
      code: hrBillingPaymentsModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['HR'],
        tenantId: _tenantUuid,
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockHrRepository repository, {
  List<HrStaffProfile> staff = const <HrStaffProfile>[_staff],
  HrStaffDetail detail = _staffDetail,
  Result<HrWorkspaceOverview>? overviewOverride,
  bool failStaffList = false,
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async =>
        overviewOverride ??
        const Result<HrWorkspaceOverview>.success(
          HrWorkspaceOverview(summary: HrWorkspaceSummary(totalStaff: 1)),
        ),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async {
      if (failStaffList) {
        return const Result<AppPage<HrStaffProfile>>.failure(
          AppFailure.network(),
        );
      }
      return Result<AppPage<HrStaffProfile>>.success(
        AppPage<HrStaffProfile>(
          items: staff,
          request: const AppPageRequest(),
          totalItemCount: staff.length,
        ),
      );
    },
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
  when(() => repository.loadStaffDetail(any())).thenAnswer(
    (_) async => Result<HrStaffDetail>.success(detail),
  );
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
  List<HrStaffProfile> staff = const <HrStaffProfile>[_staff],
  HrStaffDetail detail = _staffDetail,
  bool usersCanWrite = true,
  List<AccessAdminItem> users = const <AccessAdminItem>[_user],
  String initialLocation = '/hr?section=staff',
  Result<HrWorkspaceOverview>? overviewOverride,
  bool failStaffList = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    staff: staff,
    detail: detail,
    overviewOverride: overviewOverride,
    failStaffList: failStaffList,
  );
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

  group('HR Human resources financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        HrHumanResourcesBillingInventory.humanResourcesTabHasNoBillableActions,
        isTrue,
      );
      expect(
        HrHumanResourcesBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(HrHumanResourcesBillingInventory.atoms, isNotEmpty);
      expect(
        HrHumanResourcesBillingInventory.billableClasses.every(
          (HrHumanResourcesFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(hrHumanResourcesBillingScopeNote, contains('NOT_BILLED'));
      expect(hrHumanResourcesBillingScopeNote, contains('payroll'));
      expect(hrHumanResourcesTabHasNoBillableActions(), isTrue);

      for (final HrHumanResourcesFinancialAtom atom
          in HrHumanResourcesBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<HrHumanResourcesFinancialClass>[
            HrHumanResourcesFinancialClass.notRequired,
            HrHumanResourcesFinancialClass.notBilled,
            HrHumanResourcesFinancialClass.noCharge,
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

    test('compensation / payroll / consultation fee stay NOT_BILLED staff ops', () {
      for (final String id in <String>[
        'add_staff',
        'consultation_fee_catalog',
        'compensation_mutate',
        'run_payroll_wizard',
        'offboard_schedule_final_payroll',
      ]) {
        final HrHumanResourcesFinancialAtom atom =
            HrHumanResourcesBillingInventory.atoms.singleWhere(
              (HrHumanResourcesFinancialAtom a) => a.id == id,
            );
        expect(
          atom.financialClass,
          HrHumanResourcesFinancialClass.notBilled,
          reason: id,
        );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
        expect(atom.mounted, isTrue, reason: id);
      }
    });

    test('unmounted billable atoms document Billing SoR', () {
      for (final String id in <String>[
        'patient_create_charge',
        'collect_payment',
        'issue_invoice_adjust_refund',
      ]) {
        final HrHumanResourcesFinancialAtom atom =
            HrHumanResourcesBillingInventory.atoms.singleWhere(
              (HrHumanResourcesFinancialAtom a) => a.id == id,
            );
        expect(atom.mounted, isFalse, reason: id);
        expect(atom.auditCode, 'REQUIRES_BILLING', reason: id);
      }
    });
  });

  group('HR Human resources billing bypass (AC2–AC4)', () {
    testWidgets('directory has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.byType(ManageUsersPanel), findsOneWidget);
      expect(find.text('Ada User'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('staff detail: sibling sections; no patient financial controls', (
      WidgetTester tester,
    ) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
            AppPermissions.rosterWrite,
          },
        ),
        initialLocation: '/hr?section=staff&staff=STF-1',
      );

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Compensation'), findsWidgets);
      expect(find.text('Run payroll'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.textContaining('Write off'), findsNothing);
      expect(find.byType(AppCollapsibleSection), findsAtLeastNWidgets(2));
      expectFlatSections(tester);
    });

    testWidgets('unauthorized users cannot collect/adjust or run payroll', (
      WidgetTester tester,
    ) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.hrRead},
        ),
        usersCanWrite: false,
        initialLocation: '/hr?section=staff&staff=STF-1',
      );

      expect(find.byType(ManageUsersPanel), findsOneWidget);
      expect(_searchAction('Create user'), findsNothing);
      expect(_searchAction('Add staff'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);

      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Run payroll'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Compensation'),
        ),
        findsNothing,
      );
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Write off'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('Create user primary is present without Billing chrome', (
      WidgetTester tester,
    ) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
      );

      expect(find.byType(ManageUsersPanel), findsOneWidget);
      expect(_searchAction('Create user'), findsOneWidget);
      expect(_searchAction('Add staff'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('compensation open does not introduce patient payment UX', (
      WidgetTester tester,
    ) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
          },
        ),
        initialLocation: '/hr?section=staff&staff=STF-1',
      );

      await tester.tap(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Compensation'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expectFlatSections(tester);
    });
  });

  group('HR Human resources section layout (AC5)', () {
    testWidgets('desktop staff list + detail: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
            AppPermissions.rosterWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
        initialLocation: '/hr?section=staff&staff=STF-1',
      );

      expect(find.byType(ManageUsersPanel), findsOneWidget);
      expectFlatSections(tester);
      expect(find.text('Assignments'), findsWidgets);
      expect(find.text('Compensation'), findsWidgets);
      expectFlatSections(tester);
    });

    testWidgets('mobile staff: flat sections', (WidgetTester tester) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
        physicalSize: const Size(390, 844),
        initialLocation: '/hr?section=staff&staff=STF-1',
      );
      expectFlatSections(tester);
      expect(find.byType(ManageUsersPanel), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
        themeMode: ThemeMode.light,
        initialLocation: '/hr?section=staff&staff=STF-1',
      );
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
        themeMode: ThemeMode.dark,
        initialLocation: '/hr?section=staff&staff=STF-1',
      );
      expectFlatSections(tester);
    });
  });

  group('HR Human resources sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.hrRead},
        ),
        usersCanWrite: false,
        users: const <AccessAdminItem>[],
        staff: const <HrStaffProfile>[],
      );

      expect(find.byType(ManageUsersPanel), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpStaffTab(
        tester,
        repository: repository,
        accessRepository: accessRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.hrRead},
        ),
        usersCanWrite: false,
        overviewOverride: const Result<HrWorkspaceOverview>.failure(
          AppFailure.network(),
        ),
        failStaffList: true,
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    test('inventory reuses shared permissions + financial vocabulary', () {
      expect(
        HrHumanResourcesBillingInventory.atoms.any(
          (HrHumanResourcesFinancialAtom atom) =>
              atom.financialClass ==
              HrHumanResourcesFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        identical(
          HrHumanResourcesAtomPermissions.tab,
          hrReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrHumanResourcesAtomPermissions.compensation,
          hrWriteRequirement,
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
    });
  });
}
