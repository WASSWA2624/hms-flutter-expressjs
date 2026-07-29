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

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

const MortuaryBillableEvent _billableEvent = MortuaryBillableEvent(
  id: 'bill-1',
  eventType: 'STORAGE_FEE',
  description: 'Cold storage day 1',
  amountText: '50.00',
  currency: 'UGX',
  status: 'OPEN',
);

const MortuaryWorkspaceItem _storageItem = MortuaryWorkspaceItem(
  id: 'storage-1',
  displayId: 'MOR-STO-1',
  resource: mortuaryResourceStorageAssignments,
  status: 'IN_STORAGE',
  identificationStatus: 'VERIFIED',
  billingStatus: 'UNSETTLED',
  deceasedProfileLabel: 'Storage Patient',
  storageUnitLabel: 'Cold Unit A',
  storageSlotLabel: 'Slot 12',
  storageSlotStatus: 'OCCUPIED',
  billableEvents: <MortuaryBillableEvent>[_billableEvent],
  storageAssignment: MortuaryStorageAssignment(
    id: 'assign-1',
    status: 'ACTIVE',
    storageUnitLabel: 'Cold Unit A',
    storageSlotLabel: 'Slot 12',
    storageSlotStatus: 'OCCUPIED',
  ),
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

AppAccessPolicy _manageStoragePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.mortuaryManageStorage,
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
      items: const <MortuaryWorkspaceItem>[_storageItem],
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
        count: 1,
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
    (_) async => const Result<MortuaryWorkspaceItem>.success(_storageItem),
  );
}

