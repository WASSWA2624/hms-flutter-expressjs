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
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = const Size(1440, 900);
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
        appAccessPolicyProvider.overrideWithValue(_operationsWritePolicy()),
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

void main() {
  late _MockOperationsRepository repository;

  setUpAll(() {
    registerFallbackValue(const OperationsWorkItemQuery());
    registerFallbackValue(const OperationsAssetQuery());
    registerFallbackValue(const OperationsServiceLogQuery());
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
    expect(find.text('Backup Generator'), findsOneWidget);
    expect(find.text('GEN-01'), findsOneWidget);
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

    expect(find.text('Backup Generator'), findsOneWidget);
    expect(find.text('GEN-01'), findsOneWidget);
    expect(find.text('Generator alarm'), findsNothing);
  });
}
