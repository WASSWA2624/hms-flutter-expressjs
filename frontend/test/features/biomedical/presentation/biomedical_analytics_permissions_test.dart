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
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

const BiomedicalAsset _analyticsAsset = BiomedicalAsset(
  id: 'UTIL-001',
  humanFriendlyId: 'UTIL-001',
  resource: BiomedicalResources.utilizationSnapshots,
  title: 'Ventilator utilization',
  status: 'ACTIVE',
  priority: 'MEDIUM',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Ventilator A',
  categoryLabel: 'Respiratory',
  facilityLabel: 'ICU Wing',
  engineerLabel: 'Alex Engineer',
);

const BiomedicalLookupData _analyticsLookups = BiomedicalLookupData(
  equipment: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'EQ-100', label: 'Ventilator A'),
  ],
);

const AppModuleEntitlement _biomedModule = AppModuleEntitlement(
  code: biomedicalActiveModule,
  licenseStatus: 'ACTIVE',
);

const AppModuleEntitlement _reportsModule = AppModuleEntitlement(
  code: 'reporting-analytics',
  licenseStatus: 'ACTIVE',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    _biomedModule,
    _reportsModule,
  ],
  String? facilityId = 'facility-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: const <String>['BIOMED_ENGINEER'],
        tenantId: 'tenant-1',
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockBiomedicalRepository repository, {
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_analyticsAsset],
  Result<BiomedicalWorkbench>? failure,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (failure != null) {
      return failure;
    }
    final BiomedicalWorkspaceQuery query =
        invocation.positionalArguments.single as BiomedicalWorkspaceQuery;
    return Result<BiomedicalWorkbench>.success(
      BiomedicalWorkbench(
        summary: const BiomedicalSummary(totalEquipment: 1),
        queues: const <BiomedicalQueueSummary>[],
        panels: const <BiomedicalPanelSummary>[],
        lookups: _analyticsLookups,
        assets: AppPage<BiomedicalAsset>(
          items: assets,
          request: query.pageRequest,
          totalItemCount: assets.length,
        ),
      ),
    );
  });
}