Future<GoRouter> _pumpStorageTab(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/mortuary?panel=storage',
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
  table.onRowSelected!(_storageItem);
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

  group('MortuaryStorageAtomPermissions inventory (AC1)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          MortuaryStorageAtomPermissions.tab,
          mortuaryWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryStorageAtomPermissions.create,
          mortuaryManageStorageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryStorageAtomPermissions.update,
          mortuaryManageStorageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryStorageAtomPermissions.assignStorage,
          mortuaryManageStorageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryStorageAtomPermissions.manageStorage,
          mortuaryManageStorageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryStorageAtomPermissions.delete,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryStorageAtomPermissions.success,
          mortuaryManageStorageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryStorageAtomPermissions.printDocuments,
          mortuaryExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryStorageAtomPermissions.billingPanel,
          mortuaryBillingPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryStorageAtomPermissions.routeEntry,
          RouteAccessCatalog.mortuaryEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryStorageAtomPermissions.routeEntry,
          AppRoutes.mortuary.accessRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelTabRequirement(mortuaryPanelStorage),
          MortuaryStorageAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelPrintRequirement(mortuaryPanelStorage),
          MortuaryStorageAtomPermissions.printDocuments,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelBillingRequirement(mortuaryPanelStorage),
          MortuaryStorageAtomPermissions.billingPanel,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing mortuary:read fails tab; write-only still enters', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryWrite},
      );
      expect(MortuaryStorageAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canViewMortuaryPanel(writeOnly, mortuaryPanelStorage), isFalse);
      expect(MortuaryStorageAtomPermissions.delete.isAllowed(writeOnly), isTrue);
      expect(MortuaryStorageAtomPermissions.create.isAllowed(writeOnly), isFalse);
      expect(canEnterMortuaryWorkspace(writeOnly), isTrue);
    });

    test('full ∩ read grants list chrome; manage_storage/export denied', () {
      final AppAccessPolicy read = _readPolicy();
      expect(MortuaryStorageAtomPermissions.tab.isAllowed(read), isTrue);
      expect(MortuaryStorageAtomPermissions.listChrome.isAllowed(read), isTrue);
      expect(MortuaryStorageAtomPermissions.search.isAllowed(read), isTrue);
      expect(MortuaryStorageAtomPermissions.rowSelect.isAllowed(read), isTrue);
      expect(MortuaryStorageAtomPermissions.create.isAllowed(read), isFalse);
      expect(MortuaryStorageAtomPermissions.update.isAllowed(read), isFalse);
      expect(MortuaryStorageAtomPermissions.assignStorage.isAllowed(read), isFalse);
      expect(MortuaryStorageAtomPermissions.delete.isAllowed(read), isFalse);
      expect(MortuaryStorageAtomPermissions.success.isAllowed(read), isFalse);
      expect(
        MortuaryStorageAtomPermissions.printDocuments.isAllowed(read),
        isFalse,
      );
      expect(
        MortuaryStorageAtomPermissions.billingPanel.isAllowed(read),
        isFalse,
      );
    });

    test('∩ create/update need manage_storage; delete needs write', () {
      final AppAccessPolicy manager = _manageStoragePolicy();
      final AppAccessPolicy writer = _readWritePolicy();
      expect(MortuaryStorageAtomPermissions.create.isAllowed(manager), isTrue);
      expect(MortuaryStorageAtomPermissions.update.isAllowed(manager), isTrue);
      expect(MortuaryStorageAtomPermissions.assignStorage.isAllowed(manager), isTrue);
      expect(MortuaryStorageAtomPermissions.delete.isAllowed(manager), isFalse);
      expect(MortuaryStorageAtomPermissions.create.isAllowed(writer), isFalse);
      expect(MortuaryStorageAtomPermissions.delete.isAllowed(writer), isTrue);
    });

    test('∪ export allows mortuary:export or reports:read', () {
      expect(
        MortuaryStorageAtomPermissions.printDocuments.isAllowed(_exportPolicy()),
        isTrue,
      );
      expect(
        MortuaryStorageAtomPermissions.printDocuments.isAllowed(
          _reportsExportUnionPolicy(),
        ),
        isTrue,
      );
      expect(
        MortuaryStorageAtomPermissions.printDocuments.isAllowed(_readPolicy()),
        isFalse,
      );
    });

    test('∩ billing panel needs mortuary:billing_event and billing:read', () {
      final AppAccessPolicy mortuaryBillingOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryBillingEvent,
        },
      );
      expect(
        MortuaryStorageAtomPermissions.billingPanel.isAllowed(
          mortuaryBillingOnly,
        ),
        isFalse,
      );
      expect(
        MortuaryStorageAtomPermissions.billingPanel.isAllowed(
          _billingPanelPolicy(),
        ),
        isTrue,
      );
    });

    test('subscription/ABAC strip module or facility from tab gate', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryManageStorage,
        },
        modules: const <AppModuleEntitlement>[],
      );
      final AppAccessPolicy basicPlan = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryManageStorage,
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
      expect(MortuaryStorageAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(MortuaryStorageAtomPermissions.tab.isAllowed(basicPlan), isFalse);
      expect(canEnterMortuaryWorkspace(noModule), isFalse);
      expect(MortuaryStorageAtomPermissions.tab.isAllowed(noFacility), isFalse);
    });
  });

  group('Storage tab UI gates', () {
    testWidgets('authorized read mounts Storage tab, list chrome, row select', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpStorageTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
      );

      expect(router.state.uri.queryParameters['panel'], 'storage');
      expect(_tab('Storage'), findsOneWidget);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Storage Patient'), findsWidgets);
      expect(_table(tester).columnVisibilityStorageKey, 'mortuary_storage');
      expect(
        _table(tester).columns.map(
          (AppListTableColumn<MortuaryWorkspaceItem> column) => column.id,
        ),
        <String>['deceased', 'storage', 'status', 'date', 'next_action'],
      );

      await _openDetail(tester);
      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.text('Actions unavailable'), findsNothing);
      expect(find.text('Assign storage'), findsNothing);
      expect(find.text('Receive case'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      '∩ denial: read without manage_storage omits Assign storage',
      (WidgetTester tester) async {
        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Assign storage'), findsNothing);
        expect(find.text('Print documents'), findsNothing);
        expect(find.text('Billing'), findsNothing);
      },
    );

    testWidgets(
      'full ∩ manage_storage: Assign storage still absent (not mounted)',
      (WidgetTester tester) async {
        expect(
          MortuaryStorageAtomPermissions.assignStorage.isAllowed(
            _manageStoragePolicy(),
          ),
          isTrue,
        );

        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _manageStoragePolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Assign storage'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      '∩ denial: read without billing ∩ omits billing panel',
      (WidgetTester tester) async {
        await _pumpStorageTab(
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
        await _pumpStorageTab(
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
      '∩ denial: missing export omits print documents',
      (WidgetTester tester) async {
        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Print documents'), findsNothing);
      },
    );

    testWidgets(
      '∪ allowance: mortuary:export mounts print documents',
      (WidgetTester tester) async {
        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _exportPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Print documents'), findsOneWidget);
      },
    );

    testWidgets(
      '∪ allowance: reports:read mounts print documents',
      (WidgetTester tester) async {
        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _reportsExportUnionPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Print documents'), findsOneWidget);
      },
    );

    testWidgets(
      'nested cross-module write n/a: mutation chrome absent with/without rights',
      (WidgetTester tester) async {
        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
        );
        await _openDetail(tester);
        expect(find.text('Assign storage'), findsNothing);
        expect(find.text('Record custody'), findsNothing);
        expect(find.text('Request post-mortem'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryManageStorage,
              AppPermissions.mortuaryWrite,
              AppPermissions.mortuaryApprove,
              AppPermissions.mortuaryRelease,
            },
          ),
        );
        await _openDetail(tester);
        expect(find.text('Assign storage'), findsNothing);
        expect(find.text('Approve release'), findsNothing);
        expect(find.text('Receive case'), findsNothing);
      },
    );

    testWidgets(
      'subscription denial: permissions without mortuary module show forbidden',
      (WidgetTester tester) async {
        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryManageStorage,
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
      await _pumpStorageTab(
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
                id: mortuaryPanelStorage,
                count: 0,
                defaultResource: mortuaryResourceStorageAssignments,
              ),
            ],
            filters: const MortuaryWorkspaceQuery(panel: mortuaryPanelStorage),
            lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
          ),
        ),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_tab('Storage'), findsOneWidget);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      expect(find.text('Assign storage'), findsNothing);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpStorageTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        workspaceOverride: const Result<MortuaryWorkspacePayload>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('mobile viewport keeps Storage strip and worklist', (
      WidgetTester tester,
    ) async {
      await _pumpStorageTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        viewport: const Size(390, 844),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_tab('Storage'), findsOneWidget);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      expect(find.text('Storage Patient'), findsWidgets);
      expect(find.text('Assign storage'), findsNothing);
    });

    testWidgets('desktop dark theme mounts Storage authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpStorageTab(
        tester,
        repository: repository,
        policy: _exportPolicy(),
        themeMode: ThemeMode.dark,
        viewport: const Size(1440, 900),
      );

      expect(_tab('Storage'), findsOneWidget);
      await _openDetail(tester);
      expect(find.text('Print documents'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Storage').first)).brightness,
        Brightness.dark,
      );
      expect(find.text('Assign storage'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      'post-mutation sync: detail reload uses repository after row select',
      (WidgetTester tester) async {
        await _pumpStorageTab(
          tester,
          repository: repository,
          policy: _manageStoragePolicy(),
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

    testWidgets('deep link panel=storage selects Storage for authorized reader', (
      WidgetTester tester,
    ) async {
      await _pumpStorageTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
      );

      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      expect(strip.selectedId, mortuaryPanelStorage);
      expect(_table(tester).columnVisibilityStorageKey, 'mortuary_storage');
    });
  });
}
