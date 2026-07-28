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
import 'package:hosspi_hms/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/features/reports/presentation/pages/reports_workspace_page.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_workspace_table_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockReportsRepository extends Mock implements ReportsRepository {}

const ReportsWorkspaceItem _definitionItem = ReportsWorkspaceItem(
  id: 'definition-1',
  kind: ReportItemKind.definition,
  title: 'Daily census',
  subtitle: 'Census export',
  status: 'ACTIVE',
  reference: 'RPT-001',
  ownerLabel: 'Ops Lead',
);

const ReportsWorkspaceItem _scheduleItem = ReportsWorkspaceItem(
  id: 'schedule-1',
  kind: ReportItemKind.schedule,
  title: 'Daily census email',
  subtitle: 'Morning delivery',
  status: 'ACTIVE',
  format: 'PDF',
);

const ReportsWorkspaceItem _widgetItem = ReportsWorkspaceItem(
  id: 'widget-1',
  kind: ReportItemKind.dashboardWidget,
  title: 'Occupancy widget',
  status: 'ACTIVE',
);

AppAccessPolicy _reportsPolicy({
  bool write = false,
  bool export = false,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['REPORTING']),
      permissions: <AppPermission>{
        AppPermissions.reportsRead,
        if (write) AppPermissions.reportsWrite,
        if (export) AppPermissions.evidenceExport,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'reports', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

void _stubWorkspace(_MockReportsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((invocation) async {
    final ReportsWorkspaceQuery query =
        invocation.positionalArguments.single as ReportsWorkspaceQuery;
    return Result<ReportsWorkspaceOverview>.success(
      ReportsWorkspaceOverview(
        summary: const <ReportsSummaryCard>[
          ReportsSummaryCard(id: 'definitions', label: 'Definitions', value: 1),
        ],
        items: AppPage<ReportsWorkspaceItem>(
          items: const <ReportsWorkspaceItem>[_definitionItem, _widgetItem],
          request: query.pageRequest,
          totalItemCount: 2,
        ),
      ),
    );
  });
}

void _stubSchedules(_MockReportsRepository repository) {
  when(() => repository.listSchedules(any())).thenAnswer((invocation) async {
    final ReportsWorkspaceQuery query =
        invocation.positionalArguments.single as ReportsWorkspaceQuery;
    return Result<AppPage<ReportsWorkspaceItem>>.success(
      AppPage<ReportsWorkspaceItem>(
        items: const <ReportsWorkspaceItem>[_scheduleItem],
        request: query.pageRequest,
        totalItemCount: 1,
      ),
    );
  });
}

Future<void> _pumpReports(
  WidgetTester tester, {
  required _MockReportsRepository repository,
  AppAccessPolicy? policy,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository);
  _stubSchedules(repository);

  tester.view.physicalSize = const Size(1920, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/reports',
    routes: <RouteBase>[
      GoRoute(
        path: '/reports',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: ReportsWorkspacePage());
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reportsRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(
          policy ?? _reportsPolicy(),
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
  late _MockReportsRepository repository;

  setUp(() {
    repository = _MockReportsRepository();
    registerFallbackValue(const ReportsWorkspaceQuery());
  });

  testWidgets('workspace has no Refresh or toolbar Run / summary chips', (
    WidgetTester tester,
  ) async {
    await _pumpReports(
      tester,
      repository: repository,
      policy: _reportsPolicy(write: true),
    );

    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Definitions'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppWorkspaceToolbar),
        matching: find.text('Run report'),
      ),
      findsNothing,
    );
  });

  testWidgets('Filters remains the sole panel entry', (
    WidgetTester tester,
  ) async {
    await _pumpReports(tester, repository: repository);

    final AppListTable<ReportsWorkspaceItem> itemsTable = tester
        .widgetList<AppListTable<ReportsWorkspaceItem>>(
          find.byType(AppListTable<ReportsWorkspaceItem>),
        )
        .first;
    expect(itemsTable.search?.advancedFilterButtonLabel, 'Filters');
    expect(
      itemsTable.search?.filterGroups.any(
        (AppSearchBarFilterGroup group) => group.key == 'panel',
      ),
      isTrue,
    );
    expect(
      itemsTable.search?.filterGroups
          .expand((AppSearchBarFilterGroup group) => group.choices)
          .any((AppSearchBarFilterChoice choice) => choice.label == 'Catalog'),
      isTrue,
    );
  });

  testWidgets('next action Run is sole primary; detail omits Run', (
    WidgetTester tester,
  ) async {
    await _pumpReports(
      tester,
      repository: repository,
      policy: _reportsPolicy(write: true, export: true),
    );

    expect(find.text('Run report'), findsWidgets);

    final AppListTable<ReportsWorkspaceItem> table = tester
        .widgetList<AppListTable<ReportsWorkspaceItem>>(
          find.byType(AppListTable<ReportsWorkspaceItem>),
        )
        .first;
    table.onRowSelected!(_definitionItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('REPORT PREVIEW'), findsWidgets);
    // Detail omits Run (next-action primary); Schedule remains complementary.
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Run report'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Schedule'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('preview-only next action is absent; row select opens detail', (
    WidgetTester tester,
  ) async {
    await _pumpReports(tester, repository: repository);

    expect(
      reportNextActionLabel(
        AppLocalizationsEn(),
        _widgetItem,
        canWrite: true,
        canExport: true,
      ),
      isNull,
    );

    final AppListTable<ReportsWorkspaceItem> table = tester
        .widgetList<AppListTable<ReportsWorkspaceItem>>(
          find.byType(AppListTable<ReportsWorkspaceItem>),
        )
        .first;
    table.onRowSelected!(_widgetItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('REPORT PREVIEW'), findsWidgets);
  });

  testWidgets('schedules panel has no duplicate search field', (
    WidgetTester tester,
  ) async {
    await _pumpReports(tester, repository: repository);

    final AppListTable<ReportsWorkspaceItem> schedulesTable = tester
        .widgetList<AppListTable<ReportsWorkspaceItem>>(
          find.byType(AppListTable<ReportsWorkspaceItem>),
        )
        .last;
    expect(schedulesTable.search, isNull);
    expect(find.text('Daily census email'), findsOneWidget);
  });

  testWidgets('unauthorized write user has no Run next action', (
    WidgetTester tester,
  ) async {
    await _pumpReports(
      tester,
      repository: repository,
      policy: _reportsPolicy(),
    );

    expect(
      reportNextActionLabel(
        AppLocalizationsEn(),
        _definitionItem,
        canWrite: false,
        canExport: false,
      ),
      isNull,
    );
    expect(find.text('Run report'), findsNothing);
  });
}
