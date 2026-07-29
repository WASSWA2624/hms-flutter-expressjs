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

const MortuaryWorkspaceItem _reportsItem = MortuaryWorkspaceItem(
  id: 'pm-1',
  displayId: 'MOR-PM-1',
  resource: mortuaryResourcePostMortemRequests,
  status: 'SCHEDULED',
  identificationStatus: 'VERIFIED',
  billingStatus: 'UNSETTLED',
  deceasedProfileLabel: 'Reports Patient',
  requestReason: 'Coroner request',
  diagnosticsReferenceId: 'DX-9',
  requestedByName: 'Dr. A',
  scheduledAt: null,
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

AppAccessPolicy _auditOnlyPolicy() {
  return _policy(permissions: <AppPermission>{AppPermissions.mortuaryAudit});
}

AppAccessPolicy _exportOnlyPolicy() {
  return _policy(permissions: <AppPermission>{AppPermissions.mortuaryExport});
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
      items: const <MortuaryWorkspaceItem>[_reportsItem],
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
        count: 1,
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
    (_) async => const Result<MortuaryWorkspaceItem>.success(_reportsItem),
  );
}

Future<GoRouter> _pumpReportsTab(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/mortuary?panel=reporting',
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
  table.onRowSelected!(_reportsItem);
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

  group('MortuaryReportsAtomPermissions helpers', () {
    test('reuses feature *Requirement vocabulary (no second map)', () {
      expect(
        identical(
          MortuaryReportsAtomPermissions.tab,
          mortuaryReportsTabReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReportsAtomPermissions.read,
          mortuaryWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReportsAtomPermissions.write,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReportsAtomPermissions.nestedWrite,
          mortuaryReportsNestedExportWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReportsAtomPermissions.printDocuments,
          mortuaryExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReportsAtomPermissions.audit,
          mortuaryAuditRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReportsAtomPermissions.billingPanel,
          mortuaryBillingPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReportsAtomPermissions.routeEntry,
          RouteAccessCatalog.mortuaryEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryReportsAtomPermissions.routeEntry,
          AppRoutes.mortuary.accessRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelTabRequirement(mortuaryPanelReporting),
          MortuaryReportsAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelPrintRequirement(mortuaryPanelReporting),
          MortuaryReportsAtomPermissions.printDocuments,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelBillingRequirement(mortuaryPanelReporting),
          MortuaryReportsAtomPermissions.billingPanel,
        ),
        isTrue,
      );
    });

    test('intersection denial: ∩ mortuary:read fails without that key', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryWrite},
      );
      expect(MortuaryReportsAtomPermissions.read.isAllowed(writeOnly), isFalse);
      expect(MortuaryReportsAtomPermissions.create.isAllowed(writeOnly), isTrue);
      expect(canEnterMortuaryWorkspace(writeOnly), isTrue);
      // Reports tab ∪ still denied — write is not in read|audit|export.
      expect(MortuaryReportsAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(canViewMortuaryPanel(writeOnly, mortuaryPanelReporting), isFalse);
    });

    test('full ∩ read set allows Reports tab and list chrome', () {
      final AppAccessPolicy read = _readPolicy();
      expect(MortuaryReportsAtomPermissions.tab.isAllowed(read), isTrue);
      expect(MortuaryReportsAtomPermissions.listChrome.isAllowed(read), isTrue);
      expect(MortuaryReportsAtomPermissions.create.isAllowed(read), isFalse);
      expect(MortuaryReportsAtomPermissions.nestedWrite.isAllowed(read), isFalse);
      expect(MortuaryReportsAtomPermissions.audit.isAllowed(read), isFalse);
    });

    test('union: Reports tab allows read | audit | export', () {
      expect(canViewMortuaryReportsTab(_readPolicy()), isTrue);
      expect(canViewMortuaryReportsTab(_auditOnlyPolicy()), isTrue);
      expect(canViewMortuaryReportsTab(_exportOnlyPolicy()), isTrue);
      expect(
        canViewMortuaryReportsTab(
          _policy(permissions: <AppPermission>{AppPermissions.mortuaryWrite}),
        ),
        isFalse,
      );
      expect(
        mortuaryAllowedPanels(_auditOnlyPolicy()),
        <String>[mortuaryPanelReporting],
      );
      expect(
        mortuaryAllowedPanels(_exportOnlyPolicy()),
        <String>[mortuaryPanelReporting],
      );
      // Source route entry ∪ excludes export alone — gate blocks workspace.
      expect(canEnterMortuaryWorkspace(_exportOnlyPolicy()), isFalse);
      expect(canEnterMortuaryWorkspace(_auditOnlyPolicy()), isTrue);
    });

    test(
      'union: source print keeps mortuary:export | reports:read; '
      'matrix nested write is mortuary:export only',
      () {
        expect(canExportMortuary(_exportPolicy()), isTrue);
        expect(canExportMortuary(_reportsExportUnionPolicy()), isTrue);
        expect(canExportMortuary(_readPolicy()), isFalse);
        expect(canWriteMortuaryReportsNestedExport(_exportOnlyPolicy()), isTrue);
        expect(
          canWriteMortuaryReportsNestedExport(_reportsExportUnionPolicy()),
          isFalse,
        );
        expect(canWriteMortuaryReportsNestedExport(_readPolicy()), isFalse);
      },
    );

    test('subscription strips Reports tab when mortuary module inactive', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryExport,
          AppPermissions.mortuaryAudit,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(MortuaryReportsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canEnterMortuaryWorkspace(noModule), isFalse);
    });

    test('ABAC facility context required for Reports tab', () {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRead},
        facilityId: null,
      );
      expect(MortuaryReportsAtomPermissions.tab.isAllowed(noFacility), isFalse);
    });
  });

  group('Reports tab UI gates', () {
    testWidgets('authorized read mounts Reports tab, list chrome, row select', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpReportsTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
      );

      expect(router.state.uri.queryParameters['panel'], 'reporting');
      expect(find.text('Reports'), findsWidgets);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(_table(tester).columnVisibilityStorageKey, 'mortuary_reporting');
      expect(
        _table(tester).columns.map(
          (AppListTableColumn<MortuaryWorkspaceItem> column) => column.id,
        ),
        <String>['deceased', 'request', 'scheduled', 'status', 'next_action'],
      );

      await _openDetail(tester);
      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.text('Actions unavailable'), findsNothing);
      expect(find.text('Receive case'), findsNothing);
      expect(find.text('Approve release'), findsNothing);
      expect(find.text('Request post-mortem'), findsNothing);
    });

    testWidgets(
      'union allowance: audit-only mounts Reports strip (not Overview)',
      (WidgetTester tester) async {
        await _pumpReportsTab(
          tester,
          repository: repository,
          policy: _auditOnlyPolicy(),
        );

        expect(find.text('Reports'), findsWidgets);
        expect(find.text('Overview'), findsNothing);
        expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
      },
    );

    testWidgets(
      'union allowance: export via route-entry companion mounts Reports + print',
      (WidgetTester tester) async {
        // Route entry ∪ excludes mortuary:export alone (source inventory);
        // approve grants entry, export ∪ unlocks Reports strip + print.
        await _pumpReportsTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryApprove,
              AppPermissions.mortuaryExport,
            },
          ),
        );

        expect(find.text('Reports'), findsWidgets);
        expect(find.text('Overview'), findsNothing);
        expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
        await _openDetail(tester);
        expect(find.text('Print documents'), findsOneWidget);
      },
    );

    testWidgets(
      'intersection denial: read without billing ∩ omits billing panel',
      (WidgetTester tester) async {
        await _pumpReportsTab(
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
        await _pumpReportsTab(
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
        await _pumpReportsTab(
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
        await _pumpReportsTab(
          tester,
          repository: repository,
          policy: _exportPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Print documents'), findsOneWidget);
      },
    );

    testWidgets(
      'union allowance: reports:read mounts print (source gate note)',
      (WidgetTester tester) async {
        await _pumpReportsTab(
          tester,
          repository: repository,
          policy: _reportsExportUnionPolicy(),
        );
        await _openDetail(tester);

        expect(find.text('Print documents'), findsOneWidget);
        // Matrix nested write is mortuary:export only — reports:read alone
        // does not satisfy nestedWrite; source print ∪ still allows print.
        expect(
          MortuaryReportsAtomPermissions.nestedWrite.isAllowed(
            _reportsExportUnionPolicy(),
          ),
          isFalse,
        );
      },
    );

    testWidgets(
      'nested export / mutation chrome absent without rights (and when granted)',
      (WidgetTester tester) async {
        await _pumpReportsTab(
          tester,
          repository: repository,
          policy: _readPolicy(),
        );
        await _openDetail(tester);
        expect(find.text('Export report'), findsNothing);
        expect(find.text('Receive case'), findsNothing);
        expect(find.text('Request post-mortem'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        await _pumpReportsTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryWrite,
              AppPermissions.mortuaryExport,
              AppPermissions.mortuaryAudit,
            },
          ),
        );
        await _openDetail(tester);
        // Inventory removed no-op mutation chrome — still absent when granted.
        expect(find.text('Export report'), findsNothing);
        expect(find.text('Receive case'), findsNothing);
        expect(find.text('Request post-mortem'), findsNothing);
        expect(find.text('Print documents'), findsOneWidget);
        expect(canWriteMortuaryReportsNestedExport(_exportOnlyPolicy()), isTrue);
        expect(canAuditMortuary(_auditOnlyPolicy()), isTrue);
      },
    );

    testWidgets(
      'subscription denial: permissions without mortuary module show forbidden',
      (WidgetTester tester) async {
        await _pumpReportsTab(
          tester,
          repository: repository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.mortuaryRead,
              AppPermissions.mortuaryExport,
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
      await _pumpReportsTab(
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
                id: mortuaryPanelReporting,
                count: 0,
                defaultResource: mortuaryResourcePostMortemRequests,
              ),
            ],
            filters: const MortuaryWorkspaceQuery(panel: mortuaryPanelReporting),
            lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
          ),
        ),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Reports'), findsWidgets);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpReportsTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        workspaceOverride: const Result<MortuaryWorkspacePayload>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('mobile viewport keeps Reports strip and worklist', (
      WidgetTester tester,
    ) async {
      await _pumpReportsTab(
        tester,
        repository: repository,
        policy: _readPolicy(),
        viewport: const Size(390, 844),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Reports'), findsWidgets);
      expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
    });

    testWidgets('desktop dark theme mounts Reports authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpReportsTab(
        tester,
        repository: repository,
        policy: _exportPolicy(),
        themeMode: ThemeMode.dark,
        viewport: const Size(1440, 900),
      );

      expect(find.text('Reports'), findsWidgets);
      await _openDetail(tester);
      expect(find.text('Print documents'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Reports').first)).brightness,
        Brightness.dark,
      );
    });

    testWidgets(
      'post-mutation sync: detail reload uses repository after row select',
      (WidgetTester tester) async {
        await _pumpReportsTab(
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
  });
}
