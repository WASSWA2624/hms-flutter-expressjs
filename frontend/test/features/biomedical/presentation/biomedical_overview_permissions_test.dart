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
import 'package:hosspi_hms/features/biomedical/data/repositories/biomedical_repository_impl.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/domain/repositories/biomedical_repository.dart';
import 'package:hosspi_hms/features/biomedical/presentation/biomedical_access.dart';
import 'package:hosspi_hms/features/biomedical/presentation/pages/biomedical_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

const BiomedicalAsset _overviewAsset = BiomedicalAsset(
  id: 'WO-100',
  humanFriendlyId: 'WO-100',
  resource: BiomedicalResources.workOrders,
  title: 'Infusion pump repair',
  status: 'OPEN',
  priority: 'HIGH',
  categoryLabel: 'Infusion',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
);

const BiomedicalAsset _startedWorkOrder = BiomedicalAsset(
  id: 'WO-100',
  humanFriendlyId: 'WO-100',
  resource: BiomedicalResources.workOrders,
  title: 'Infusion pump repair',
  status: 'IN_PROGRESS',
  priority: 'HIGH',
  categoryLabel: 'Infusion',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: biomedicalEngineeringSuiteModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BIOMED_ENGINEER'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockBiomedicalRepository repository, {
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_overviewAsset],
  Result<BiomedicalWorkbench>? workspaceOverride,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (workspaceOverride != null) {
      return workspaceOverride;
    }
    final BiomedicalWorkspaceQuery query =
        invocation.positionalArguments.single as BiomedicalWorkspaceQuery;
    return Result<BiomedicalWorkbench>.success(
      BiomedicalWorkbench(
        summary: const BiomedicalSummary(
          totalEquipment: 1,
          overduePm: 1,
          openWorkOrders: 1,
        ),
        queues: const <BiomedicalQueueSummary>[],
        panels: const <BiomedicalPanelSummary>[],
        lookups: BiomedicalLookupData.empty,
        assets: AppPage<BiomedicalAsset>(
          items: assets,
          request: query.pageRequest,
          totalItemCount: assets.length,
        ),
      ),
    );
  });
}

