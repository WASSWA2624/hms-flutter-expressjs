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
import 'package:hosspi_hms/features/biomedical/data/repositories/biomedical_repository_impl.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/domain/repositories/biomedical_repository.dart';
import 'package:hosspi_hms/features/biomedical/presentation/pages/biomedical_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

const BiomedicalAsset _registryAsset = BiomedicalAsset(
  id: 'EQ-001',
  humanFriendlyId: 'EQ-001',
  resource: BiomedicalResources.registries,
  title: 'Defibrillator',
  status: 'ACTIVE',
  priority: 'HIGH',
  categoryLabel: 'Life Support',
  facilityLabel: 'Main Ward',
  engineerLabel: 'Alex Engineer',
);

AppAccessPolicy _biomedWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['BIOMED_ENGINEER']),
      permissions: <AppPermission>{
        AppPermissions.biomedRead,
        AppPermissions.biomedWrite,
        AppPermissions.operationsRead,
        AppPermissions.operationsWrite,
        AppPermissions.evidenceExport,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'biomedical-engineering-suite',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

void _stubWorkspace(_MockBiomedicalRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final BiomedicalWorkspaceQuery query =
        invocation.positionalArguments.single as BiomedicalWorkspaceQuery;
    return Result<BiomedicalWorkbench>.success(
      BiomedicalWorkbench(
        summary: const BiomedicalSummary(
          totalEquipment: 1,
          overduePm: 1,
          openWorkOrders: 1,
        ),
        queues: const <BiomedicalQueueSummary>[
          BiomedicalQueueSummary(
            queue: BiomedicalQueues.overduePm,
            count: 1,
            panel: BiomedicalPanels.preventive,
            resource: BiomedicalResources.maintenancePlans,
          ),
          BiomedicalQueueSummary(
            queue: BiomedicalQueues.openWorkOrders,
            count: 1,
            panel: BiomedicalPanels.workOrders,
            resource: BiomedicalResources.workOrders,
          ),
        ],
        panels: const <BiomedicalPanelSummary>[],
        lookups: BiomedicalLookupData.empty,
        assets: AppPage<BiomedicalAsset>(
          items: const <BiomedicalAsset>[_registryAsset],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
      ),
    );
  });
}

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockBiomedicalRepository repository;
  final GoRouter router;
}

