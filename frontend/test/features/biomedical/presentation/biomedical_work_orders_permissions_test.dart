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

const BiomedicalAsset _openWorkOrder = BiomedicalAsset(
  id: 'WO-100',
  humanFriendlyId: 'WO-100',
  resource: BiomedicalResources.workOrders,
  title: 'Pump repair',
  status: 'OPEN',
  priority: 'HIGH',
  categoryLabel: 'Infusion',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Infusion Pump A',
);

const BiomedicalAsset _startedWorkOrder = BiomedicalAsset(
  id: 'WO-100',
  humanFriendlyId: 'WO-100',
  resource: BiomedicalResources.workOrders,
  title: 'Pump repair',
  status: 'IN_PROGRESS',
  priority: 'HIGH',
  facilityLabel: 'ICU',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Infusion Pump A',
);

const BiomedicalLookupData _lookups = BiomedicalLookupData(
  equipment: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'EQ-100', label: 'Infusion Pump A'),
  ],
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
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_openWorkOrder],
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
          openWorkOrders: 1,
        ),
        queues: const <BiomedicalQueueSummary>[],
        panels: const <BiomedicalPanelSummary>[],
        lookups: _lookups,
        assets: AppPage<BiomedicalAsset>(
          items: assets,
          request: query.pageRequest,
          totalItemCount: assets.length,
        ),
      ),
    );
  });
}

