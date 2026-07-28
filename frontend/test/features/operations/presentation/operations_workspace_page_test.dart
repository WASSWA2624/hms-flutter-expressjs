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
import 'package:hosspi_hms/features/operations/data/repositories/operations_repository_impl.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/features/operations/domain/repositories/operations_repository.dart';
import 'package:hosspi_hms/features/operations/presentation/pages/operations_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
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

const OperationsWorkItem _inProgressRequest = OperationsWorkItem(
  id: 'MR-WIP',
  displayId: 'MR-WIP',
  status: 'IN_PROGRESS',
  assetLabel: 'Pump',
  metadata: OperationsRequestMetadata(
    issue: 'Pump seal leak',
    priority: 'NORMAL',
    category: 'PLUMBING',
  ),
);

const OperationsWorkItem _inProgressWithAsset = OperationsWorkItem(
  id: 'MR-WIP-ASSET',
  displayId: 'MR-WIP-ASSET',
  status: 'IN_PROGRESS',
  assetId: 'AS-001',
  assetLabel: 'Backup Generator',
  metadata: OperationsRequestMetadata(
    issue: 'Oil pressure fault',
    priority: 'HIGH',
    category: 'POWER_BACKUP',
  ),
);

const OperationsWorkItem _completedRequest = OperationsWorkItem(
  id: 'MR-DONE',
  displayId: 'MR-DONE',
  status: 'COMPLETED',
  assetLabel: 'HVAC Unit',
  metadata: OperationsRequestMetadata(
    issue: 'Filter replaced',
    priority: 'LOW',
    category: 'HVAC',
  ),
);

const OperationsAsset _generatorAsset = OperationsAsset(
  id: 'AS-001',
  name: 'Backup Generator',
  assetTag: 'GEN-01',
  status: 'OPEN',
  facilityLabel: 'Main Campus',
);