Future<_Harness> _pumpBiomedicalWorkspace(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  BiomedicalRouteQuery? initialQuery,
  String initialLocation = '/biomedical',
  Size viewport = const Size(1440, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/biomedical',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: BiomedicalWorkspacePage(
              initialQuery:
                  initialQuery ?? BiomedicalRouteQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        biomedicalRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(_biomedWritePolicy()),
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
  return _Harness(repository: repository, router: router);
}

void main() {
  late _MockBiomedicalRepository repository;

  setUpAll(() {
    registerFallbackValue(const BiomedicalWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockBiomedicalRepository();
  });

  testWidgets('renders tab strip, registry columns, and register action', (
    WidgetTester tester,
  ) async {
    await _pumpBiomedicalWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppListTable<BiomedicalAsset>), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Registry'), findsWidgets);
    expect(find.text('Preventive'), findsWidgets);
    expect(find.text('Work orders'), findsWidgets);
    expect(find.text('Compliance'), findsWidgets);
    expect(find.text('Support'), findsWidgets);
    expect(find.text('Analytics'), findsWidgets);
    expect(find.byTooltip('Register asset'), findsOneWidget);
    expect(find.text('Asset tag'), findsOneWidget);
    expect(find.text('Risk'), findsOneWidget);
    // Default max visible columns is 5; registry's 6th/7th stay hidden.
    expect(find.text('Owner'), findsNothing);
    expect(find.text('Next due'), findsNothing);
    expect(find.text('Defibrillator'), findsOneWidget);
  });

  testWidgets('switching tabs calls applyPanel and updates URL panel', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpBiomedicalWorkspace(
      tester,
      repository: repository,
    );
    clearInteractions(repository);
    _stubWorkspace(repository);

    await tester.tap(find.text('Work orders').first);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['panel'], 'work-orders');
    expect(find.byTooltip('Create work order'), findsOneWidget);
    expect(find.byTooltip('Register asset'), findsNothing);
    expect(find.text('Risk'), findsOneWidget);

    final List<BiomedicalWorkspaceQuery> queries = verify(
      () => repository.getWorkspace(captureAny()),
    ).captured.cast<BiomedicalWorkspaceQuery>();
    expect(
      queries.any(
        (BiomedicalWorkspaceQuery q) => q.panel == BiomedicalPanels.workOrders,
      ),
      isTrue,
    );
  });

  testWidgets('deep link panel=work-orders selects Work orders tab', (
    WidgetTester tester,
  ) async {
    await _pumpBiomedicalWorkspace(
      tester,
      repository: repository,
      initialLocation: '/biomedical?panel=work-orders',
      initialQuery: BiomedicalRouteQuery.fromUri(
        Uri.parse('/biomedical?panel=work-orders'),
      ),
    );

    expect(find.byTooltip('Create work order'), findsOneWidget);
    expect(find.byTooltip('Register asset'), findsNothing);

    final List<BiomedicalWorkspaceQuery> queries = verify(
      () => repository.getWorkspace(captureAny()),
    ).captured.cast<BiomedicalWorkspaceQuery>();
    expect(
      queries.any(
        (BiomedicalWorkspaceQuery q) => q.panel == BiomedicalPanels.workOrders,
      ),
      isTrue,
    );
  });

  testWidgets('primary action changes per panel and hides for read-only tabs', (
    WidgetTester tester,
  ) async {
    await _pumpBiomedicalWorkspace(tester, repository: repository);

    expect(find.byTooltip('Register asset'), findsOneWidget);

    await tester.tap(find.text('Preventive').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Schedule maintenance'), findsOneWidget);
    expect(find.text('Next due'), findsOneWidget);

    await tester.tap(find.text('Compliance').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Record calibration'), findsOneWidget);

    await tester.tap(find.text('Support').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Register asset'), findsNothing);
    expect(find.byTooltip('Create work order'), findsNothing);
    expect(find.byTooltip('Schedule maintenance'), findsNothing);
    expect(find.byTooltip('Record calibration'), findsNothing);

    await tester.tap(find.text('Analytics').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Register asset'), findsNothing);
    expect(find.byTooltip('Create work order'), findsNothing);
  });

  testWidgets('filter dialog excludes panel filter', (
    WidgetTester tester,
  ) async {
    await _pumpBiomedicalWorkspace(tester, repository: repository);

    await tester.tap(find.byTooltip('Biomedical filters'));
    await tester.pumpAndSettle();

    expect(find.text('Status'), findsWidgets);
    expect(find.text('Priority'), findsWidgets);
    expect(find.text('Due date'), findsWidgets);
    // Panel is selected via tabs, not the advanced filter dialog.
    expect(find.text('Panel'), findsNothing);
  });

  testWidgets('search submits applySearch to repository', (
    WidgetTester tester,
  ) async {
    await _pumpBiomedicalWorkspace(tester, repository: repository);
    clearInteractions(repository);
    _stubWorkspace(repository);

    await tester.enterText(find.byType(TextField).first, 'pump');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final List<BiomedicalWorkspaceQuery> queries = verify(
      () => repository.getWorkspace(captureAny()),
    ).captured.cast<BiomedicalWorkspaceQuery>();
    expect(
      queries.any((BiomedicalWorkspaceQuery q) => q.search == 'pump'),
      isTrue,
    );
  });

  testWidgets('row selection opens asset detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpBiomedicalWorkspace(tester, repository: repository);

    await tester.tap(find.text('Defibrillator'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
  });

  testWidgets('AppTabStrip renders on narrow mobile viewport', (
    WidgetTester tester,
  ) async {
    await _pumpBiomedicalWorkspace(
      tester,
      repository: repository,
      viewport: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Registry'), findsWidgets);
    expect(find.text('Work orders'), findsWidgets);
  });
}
