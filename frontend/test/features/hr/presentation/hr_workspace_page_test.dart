import 'dart:io';

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
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
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

AccessAdminWorkspaceData _usersData({bool canWrite = true}) {
  return AccessAdminWorkspaceData(
    permissions: AccessAdminWorkspacePermissions(
      canRead: true,
      canWrite: canWrite,
    ),
    lookups: const AccessAdminLookups(
      userStatuses: <String>['ACTIVE', 'INACTIVE'],
    ),
    items: const <AccessAdminItem>[_user],
    page: const AppPage<AccessAdminItem>(
      items: <AccessAdminItem>[_user],
      request: AppPageRequest(pageSize: 25),
      totalItemCount: 1,
    ),
    query: const AccessAdminWorkspaceQuery(
      resource: AccessAdminResource.users,
      includeDeleted: true,
      lean: true,
    ),
  );
}

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

void _stubHrWorkspace(_MockHrRepository repository) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async => const Result<HrWorkspaceOverview>.success(
      HrWorkspaceOverview(
        summary: HrWorkspaceSummary(leaveRequests: 1),
      ),
    ),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[],
        request: AppPageRequest(),
        totalItemCount: 0,
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
    final List<HrWorkItem> items = <HrWorkItem>[_leaveItem]
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
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => Result<AccessAdminWorkspaceData>.success(
      _usersData(canWrite: canWrite),
    ),
  );
}

Future<void> _pumpHrWorkspace(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required _MockAccessAdminRepository accessRepository,
  HrWorkspaceQuery? initialQuery,
  String initialLocation = '/hr',
  AppAccessPolicy? accessPolicy,
  bool usersCanWrite = true,
  Size physicalSize = const Size(1440, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubUsersWorkspace(accessRepository, canWrite: usersCanWrite);

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
        accessAdminRepositoryProvider.overrideWithValue(accessRepository),
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
  late _MockAccessAdminRepository accessRepository;

  setUpAll(() {
    registerFallbackValue(const HrStaffQuery());
    registerFallbackValue(const HrWorkItemsQuery());
    registerFallbackValue(const HrAccessQuery());
    registerFallbackValue(const HrStaffProfile(id: 'fallback'));
    registerFallbackValue(const AccessAdminWorkspaceQuery());
  });

  setUp(() {
    repository = _MockHrRepository();
    accessRepository = _MockAccessAdminRepository();
  });

  testWidgets('Human resources hosts ManageUsersPanel Users CRUD', (
    WidgetTester tester,
  ) async {
    _stubHrWorkspace(repository);
    await _pumpHrWorkspace(
      tester,
      repository: repository,
      accessRepository: accessRepository,
    );

    expect(find.byType(ManageUsersPanel), findsOneWidget);
    expect(_searchAction('Create user'), findsOneWidget);
    expect(find.text('Ada User'), findsOneWidget);
    expect(_tabToolbarRefresh(), findsNothing);
    expect(find.byTooltip('HR activity'), findsNothing);

    await _selectTab(tester, 'Leave requests');
    expect(_searchAction('Request leave'), findsOneWidget);
    expect(find.byType(ManageUsersPanel), findsNothing);

    await _selectTab(tester, 'Swap requests');
    expect(_searchAction('Request leave'), findsNothing);
    expect(_searchAction('Create roster template'), findsNothing);

    await _selectTab(tester, 'Rosters');
    expect(_searchAction('Create roster template'), findsOneWidget);

    await _selectTab(tester, 'Unassigned shifts');
    expect(_searchAction('Create roster template'), findsNothing);

    await _selectTab(tester, 'Payroll drafts');
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
  });

  testWidgets('read-only HR hides Create user on ManageUsersPanel', (
    WidgetTester tester,
  ) async {
    _stubHrWorkspace(repository);
    await _pumpHrWorkspace(
      tester,
      repository: repository,
      accessRepository: accessRepository,
      accessPolicy: _hrReadOnlyPolicy(),
      usersCanWrite: false,
    );

    expect(find.byType(ManageUsersPanel), findsOneWidget);
    expect(_searchAction('Create user'), findsNothing);
    expect(find.text('Ada User'), findsOneWidget);
  });

  testWidgets('leave next-action opens approve surface without Quick actions', (
    WidgetTester tester,
  ) async {
    _stubHrWorkspace(repository);
    await _pumpHrWorkspace(
      tester,
      repository: repository,
      accessRepository: accessRepository,
      initialQuery: const HrWorkspaceQuery(section: 'leave-requests'),
      initialLocation: '/hr?section=leave-requests',
    );

    expect(find.text('Approve leave'), findsOneWidget);
    await tester.tap(find.text('Approve leave'));
    await tester.pumpAndSettle();

    expect(find.text('Approve leave'), findsWidgets);
    expect(find.text('Quick actions'), findsNothing);
  });

  test('Human resources tab embeds ManageUsersPanel Users CRUD', () {
    final String source = File(
      'lib/features/hr/presentation/pages/hr_workspace_page.dart',
    ).readAsStringSync();
    expect(
      source.contains('HrDeskSection.staffDirectory => ManageUsersPanel('),
      isTrue,
    );
    expect(source.contains('class _HrStaffDirectory'), isFalse);
    expect(
      RegExp(
        r'onPressed: state\.isRefreshing\s*\?\s*null\s*:\s*\(\)\s*=>\s*'
        r'showHrStaffOnboardingDialog\(context,\s*ref\)',
      ).hasMatch(source),
      isFalse,
    );
  });
}