Future<void> _pumpOverviewTab(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_overviewAsset],
  Result<BiomedicalWorkbench>? workspaceOverride,
  String initialLocation = '/biomedical?panel=overview',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    assets: assets,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
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
              initialQuery: BiomedicalRouteQuery.fromUri(state.uri),
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
  late _MockBiomedicalRepository repository;

  setUpAll(() {
    registerFallbackValue(const BiomedicalWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockBiomedicalRepository();
  });

  testWidgets(
    'read-only: Overview list visible; write next-action / create absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      expect(BiomedicalOverviewAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(BiomedicalOverviewAtomPermissions.create.isAllowed(reader), isFalse);
      expect(BiomedicalOverviewAtomPermissions.update.isAllowed(reader), isFalse);
      expect(BiomedicalOverviewAtomPermissions.delete.isAllowed(reader), isFalse);
      expect(BiomedicalOverviewAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        BiomedicalOverviewAtomPermissions.workOrderFollowUp.isAllowed(reader),
        isFalse,
      );
      expect(
        BiomedicalOverviewAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );

      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Infusion pump repair'), findsOneWidget);
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Risk'), findsOneWidget);
      expect(find.byTooltip('Register asset'), findsNothing);
      expect(find.byTooltip('Create work order'), findsNothing);
      expect(find.text('Work order follow-up'), findsNothing);
      expect(find.text('Review record'), findsWidgets);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Edit asset'), findsNothing);
      expect(find.text('Create work order'), findsNothing);
      expect(find.text('Schedule maintenance'), findsNothing);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩ / source ∪: Overview write next-action and detail writes mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
          AppPermissions.evidenceExport,
        },
      );
      expect(BiomedicalOverviewAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        BiomedicalOverviewAtomPermissions.workOrderFollowUp.isAllowed(writer),
        isTrue,
      );
      expect(BiomedicalOverviewAtomPermissions.print.isAllowed(writer), isTrue);

      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Infusion pump repair'), findsOneWidget);
      expect(find.byTooltip('Create work order'), findsNothing);
      expect(find.byTooltip('Register asset'), findsNothing);
      expect(find.text('Work order follow-up'), findsWidgets);

      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Update work order'), findsOneWidget);
      // Start WO is the row next-action — omitted from complementary detail.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Start work order'),
        ),
        findsNothing,
      );
      expect(find.text('Print report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write ∪: operations:write without biomed:write still mounts write atoms',
    (WidgetTester tester) async {
      final AppAccessPolicy operationsWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.operationsWrite,
          AppPermissions.evidenceExport,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: biomedicalEngineeringSuiteModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        BiomedicalOverviewAtomPermissions.write.isAllowed(operationsWriter),
        isTrue,
      );

      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: operationsWriter,
      );

      expect(find.text('Work order follow-up'), findsWidgets);

      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
    },
  );

  testWidgets(
    'route entry ∪: biomed:write alone without biomed:read omits Overview chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.biomedWrite},
      );
      expect(
        BiomedicalOverviewAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BiomedicalOverviewAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Infusion pump repair'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Create work order'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: biomedical-engineering-suite missing omits Overview',
    (WidgetTester tester) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Infusion pump repair'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: print absent without evidence:export',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoExport = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      );
      expect(
        BiomedicalOverviewAtomPermissions.print.isAllowed(writerNoExport),
        isFalse,
      );
      expect(
        BiomedicalOverviewAtomPermissions.nestedWrite.isAllowed(writerNoExport),
        isTrue,
      );

      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: writerNoExport,
      );

      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Overview next-action opens dialog and mutation syncs list',
    (WidgetTester tester) async {
      when(
        () => repository.startWorkOrder(any(), any()),
      ).thenAnswer(
        (_) async => const Result<BiomedicalMutationResult>.success(
          BiomedicalMutationResult(asset: _startedWorkOrder),
        ),
      );

      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.text('Work order follow-up').first);
      await tester.pumpAndSettle();

      expect(find.text('START WORK ORDER'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      verify(() => repository.startWorkOrder(any(), any())).called(1);
      expect(find.text('Biomedical changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized Overview detail Schedule maintenance opens nested dialog',
    (WidgetTester tester) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule maintenance'), findsOneWidget);
      await tester.tap(find.text('Schedule maintenance'));
      await tester.pumpAndSettle();

      expect(find.text('SCHEDULE MAINTENANCE'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Overview Schedule maintenance validation keeps dialog open',
    (WidgetTester tester) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.text('Infusion pump repair'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule maintenance'));
      await tester.pumpAndSettle();

      expect(find.text('SCHEDULE MAINTENANCE'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('SCHEDULE MAINTENANCE'), findsOneWidget);
      expect(find.textContaining('is required'), findsWidgets);
      verifyNever(() => repository.createResource(any(), any()));
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty authorized Overview still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No equipment records'), findsOneWidget);
      expect(find.byTooltip('Create work order'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty write-authorized Overview still omits create primary',
    (WidgetTester tester) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No equipment records'), findsOneWidget);
      expect(find.byTooltip('Create work order'), findsNothing);
      expect(find.byTooltip('Register asset'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Overview',
    (WidgetTester tester) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
        workspaceOverride: const Result<BiomedicalWorkbench>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized loading then success on Overview', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.getWorkspace(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Result<BiomedicalWorkbench>.success(
        BiomedicalWorkbench(
          summary: const BiomedicalSummary(
            totalEquipment: 1,
            overduePm: 1,
            openWorkOrders: 1,
          ),
          queues: const <BiomedicalQueueSummary>[],
          panels: const <BiomedicalPanelSummary>[],
          lookups: BiomedicalLookupData.empty,
          assets: AppPage<BiomedicalAsset>(
            items: const <BiomedicalAsset>[_overviewAsset],
            request: const AppPageRequest(pageSize: 20),
            totalItemCount: 1,
          ),
        ),
      );
    });

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/biomedical?panel=overview',
      routes: <RouteBase>[
        GoRoute(
          path: '/biomedical',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: BiomedicalWorkspacePage(
                initialQuery: BiomedicalRouteQuery.fromUri(state.uri),
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
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{AppPermissions.biomedRead},
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.textContaining('Loading').evaluate().isNotEmpty ||
          find.textContaining('Biomedical').evaluate().isNotEmpty,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('Infusion pump repair'), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
  });

  testWidgets('mobile viewport: authorized Overview chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpOverviewTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
      physicalSize: const Size(390, 844),
      initialLocation: '/biomedical?panel=overview',
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.byType(AppListTable<BiomedicalAsset>), findsOneWidget);
    // Mobile rows use Text.rich; match textContaining or the mobile item.
    expect(
      find.textContaining('Infusion pump repair').evaluate().isNotEmpty ||
          find.byType(AppListTableMobileItem).evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('desktop viewport: authorized Overview chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpOverviewTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Infusion pump repair'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Risk'), findsOneWidget);
    expect(find.text('Work order follow-up'), findsWidgets);
  });

  testWidgets('dark theme: authorized Overview chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpOverviewTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
          AppPermissions.evidenceExport,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Infusion pump repair'), findsOneWidget);
    expect(find.text('Work order follow-up'), findsWidgets);

    await tester.tap(find.text('Infusion pump repair'));
    await tester.pumpAndSettle();
    expect(find.text('Print report'), findsOneWidget);
  });

  testWidgets('light theme: authorized Overview chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpOverviewTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Infusion pump repair'), findsOneWidget);
    expect(find.text('Work order follow-up'), findsWidgets);
  });
}
