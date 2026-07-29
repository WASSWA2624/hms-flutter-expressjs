import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
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
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

const MortuaryBillableEvent _billableEvent = MortuaryBillableEvent(
  id: 'bill-1',
  eventType: 'STORAGE_FEE',
  description: 'Cold storage day 1',
  amountText: '50.00',
  currency: 'UGX',
  status: 'OPEN',
);

const MortuaryWorkspaceItem _overviewItem = MortuaryWorkspaceItem(
  id: 'case-1',
  displayId: 'MOR-001',
  resource: mortuaryResourceCases,
  status: 'IN_STORAGE',
  identificationStatus: 'VERIFIED',
  billingStatus: 'UNSETTLED',
  deceasedProfileLabel: 'Overview Patient',
  billableEvents: <MortuaryBillableEvent>[_billableEvent],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: mortuaryActiveModule, licenseStatus: 'ACTIVE'),
  ],
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: const <String>['MORTUARY_STAFF'],
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readPolicy() {
  return _policy(permissions: <AppPermission>{AppPermissions.mortuaryRead});
}

AppAccessPolicy _readWritePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.mortuaryWrite,
    },
  );
}

AppAccessPolicy _exportPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.mortuaryExport,
    },
  );
}

AppAccessPolicy _reportsExportUnionPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.reportsRead,
    },
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: mortuaryActiveModule, licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(
        code: 'reporting-analytics',
        licenseStatus: 'ACTIVE',
      ),
    ],
  );
}

AppAccessPolicy _billingPanelPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.mortuaryBillingEvent,
      AppPermissions.billingRead,
    },
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: mortuaryActiveModule, licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    ],
  );
}

MortuaryWorkspacePayload _payload(MortuaryWorkspaceQuery query) {
  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: const <MortuaryWorkspaceItem>[_overviewItem],
      request: query.pageRequest,
      totalItemCount: 1,
    ),
    lookups: const MortuaryLookupData(),
    summary: const <MortuarySummaryItem>[
      MortuarySummaryItem(id: 'total_cases', value: 1),
    ],
    queues: const <MortuaryQueueSummary>[],
    panels: const <MortuaryPanelSummary>[
      MortuaryPanelSummary(
        id: mortuaryPanelOverview,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelIntake,
        count: 0,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelStorage,
        count: 0,
        defaultResource: mortuaryResourceStorageAssignments,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelCustody,
        count: 0,
        defaultResource: mortuaryResourceCustodyEvents,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelRelease,
        count: 0,
        defaultResource: mortuaryResourceReleaseAuthorisations,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelReporting,
        count: 0,
        defaultResource: mortuaryResourcePostMortemRequests,
      ),
    ],
    filters: query,
    lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
  );
}

void _stubWorkspace(_MockMortuaryRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final MortuaryWorkspaceQuery query =
        invocation.positionalArguments.single as MortuaryWorkspaceQuery;
    return Result<MortuaryWorkspacePayload>.success(_payload(query));
  });
  when(
    () => repository.getItem(
      resource: any(named: 'resource'),
      id: any(named: 'id'),
      baseQuery: any(named: 'baseQuery'),
    ),
  ).thenAnswer(
    (_) async => const Result<MortuaryWorkspaceItem>.success(_overviewItem),
  );
}

Future<GoRouter> _pumpOverviewTab(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/mortuary',
  Result<MortuaryWorkspacePayload>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  if (workspaceOverride != null) {
    when(() => repository.getWorkspace(any())).thenAnswer(
      (_) async => workspaceOverride,
    );
  } else {
    _stubWorkspace(repository);
  }

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/mortuary',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: MortuaryWorkspacePage(
              initialQuery: MortuaryRouteQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mortuaryRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy ?? _readWritePolicy()),
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

AppListTable<MortuaryWorkspaceItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<MortuaryWorkspaceItem>>(
    find.byType(AppListTable<MortuaryWorkspaceItem>),
  );
}

