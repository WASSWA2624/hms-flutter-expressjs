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

const MortuaryWorkspaceItem _releaseItem = MortuaryWorkspaceItem(
  id: 'release-1',
  displayId: 'MOR-REL-1',
  resource: mortuaryResourceReleaseAuthorisations,
  status: 'READY_FOR_RELEASE',
  identificationStatus: 'VERIFIED',
  billingStatus: 'SETTLED',
  deceasedProfileLabel: 'Release Patient',
  recipientName: 'Next of Kin',
  recipientRelationship: 'Spouse',
  storageLabel: 'Cold Bay A-1',
  billableEvents: <MortuaryBillableEvent>[_billableEvent],
  releaseAuthorisations: <MortuaryReleaseAuthorisation>[
    MortuaryReleaseAuthorisation(
      id: 'auth-1',
      status: 'PENDING_APPROVAL',
      recipientName: 'Next of Kin',
      recipientRelationship: 'Spouse',
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

AppAccessPolicy _readReleasePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.mortuaryRead,
      AppPermissions.mortuaryRelease,
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
      items: const <MortuaryWorkspaceItem>[_releaseItem],
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
        count: 1,
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
    (_) async => const Result<MortuaryWorkspaceItem>.success(_releaseItem),
  );
}

Future<GoRouter> _pumpReleaseTab(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/mortuary?panel=release',
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
  table.onRowSelected!(_releaseItem);
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

  group('MortuaryReleaseAtomPermissions inventory (AC1)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          MortuaryReleaseAtomPermissions.tab,
          mortuaryWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReleaseAtomPermissions.create,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReleaseAtomPermissions.delete,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReleaseAtomPermissions.update,
          mortuaryReleaseRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReleaseAtomPermissions.release,
          mortuaryReleaseRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReleaseAtomPermissions.approve,
          mortuaryApproveRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReleaseAtomPermissions.success,
          mortuaryReleaseRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReleaseAtomPermissions.printDocuments,
          mortuaryExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReleaseAtomPermissions.billingPanel,
          mortuaryBillingPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReleaseAtomPermissions.routeEntry,
          RouteAccessCatalog.mortuaryEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReleaseAtomPermissions.routeEntry,
          AppRoutes.mortuary.accessRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelTabRequirement(mortuaryPanelRelease),
          MortuaryReleaseAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelPrintRequirement(mortuaryPanelRelease),
          MortuaryReleaseAtomPermissions.printDocuments,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelBillingRequirement(mortuaryPanelRelease),
          MortuaryReleaseAtomPermissions.billingPanel,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing mortuary:read fails tab; ∪ route entry allows', () {
      final AppAccessPolicy releaseOnly = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRelease},
      );
      expect(
        MortuaryReleaseAtomPermissions.routeEntry.isAllowed(releaseOnly),
        isTrue,
      );
      expect(MortuaryReleaseAtomPermissions.tab.isAllowed(releaseOnly), isFalse);
      expect(
        MortuaryReleaseAtomPermissions.update.isAllowed(releaseOnly),
        isTrue,
      );
      expect(
        MortuaryReleaseAtomPermissions.release.isAllowed(releaseOnly),
        isTrue,
      );
      expect(canViewMortuaryPanel(releaseOnly, mortuaryPanelRelease), isFalse);
      expect(canEnterMortuaryWorkspace(releaseOnly), isTrue);
      expect(canReleaseMortuary(releaseOnly), isTrue);
    });

    test('full ∩ read grants list chrome; write/release/export denied', () {
      final AppAccessPolicy reader = _readPolicy();
      expect(MortuaryReleaseAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(MortuaryReleaseAtomPermissions.search.isAllowed(reader), isTrue);
      expect(MortuaryReleaseAtomPermissions.filters.isAllowed(reader), isTrue);
      expect(
        MortuaryReleaseAtomPermissions.rowSelect.isAllowed(reader),
        isTrue,
      );
      expect(MortuaryReleaseAtomPermissions.detail.isAllowed(reader), isTrue);
      expect(MortuaryReleaseAtomPermissions.create.isAllowed(reader), isFalse);
      expect(MortuaryReleaseAtomPermissions.update.isAllowed(reader), isFalse);
      expect(MortuaryReleaseAtomPermissions.release.isAllowed(reader), isFalse);
      expect(MortuaryReleaseAtomPermissions.approve.isAllowed(reader), isFalse);
      expect(MortuaryReleaseAtomPermissions.success.isAllowed(reader), isFalse);
      expect(
        MortuaryReleaseAtomPermissions.printDocuments.isAllowed(reader),
        isFalse,
      );
      expect(
        MortuaryReleaseAtomPermissions.billingPanel.isAllowed(reader),
        isFalse,
      );
    });

    test('matrix update ∩ mortuary:release; create/delete ∩ write', () {
      final AppAccessPolicy releaser = _readReleasePolicy();
      final AppAccessPolicy writer = _readWritePolicy();
      expect(MortuaryReleaseAtomPermissions.update.isAllowed(releaser), isTrue);
      expect(MortuaryReleaseAtomPermissions.create.isAllowed(releaser), isFalse);
      expect(MortuaryReleaseAtomPermissions.delete.isAllowed(releaser), isFalse);
      expect(MortuaryReleaseAtomPermissions.create.isAllowed(writer), isTrue);
      expect(MortuaryReleaseAtomPermissions.delete.isAllowed(writer), isTrue);
      expect(MortuaryReleaseAtomPermissions.update.isAllowed(writer), isFalse);
    });

    test('∩ billing panel needs mortuary:billing_event and billing:read', () {
      final AppAccessPolicy mortuaryBillingOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryBillingEvent,
        },
      );
      expect(
        MortuaryReleaseAtomPermissions.billingPanel.isAllowed(
          mortuaryBillingOnly,
        ),
        isFalse,
      );
      expect(
        MortuaryReleaseAtomPermissions.billingPanel.isAllowed(
          _billingPanelPolicy(),
        ),
        isTrue,
      );
    });

    test('∪ export allows mortuary:export or reports:read', () {
      expect(
        MortuaryReleaseAtomPermissions.printDocuments.isAllowed(_exportPolicy()),
        isTrue,
      );
      expect(
        MortuaryReleaseAtomPermissions.printDocuments.isAllowed(
          _reportsExportUnionPolicy(),
        ),
        isTrue,
      );
      expect(
        MortuaryReleaseAtomPermissions.printDocuments.isAllowed(_readPolicy()),
        isFalse,
      );
    });

    test('nested cross-module matrix rows are n/a (no nested write map)', () {
      // Release matrix nested cross-module read/write are n/a — no second
      // vocabulary; within-module approve/release remain fine-grained ∩.
      expect(MortuaryReleaseAtomPermissions.approve, isNotNull);
      expect(MortuaryReleaseAtomPermissions.release, isNotNull);
      expect(
        MortuaryReleaseAtomPermissions.nestedRead,
        mortuaryWorkspaceReadRequirement,
      );
    });

    test('subscription/ABAC strip module, BASIC plan, or facility', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryRelease,
        },
        modules: const <AppModuleEntitlement>[],
      );
      final AppAccessPolicy basicPlan = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryRelease,
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
      expect(MortuaryReleaseAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(MortuaryReleaseAtomPermissions.tab.isAllowed(basicPlan), isFalse);
      expect(
        MortuaryReleaseAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
      expect(MortuaryReleaseAtomPermissions.tab.isAllowed(noFacility), isFalse);
    });
  });

  group('Release tab UI gates', () {
    testWidgets('authorized read mounts Release tab, list chrome, row select', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpReleaseTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
      );

      expect(router.state.uri.queryParameters['panel'], 'release');
      expect(_tab('Release'), findsOneWidget);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(_table(tester).columnVisibilityStorageKey, 'mortuary_release');
      expect(
        _table(tester).columns.map(
          (AppListTableColumn<MortuaryWorkspaceItem> column) => column.id,
        ),
        <String>['deceased', 'recipient', 'status', 'date', 'next_action'],
      );
      expect(find.text('Release Patient'), findsWidgets);
      expect(find.text('Next of Kin'), findsWidgets);

      await _openDetail(tester);
      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.text('Actions unavailable'), findsNothing);
      expect(find.text('Receive case'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Approve release'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Assign storage'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      '∩ denial: read without release omits mutation chrome; update denied',
      (WidgetTester tester) async {
        expect(
          MortuaryReleaseAtomPermissions.update.isAllowed(_readPolicy()),
          isFalse,
        );
        await _pumpReleaseTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
        );

        expect(_tab('Release'), findsOneWidget);
        expect(find.text('Receive case'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Approve release'), findsNothing);

        await _openDetail(tester);
        expect(find.text('Print documents'), findsNothing);
        expect(find.text('Billing'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Approve release'), findsNothing);
      },
    );

    testWidgets(
      'full ∩ release grants update helper; mutation chrome still unmounted',
      (WidgetTester tester) async {
        expect(
          MortuaryReleaseAtomPermissions.update.isAllowed(_readReleasePolicy()),
          isTrue,
        );
        expect(
          MortuaryReleaseAtomPermissions.approve.isAllowed(_readReleasePolicy()),
          isFalse,
        );

        await _pumpReleaseTab(
          tester,
          repository: repository,
          policy: _readReleasePolicy(),
        );
        await _openDetail(tester);

        // Inventory removed no-op mutation chrome — absent even when granted.
        expect(find.widgetWithText(FilledButton, 'Approve release'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'intersection denial: read without billing ∩ omits billing panel',
      (WidgetTester tester) async {
        await _pumpReleaseTab(
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

    testWidgets('full billing intersection mounts billing events panel', (
      WidgetTester tester,
    ) async {
      await _pumpReleaseTab(
        tester,
        repository: repository,
        policy: _billingPanelPolicy(),
      );
      await _openDetail(tester);

      expect(find.text('Billing'), findsOneWidget);
      expect(find.textContaining('Cold storage day 1'), findsOneWidget);
    });

    testWidgets(
      'intersection denial: missing export omits print documents',
      (WidgetTester tester) async {
        await _pumpReleaseTab(
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
        await _pumpReleaseTab(
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
        await _pumpReleaseTab(
          tester,
          repository: repository,
          policy: _reportsExportUnionPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Print documents'), findsOneWidget);
      },
    );

    testWidgets(
      'nested cross-module UI absent (matrix n/a); within-module write absent',
      (WidgetTester tester) async {
        await _pumpReleaseTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryWrite,
              AppPermissions.mortuaryRelease,
              AppPermissions.mortuaryApprove,
            },
          ),
        );
        await _openDetail(tester);

        expect(find.text('Receive case'), findsNothing);
        expect(find.text('Record custody'), findsNothing);
        expect(find.text('Request post-mortem'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Approve release'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Assign storage'), findsNothing);
      },
    );

    testWidgets(
      'subscription denial: permissions without mortuary module show forbidden',
      (WidgetTester tester) async {
        await _pumpReleaseTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryRelease,
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
      await _pumpReleaseTab(
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
                id: mortuaryPanelRelease,
                count: 0,
                defaultResource: mortuaryResourceReleaseAuthorisations,
              ),
            ],
            filters: const MortuaryWorkspaceQuery(panel: mortuaryPanelRelease),
            lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
          ),
        ),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_tab('Release'), findsOneWidget);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpReleaseTab(
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

    testWidgets('mobile viewport keeps Release strip and worklist', (
      WidgetTester tester,
    ) async {
      await _pumpReleaseTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        viewport: const Size(390, 844),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_tab('Release'), findsOneWidget);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      expect(find.text('Release Patient'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'Approve release'), findsNothing);
    });

    testWidgets('desktop dark theme mounts Release authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpReleaseTab(
        tester,
        repository: repository,
        policy: _exportPolicy(),
        themeMode: ThemeMode.dark,
        viewport: const Size(1440, 900),
      );

      expect(_tab('Release'), findsOneWidget);
      await _openDetail(tester);
      expect(find.text('Print documents'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Release').first)).brightness,
        Brightness.dark,
      );
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      'post-mutation sync: detail reload uses repository after row select',
      (WidgetTester tester) async {
        await _pumpReleaseTab(
          tester,
          repository: repository,
          policy: _readReleasePolicy(),
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
        expect(find.text('Release'), findsWidgets);
      },
    );

    testWidgets('deep link panel=release selects Release for authorized reader', (
      WidgetTester tester,
    ) async {
      await _pumpReleaseTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
      );

      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      expect(strip.selectedId, mortuaryPanelRelease);
      expect(_table(tester).columnVisibilityStorageKey, 'mortuary_release');
    });
  });
}
