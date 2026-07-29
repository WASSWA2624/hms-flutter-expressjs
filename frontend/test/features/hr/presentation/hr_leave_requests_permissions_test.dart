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
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore_for_file: avoid_redundant_argument_values

class _MockHrRepository extends Mock implements HrRepository {}

const String _tenantUuid = '550e8400-e29b-41d4-a716-446655440000';

const HrWorkItem _leaveItem = HrWorkItem(
  id: 'leave-1',
  displayId: 'LV-1',
  queue: HrQueue.leaveRequests,
  status: 'REQUESTED',
  staffName: 'Ada Leave',
  staffNumber: 'EMP-1',
  leaveType: 'ANNUAL',
);

Finder _toolbarPrimary(String label) => find.descendant(
  of: find.byType(AppTabToolbarPrimary),
  matching: find.text(label),
);

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
  List<HrWorkItem> workItems = const <HrWorkItem>[_leaveItem],
  Result<HrWorkspaceOverview>? overviewOverride,
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async =>
        overviewOverride ??
        const Result<HrWorkspaceOverview>.success(
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

Future<void> _pumpLeaveTab(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HrWorkItem> workItems = const <HrWorkItem>[_leaveItem],
  Result<HrWorkspaceOverview>? overviewOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    workItems: workItems,
    overviewOverride: overviewOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/hr?section=leave-requests',
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
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockHrRepository();
  });

  group('HrLeaveRequestsAtomPermissions helpers', () {
    test('reuses hr read/write requirements (no second vocabulary)', () {
      expect(
        identical(
          HrLeaveRequestsAtomPermissions.tab,
          hrWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(HrLeaveRequestsAtomPermissions.tab, hrReadRequirement),
        isTrue,
      );
      expect(
        identical(
          HrLeaveRequestsAtomPermissions.requestLeave,
          hrWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrLeaveRequestsAtomPermissions.approveLeave,
          hrWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrLeaveRequestsAtomPermissions.rejectLeave,
          hrWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrLeaveRequestsAtomPermissions.routeEntry,
          hrWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrLeaveRequestsAtomPermissions.routeEntry,
          RouteAccessCatalog.hrEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          hrSectionRequirement(HrDeskSection.leaveRequests),
          HrLeaveRequestsAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing hr:read hides Leave requests tab requirement', () {
      final AppAccessPolicy none = _policy(permissions: <AppPermission>{});
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.hrWrite},
      );
      expect(HrLeaveRequestsAtomPermissions.tab.isAllowed(none), isFalse);
      expect(HrLeaveRequestsAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canReadHr(writeOnly), isFalse);
      expect(
        canViewHrSection(writeOnly, HrDeskSection.leaveRequests),
        isFalse,
      );
    });

    test('∩ presence: hr:read + module allows Leave requests read atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );
      expect(HrLeaveRequestsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(HrLeaveRequestsAtomPermissions.search.isAllowed(reader), isTrue);
      expect(HrLeaveRequestsAtomPermissions.loading.isAllowed(reader), isTrue);
      expect(HrLeaveRequestsAtomPermissions.empty.isAllowed(reader), isTrue);
      expect(HrLeaveRequestsAtomPermissions.detail.isAllowed(reader), isTrue);
      expect(HrLeaveRequestsAtomPermissions.activity.isAllowed(reader), isTrue);
      expect(HrLeaveRequestsAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        HrLeaveRequestsAtomPermissions.requestLeave.isAllowed(reader),
        isFalse,
      );
      expect(
        HrLeaveRequestsAtomPermissions.approveLeave.isAllowed(reader),
        isFalse,
      );
      expect(
        HrLeaveRequestsAtomPermissions.success.isAllowed(reader),
        isFalse,
      );
    });

    test(
      'route entry: prompt ∪ read|write → keep catalog ∩ hr:read (noted)',
      () {
        final AppAccessPolicy writeOnly = _policy(
          permissions: <AppPermission>{AppPermissions.hrWrite},
        );
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.hrRead},
        );
        expect(
          HrLeaveRequestsAtomPermissions.routeEntry.isAllowed(writeOnly),
          isFalse,
        );
        expect(
          HrLeaveRequestsAtomPermissions.routeEntry.isAllowed(reader),
          isTrue,
        );
        expect(
          identical(
            HrLeaveRequestsAtomPermissions.routeEntry,
            RouteAccessCatalog.hrEntry,
          ),
          isTrue,
        );
        expect(
          HrLeaveRequestsAtomPermissions.routeEntry.allPermissions,
          contains(AppPermissions.hrRead),
        );
      },
    );

    test(
      '∪ allowance: roster:approve alone satisfies shared roster approve helper',
      () {
        // Leave matrix nested ∪ rows are _(n/a)_. Shared ∪ vocabulary for
        // sibling Shifts/swap queues: hr:write | roster:approve.
        final AppAccessPolicy rosterApprover = _policy(
          permissions: <AppPermission>{AppPermissions.rosterApprove},
        );
        expect(hrRosterApproveRequirement.isAllowed(rosterApprover), isTrue);
        expect(
          hrRosterNestedWriteRequirement.isAllowed(rosterApprover),
          isTrue,
        );
        expect(
          HrLeaveRequestsAtomPermissions.approve.isAllowed(rosterApprover),
          isFalse,
        );
        expect(
          HrLeaveRequestsAtomPermissions.nestedWrite.anyPermissions,
          isEmpty,
        );
      },
    );
  });

  testWidgets(
    'read-only ∩ denial: Leave list visible; Request / Approve / Reject absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );
      expect(HrLeaveRequestsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(HrLeaveRequestsAtomPermissions.write.isAllowed(reader), isFalse);

      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Leave requests'), findsOneWidget);
      expect(find.text('Ada Leave'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(_toolbarPrimary('Request leave'), findsNothing);
      expect(find.text('Approve leave'), findsNothing);
      expect(find.text('Reject leave'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Ada Leave'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Approve leave'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Reject leave'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Request leave, Approve next-action, detail Reject mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
      );
      expect(HrLeaveRequestsAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        HrLeaveRequestsAtomPermissions.requestLeave.isAllowed(writer),
        isTrue,
      );

      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(_toolbarPrimary('Request leave'), findsOneWidget);
      expect(find.text('Approve leave'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Ada Leave'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Approve leave'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Reject leave'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write-only ∩ denial: catalog entry fails; Leave chrome omitted',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.hrWrite},
      );
      expect(
        HrLeaveRequestsAtomPermissions.routeEntry.isAllowed(writeOnly),
        isFalse,
      );
      expect(HrLeaveRequestsAtomPermissions.tab.isAllowed(writeOnly), isFalse);

      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(_toolbarPrimary('Request leave'), findsNothing);
      expect(find.text('Ada Leave'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: missing hr-rosters module denies Leave atoms',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(HrLeaveRequestsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(HrLeaveRequestsAtomPermissions.write.isAllowed(noModule), isFalse);
      expect(canEnterHrWorkspace(noModule), isFalse);

      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(_toolbarPrimary('Request leave'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC facility strip: missing facility fails route entry; in-page read ok',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
        facilityId: null,
      );
      expect(HrLeaveRequestsAtomPermissions.tab.isAllowed(noFacility), isTrue);
      expect(
        HrLeaveRequestsAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
      expect(canEnterHrWorkspace(noFacility), isFalse);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: no cross-module nested write on Leave',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
      );

      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.text('Ada Leave'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Billing'), findsNothing);
      expect(find.textContaining('Clinical'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Request leave opens dialog with validation chrome',
    (WidgetTester tester) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
      );

      await tester.tap(_toolbarPrimary('Request leave'));
      await tester.pumpAndSettle();

      expect(find.text('Request leave'), findsWidgets);
      expect(find.textContaining('Leave type'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Approve next-action mutates, syncs queue, shows success',
    (WidgetTester tester) async {
      when(
        () => repository.approveLeave(any(), reason: any(named: 'reason')),
      ).thenAnswer((_) async => const Result<Object?>.success(null));

      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
      );

      expect(find.text('Approve leave'), findsOneWidget);
      await tester.tap(find.text('Approve leave'));
      await tester.pumpAndSettle();

      // Nested approve dialog (not Quick actions detail shell).
      expect(find.text('Quick actions'), findsNothing);
      expect(find.text('Approve leave'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Approve leave'),
        ).last,
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.approveLeave(any(), reason: any(named: 'reason')),
      ).called(1);
      verify(() => repository.listWorkItems(any())).called(greaterThan(1));
      expect(find.text('HR changes saved.'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized empty Leave queue shows empty state (no no-access banner)',
    (WidgetTester tester) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.hrRead},
        ),
        workItems: const <HrWorkItem>[],
      );

      expect(find.textContaining('No'), findsWidgets);
      expect(_toolbarPrimary('Request leave'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Leave',
    (WidgetTester tester) async {
      when(() => repository.loadOverview()).thenAnswer(
        (_) async => const Result<HrWorkspaceOverview>.failure(
          AppFailure.network(),
        ),
      );
      when(() => repository.listStaffProfiles(any())).thenAnswer(
        (_) async => const Result<AppPage<HrStaffProfile>>.failure(
          AppFailure.network(),
        ),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/hr?section=leave-requests',
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
            appAccessPolicyProvider.overrideWithValue(
              _policy(
                permissions: <AppPermission>{
                  AppPermissions.hrRead,
                  AppPermissions.hrWrite,
                },
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'Leave requests chrome works on mobile viewport (light)',
    (WidgetTester tester) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
        physicalSize: const Size(390, 844),
      );

      expect(_tab('Leave requests'), findsOneWidget);
      expect(find.byType(AppListTable<HrWorkItem>), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Leave requests chrome works on desktop viewport (dark)',
    (WidgetTester tester) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
        physicalSize: const Size(1440, 900),
        themeMode: ThemeMode.dark,
      );

      expect(_tab('Leave requests'), findsOneWidget);
      expect(_toolbarPrimary('Request leave'), findsOneWidget);
      expect(find.text('Ada Leave'), findsOneWidget);
      expect(find.text('Approve leave'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
