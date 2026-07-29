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
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLabRepository extends Mock implements LabRepository {}

const LabOrderSummary _orderedOrder = LabOrderSummary(
  id: 'LAB-ORDER-1',
  displayId: 'LO-1',
  status: 'ORDERED',
  patientDisplayName: 'Ann Ordered',
  patientId: 'PAT-1',
  paymentStatus: 'UNPAID',
);

const LabOrderSummary _completedOrder = LabOrderSummary(
  id: 'LAB-ORDER-2',
  displayId: 'LO-2',
  status: 'COMPLETED',
  patientDisplayName: 'Vera Verified',
  patientId: 'PAT-2',
  paymentStatus: 'PAID',
);

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: labWorkflowsModule, licenseStatus: 'ACTIVE'),
  ],
  List<String> roles = const <String>['LAB_TECH'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _labWritePolicy() {
  return _policyFor(
    permissions: <AppPermission>{
      AppPermissions.labRead,
      AppPermissions.labWrite,
    },
  );
}

AppAccessPolicy _labReadPolicy() {
  return _policyFor(permissions: <AppPermission>{AppPermissions.labRead});
}

LabWorkbenchBundle _workbenchFor(LabWorkbenchQuery query) {
  final List<LabOrderSummary> all = <LabOrderSummary>[
    _orderedOrder,
    _completedOrder,
  ];
  final List<LabOrderSummary> items = all
      .where(
        (LabOrderSummary order) => labOrderMatchesScope(order, query.scope),
      )
      .toList(growable: false);
  return LabWorkbenchBundle(
    summary: const LabWorkbenchSummary(
      totalOrders: 2,
      collectionQueue: 1,
      completedOrders: 1,
      totalPatients: 2,
      collectionPatients: 1,
      completedPatients: 1,
    ),
    worklist: AppPage<LabOrderSummary>(
      items: items,
      request: query.pageRequest,
      totalItemCount: items.length,
    ),
  );
}

void _stubWorkspace(_MockLabRepository repository) {
  when(() => repository.loadWorkbench(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final LabWorkbenchQuery query =
        invocation.positionalArguments.single as LabWorkbenchQuery;
    return Result<LabWorkbenchBundle>.success(_workbenchFor(query));
  });
  when(
    () => repository.listQcLogs(search: any(named: 'search')),
  ).thenAnswer((_) async => const Result<List<LabQcLog>>.success(<LabQcLog>[]));
  when(() => repository.loadOrderWorkflow(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String orderId = invocation.positionalArguments.single as String;
    final LabOrderSummary order = orderId == _completedOrder.id
        ? _completedOrder
        : _orderedOrder;
    return Result<LabOrderWorkflow>.success(
      LabOrderWorkflow(
        order: order,
        nextActions: const LabWorkflowNextActions(canCollect: true),
      ),
    );
  });
}

AppListTable<LabOrderSummary> _table(WidgetTester tester) {
  return tester.widget<AppListTable<LabOrderSummary>>(
    find.byType(AppListTable<LabOrderSummary>),
  );
}

Future<GoRouter> _pumpLabWorkspace(
  WidgetTester tester, {
  required _MockLabRepository repository,
  LabWorkspaceQuery? initialQuery,
  String initialLocation = '/lab',
  Size viewport = const Size(1440, 900),
  AppAccessPolicy? policy,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  _stubWorkspace(repository);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/lab',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: LabWorkspacePage(
              initialQuery:
                  initialQuery ?? LabWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        labRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy ?? _labWritePolicy()),
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
  return router;
}

void main() {
  late _MockLabRepository repository;

  setUpAll(() {
    registerFallbackValue(const LabWorkbenchQuery());
  });

  setUp(() {
    repository = _MockLabRepository();
  });

  testWidgets('renders AppTabStrip with six section tabs and worklist table', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppWorkspaceToolbar), findsNothing);
    expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
    expect(find.textContaining('All'), findsWidgets);
    expect(find.textContaining('Awaiting results'), findsWidgets);
    expect(find.textContaining('Processing'), findsWidgets);
    expect(find.textContaining('Pending verification'), findsWidgets);
    expect(find.textContaining('Critical'), findsWidgets);
    expect(find.textContaining('Verified'), findsWidgets);
    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byTooltip('Orders view'), findsOneWidget);
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(_table(tester).columnVisibilityTitle, 'Table Settings');
    expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
    expect(_table(tester).search?.advancedFilterTitle, 'Advanced filters');
    expect(_table(tester).columns.length, lessThanOrEqualTo(5));
    expect(
      _table(tester).columns.any((AppListTableColumn<LabOrderSummary> column) {
        return column.id == 'next_action' && column.alwaysVisible;
      }),
      isTrue,
    );
  });

  testWidgets('does not paint a dedicated laboratory title header', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(tester, repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );
    expect(find.text(l10n.labTitle), findsNothing);
  });

  testWidgets('keeps stable create primary and configurations secondary', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpLabWorkspace(
      tester,
      repository: repository,
    );

    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);

    // Prefer deep links over tab taps: AppTheme tab widths can overflow later
    // sections into the More menu (labels not mounted until opened).
    router.go('/lab?section=processing');
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'processing');
    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(_table(tester).columnVisibilityStorageKey, 'lab_processing');

    router.go('/lab?section=verified');
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'verified');
    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(_table(tester).columnVisibilityStorageKey, 'lab_completed');
  });

  testWidgets('deep link section=critical selects Critical tab', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(
      tester,
      repository: repository,
      initialLocation: '/lab?section=critical',
      initialQuery: LabWorkspaceQuery.fromUri(
        Uri.parse('/lab?section=critical'),
      ),
    );

    final List<LabWorkbenchQuery> queries = verify(
      () => repository.loadWorkbench(captureAny()),
    ).captured.cast<LabWorkbenchQuery>();
    expect(
      queries.any((LabWorkbenchQuery q) => q.scope == LabQueueScope.critical),
      isTrue,
    );
    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    expect(_table(tester).columnVisibilityStorageKey, 'lab_critical');
  });

  testWidgets('next action opens result entry without route-only loop', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(tester, repository: repository);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );
    expect(find.text(l10n.labNextActionEnterResult), findsWidgets);

    await tester.tap(find.text(l10n.labNextActionEnterResult).first);
    await tester.pumpAndSettle();

    expect(find.byType(LabResultEntryDialog), findsOneWidget);
    // Edit/Delete live only on the order section (not duplicated in the footer).
    expect(find.text(l10n.labEditOrderAction), findsOneWidget);
    expect(find.text(l10n.labDeleteOrderAction), findsOneWidget);
  });

  testWidgets('deep link orderId opens result entry dialog directly', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(
      tester,
      repository: repository,
      initialLocation: '/lab?orderId=LAB-ORDER-1',
      initialQuery: LabWorkspaceQuery.fromUri(
        Uri.parse('/lab?orderId=LAB-ORDER-1'),
      ),
    );

    expect(find.byType(LabResultEntryDialog), findsOneWidget);
    verify(() => repository.loadOrderWorkflow(any())).called(greaterThan(0));
  });

  testWidgets('read-only users keep view toggle; write actions absent', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(
      tester,
      repository: repository,
      policy: _labReadPolicy(),
    );

    expect(find.byTooltip('Create Lab Order'), findsNothing);
    expect(find.byTooltip('Lab Configurations'), findsNothing);
    expect(find.byTooltip('Orders view'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.textContaining('All'), findsWidgets);
    expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
  });

  testWidgets(
    'intersection denial: lab:write without lab-workflows strips create',
    (WidgetTester tester) async {
      await _pumpLabWorkspace(
        tester,
        repository: repository,
        policy: _policyFor(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      // No module → no allowed sections / empty panel; write chrome absent.
      expect(find.byTooltip('Create Lab Order'), findsNothing);
      expect(find.byTooltip('Lab Configurations'), findsNothing);
    },
  );

  testWidgets(
    'union route entry: clinical:read sees All chrome without create/config',
    (WidgetTester tester) async {
      await _pumpLabWorkspace(
        tester,
        repository: repository,
        policy: _policyFor(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: labWorkflowsModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
          roles: const <String>['DOCTOR'],
        ),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('All'), findsWidgets);
      expect(find.byTooltip('Orders view'), findsOneWidget);
      expect(find.byTooltip('Create Lab Order'), findsNothing);
      expect(find.byTooltip('Lab Configurations'), findsNothing);
      expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
    },
  );

  testWidgets('full write set mounts create and configurations on All', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(tester, repository: repository);

    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    expect(find.textContaining('All'), findsWidgets);
  });

  testWidgets('read-only result entry omits edit/delete and additional create', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(
      tester,
      repository: repository,
      policy: _labReadPolicy(),
    );

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );
    await tester.tap(find.text(l10n.labNextActionEnterResult).first);
    await tester.pumpAndSettle();

    expect(find.byType(LabResultEntryDialog), findsOneWidget);
    expect(find.text(l10n.labEditOrderAction), findsNothing);
    expect(find.text(l10n.labDeleteOrderAction), findsNothing);
    expect(find.text(l10n.labCollectSampleAction), findsNothing);
  });

  testWidgets('authorized write result entry keeps edit/delete', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(tester, repository: repository);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );
    await tester.tap(find.text(l10n.labNextActionEnterResult).first);
    await tester.pumpAndSettle();

    expect(find.text(l10n.labEditOrderAction), findsOneWidget);
    expect(find.text(l10n.labDeleteOrderAction), findsOneWidget);
    expect(find.text(l10n.labCollectSampleAction), findsOneWidget);
  });

  testWidgets('mobile viewport: All tab authorized chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(
      tester,
      repository: repository,
      viewport: const Size(390, 844),
    );

    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('All'), findsWidgets);
    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
  });

  testWidgets('desktop viewport: All tab authorized chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(
      tester,
      repository: repository,
      viewport: const Size(1440, 900),
    );

    expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);
  });

  testWidgets('dark theme: All tab write chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(
      tester,
      repository: repository,
      themeMode: ThemeMode.dark,
    );

    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    expect(find.textContaining('All'), findsWidgets);
  });

  testWidgets('light theme: All tab write chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(
      tester,
      repository: repository,
      themeMode: ThemeMode.light,
    );

    expect(find.byTooltip('Create Lab Order'), findsOneWidget);
    expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
  });

  testWidgets('nested cross-module request-from-clinical not on lab strip', (
    WidgetTester tester,
  ) async {
    await _pumpLabWorkspace(
      tester,
      repository: repository,
      policy: _policyFor(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: labWorkflowsModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
        roles: const <String>['DOCTOR'],
      ),
    );

    // clinical:write may request lab from clinical ∪, but lab strip create
    // stays ∩ lab:write — absent here.
    expect(find.byTooltip('Create Lab Order'), findsNothing);
    expect(find.byTooltip('Lab Configurations'), findsNothing);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });
}