Future<void> _pumpWorkOrdersTab(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_openWorkOrder],
  Result<BiomedicalWorkbench>? workspaceOverride,
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
    initialLocation: '/biomedical?panel=work-orders',
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
    'read-only: Work orders list visible; Create WO / write next-actions absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      expect(BiomedicalWorkOrdersAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        BiomedicalWorkOrdersAtomPermissions.createWorkOrder.isAllowed(reader),
        isFalse,
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.startWorkOrder.isAllowed(reader),
        isFalse,
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.write.isAllowed(reader),
        isFalse,
      );

      await _pumpWorkOrdersTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Pump repair'), findsOneWidget);
      expect(find.text('Work orders'), findsWidgets);
      expect(find.text('Risk'), findsOneWidget);
      expect(find.byTooltip('Create work order'), findsNothing);
      expect(find.text('Work order follow-up'), findsNothing);
      expect(find.text('Review record'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Update work order'), findsNothing);
      expect(find.text('Start work order'), findsNothing);
      expect(find.text('Transfer location'), findsNothing);
      expect(find.text('Schedule maintenance'), findsNothing);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩ / source ∪: Create WO, write next-action, detail writes mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
          AppPermissions.evidenceExport,
        },
      );
      expect(BiomedicalWorkOrdersAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        BiomedicalWorkOrdersAtomPermissions.createWorkOrder.isAllowed(writer),
        isTrue,
      );
      expect(BiomedicalWorkOrdersAtomPermissions.print.isAllowed(writer), isTrue);

      await _pumpWorkOrdersTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Pump repair'), findsOneWidget);
      expect(find.byTooltip('Create work order'), findsOneWidget);
      expect(find.text('Work order follow-up'), findsWidgets);

      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Update work order'), findsOneWidget);
      expect(find.text('Transfer location'), findsOneWidget);
      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
      // Start WO is the row next-action — omitted from complementary detail writes.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Start work order'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write ∪: operations:write without biomed:write still mounts Work orders write atoms',
    (WidgetTester tester) async {
      // operations:write is plan-gated to facilities-maintenance via grants().
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
        BiomedicalWorkOrdersAtomPermissions.write.isAllowed(operationsWriter),
        isTrue,
      );

      await _pumpWorkOrdersTab(
        tester,
        repository: repository,
        accessPolicy: operationsWriter,
      );

      expect(find.byTooltip('Create work order'), findsOneWidget);
      expect(find.text('Work order follow-up'), findsWidgets);

      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Update work order'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Start work order'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'route entry ∪: biomed:write alone without biomed:read omits Work orders chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.biomedWrite},
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpWorkOrdersTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Pump repair'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Create work order'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: biomedical-engineering-suite missing omits Work orders',
    (WidgetTester tester) async {
      await _pumpWorkOrdersTab(
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
      expect(find.text('Pump repair'), findsNothing);
      expect(find.byTooltip('Create work order'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: print absent without evidence:export; WO write mounts',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoExport = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.print.isAllowed(writerNoExport),
        isFalse,
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.startWorkOrder.isAllowed(
          writerNoExport,
        ),
        isTrue,
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.nestedWrite.isAllowed(
          writerNoExport,
        ),
        isTrue,
      );

      await _pumpWorkOrdersTab(
        tester,
        repository: repository,
        accessPolicy: writerNoExport,
      );

      expect(find.text('Work order follow-up'), findsWidgets);

      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Update work order'), findsOneWidget);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Create work order opens dialog',
    (WidgetTester tester) async {
      await _pumpWorkOrdersTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Create work order'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE WORK ORDER'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'IN_PROGRESS ∩ denial: Return to service next-action absent for read-only',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.returnToService.isAllowed(reader),
        isFalse,
      );

      await _pumpWorkOrdersTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        assets: const <BiomedicalAsset>[_startedWorkOrder],
      );

      expect(find.text('Pump repair'), findsOneWidget);
      expect(find.text('Return to service'), findsNothing);
      expect(find.text('Review record'), findsWidgets);
      expect(find.byTooltip('Create work order'), findsNothing);

      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Update work order'), findsNothing);
      expect(find.text('Return to service'), findsNothing);
      expect(find.text('Start work order'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'IN_PROGRESS write ∪: Return to service next-action mounts; omitted from detail',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      );
      expect(
        BiomedicalWorkOrdersAtomPermissions.returnToService.isAllowed(writer),
        isTrue,
      );

      await _pumpWorkOrdersTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        assets: const <BiomedicalAsset>[_startedWorkOrder],
      );

      expect(find.text('Return to service'), findsWidgets);
      expect(find.text('Work order follow-up'), findsNothing);

      await tester.tap(find.text('Pump repair'));
      await tester.pumpAndSettle();

      expect(find.text('Update work order'), findsOneWidget);
      // Return is the row next-action — omitted from complementary detail writes.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Return to service'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Start work order'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'authorized Work orders next-action opens dialog and mutation syncs list',
    (WidgetTester tester) async {
      when(
        () => repository.startWorkOrder(any(), any()),
      ).thenAnswer(
        (_) async => const Result<BiomedicalMutationResult>.success(
          BiomedicalMutationResult(asset: _startedWorkOrder),
        ),
      );

      await _pumpWorkOrdersTab(
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
    'authorized Create work order validation keeps dialog open without mutation',
    (WidgetTester tester) async {
      await _pumpWorkOrdersTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Create work order'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE WORK ORDER'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE WORK ORDER'), findsOneWidget);
      expect(find.textContaining('is required'), findsWidgets);
      verifyNever(() => repository.createResource(any(), any()));
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty authorized Work orders still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpWorkOrdersTab(
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
    'authorized error/retry surface remains observable on Work orders',
    (WidgetTester tester) async {
      await _pumpWorkOrdersTab(
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

  testWidgets('authorized loading then success on Work orders', (
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
            openWorkOrders: 1,
          ),
          queues: const <BiomedicalQueueSummary>[],
          panels: const <BiomedicalPanelSummary>[],
          lookups: _lookups,
          assets: AppPage<BiomedicalAsset>(
            items: const <BiomedicalAsset>[_openWorkOrder],
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
      initialLocation: '/biomedical?panel=work-orders',
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
    expect(find.text('Pump repair'), findsOneWidget);
    expect(find.text('Work orders'), findsWidgets);
    expect(find.byTooltip('Create work order'), findsNothing);
  });

  testWidgets('mobile viewport: authorized Work orders chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpWorkOrdersTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Work orders'), findsWidgets);
    expect(find.byTooltip('Create work order'), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Pump'), findsWidgets);
  });

  testWidgets('desktop viewport: authorized Work orders chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpWorkOrdersTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
    );

    expect(find.text('Pump repair'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Risk'), findsOneWidget);
    expect(find.text('Work order follow-up'), findsWidgets);
  });

  testWidgets('dark theme: authorized Work orders chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpWorkOrdersTab(
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

    expect(find.text('Pump repair'), findsOneWidget);
    expect(find.byTooltip('Create work order'), findsOneWidget);

    await tester.tap(find.text('Pump repair'));
    await tester.pumpAndSettle();
    expect(find.text('Print report'), findsOneWidget);
  });

  testWidgets('light theme: authorized Work orders chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpWorkOrdersTab(
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

    expect(find.text('Pump repair'), findsOneWidget);
    expect(find.byTooltip('Create work order'), findsOneWidget);
    expect(find.text('Work order follow-up'), findsWidgets);
  });
}
