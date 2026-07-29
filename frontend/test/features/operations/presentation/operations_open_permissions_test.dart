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
import 'package:hosspi_hms/features/operations/data/repositories/operations_repository_impl.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/features/operations/domain/repositories/operations_repository.dart';
import 'package:hosspi_hms/features/operations/presentation/operations_access.dart';
import 'package:hosspi_hms/features/operations/presentation/pages/operations_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOperationsRepository extends Mock implements OperationsRepository {}

const OperationsWorkItem _openRequest = OperationsWorkItem(
  id: 'MR-OPEN',
  displayId: 'MR-OPEN',
  status: 'OPEN',
  assetLabel: 'Generator',
  metadata: OperationsRequestMetadata(
    issue: 'Generator alarm',
    priority: 'HIGH',
    category: 'POWER_BACKUP',
  ),
);

const OperationsAsset _generatorAsset = OperationsAsset(
  id: 'AS-001',
  name: 'Backup Generator',
  assetTag: 'GEN-01',
  status: 'OPEN',
  facilityLabel: 'Main Campus',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<String> roles = const <String>['VIEWER'],
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: operationsFacilitiesMaintenanceModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
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

void _stubRepository(
  _MockOperationsRepository repository, {
  List<OperationsWorkItem> requests = const <OperationsWorkItem>[_openRequest],
  List<OperationsAsset> assets = const <OperationsAsset>[_generatorAsset],
  Result<AppPage<OperationsWorkItem>>? listOverride,
}) {
  when(() => repository.listRequests(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (listOverride != null) {
      return listOverride;
    }
    final OperationsWorkItemQuery query =
        invocation.positionalArguments.single as OperationsWorkItemQuery;
    List<OperationsWorkItem> items = requests;
    final String? status = query.status?.trim().toUpperCase();
    if (status != null && status.isNotEmpty) {
      items = requests
          .where((OperationsWorkItem item) => item.normalizedStatus == status)
          .toList(growable: false);
    }
    return Result<AppPage<OperationsWorkItem>>.success(
      AppPage<OperationsWorkItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.listAssets(any())).thenAnswer(
    (_) async => Result<AppPage<OperationsAsset>>.success(
      AppPage<OperationsAsset>(
        items: assets,
        request: const AppPageRequest(),
        totalItemCount: assets.length,
      ),
    ),
  );
  when(() => repository.listServiceLogs(any())).thenAnswer(
    (_) async => const Result<AppPage<OperationsServiceLog>>.success(
      AppPage<OperationsServiceLog>(
        items: <OperationsServiceLog>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(() => repository.getRequest(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.first as String;
    final OperationsWorkItem item = requests.firstWhere(
      (OperationsWorkItem request) =>
          request.id == id || request.displayId == id,
      orElse: () => requests.first,
    );
    return Result<OperationsWorkItem>.success(item);
  });
}

Future<void> _pumpOpenTab(
  WidgetTester tester, {
  required _MockOperationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<OperationsWorkItem> requests = const <OperationsWorkItem>[_openRequest],
  Result<AppPage<OperationsWorkItem>>? listOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    requests: requests,
    listOverride: listOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/operations?section=open',
    routes: <RouteBase>[
      GoRoute(
        path: '/operations',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: OperationsWorkspacePage(
              initialQuery: OperationsWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        operationsRepositoryProvider.overrideWithValue(repository),
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

Finder _tabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.textContaining(label),
  );
}

void main() {
  late _MockOperationsRepository repository;

  setUpAll(() {
    registerFallbackValue(const OperationsWorkItemQuery());
    registerFallbackValue(const OperationsAssetQuery());
    registerFallbackValue(const OperationsServiceLogQuery());
    registerFallbackValue(_openRequest);
    registerFallbackValue(
      const OperationsRequestDraft(
        category: 'OTHER',
        priority: 'NORMAL',
        issue: 'Test',
      ),
    );
    registerFallbackValue(
      const OperationsTriageDraft(assignedEngineer: 'Tech'),
    );
    registerFallbackValue(
      const OperationsStatusUpdateDraft(status: 'IN_PROGRESS'),
    );
    registerFallbackValue(
      const OperationsRequestNoteDraft(kind: 'CLOSEOUT', note: 'Done'),
    );
  });

  setUp(() {
    repository = _MockOperationsRepository();
  });

  test('reuses feature *Requirement helpers (no second vocabulary)', () {
    expect(
      identical(
        OperationsOpenAtomPermissions.tab,
        operationsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsOpenAtomPermissions.write,
        operationsWorkspaceWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsOpenAtomPermissions.createRequest,
        operationsWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsOpenAtomPermissions.assign,
        operationsMutationRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsOpenAtomPermissions.nextAction,
        operationsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsOpenAtomPermissions.mutate,
        operationsMutationRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsOpenAtomPermissions.report,
        operationsWorkspaceReportRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsOpenAtomPermissions.routeEntry,
        RouteAccessCatalog.operationsEntry,
      ),
      isTrue,
    );
    // Report matrix read ∩ narrows inventory "Always" — same as read helper.
    expect(
      identical(
        operationsWorkspaceReportRequirement,
        operationsWorkspaceReadRequirement,
      ),
      isTrue,
    );
  });

  test('atom map covers inventory verbs (AC1)', () {
    expect(OperationsOpenAtomPermissions.tab, isNotNull);
    expect(OperationsOpenAtomPermissions.listChrome, isNotNull);
    expect(OperationsOpenAtomPermissions.search, isNotNull);
    expect(OperationsOpenAtomPermissions.filters, isNotNull);
    expect(OperationsOpenAtomPermissions.settings, isNotNull);
    expect(OperationsOpenAtomPermissions.empty, isNotNull);
    expect(OperationsOpenAtomPermissions.loading, isNotNull);
    expect(OperationsOpenAtomPermissions.retry, isNotNull);
    expect(OperationsOpenAtomPermissions.success, isNotNull);
    expect(OperationsOpenAtomPermissions.validation, isNotNull);
    expect(OperationsOpenAtomPermissions.rowSelect, isNotNull);
    expect(OperationsOpenAtomPermissions.detail, isNotNull);
    expect(OperationsOpenAtomPermissions.nextAction, isNotNull);
    expect(OperationsOpenAtomPermissions.create, isNotNull);
    expect(OperationsOpenAtomPermissions.update, isNotNull);
    expect(OperationsOpenAtomPermissions.delete, isNotNull);
    expect(OperationsOpenAtomPermissions.assign, isNotNull);
    expect(OperationsOpenAtomPermissions.updateStatus, isNotNull);
    expect(OperationsOpenAtomPermissions.serviceLog, isNotNull);
    expect(OperationsOpenAtomPermissions.note, isNotNull);
    expect(OperationsOpenAtomPermissions.closeout, isNotNull);
    expect(OperationsOpenAtomPermissions.report, isNotNull);
    expect(OperationsOpenAtomPermissions.nestedWrite, isNotNull);
    expect(OperationsOpenAtomPermissions.nestedRead, isNotNull);
    expect(OperationsOpenAtomPermissions.routeEntry, isNotNull);
    expect(
      OperationsOpenAtomPermissions.tab.allPermissions,
      contains(AppPermissions.operationsRead),
    );
    expect(
      OperationsOpenAtomPermissions.create.allPermissions,
      contains(AppPermissions.operationsWrite),
    );
    expect(
      OperationsOpenAtomPermissions.routeEntry.anyPermissions,
      containsAll(<AppPermission>[
        AppPermissions.operationsRead,
        AppPermissions.operationsWrite,
      ]),
    );
  });

  testWidgets(
    'read ∩ denial of write: list/Report visible; Create / Assign / detail writes absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(OperationsOpenAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(OperationsOpenAtomPermissions.nextAction.isAllowed(reader), isTrue);
      expect(OperationsOpenAtomPermissions.write.isAllowed(reader), isFalse);
      expect(OperationsOpenAtomPermissions.assign.isAllowed(reader), isFalse);
      expect(OperationsOpenAtomPermissions.report.isAllowed(reader), isTrue);

      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Generator alarm'), findsOneWidget);
      expect(_tabLabel('Open'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Assign technician or team'), findsNothing);
      expect(find.text('Review request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Generator alarm'));
      await tester.pumpAndSettle();

      expect(find.text('REQUEST DETAIL'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Assign'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Update status'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Create, Assign next-action, complementary detail writes mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        roles: const <String>['OPERATIONS'],
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(OperationsOpenAtomPermissions.write.isAllowed(writer), isTrue);
      expect(OperationsOpenAtomPermissions.assign.isAllowed(writer), isTrue);

      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Generator alarm'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Assign technician or team'), findsOneWidget);

      await tester.tap(find.text('Generator alarm'));
      await tester.pumpAndSettle();

      // Assign is the row next-action — omitted from complementary detail.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Assign'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Update status'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:write alone without operations:read omits Open chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );
      expect(
        OperationsOpenAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(OperationsOpenAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(OperationsOpenAtomPermissions.report.isAllowed(writeOnly), isFalse);
      // Matrix create ∩ write alone — create helper allows write; chrome
      // collapses because tab read ∩ fails.
      expect(OperationsOpenAtomPermissions.create.isAllowed(writeOnly), isTrue);

      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Generator alarm'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:read alone satisfies entry and Open chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy readOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        OperationsOpenAtomPermissions.routeEntry.isAllowed(readOnly),
        isTrue,
      );
      expect(OperationsOpenAtomPermissions.tab.isAllowed(readOnly), isTrue);

      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: readOnly,
      );

      expect(find.text('Generator alarm'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
    },
  );

  testWidgets(
    'subscription strip: facilities-maintenance missing omits Open chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(OperationsOpenAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(OperationsOpenAtomPermissions.write.isAllowed(noModule), isFalse);

      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Generator alarm'), findsNothing);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC facility strip: missing facility context fails route entry ∪',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
        facilityId: null,
      );
      expect(OperationsOpenAtomPermissions.tab.isAllowed(noFacility), isTrue);
      expect(
        OperationsOpenAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
      expect(canEnterOperationsWorkspace(noFacility), isFalse);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: no extra nested module chrome on Open',
    (WidgetTester tester) async {
      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.text('Generator alarm'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Billing'), findsNothing);
      expect(find.textContaining('Clinical'), findsNothing);
      expect(find.text('Service logs'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Update status'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'authorized Create opens dialog; validation keeps it open',
    (WidgetTester tester) async {
      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.textContaining('Create request'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Create request'), findsWidgets);

      await tester.tap(find.text('Create request').last);
      await tester.pumpAndSettle();

      verifyNever(() => repository.createRequest(any()));
    },
  );

  testWidgets(
    'authorized Assign next-action opens dialog and mutation syncs list',
    (WidgetTester tester) async {
      const OperationsWorkItem assigned = OperationsWorkItem(
        id: 'MR-OPEN',
        displayId: 'MR-OPEN',
        status: 'IN_PROGRESS',
        assetLabel: 'Generator',
        metadata: OperationsRequestMetadata(
          issue: 'Generator alarm',
          priority: 'HIGH',
          category: 'POWER_BACKUP',
          assignee: 'Tech A',
        ),
      );
      when(() => repository.triageRequest(any(), any())).thenAnswer(
        (_) async => const Result<OperationsWorkItem>.success(assigned),
      );

      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Assign technician or team'));
      await tester.pumpAndSettle();

      expect(find.text('Save assignment'), findsOneWidget);
      expect(find.text('REQUEST DETAIL'), findsNothing);

      await tester.tap(find.text('Save assignment'));
      await tester.pumpAndSettle();

      verify(() => repository.triageRequest(any(), any())).called(1);
      expect(find.text('Operations changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'empty authorized Open queue still shows Create when allowed',
    (WidgetTester tester) async {
      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        requests: const <OperationsWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('No maintenance requests'), findsOneWidget);
    },
  );

  testWidgets(
    'error/retry surface remains for authorized Open users',
    (WidgetTester tester) async {
      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        listOverride: const Result<AppPage<OperationsWorkItem>>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(AppFailureStateView), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized loading then success on Open', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.listRequests(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Result<AppPage<OperationsWorkItem>>.success(
        AppPage<OperationsWorkItem>(
          items: const <OperationsWorkItem>[_openRequest],
          request: const AppPageRequest(),
          totalItemCount: 1,
        ),
      );
    });
    when(() => repository.listAssets(any())).thenAnswer(
      (_) async => Result<AppPage<OperationsAsset>>.success(
        AppPage<OperationsAsset>(
          items: const <OperationsAsset>[_generatorAsset],
          request: const AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
    );
    when(() => repository.listServiceLogs(any())).thenAnswer(
      (_) async => const Result<AppPage<OperationsServiceLog>>.success(
        AppPage<OperationsServiceLog>(
          items: <OperationsServiceLog>[],
          request: AppPageRequest(),
        ),
      ),
    );

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/operations?section=open',
      routes: <RouteBase>[
        GoRoute(
          path: '/operations',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: OperationsWorkspacePage(
                initialQuery: OperationsWorkspaceQuery.fromUri(state.uri),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          operationsRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.operationsRead,
                AppPermissions.operationsWrite,
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
    expect(find.textContaining('Loading'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('Generator alarm'), findsOneWidget);
  });

  testWidgets(
    'Open advanced filters omit status (tab owns status)',
    (WidgetTester tester) async {
      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        physicalSize: const Size(1440, 900),
      );

      final AppListTable<OperationsWorkItem> table = tester
          .widget<AppListTable<OperationsWorkItem>>(
            find.byType(AppListTable<OperationsWorkItem>),
          );
      expect(
        table.search!.filterGroups.any(
          (AppSearchBarFilterGroup group) => group.key == 'status',
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'mobile viewport: Assign next-action and row select remain reachable',
    (WidgetTester tester) async {
      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        physicalSize: const Size(390, 844),
      );

      expect(find.byType(AppListTableMobileItem), findsWidgets);
      expect(find.textContaining('Generator alarm'), findsOneWidget);
      expect(find.byTooltip('Assign technician or team'), findsOneWidget);
      expect(_tabLabel('Open'), findsOneWidget);

      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expect(find.byTooltip('Assign technician or team'), findsNothing);
      expect(find.text('Review request'), findsNothing);
    },
  );

  testWidgets(
    'dark theme: authorized Open chrome still mounts',
    (WidgetTester tester) async {
      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        themeMode: ThemeMode.dark,
      );

      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Generator alarm'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'Report summary (read ∩) opens metrics-only dialog',
    (WidgetTester tester) async {
      await _pumpOpenTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
      );

      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      expect(find.textContaining('All requests'), findsWidgets);
      expect(find.text('Preview'), findsNothing);
    },
  );

  test(
    'section tab gate: Open uses Open atom tab requirement',
    () {
      expect(
        identical(
          operationsSectionTabRequirement(OperationsDeskSection.open),
          OperationsOpenAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        canViewOperationsSection(
          _policy(permissions: <AppPermission>{AppPermissions.operationsRead}),
          OperationsDeskSection.open,
        ),
        isTrue,
      );
    },
  );
}
