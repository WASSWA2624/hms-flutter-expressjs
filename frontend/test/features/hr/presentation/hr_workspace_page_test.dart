import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHrRepository extends Mock implements HrRepository {}

const String _tenantUuid = '550e8400-e29b-41d4-a716-446655440000';

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
);

const HrWorkItem _leaveItem = HrWorkItem(
  id: 'leave-1',
  displayId: 'LV-1',
  queue: HrQueue.leaveRequests,
  status: 'REQUESTED',
  staffName: 'Ada Needs Dept',
  staffNumber: 'EMP-1',
  leaveType: 'ANNUAL',
);

Finder _searchAction(String label) => find.byTooltip(label);

Finder _tabToolbarRefresh() => find.descendant(
  of: find.byType(AppTabStrip),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        (widget is AppTabToolbarAction && widget.label == 'Refresh') ||
        (widget is AppTabToolbarPrimary && widget.label == 'Refresh'),
  ),
);

AppAccessPolicy _hrWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['HR'],
        tenantId: _tenantUuid,
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.rosterWrite,
        AppPermissions.rosterApprove,
        AppPermissions.rosterPublish,
        AppPermissions.financialApprove,
        AppPermissions.tenantAdmin,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _hrReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['HR'],
        tenantId: _tenantUuid,
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{AppPermissions.hrRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockHrRepository repository, {
  List<HrStaffProfile> staff = const <HrStaffProfile>[_staffNeedsDepartment],
  List<HrWorkItem> workItems = const <HrWorkItem>[_leaveItem],
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async => const Result<HrWorkspaceOverview>.success(
      HrWorkspaceOverview(
        summary: HrWorkspaceSummary(leaveRequests: 1),
      ),
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
  when(() => repository.loadStaffDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final HrStaffProfile profile =
        invocation.positionalArguments.single as HrStaffProfile;
    return Result<HrStaffDetail>.success(HrStaffDetail(profile: profile));
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

Future<void> _pumpHrWorkspace(
  WidgetTester tester, {
  required _MockHrRepository repository,
  HrWorkspaceQuery? initialQuery,
  String initialLocation = '/hr',
  AppAccessPolicy? accessPolicy,
  Size physicalSize = const Size(1440, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

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
              initialQuery:
                  initialQuery ?? HrWorkspaceQuery.fromUri(state.uri),
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
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _hrWritePolicy(),
        ),
      ],
      child: MaterialApp.router(
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

Future<void> _selectTab(WidgetTester tester, String label) async {
  final Finder bySemantics = find.bySemanticsLabel(RegExp(label));
  if (bySemantics.evaluate().isNotEmpty) {
    await tester.tap(bySemantics.first);
    await tester.pumpAndSettle();
    return;
  }

  final Finder visible = find.textContaining(label);
  if (visible.evaluate().isNotEmpty) {
    await tester.tap(visible.first);
    await tester.pumpAndSettle();
    return;
  }

  final Finder more = find.byKey(const ValueKey<String>('tabOverflowMore'));
  expect(more, findsOneWidget);
  await tester.tap(more);
  await tester.pumpAndSettle();
  final Finder overflow = find.textContaining(label);
  expect(overflow, findsWidgets);
  await tester.tap(overflow.last);
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

  testWidgets('moves section actions to search bar and drops HR activity', (
    WidgetTester tester,
  ) async {
    _stubWorkspace(repository);
    await _pumpHrWorkspace(tester, repository: repository);

    expect(_searchAction('Add staff'), findsOneWidget);
    expect(_tabToolbarRefresh(), findsNothing);
    expect(find.byTooltip('HR activity'), findsNothing);
    expect(find.text('Request maintenance'), findsNothing);
    expect(find.text('Report equipment fault'), findsNothing);

    await _selectTab(tester, 'Leave requests');
    expect(_searchAction('Request leave'), findsOneWidget);
    expect(_searchAction('Run payroll'), findsNothing);

    await _selectTab(tester, 'Swap requests');
    expect(_searchAction('Request leave'), findsNothing);
    expect(_searchAction('Schedule templates'), findsNothing);

    await _selectTab(tester, 'Roster drafts');
    expect(_searchAction('Schedule templates'), findsOneWidget);

    await _selectTab(tester, 'Unassigned shifts');
    expect(_searchAction('Schedule templates'), findsNothing);

    await _selectTab(tester, 'Payroll drafts');
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(_searchAction('Run payroll'), findsNothing);

    await _selectTab(tester, 'Manage users and roles');
    expect(_searchAction('Manage users and roles'), findsNothing);
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(find.text('Create staff'), findsOneWidget);
  });

  testWidgets('queue deep-link prefers owning primary over conflicting section', (
    WidgetTester tester,
  ) async {
    _stubWorkspace(repository);
    await _pumpHrWorkspace(
      tester,
      repository: repository,
      initialQuery: const HrWorkspaceQuery(
        section: 'shifts',
        queue: HrQueue.swapRequests,
      ),
      initialLocation: '/hr?section=shifts&queue=SWAP_REQUESTS',
    );

    // Swap → Swap requests primary; Leave/Shifts trailing actions absent.
    expect(_searchAction('Schedule templates'), findsNothing);
    expect(_searchAction('Request leave'), findsNothing);
  });

  testWidgets('hides unauthorized primary and next-action controls', (
    WidgetTester tester,
  ) async {
    _stubWorkspace(repository);
    await _pumpHrWorkspace(
      tester,
      repository: repository,
      accessPolicy: _hrReadOnlyPolicy(),
    );

    expect(_searchAction('Add staff'), findsNothing);
    expect(find.text('Assign department'), findsNothing);

    await _selectTab(tester, 'Leave requests');
    expect(_searchAction('Request leave'), findsNothing);
    expect(find.text('Approve leave'), findsNothing);
  });

  testWidgets('staff next-action opens assign department without detail shell', (
    WidgetTester tester,
  ) async {
    _stubWorkspace(repository);
    await _pumpHrWorkspace(tester, repository: repository);

    await tester.tap(find.text('Assign department'));
    await tester.pumpAndSettle();

    expect(find.text('Assign department'), findsWidgets);
    expect(find.text('Staff actions'), findsNothing);
    verify(() => repository.loadStaffDetail(any())).called(greaterThan(0));
  });

  testWidgets('work-queue next-action opens approve leave without detail shell', (
    WidgetTester tester,
  ) async {
    _stubWorkspace(repository);
    await _pumpHrWorkspace(
      tester,
      repository: repository,
      initialQuery: const HrWorkspaceQuery(section: 'leave-requests'),
      initialLocation: '/hr?section=leave-requests',
    );

    expect(find.text('Approve leave'), findsOneWidget);
    await tester.tap(find.text('Approve leave'));
    await tester.pumpAndSettle();

    expect(find.text('Approve leave'), findsWidgets);
    expect(find.text('Quick actions'), findsNothing);
  });

  testWidgets('row select still opens staff detail for review profile path', (
    WidgetTester tester,
  ) async {
    _stubWorkspace(
      repository,
      staff: const <HrStaffProfile>[_staffComplete],
    );
    await _pumpHrWorkspace(tester, repository: repository);

    await tester.tap(find.text('Review profile'));
    await tester.pumpAndSettle();

    expect(find.text('Staff actions'), findsOneWidget);
    expect(find.text('Assign department'), findsOneWidget);
    expect(find.text('Run payroll'), findsOneWidget);
  });
}
