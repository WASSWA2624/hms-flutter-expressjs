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
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

const MortuaryWorkspaceItem _caseItem = MortuaryWorkspaceItem(
  id: 'case-1',
  displayId: 'MOR-001',
  status: 'IN_STORAGE',
  identificationStatus: 'VERIFIED',
  billingStatus: 'SETTLED',
  deceasedProfileLabel: 'Amina K.',
);

AppAccessPolicy _readPolicy({bool includeExport = false}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['MORTUARY_STAFF'],
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.mortuaryRead,
        if (includeExport) AppPermissions.mortuaryExport,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'mortuary', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

MortuaryWorkspacePayload _payload(MortuaryWorkspaceQuery query) {
  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: const <MortuaryWorkspaceItem>[_caseItem],
      request: query.pageRequest,
      totalItemCount: 1,
    ),
    lookups: const MortuaryLookupData(),
    summary: const <MortuarySummaryItem>[
      MortuarySummaryItem(id: 'total_cases', value: 1),
      MortuarySummaryItem(id: 'in_storage', value: 1),
      MortuarySummaryItem(id: 'identification_pending', value: 1),
      MortuarySummaryItem(id: 'release_ready', value: 1),
      MortuarySummaryItem(id: 'unsettled_billing', value: 1),
    ],
    queues: const <MortuaryQueueSummary>[
      MortuaryQueueSummary(
        queue: mortuaryQueueIdentificationPending,
        count: 1,
        panel: mortuaryPanelIntake,
        resource: mortuaryResourceCases,
      ),
      MortuaryQueueSummary(
        queue: mortuaryQueueStorageExceptions,
        count: 1,
        panel: mortuaryPanelStorage,
        resource: mortuaryResourceStorageAssignments,
      ),
      MortuaryQueueSummary(
        queue: mortuaryQueueReleaseReady,
        count: 1,
        panel: mortuaryPanelRelease,
        resource: mortuaryResourceReleaseAuthorisations,
      ),
      MortuaryQueueSummary(
        queue: mortuaryQueueUnsettledBilling,
        count: 1,
        panel: mortuaryPanelRelease,
        resource: mortuaryResourceBillableEvents,
      ),
      MortuaryQueueSummary(
        queue: mortuaryQueuePostMortemPending,
        count: 1,
        panel: mortuaryPanelReporting,
        resource: mortuaryResourcePostMortemRequests,
      ),
    ],
    panels: const <MortuaryPanelSummary>[
      MortuaryPanelSummary(
        id: mortuaryPanelOverview,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelIntake,
        count: 1,
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
    (_) async => const Result<MortuaryWorkspaceItem>.success(_caseItem),
  );
}

Future<void> _pumpMortuary(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  AppAccessPolicy? policy,
  MortuaryRouteQuery? initialQuery,
  String initialLocation = '/mortuary',
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
        path: '/mortuary',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: MortuaryWorkspacePage(
              initialQuery:
                  initialQuery ?? MortuaryRouteQuery.fromUri(state.uri),
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
        appAccessPolicyProvider.overrideWithValue(
          policy ?? _readPolicy(),
        ),
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

  testWidgets('tab strip has no Refresh control', (WidgetTester tester) async {
    await _pumpMortuary(tester, repository: repository);

    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
  });

  testWidgets('tab strip has no queue or in-storage shortcut chips', (
    WidgetTester tester,
  ) async {
    await _pumpMortuary(tester, repository: repository);

    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Identification pending'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('In storage'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Release ready'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Unsettled billing'),
      ),
      findsNothing,
    );
  });

  testWidgets('queue filter remains available via Filters dialog', (
    WidgetTester tester,
  ) async {
    await _pumpMortuary(tester, repository: repository);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Queue'), findsWidgets);
    expect(find.text('ADVANCED FILTERS'), findsOneWidget);
  });

  testWidgets('row select is the sole path into case detail', (
    WidgetTester tester,
  ) async {
    await _pumpMortuary(tester, repository: repository);

    await tester.tap(find.text('Assign storage'));
    await tester.pumpAndSettle();
    expect(find.text('CASE DETAIL'), findsNothing);

    final AppListTable<MortuaryWorkspaceItem> table = tester
        .widget<AppListTable<MortuaryWorkspaceItem>>(
          find.byType(AppListTable<MortuaryWorkspaceItem>),
        );
    expect(table.onRowSelected, isNotNull);
    table.onRowSelected!(_caseItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('CASE DETAIL'), findsOneWidget);
    expect(find.text('Actions unavailable'), findsNothing);
    expect(find.text('Receive case'), findsNothing);
    expect(find.text('Confirm release'), findsNothing);
  });

  testWidgets('unauthorized user has no print documents control', (
    WidgetTester tester,
  ) async {
    await _pumpMortuary(tester, repository: repository, policy: _readPolicy());

    final AppListTable<MortuaryWorkspaceItem> table = tester
        .widget<AppListTable<MortuaryWorkspaceItem>>(
          find.byType(AppListTable<MortuaryWorkspaceItem>),
        );
    table.onRowSelected!(_caseItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('CASE DETAIL'), findsOneWidget);
    expect(find.text('Print documents'), findsNothing);
  });

  testWidgets('authorized export user sees print documents', (
    WidgetTester tester,
  ) async {
    await _pumpMortuary(
      tester,
      repository: repository,
      policy: _readPolicy(includeExport: true),
    );

    final AppListTable<MortuaryWorkspaceItem> table = tester
        .widget<AppListTable<MortuaryWorkspaceItem>>(
          find.byType(AppListTable<MortuaryWorkspaceItem>),
        );
    table.onRowSelected!(_caseItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('CASE DETAIL'), findsOneWidget);
    expect(find.text('Print documents'), findsOneWidget);
  });

  testWidgets('deep link queue applies without toolbar shortcut', (
    WidgetTester tester,
  ) async {
    await _pumpMortuary(
      tester,
      repository: repository,
      initialLocation: '/mortuary?queue=IDENTIFICATION_PENDING',
      initialQuery: MortuaryRouteQuery.fromUri(
        Uri.parse('/mortuary?queue=IDENTIFICATION_PENDING'),
      ),
    );

    final List<MortuaryWorkspaceQuery> queries = verify(
      () => repository.getWorkspace(captureAny()),
    ).captured.cast<MortuaryWorkspaceQuery>();
    expect(
      queries.any(
        (MortuaryWorkspaceQuery q) =>
            q.queue == mortuaryQueueIdentificationPending,
      ),
      isTrue,
    );
    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.text('Identification pending'),
      ),
      findsNothing,
    );
  });
}