Future<void> _pumpAnalytics(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_analyticsAsset],
  String initialLocation = '/biomedical?panel=analytics',
  Result<BiomedicalWorkbench>? failure,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, assets: assets, failure: failure);

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

  group('BiomedicalAnalyticsAtomPermissions helpers', () {
    test('∩ denial: biomed:read without reports:read denies Analytics tab', () {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      expect(BiomedicalAnalyticsAtomPermissions.read.isAllowed(policy), isTrue);
      expect(BiomedicalAnalyticsAtomPermissions.tab.isAllowed(policy), isFalse);
      expect(
        BiomedicalAnalyticsAtomPermissions.nestedRead.isAllowed(policy),
        isFalse,
      );
      expect(canAccessBiomedicalAnalytics(policy), isFalse);
      expect(
        canViewBiomedicalPanel(policy, BiomedicalPanels.analytics),
        isFalse,
      );
    });

    test('full ∩ + nested ∪: biomed:read and reports:read allow Analytics', () {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.reportsRead,
        },
      );
      expect(BiomedicalAnalyticsAtomPermissions.tab.isAllowed(policy), isTrue);
      expect(
        BiomedicalAnalyticsAtomPermissions.nestedRead.isAllowed(policy),
        isTrue,
      );
      expect(BiomedicalAnalyticsAtomPermissions.listChrome.isAllowed(policy), isTrue);
      expect(canAccessBiomedicalAnalytics(policy), isTrue);
    });

    test('write ∪: operations:write alone satisfies source write gate', () {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.reportsRead,
          AppPermissions.operationsWrite,
        },
        modules: const <AppModuleEntitlement>[
          _biomedModule,
          _reportsModule,
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      // Matrix ∩ is biomed:write; source keeps biomed:write ∪ operations:write.
      expect(BiomedicalAnalyticsAtomPermissions.write.isAllowed(policy), isTrue);
      expect(canWriteBiomedical(policy), isTrue);
    });

    test('subscription strip: missing biomed module denies Analytics', () {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.reportsRead,
        },
        modules: const <AppModuleEntitlement>[_reportsModule],
      );
      expect(BiomedicalAnalyticsAtomPermissions.tab.isAllowed(policy), isFalse);
      expect(canEnterBiomedicalWorkspace(policy), isFalse);
    });

    test('reports:read without reporting-analytics module denies nested ∪', () {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.reportsRead,
        },
        modules: const <AppModuleEntitlement>[_biomedModule],
      );
      expect(
        BiomedicalAnalyticsAtomPermissions.nestedRead.isAllowed(policy),
        isFalse,
      );
      expect(BiomedicalAnalyticsAtomPermissions.tab.isAllowed(policy), isFalse);
    });

    test('route entry ∪: biomed:write alone enters workspace', () {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{AppPermissions.biomedWrite},
      );
      expect(
        BiomedicalAnalyticsAtomPermissions.routeEntry.isAllowed(policy),
        isTrue,
      );
      expect(BiomedicalAnalyticsAtomPermissions.tab.isAllowed(policy), isFalse);
    });

    test('helpers reuse AccessRequirement vocabulary (no second map)', () {
      expect(
        identical(
          BiomedicalAnalyticsAtomPermissions.tab,
          biomedicalAnalyticsTabRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalAnalyticsAtomPermissions.write,
          biomedicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalAnalyticsAtomPermissions.nestedWrite,
          biomedicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalAnalyticsAtomPermissions.export,
          biomedicalExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalAnalyticsAtomPermissions.print,
          biomedicalExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalAnalyticsAtomPermissions.entry,
          biomedicalWorkspaceEntryRequirement,
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    '∩ denial: Analytics tab and list absent without reports:read',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );

      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Analytics'), findsNothing);
      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      expect(
        strip.tabs.any((AppTabItem tab) => tab.label == 'Analytics'),
        isFalse,
      );
      expect(strip.tabs.any((AppTabItem tab) => tab.label == 'Registry'), isTrue);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Analytics: list chrome and Review next-action present',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.reportsRead,
        },
      );

      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Analytics'), findsWidgets);
      expect(find.text('Ventilator utilization'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.text('Next action'), findsOneWidget);
      expect(find.text('Review record'), findsWidgets);
      expect(find.byTooltip('Register asset'), findsNothing);
      expect(find.byTooltip('Create work order'), findsNothing);
      expect(find.byTooltip('Report fault'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write ∪: operations:write without biomed:write mounts Analytics detail writes',
    (WidgetTester tester) async {
      final AppAccessPolicy operationsWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.reportsRead,
          AppPermissions.operationsWrite,
          AppPermissions.evidenceExport,
        },
        modules: const <AppModuleEntitlement>[
          _biomedModule,
          _reportsModule,
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      // Matrix ∩ is biomed:write; source keeps biomed:write ∪ operations:write.
      expect(
        BiomedicalAnalyticsAtomPermissions.write.isAllowed(operationsWriter),
        isTrue,
      );
      expect(
        BiomedicalAnalyticsAtomPermissions.export.isAllowed(operationsWriter),
        isTrue,
      );

      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: operationsWriter,
      );

      await tester.tap(find.text('Ventilator utilization'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Create work order'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested export: print absent without evidence:export; nested writes mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoExport = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
          AppPermissions.reportsRead,
        },
      );
      expect(
        BiomedicalAnalyticsAtomPermissions.print.isAllowed(writerNoExport),
        isFalse,
      );
      expect(
        BiomedicalAnalyticsAtomPermissions.nestedWrite.isAllowed(
          writerNoExport,
        ),
        isTrue,
      );

      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: writerNoExport,
      );

      await tester.tap(find.text('Ventilator utilization'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Create work order'), findsOneWidget);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪ write-only without biomed:read omits Analytics chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedWrite,
          AppPermissions.reportsRead,
        },
      );
      expect(
        BiomedicalAnalyticsAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BiomedicalAnalyticsAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        BiomedicalAnalyticsAtomPermissions.read.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Ventilator utilization'), findsNothing);
      expect(find.text('Analytics'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'read-only: detail write atoms absent; Print absent without export',
    (WidgetTester tester) async {
      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.reportsRead,
          },
        ),
      );

      await tester.tap(find.text('Ventilator utilization'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Edit asset'), findsNothing);
      expect(find.text('Schedule maintenance'), findsNothing);
      expect(find.text('Create work order'), findsNothing);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∪ + export: detail complementary writes and Print mount',
    (WidgetTester tester) async {
      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
            AppPermissions.reportsRead,
            AppPermissions.evidenceExport,
          },
        ),
      );

      await tester.tap(find.text('Ventilator utilization'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Create work order'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
    },
  );

  testWidgets(
    'nested ∪ allowance: reports:read restores Analytics on strip',
    (WidgetTester tester) async {
      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.reportsRead,
          },
        ),
        initialLocation: '/biomedical',
      );

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      expect(
        strip.tabs.any((AppTabItem tab) => tab.label == 'Analytics'),
        isTrue,
      );
    },
  );

  testWidgets(
    'deep link to Analytics without nested ∪ falls back without mounting tab',
    (WidgetTester tester) async {
      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        initialLocation: '/biomedical?panel=analytics',
      );

      expect(find.text('Analytics'), findsNothing);
      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      expect(strip.selectedId, BiomedicalPanels.registry);
      expect(find.byType(AppListTable<BiomedicalAsset>), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: no biomed module omits Analytics chrome',
    (WidgetTester tester) async {
      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.reportsRead,
            AppPermissions.biomedWrite,
          },
          modules: const <AppModuleEntitlement>[_reportsModule],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Ventilator utilization'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized empty Analytics state remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpAnalytics(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.reportsRead,
        },
      ),
      assets: const <BiomedicalAsset>[],
    );

    expect(find.byType(AppWorkspaceStatePanel), findsOneWidget);
    expect(find.text('Analytics'), findsWidgets);
  });

  testWidgets(
    'authorized error/retry surface remains observable on Analytics',
    (WidgetTester tester) async {
      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.reportsRead,
          },
        ),
        failure: const Result<BiomedicalWorkbench>.failure(AppFailure.network()),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized loading then success on Analytics', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.getWorkspace(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Result<BiomedicalWorkbench>.success(
        BiomedicalWorkbench(
          summary: const BiomedicalSummary(totalEquipment: 1),
          queues: const <BiomedicalQueueSummary>[],
          panels: const <BiomedicalPanelSummary>[],
          lookups: _analyticsLookups,
          assets: AppPage<BiomedicalAsset>(
            items: const <BiomedicalAsset>[_analyticsAsset],
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
      initialLocation: '/biomedical?panel=analytics',
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
              permissions: <AppPermission>{
                AppPermissions.biomedRead,
                AppPermissions.reportsRead,
              },
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
    // Loading chrome from AsyncStateScaffold (title and/or progress).
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.textContaining('Loading').evaluate().isNotEmpty ||
          find.textContaining('Biomedical').evaluate().isNotEmpty,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('Ventilator utilization'), findsOneWidget);
    expect(find.text('Analytics'), findsWidgets);
  });

  testWidgets('mobile + dark: authorized Analytics chrome mounts', (
    WidgetTester tester,
  ) async {
    await _pumpAnalytics(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.reportsRead,
        },
      ),
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Analytics'), findsWidgets);
    expect(find.byType(AppListTable<BiomedicalAsset>), findsOneWidget);
    expect(
      find.text('Ventilator utilization').evaluate().isNotEmpty ||
          find.byType(AppListTableMobileItem).evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('desktop + light: authorized Analytics chrome mounts', (
    WidgetTester tester,
  ) async {
    await _pumpAnalytics(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.reportsRead,
        },
      ),
      physicalSize: const Size(1920, 1200),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Analytics'), findsWidgets);
    expect(find.text('Ventilator utilization'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets(
    'post-mutation sync: Schedule maintenance refreshes Analytics workbench',
    (WidgetTester tester) async {
      when(
        () => repository.createResource(any(), any()),
      ).thenAnswer(
        (_) async => const Result<BiomedicalMutationResult>.success(
          BiomedicalMutationResult(
            asset: BiomedicalAsset(
              id: 'UTIL-001',
              humanFriendlyId: 'UTIL-001',
              resource: BiomedicalResources.utilizationSnapshots,
              title: 'Ventilator utilization',
              status: 'ACTIVE',
              equipmentId: 'EQ-100',
            ),
          ),
        ),
      );

      await _pumpAnalytics(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
            AppPermissions.reportsRead,
          },
        ),
      );

      clearInteractions(repository);
      when(() => repository.getWorkspace(any())).thenAnswer((
        Invocation invocation,
      ) async {
        final BiomedicalWorkspaceQuery query =
            invocation.positionalArguments.single as BiomedicalWorkspaceQuery;
        return Result<BiomedicalWorkbench>.success(
          BiomedicalWorkbench(
            summary: const BiomedicalSummary(totalEquipment: 1),
            queues: const <BiomedicalQueueSummary>[],
            panels: const <BiomedicalPanelSummary>[],
            lookups: _analyticsLookups,
            assets: AppPage<BiomedicalAsset>(
              items: const <BiomedicalAsset>[_analyticsAsset],
              request: query.pageRequest,
              totalItemCount: 1,
            ),
          ),
        );
      });
      when(
        () => repository.createResource(any(), any()),
      ).thenAnswer(
        (_) async => const Result<BiomedicalMutationResult>.success(
          BiomedicalMutationResult(
            asset: _analyticsAsset,
          ),
        ),
      );

      await tester.tap(find.text('Ventilator utilization'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Schedule maintenance'));
      await tester.pumpAndSettle();

      final Finder formFields = find.descendant(
        of: find.byType(AppDialog).last,
        matching: find.byType(TextFormField),
      );
      expect(formFields, findsWidgets);
      // Plan name is the first required AppTextField after the equipment select.
      for (int i = 0; i < formFields.evaluate().length; i++) {
        await tester.enterText(formFields.at(i), 'Quarterly PM');
      }
      await tester.pump();

      await tester.tap(find.text('Submit').last);
      await tester.pumpAndSettle();

      verify(
        () => repository.createResource(
          BiomedicalResources.maintenancePlans,
          any(),
        ),
      ).called(1);
      // Controller synchronizes the workbench in-memory from the mutation
      // result (no full getWorkspace round-trip required).
      expect(find.text('Biomedical changes saved.'), findsOneWidget);
      expect(find.text('Ventilator utilization'), findsWidgets);
    },
  );
}
