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

const MortuaryWorkspaceItem _custodyItem = MortuaryWorkspaceItem(
  id: 'custody-1',
  displayId: 'MOR-CUS-1',
  resource: mortuaryResourceCustodyEvents,
  status: 'IN_STORAGE',
  identificationStatus: 'VERIFIED',
  billingStatus: 'UNSETTLED',
  deceasedProfileLabel: 'Custody Patient',
  eventType: 'TRANSFER',
  actorName: 'Officer A',
  billableEvents: <MortuaryBillableEvent>[_billableEvent],
  custodyEvents: <MortuaryTimelineEvent>[
    MortuaryTimelineEvent(
      id: 'evt-1',
      eventType: 'TRANSFER',
      actorName: 'Officer A',
    ),
  ],
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
      items: const <MortuaryWorkspaceItem>[_custodyItem],
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
        count: 1,
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
    (_) async => const Result<MortuaryWorkspaceItem>.success(_custodyItem),
  );
}

Future<GoRouter> _pumpCustodyTab(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/mortuary?panel=custody',
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
  table.onRowSelected!(_custodyItem);
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

  group('MortuaryCustodyAtomPermissions helpers', () {
    test('reuses feature *Requirement vocabulary (no second map)', () {
      expect(
        identical(
          MortuaryCustodyAtomPermissions.tab,
          mortuaryWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryCustodyAtomPermissions.create,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryCustodyAtomPermissions.update,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryCustodyAtomPermissions.delete,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryCustodyAtomPermissions.write,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryCustodyAtomPermissions.nestedWrite,
          mortuaryNestedWorkflowWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryCustodyAtomPermissions.printDocuments,
          mortuaryExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryCustodyAtomPermissions.billingPanel,
          mortuaryBillingPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryCustodyAtomPermissions.routeEntry,
          RouteAccessCatalog.mortuaryEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryCustodyAtomPermissions.routeEntry,
          AppRoutes.mortuary.accessRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelTabRequirement(mortuaryPanelCustody),
          MortuaryCustodyAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelPrintRequirement(mortuaryPanelCustody),
          MortuaryCustodyAtomPermissions.printDocuments,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelBillingRequirement(mortuaryPanelCustody),
          MortuaryCustodyAtomPermissions.billingPanel,
        ),
        isTrue,
      );
    });

    test('intersection denial: missing mortuary:read fails tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryWrite},
      );
      expect(MortuaryCustodyAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canViewMortuaryPanel(writeOnly, mortuaryPanelCustody), isFalse);
      expect(canWriteMortuary(writeOnly), isTrue);
      expect(canEnterMortuaryWorkspace(writeOnly), isTrue);
      expect(
        MortuaryCustodyAtomPermissions.nestedWrite.isAllowed(writeOnly),
        isTrue,
      );
    });

    test('full intersection set allows custody tab read chrome', () {
      final AppAccessPolicy read = _readPolicy();
      expect(MortuaryCustodyAtomPermissions.tab.isAllowed(read), isTrue);
      expect(MortuaryCustodyAtomPermissions.listChrome.isAllowed(read), isTrue);
      expect(MortuaryCustodyAtomPermissions.search.isAllowed(read), isTrue);
      expect(MortuaryCustodyAtomPermissions.filters.isAllowed(read), isTrue);
      expect(MortuaryCustodyAtomPermissions.rowSelect.isAllowed(read), isTrue);
      expect(MortuaryCustodyAtomPermissions.detail.isAllowed(read), isTrue);
      expect(MortuaryCustodyAtomPermissions.create.isAllowed(read), isFalse);
      expect(MortuaryCustodyAtomPermissions.success.isAllowed(read), isFalse);
      expect(
        MortuaryCustodyAtomPermissions.printDocuments.isAllowed(read),
        isFalse,
      );
      expect(
        MortuaryCustodyAtomPermissions.billingPanel.isAllowed(read),
        isFalse,
      );
      expect(
        MortuaryCustodyAtomPermissions.nestedWrite.isAllowed(read),
        isFalse,
      );
    });

    test('intersection: billing panel needs billing_event ∩ billing:read', () {
      final AppAccessPolicy mortuaryBillingOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryBillingEvent,
        },
      );
      expect(
        MortuaryCustodyAtomPermissions.billingPanel.isAllowed(
          mortuaryBillingOnly,
        ),
        isFalse,
      );
      expect(
        MortuaryCustodyAtomPermissions.billingPanel.isAllowed(
          _billingPanelPolicy(),
        ),
        isTrue,
      );
    });

    test('union: nested write allows any of post_mortem|approve|write', () {
      expect(
        canWriteMortuaryNestedWorkflow(
          _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryPostMortemRequest,
            },
          ),
        ),
        isTrue,
      );
      expect(
        canWriteMortuaryNestedWorkflow(
          _policy(permissions: <AppPermission>{AppPermissions.mortuaryApprove}),
        ),
        isTrue,
      );
      expect(
        canWriteMortuaryNestedWorkflow(
          _policy(permissions: <AppPermission>{AppPermissions.mortuaryWrite}),
        ),
        isTrue,
      );
      expect(
        canWriteMortuaryNestedWorkflow(_readPolicy()),
        isFalse,
      );
    });

    test('union: export allows mortuary:export or reports:read', () {
      expect(canExportMortuary(_exportPolicy()), isTrue);
      expect(canExportMortuary(_reportsExportUnionPolicy()), isTrue);
      expect(canExportMortuary(_readPolicy()), isFalse);
    });

    test('subscription/ABAC strip module, BASIC plan, or facility', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      final AppAccessPolicy basicPlan = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: mortuaryActiveModule,
            licenseStatus: 'ACTIVE',
            planTierCode: 'BASIC',
          ),
        ],
      );
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRead},
        facilityId: null,
      );
      expect(MortuaryCustodyAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canEnterMortuaryWorkspace(noModule), isFalse);
      expect(MortuaryCustodyAtomPermissions.tab.isAllowed(basicPlan), isFalse);
      expect(MortuaryCustodyAtomPermissions.tab.isAllowed(noFacility), isFalse);
    });
  });

  group('Custody tab UI gates', () {
    testWidgets('authorized read mounts custody tab, list chrome, row select', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpCustodyTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
      );

      expect(router.state.uri.queryParameters['panel'], 'custody');
      expect(find.text('Custody'), findsWidgets);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(_table(tester).columnVisibilityStorageKey, 'mortuary_custody');
      expect(
        _table(tester).columns.map(
          (AppListTableColumn<MortuaryWorkspaceItem> column) => column.id,
        ),
        <String>['deceased', 'event', 'actor', 'date', 'status'],
      );
      expect(find.textContaining('no access'), findsNothing);

      await _openDetail(tester);
      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('Custody'), findsWidgets);
      expect(find.text('Actions unavailable'), findsNothing);
      expect(find.text('Receive case'), findsNothing);
      expect(find.text('Record custody'), findsNothing);
      expect(find.text('Approve release'), findsNothing);
      expect(find.text('Request post-mortem'), findsNothing);
      expect(find.text('Print documents'), findsNothing);
      expect(find.text('Billing'), findsNothing);
    });

    testWidgets(
      'intersection denial: read without billing ∩ omits billing panel',
      (WidgetTester tester) async {
        await _pumpCustodyTab(
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
      'intersection denial: billing_event without billing:read omits panel',
      (WidgetTester tester) async {
        await _pumpCustodyTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryBillingEvent,
            },
          ),
        );
        await _openDetail(tester);

        expect(find.text('Billing'), findsNothing);
        expect(find.text('Cold storage day 1'), findsNothing);
      },
    );

    testWidgets(
      'full billing intersection mounts billing events panel',
      (WidgetTester tester) async {
        await _pumpCustodyTab(
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
        await _pumpCustodyTab(
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
        await _pumpCustodyTab(
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
        await _pumpCustodyTab(
          tester,
          repository: repository,
          policy: _reportsExportUnionPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Print documents'), findsOneWidget);
      },
    );

    testWidgets(
      'nested write chrome absent without nested ∪ rights (and when granted)',
      (WidgetTester tester) async {
        await _pumpCustodyTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
        );
        await _openDetail(tester);
        expect(find.text('Record custody'), findsNothing);
        expect(find.text('Request post-mortem'), findsNothing);
        expect(find.text('Approve post-mortem'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        await _pumpCustodyTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryPostMortemRequest,
              AppPermissions.mortuaryApprove,
              AppPermissions.mortuaryWrite,
            },
          ),
        );
        await _openDetail(tester);
        // Inventory removed no-op mutation chrome — still absent when granted.
        expect(find.text('Record custody'), findsNothing);
        expect(find.text('Request post-mortem'), findsNothing);
        expect(find.text('Approve post-mortem'), findsNothing);
        expect(
          canWriteMortuaryNestedWorkflow(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.mortuaryRead,
                AppPermissions.mortuaryPostMortemRequest,
              },
            ),
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'subscription denial: permissions without mortuary module show forbidden',
      (WidgetTester tester) async {
        await _pumpCustodyTab(
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
      await _pumpCustodyTab(
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
                id: mortuaryPanelCustody,
                count: 0,
                defaultResource: mortuaryResourceCustodyEvents,
              ),
            ],
            filters: const MortuaryWorkspaceQuery(panel: mortuaryPanelCustody),
            lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
          ),
        ),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Custody'), findsWidgets);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      expect(find.text('Record custody'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('authorized error/retry reloads custody and syncs list', (
      WidgetTester tester,
    ) async {
      var failed = false;
      when(() => repository.getWorkspace(any())).thenAnswer((
        Invocation invocation,
      ) async {
        if (!failed) {
          failed = true;
          return const Result<MortuaryWorkspacePayload>.failure(
            AppFailure.network(),
          );
        }
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
        (_) async => const Result<MortuaryWorkspaceItem>.success(_custodyItem),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/mortuary?panel=custody',
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
            appAccessPolicyProvider.overrideWithValue(_readPolicy()),
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
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.textContaining('Try again').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Custody'), findsWidgets);
      expect(find.text('Custody Patient'), findsWidgets);
      final List<dynamic> calls = verify(
        () => repository.getWorkspace(any()),
      ).captured;
      expect(calls.length, greaterThanOrEqualTo(2));
    });

    testWidgets('mobile viewport keeps custody strip and worklist', (
      WidgetTester tester,
    ) async {
      await _pumpCustodyTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        viewport: const Size(390, 844),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Custody'), findsWidgets);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      expect(find.text('Record custody'), findsNothing);
    });

    testWidgets('desktop light theme mounts custody authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpCustodyTab(
        tester,
        repository: repository,
        policy: _exportPolicy(),
        themeMode: ThemeMode.light,
        viewport: const Size(1440, 900),
      );

      expect(find.text('Custody'), findsWidgets);
      await _openDetail(tester);
      expect(find.text('Print documents'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Custody').first)).brightness,
        Brightness.light,
      );
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('desktop dark theme mounts custody authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpCustodyTab(
        tester,
        repository: repository,
        policy: _exportPolicy(),
        themeMode: ThemeMode.dark,
        viewport: const Size(1440, 900),
      );

      expect(find.text('Custody'), findsWidgets);
      await _openDetail(tester);
      expect(find.text('Print documents'), findsOneWidget);
      expect(Theme.of(tester.element(find.text('Custody').first)).brightness,
          Brightness.dark);
    });

    testWidgets(
      'post-mutation sync: detail reload uses repository after row select',
      (WidgetTester tester) async {
        await _pumpCustodyTab(
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
        expect(find.text('Record custody'), findsNothing);
      },
    );
  });
}