AppAccessPolicy _operationsWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['OPERATIONS']),
      permissions: <AppPermission>{
        AppPermissions.operationsRead,
        AppPermissions.operationsWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'facilities-maintenance',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

AppAccessPolicy _operationsReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['OPERATIONS']),
      permissions: <AppPermission>{AppPermissions.operationsRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'facilities-maintenance',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

void _stubRepository(
  _MockOperationsRepository repository, {
  List<OperationsWorkItem> requests = const <OperationsWorkItem>[
    _openRequest,
    _inProgressRequest,
    _completedRequest,
  ],
  List<OperationsAsset> assets = const <OperationsAsset>[_generatorAsset],
}) {
  when(() => repository.listRequests(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final OperationsWorkItemQuery query =
        invocation.positionalArguments.single as OperationsWorkItemQuery;
    List<OperationsWorkItem> items = requests;
    final String? status = query.status?.trim().toUpperCase();
    if (status != null && status.isNotEmpty) {
      items = requests
          .where((OperationsWorkItem item) => item.normalizedStatus == status)
          .toList(growable: false);
    }
    final String search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items
          .where((OperationsWorkItem item) {
            final String haystack =
                '${item.metadata.issue} ${item.effectiveDisplayId} ${item.assetLabel}'
                    .toLowerCase();
            return haystack.contains(search);
          })
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

Future<GoRouter> _pumpOperationsWorkspace(
  WidgetTester tester, {
  required _MockOperationsRepository repository,
  OperationsWorkspaceQuery? initialQuery,
  String initialLocation = '/operations',
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
        path: '/operations',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: OperationsWorkspacePage(
              initialQuery:
                  initialQuery ?? OperationsWorkspaceQuery.fromUri(state.uri),
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
          accessPolicy ?? _operationsWritePolicy(),
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
  return router;
}

AppListTable<OperationsWorkItem> _queueTable(WidgetTester tester) {
  return tester.widget<AppListTable<OperationsWorkItem>>(
    find.byType(AppListTable<OperationsWorkItem>),
  );
}

AppListTable<OperationsAsset> _assetsTable(WidgetTester tester) {
  return tester.widget<AppListTable<OperationsAsset>>(
    find.byType(AppListTable<OperationsAsset>),
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
    _stubRepository(repository);
  });

  testWidgets('renders tab strip with section counts and request rows', (
    WidgetTester tester,
  ) async {
    await _pumpOperationsWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('All requests'), findsWidgets);
    expect(find.textContaining('Open'), findsWidgets);
    expect(find.textContaining('In progress'), findsWidgets);
    expect(find.textContaining('Completed'), findsWidgets);
    expect(find.textContaining('Assets'), findsWidgets);
    expect(find.text('Generator alarm'), findsOneWidget);
    expect(find.text('Pump seal leak'), findsOneWidget);
    expect(find.text('Filter replaced'), findsOneWidget);
    expect(find.textContaining('Create request'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(_queueTable(tester).columnVisibilityTitle, 'Table Settings');
    expect(_queueTable(tester).search?.advancedFilterTitle, 'Advanced filters');
    expect(_queueTable(tester).columns.length, lessThanOrEqualTo(5));
    expect(
      _queueTable(tester).columns.any((
        AppListTableColumn<OperationsWorkItem> column,
      ) {
        return column.id == 'next_action' && column.alwaysVisible;
      }),
      isTrue,
    );
    expect(find.text('Assign technician or team'), findsOneWidget);
  });

  testWidgets('deep link section=open selects Open tab and filters rows', (
    WidgetTester tester,
  ) async {
    await _pumpOperationsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/operations?section=open',
      initialQuery: OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations?section=open'),
      ),
    );

    expect(find.text('Generator alarm'), findsOneWidget);
    expect(find.text('Pump seal leak'), findsNothing);
    expect(find.text('Filter replaced'), findsNothing);
    expect(find.textContaining('Create request'), findsOneWidget);
  });

  testWidgets('switching to Assets tab shows asset rows not work items', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpOperationsWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.textContaining('Assets').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'assets');
    expect(find.text('No assets registered'), findsNothing);
    expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
    expect(find.text('GEN-01'), findsWidgets);
    expect(find.text('Generator alarm'), findsNothing);
    expect(find.text('Pump seal leak'), findsNothing);
  });

  testWidgets('switching tabs updates the section query parameter', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpOperationsWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.textContaining('In progress').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'in-progress');
    expect(find.text('Pump seal leak'), findsOneWidget);
    expect(find.text('Generator alarm'), findsNothing);

    await tester.tap(find.textContaining('Completed').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'completed');
    expect(find.text('Filter replaced'), findsOneWidget);
    expect(find.text('Pump seal leak'), findsNothing);
  });

  testWidgets('Create request remains available on Assets tab', (
    WidgetTester tester,
  ) async {
    await _pumpOperationsWorkspace(tester, repository: repository);

    await tester.tap(find.textContaining('Assets').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Create request'), findsOneWidget);
  });

  testWidgets('deep link section=assets shows assets panel', (
    WidgetTester tester,
  ) async {
    await _pumpOperationsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/operations?section=assets',
      initialQuery: OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations?section=assets'),
      ),
    );

    expect(find.text('Tag'), findsOneWidget);
    expect(find.text('No assets registered'), findsNothing);
    expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
    expect(find.text('GEN-01'), findsWidgets);
    expect(find.text('Generator alarm'), findsNothing);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets(
    'Completed tab keeps Create request primary and Report secondary',
    (WidgetTester tester) async {
      await _pumpOperationsWorkspace(tester, repository: repository);

      await tester.tap(find.textContaining('Completed').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Refresh'), findsNothing);
    },
  );

  testWidgets('requestId deep link opens request detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpOperationsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/operations?requestId=MR-OPEN',
      initialQuery: OperationsWorkspaceQuery.fromUri(
        Uri.parse('/operations?requestId=MR-OPEN'),
      ),
    );

    expect(find.text('REQUEST DETAIL'), findsOneWidget);
    expect(find.text('Generator alarm'), findsWidgets);
  });

  testWidgets('assets row tap opens asset detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpOperationsWorkspace(tester, repository: repository);

    await tester.tap(find.textContaining('Assets').first);
    await tester.pumpAndSettle();

    expect(_assetsTable(tester).columnVisibilityTitle, 'Table Settings');
    expect(
      _assetsTable(tester).search?.advancedFilterTitle,
      'Advanced filters',
    );

    await tester.tap(find.text('Backup Generator (GEN-01)'));
    await tester.pumpAndSettle();

    expect(find.text('Backup Generator (GEN-01)'), findsWidgets);
    expect(find.text('GEN-01'), findsWidgets);
    expect(find.text('Main Campus'), findsAtLeastNWidgets(1));
  });

  testWidgets('next action opens assign dialog for open request', (
    WidgetTester tester,
  ) async {
    when(() => repository.triageRequest(any(), any())).thenAnswer(
      (_) async => const Result<OperationsWorkItem>.success(_openRequest),
    );

    await _pumpOperationsWorkspace(tester, repository: repository);

    await tester.tap(find.byTooltip('Assign technician or team'));
    await tester.pumpAndSettle();

    expect(find.text('Save assignment'), findsOneWidget);
    expect(find.text('REQUEST DETAIL'), findsNothing);
  });

  testWidgets(
    'next action opens update status for in-progress without asset',
    (WidgetTester tester) async {
      when(() => repository.updateRequestStatus(any(), any())).thenAnswer(
        (_) async =>
            const Result<OperationsWorkItem>.success(_inProgressRequest),
      );

      await _pumpOperationsWorkspace(tester, repository: repository);

      await tester.tap(find.textContaining('In progress').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Update repair status'));
      await tester.pumpAndSettle();

      expect(find.text('Save status'), findsOneWidget);
      expect(find.text('REQUEST DETAIL'), findsNothing);
    },
  );

  testWidgets(
    'next action opens service log for in-progress with asset',
    (WidgetTester tester) async {
      _stubRepository(
        repository,
        requests: const <OperationsWorkItem>[_inProgressWithAsset],
      );
      when(() => repository.addServiceLog(any())).thenAnswer(
        (_) async => const Result<OperationsServiceLog>.success(
          OperationsServiceLog(
            id: 'SL-1',
            assetId: 'AS-001',
            notes: 'Checked',
          ),
        ),
      );

      await _pumpOperationsWorkspace(tester, repository: repository);

      await tester.tap(find.byTooltip('Record service work'));
      await tester.pumpAndSettle();

      expect(find.text('Save service log'), findsOneWidget);
      expect(find.text('REQUEST DETAIL'), findsNothing);
    },
  );

  testWidgets('next action opens closeout for completed request', (
    WidgetTester tester,
  ) async {
    when(() => repository.appendRequestNote(any(), any())).thenAnswer(
      (_) async => const Result<OperationsWorkItem>.success(_completedRequest),
    );

    await _pumpOperationsWorkspace(tester, repository: repository);

    await tester.tap(find.textContaining('Completed').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add closeout note if needed'));
    await tester.pumpAndSettle();

    expect(find.text('Save note'), findsOneWidget);
    expect(find.text('REQUEST DETAIL'), findsNothing);
  });

  testWidgets('detail omits assign when it is the row next action', (
    WidgetTester tester,
  ) async {
    await _pumpOperationsWorkspace(tester, repository: repository);

    await tester.tap(find.text('Generator alarm'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    // Assign is the next-action primary — not duplicated in detail.
    expect(
      find.descendant(of: find.byType(AppDialog), matching: find.text('Assign')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Update status'),
      ),
      findsOneWidget,
    );
    // Detail report shortcut removed — workspace Report is the sole entry.
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Report'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'detail omits update status when it is the row next action',
    (WidgetTester tester) async {
      await _pumpOperationsWorkspace(tester, repository: repository);

      await tester.tap(find.textContaining('In progress').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pump seal leak'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Update status'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Assign'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'detail omits service log when it is the row next action',
    (WidgetTester tester) async {
      _stubRepository(
        repository,
        requests: const <OperationsWorkItem>[_inProgressWithAsset],
      );

      await _pumpOperationsWorkspace(tester, repository: repository);

      await tester.tap(find.text('Oil pressure fault'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Add service log'),
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
    },
  );

  testWidgets(
    'detail omits closeout note when it is the row next action',
    (WidgetTester tester) async {
      await _pumpOperationsWorkspace(tester, repository: repository);

      await tester.tap(find.textContaining('Completed').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter replaced'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Closeout note'),
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
    },
  );

  testWidgets('report summary has metrics only without preview shell', (
    WidgetTester tester,
  ) async {
    await _pumpOperationsWorkspace(tester, repository: repository);

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(find.textContaining('All requests'), findsWidgets);
    expect(find.text('Preview'), findsNothing);
  });

  testWidgets('unauthorized create and write next-actions are absent', (
    WidgetTester tester,
  ) async {
    await _pumpOperationsWorkspace(
      tester,
      repository: repository,
      accessPolicy: _operationsReadOnlyPolicy(),
    );

    expect(find.textContaining('Create request'), findsNothing);
    expect(find.text('Assign technician or team'), findsNothing);
    expect(find.text('Review request'), findsNothing);
    expect(find.text('Report'), findsOneWidget);

    await tester.tap(find.text('Generator alarm'));
    await tester.pumpAndSettle();
    expect(find.text('REQUEST DETAIL'), findsOneWidget);
  });

  testWidgets(
    'status filter is absent on scoped tabs and present on All requests',
    (WidgetTester tester) async {
      await _pumpOperationsWorkspace(tester, repository: repository);

      bool hasStatusFilter() {
        return _queueTable(tester).search!.filterGroups.any(
          (AppSearchBarFilterGroup group) => group.key == 'status',
        );
      }

      expect(hasStatusFilter(), isTrue);

      await tester.tap(find.textContaining('Open').first);
      await tester.pumpAndSettle();
      expect(hasStatusFilter(), isFalse);

      await tester.tap(find.textContaining('In progress').first);
      await tester.pumpAndSettle();
      expect(hasStatusFilter(), isFalse);

      await tester.tap(find.textContaining('Completed').first);
      await tester.pumpAndSettle();
      expect(hasStatusFilter(), isFalse);
    },
  );

  testWidgets('mobile list shows next-action trailing', (
    WidgetTester tester,
  ) async {
    await _pumpOperationsWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.byTooltip('Assign technician or team'), findsOneWidget);
  });

  testWidgets('mobile next-action opens assign without opening detail first', (
    WidgetTester tester,
  ) async {
    when(() => repository.triageRequest(any(), any())).thenAnswer(
      (_) async => const Result<OperationsWorkItem>.success(_openRequest),
    );

    await _pumpOperationsWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(390, 844),
    );

    await tester.tap(find.byTooltip('Assign technician or team'));
    await tester.pumpAndSettle();

    expect(find.text('Save assignment'), findsOneWidget);
    expect(find.text('REQUEST DETAIL'), findsNothing);
  });
}
