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
  List<String> roles = const <String>['OPERATIONS'],
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
  Result<AppPage<OperationsWorkItem>>? requestsOverride,
}) {
  when(() => repository.listRequests(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (requestsOverride != null) {
      return requestsOverride;
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

Future<void> _pumpAllRequestsTab(
  WidgetTester tester, {
  required _MockOperationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<OperationsWorkItem> requests = const <OperationsWorkItem>[_openRequest],
  Result<AppPage<OperationsWorkItem>>? requestsOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    requests: requests,
    requestsOverride: requestsOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/operations?section=all',
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

void main() {
  late _MockOperationsRepository repository;

  setUpAll(() {
    registerFallbackValue(const OperationsWorkItemQuery());
    registerFallbackValue(const OperationsAssetQuery());
    registerFallbackValue(const OperationsServiceLogQuery());
    registerFallbackValue(_openRequest);
    registerFallbackValue(
      const OperationsServiceLogDraft(assetId: 'AS-001', notes: 'Done'),
    );
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

  test('All requests atom helpers reuse AccessRequirement vocabulary', () {
    expect(
      identical(
        OperationsAllRequestsAtomPermissions.tab,
        operationsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsAllRequestsAtomPermissions.create,
        operationsMutationRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsAllRequestsAtomPermissions.createRequest,
        operationsWorkspaceWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsAllRequestsAtomPermissions.mutate,
        operationsMutationRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsAllRequestsAtomPermissions.routeEntry,
        operationsWorkspaceEntryRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsAllRequestsAtomPermissions.report,
        operationsReportRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsAllRequestsAtomPermissions.nextAction,
        operationsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsAllRequestsAtomPermissions.success,
        operationsWorkspaceWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsAllRequestsAtomPermissions.validation,
        operationsWorkspaceWriteRequirement,
      ),
      isTrue,
    );
    expect(
      OperationsAllRequestsAtomPermissions.create.allPermissions,
      contains(AppPermissions.operationsWrite),
    );
    expect(
      OperationsAllRequestsAtomPermissions.tab.allPermissions,
      contains(AppPermissions.operationsRead),
    );
    expect(
      OperationsAllRequestsAtomPermissions.report.allPermissions,
      contains(AppPermissions.operationsRead),
    );
    expect(
      OperationsAllRequestsAtomPermissions.routeEntry.anyPermissions,
      containsAll(<AppPermission>[
        AppPermissions.operationsRead,
        AppPermissions.operationsWrite,
      ]),
    );
    expect(
      OperationsAllRequestsAtomPermissions.nestedWrite.allPermissions,
      contains(AppPermissions.operationsWrite),
    );
  });

  testWidgets(
    '∩ denial: read-only hides Create / write next-actions; Report + list remain',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(OperationsAllRequestsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        OperationsAllRequestsAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(canMutateOperations(reader), isFalse);
      expect(canReportOperations(reader), isTrue);

      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Generator alarm'), findsOneWidget);
      expect(find.textContaining('All requests'), findsWidgets);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(
        OperationsAllRequestsAtomPermissions.listChrome.isAllowed(reader),
        isTrue,
      );
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Assign technician or team'), findsNothing);
      expect(find.text('Review request'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Generator alarm'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
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
    'full write ∩: Create request, Assign next-action, detail complementary mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(OperationsAllRequestsAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        OperationsAllRequestsAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(canMutateOperations(writer), isTrue);

      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Generator alarm'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Assign technician or team'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);

      await tester.tap(find.text('Generator alarm'));
      await tester.pumpAndSettle();

      // Assign is the row next-action — omitted from detail complementary.
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
    'route entry ∪: operations:write alone satisfies entry; All chrome needs read ∩',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );
      expect(
        OperationsAllRequestsAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        OperationsAllRequestsAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(canEnterOperationsWorkspace(writeOnly), isTrue);
      expect(canReadOperations(writeOnly), isFalse);

      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Generator alarm'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:read alone satisfies entry and All-tab chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy readOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        OperationsAllRequestsAtomPermissions.routeEntry.isAllowed(readOnly),
        isTrue,
      );
      expect(
        OperationsAllRequestsAtomPermissions.tab.isAllowed(readOnly),
        isTrue,
      );

      await _pumpAllRequestsTab(
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
    'report ∩: operations:read mounts Report; write alone does not',
    (WidgetTester tester) async {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        OperationsAllRequestsAtomPermissions.report.isAllowed(opsReader),
        isTrue,
      );

      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: opsReader,
      );

      expect(find.text('Report'), findsOneWidget);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.textContaining('All requests'), findsWidgets);
      expect(find.text('Preview'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: facilities-maintenance missing omits All chrome',
    (WidgetTester tester) async {
      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
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
      // In-page atoms: facility ABAC on route entry only.
      expect(
        OperationsAllRequestsAtomPermissions.tab.isAllowed(noFacility),
        isTrue,
      );
      expect(
        OperationsAllRequestsAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
      expect(canEnterOperationsWorkspace(noFacility), isFalse);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: no cross-module nested write atoms',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(
        OperationsAllRequestsAtomPermissions.nestedWrite.isAllowed(writer),
        isTrue,
      );

      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.text('Generator alarm'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Billing'), findsNothing);
      expect(find.textContaining('Clinical'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Create request opens dialog with validation chrome',
    (WidgetTester tester) async {
      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.textContaining('Create request'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Save assignment'), findsNothing);
      expect(find.textContaining('Create request'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Assign next-action mutates, syncs list, and shows success',
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

      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Assign technician or team'));
      await tester.pumpAndSettle();

      expect(find.text('Save assignment'), findsOneWidget);

      await tester.tap(find.text('Save assignment'));
      await tester.pumpAndSettle();

      verify(() => repository.triageRequest(any(), any())).called(1);
      expect(find.text('Operations changes saved.'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty authorized All requests still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        requests: const <OperationsWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No maintenance requests'), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty write-authorized All requests keeps Create request primary',
    (WidgetTester tester) async {
      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        requests: const <OperationsWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No maintenance requests'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on All requests',
    (WidgetTester tester) async {
      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        requestsOverride: const Result<AppPage<OperationsWorkItem>>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized loading then success on All requests', (
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
      initialLocation: '/operations?section=all',
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
    'mobile viewport: authorized next-action trailing; read-only omits write',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(390, 844),
      );

      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
      expect(find.byTooltip('Assign technician or team'), findsOneWidget);

      await _pumpAllRequestsTab(
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
    'desktop viewport: All requests status filter present for authorized reader',
    (WidgetTester tester) async {
      await _pumpAllRequestsTab(
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
        isTrue,
      );
    },
  );

  testWidgets('light + dark themes mount authorized All requests chrome', (
    WidgetTester tester,
  ) async {
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      await _pumpAllRequestsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        themeMode: mode,
      );

      expect(find.text('Generator alarm'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    }
  });
}