Future<void> _openDetail(WidgetTester tester) async {
  final AppListTable<MortuaryWorkspaceItem> table = _table(tester);
  expect(table.onRowSelected, isNotNull);
  table.onRowSelected!(_overviewItem);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  late _MockMortuaryRepository repository;

  setUpAll(() {
    registerFallbackValue(const MortuaryWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockMortuaryRepository();
  });

  group('MortuaryOverviewAtomPermissions helpers', () {
    test('reuses feature *Requirement vocabulary (no second map)', () {
      expect(
        identical(
          MortuaryOverviewAtomPermissions.tab,
          mortuaryWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryOverviewAtomPermissions.write,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryOverviewAtomPermissions.printDocuments,
          mortuaryExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryOverviewAtomPermissions.billingPanel,
          mortuaryBillingPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryOverviewAtomPermissions.routeEntry,
          RouteAccessCatalog.mortuaryEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryOverviewAtomPermissions.routeEntry,
          AppRoutes.mortuary.accessRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelTabRequirement(mortuaryPanelOverview),
          MortuaryOverviewAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelPrintRequirement(mortuaryPanelOverview),
          MortuaryOverviewAtomPermissions.printDocuments,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelBillingRequirement(mortuaryPanelOverview),
          MortuaryOverviewAtomPermissions.billingPanel,
        ),
        isTrue,
      );
    });

    test('intersection denial: missing mortuary:read fails tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryWrite},
      );
      expect(MortuaryOverviewAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canViewMortuaryPanel(writeOnly, mortuaryPanelOverview), isFalse);
      expect(canWriteMortuary(writeOnly), isTrue);
      expect(canEnterMortuaryWorkspace(writeOnly), isTrue);
    });

    test('full intersection set allows overview tab read chrome', () {
      final AppAccessPolicy read = _readPolicy();
      expect(MortuaryOverviewAtomPermissions.tab.isAllowed(read), isTrue);
      expect(MortuaryOverviewAtomPermissions.listChrome.isAllowed(read), isTrue);
      expect(MortuaryOverviewAtomPermissions.create.isAllowed(read), isFalse);
      expect(MortuaryOverviewAtomPermissions.update.isAllowed(read), isFalse);
      expect(MortuaryOverviewAtomPermissions.delete.isAllowed(read), isFalse);
    });

    test('union: export allows mortuary:export or reports:read', () {
      expect(canExportMortuary(_exportPolicy()), isTrue);
      expect(canExportMortuary(_reportsExportUnionPolicy()), isTrue);
      expect(canExportMortuary(_readPolicy()), isFalse);
      expect(
        MortuaryOverviewAtomPermissions.printDocuments.isAllowed(
          _exportPolicy(),
        ),
        isTrue,
      );
      expect(
        MortuaryOverviewAtomPermissions.printDocuments.isAllowed(
          _reportsExportUnionPolicy(),
        ),
        isTrue,
      );
    });

    test('intersection: billing panel needs mortuary:billing_event ∩ billing:read',
        () {
      expect(
        MortuaryOverviewAtomPermissions.billingPanel.isAllowed(_readPolicy()),
        isFalse,
      );
      expect(
        MortuaryOverviewAtomPermissions.billingPanel.isAllowed(
          _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryBillingEvent,
            },
          ),
        ),
        isFalse,
      );
      expect(
        MortuaryOverviewAtomPermissions.billingPanel.isAllowed(
          _billingPanelPolicy(),
        ),
        isTrue,
      );
    });

    test('subscription strips tab when mortuary module inactive', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(MortuaryOverviewAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canEnterMortuaryWorkspace(noModule), isFalse);
    });

    test('ABAC facility context required for overview tab', () {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRead},
        facilityId: null,
      );
      expect(
        MortuaryOverviewAtomPermissions.tab.isAllowed(noFacility),
        isFalse,
      );
    });

    test('nested cross-module matrix rows are n/a (no nestedWrite atom)', () {
      expect(
        MortuaryOverviewAtomPermissions.nestedRead,
        mortuaryWorkspaceReadRequirement,
      );
    });
  });

  group('Overview tab UI gates', () {
    testWidgets('authorized read mounts overview tab, list chrome, row select', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpOverviewTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
      );

      expect(
        router.state.uri.queryParameters['panel'] ?? mortuaryPanelOverview,
        mortuaryPanelOverview,
      );
      expect(find.text('Overview'), findsWidgets);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(_table(tester).columnVisibilityStorageKey, 'mortuary_overview');
      expect(find.text('Receive case'), findsNothing);
      expect(find.text('Assign storage'), findsNothing);
      expect(find.text('Approve release'), findsNothing);

      await _openDetail(tester);
      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.text('Actions unavailable'), findsNothing);
      expect(find.text('Receive case'), findsNothing);
      expect(find.text('Record custody'), findsNothing);
      expect(find.text('Approve release'), findsNothing);
      expect(find.text('Request post-mortem'), findsNothing);
    });

    testWidgets(
      'intersection denial: read without billing ∩ omits billing panel',
      (WidgetTester tester) async {
        await _pumpOverviewTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('CASE DETAIL'), findsOneWidget);
        expect(find.text('Billing'), findsNothing);
        expect(find.text('Cold storage day 1'), findsNothing);
      },
    );

    testWidgets(
      'full billing intersection mounts billing events panel',
      (WidgetTester tester) async {
        await _pumpOverviewTab(
          tester,
          repository: repository,
          policy: _billingPanelPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Billing'), findsOneWidget);
        expect(find.textContaining('Cold storage day 1'), findsOneWidget);
      },
    );

    testWidgets(
      'intersection denial: missing export omits print documents',
      (WidgetTester tester) async {
        await _pumpOverviewTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Print documents'), findsNothing);
      },
    );

    testWidgets(
      'union allowance: mortuary:export mounts print documents',
      (WidgetTester tester) async {
        await _pumpOverviewTab(
          tester,
          repository: repository,
          policy: _exportPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Print documents'), findsOneWidget);
      },
    );

    testWidgets(
      'union allowance: reports:read mounts print documents',
      (WidgetTester tester) async {
        await _pumpOverviewTab(
          tester,
          repository: repository,
          policy: _reportsExportUnionPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Print documents'), findsOneWidget);
      },
    );

    testWidgets(
      'nested cross-module write UI absent (matrix n/a; no-op chrome removed)',
      (WidgetTester tester) async {
        await _pumpOverviewTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryWrite,
              AppPermissions.mortuaryPostMortemRequest,
              AppPermissions.mortuaryApprove,
              AppPermissions.mortuaryRelease,
              AppPermissions.mortuaryManageStorage,
            },
          ),
        );
        await _openDetail(tester);

        expect(find.text('Receive case'), findsNothing);
        expect(find.text('Assign storage'), findsNothing);
        expect(find.text('Record custody'), findsNothing);
        expect(find.text('Request post-mortem'), findsNothing);
        expect(find.text('Approve release'), findsNothing);
      },
    );

    testWidgets(
      'subscription denial: permissions without mortuary module show forbidden',
      (WidgetTester tester) async {
        await _pumpOverviewTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryWrite,
            },
            modules: const <AppModuleEntitlement>[],
          ),
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsNothing);
        expect(find.text('Access denied'), findsOneWidget);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        workspaceOverride: Result<MortuaryWorkspacePayload>.success(
          MortuaryWorkspacePayload(
            items: AppPage<MortuaryWorkspaceItem>(
              items: const <MortuaryWorkspaceItem>[],
              request: const AppPageRequest(pageSize: 12),
              totalItemCount: 0,
            ),
            lookups: const MortuaryLookupData(),
            summary: const <MortuarySummaryItem>[],
            queues: const <MortuaryQueueSummary>[],
            panels: const <MortuaryPanelSummary>[
              MortuaryPanelSummary(
                id: mortuaryPanelOverview,
                count: 0,
                defaultResource: mortuaryResourceCases,
              ),
            ],
            filters: const MortuaryWorkspaceQuery(panel: mortuaryPanelOverview),
            lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
          ),
        ),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Overview'), findsWidgets);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        workspaceOverride: const Result<MortuaryWorkspacePayload>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('mobile viewport keeps overview strip and worklist', (
      WidgetTester tester,
    ) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        viewport: const Size(390, 844),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Overview'), findsWidgets);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
    });

    testWidgets('desktop dark theme mounts overview authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpOverviewTab(
        tester,
        repository: repository,
        policy: _exportPolicy(),
        themeMode: ThemeMode.dark,
        viewport: const Size(1440, 900),
      );

      expect(find.text('Overview'), findsWidgets);
      await _openDetail(tester);
      expect(find.text('Print documents'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Overview').first)).brightness,
        Brightness.dark,
      );
    });

    testWidgets(
      'post-mutation sync: detail reload uses repository after row select',
      (WidgetTester tester) async {
        await _pumpOverviewTab(
          tester,
          repository: repository,
          policy: _readWritePolicy(),
        );
        await _openDetail(tester);

        verify(
          () => repository.getItem(
            resource: any(named: 'resource'),
            id: any(named: 'id'),
            baseQuery: any(named: 'baseQuery'),
          ),
        ).called(1);
        expect(find.text('CASE DETAIL'), findsOneWidget);
      },
    );

    testWidgets(
      'deep link ?panel=overview keeps overview when read ∩ granted',
      (WidgetTester tester) async {
        final GoRouter router = await _pumpOverviewTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
          initialLocation: '/mortuary?panel=overview',
        );

        expect(router.state.uri.queryParameters['panel'], 'overview');
        expect(find.text('Overview'), findsWidgets);
        expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      },
    );
  });
}
