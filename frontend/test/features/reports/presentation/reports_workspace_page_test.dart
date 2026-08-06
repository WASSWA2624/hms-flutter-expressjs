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

const ReportsWorkspaceItem _runItem = ReportsWorkspaceItem(
  id: 'run-1',
  kind: ReportItemKind.run,
  title: 'Daily census run',
  status: 'QUEUED',
  reference: 'RUN-001',
);

const ReportsWorkspaceItem _scheduleItem = ReportsWorkspaceItem(
  id: 'schedule-1',
  kind: ReportItemKind.schedule,
  title: 'Daily census email',
  subtitle: 'Morning delivery',
  status: 'ACTIVE',
  format: 'PDF',
);

const ComplianceLogItem _auditLog = ComplianceLogItem(
  id: 'audit-1',
  kind: ComplianceLogKind.audit,
  title: 'EXPORT | REPORT_RUN',
  subtitle: 'User exported report',
  userLabel: 'Admin User',
  recordReference: 'RUN-001',
  action: 'EXPORT',
);

AppAccessPolicy _reportsReadPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['REPORTING']),
      permissions: <AppPermission>{AppPermissions.reportsRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'reports', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

AppAccessPolicy _reportsWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['REPORTING']),
      permissions: <AppPermission>{
        AppPermissions.reportsRead,
        AppPermissions.reportsWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'reports', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

void _stubWorkspace(
  _MockReportsRepository repository, {
  List<ReportsWorkspaceItem> items = const <ReportsWorkspaceItem>[
    _definitionItem,
  ],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((invocation) async {
    final ReportsWorkspaceQuery query =
        invocation.positionalArguments.single as ReportsWorkspaceQuery;
    return Result<ReportsWorkspaceOverview>.success(
      ReportsWorkspaceOverview(
        summary: const <ReportsSummaryCard>[
          ReportsSummaryCard(id: 'definitions', label: 'Definitions', value: 1),
        ],
        items: AppPage<ReportsWorkspaceItem>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
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

Future<void> _pumpReportsWorkspace(
  WidgetTester tester, {
  required _MockReportsRepository repository,
  String initialLocation = '/reports',
  Size viewport = const Size(1920, 1200),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository);
  _stubSchedules(repository);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
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
        appAccessPolicyProvider.overrideWithValue(_reportsReadPolicy()),
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

AppListTable<ReportsWorkspaceItem> _itemsTable(WidgetTester tester) {
  return tester
      .widgetList<AppListTable<ReportsWorkspaceItem>>(
        find.byType(AppListTable<ReportsWorkspaceItem>),
      )
      .first;
}

AppListTable<ReportsWorkspaceItem> _schedulesTable(WidgetTester tester) {
  return tester
      .widgetList<AppListTable<ReportsWorkspaceItem>>(
        find.byType(AppListTable<ReportsWorkspaceItem>),
      )
      .last;
}

void main() {
  late _MockReportsRepository repository;

  setUp(() {
    repository = _MockReportsRepository();
    registerFallbackValue(const ReportsWorkspaceQuery());
  });

  testWidgets('overview opens as reporting dashboard with KPIs and shortcuts', (
    WidgetTester tester,
  ) async {
    await _pumpReportsWorkspace(tester, repository: repository);

    expect(find.text('Reporting and Analytics'), findsWidgets);
    expect(find.text('Definitions'), findsWidgets);
    expect(find.text('Browse catalog'), findsOneWidget);
    expect(find.text('Runs and delivery'), findsWidgets);
    expect(find.text('Workspace activity'), findsOneWidget);
    expect(find.text('Queue mix'), findsOneWidget);
    expect(find.text('Filters'), findsWidgets);

    final AppListTable<ReportsWorkspaceItem> schedulesTable = _schedulesTable(
      tester,
    );
    expect(schedulesTable.displayMode, AppListTableDisplayMode.adaptive);
    expect(schedulesTable.columnVisibilityStorageKey, 'reports_schedules');
    expect(schedulesTable.columnWidthStorageKey, 'reports_schedules_cw');
    expect(schedulesTable.columns.length, 4);
    expect(find.text('Daily census email'), findsOneWidget);
  });

  testWidgets('catalog panel tables use adaptive mode and four default columns', (
    WidgetTester tester,
  ) async {
    await _pumpReportsWorkspace(tester, repository: repository);

    await tester.tap(find.text('Browse catalog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final AppListTable<ReportsWorkspaceItem> itemsTable = _itemsTable(tester);
    expect(itemsTable.displayMode, AppListTableDisplayMode.adaptive);
    expect(itemsTable.columnVisibilityStorageKey, 'reports_items_catalog');
    expect(itemsTable.columnWidthStorageKey, 'reports_items_cw_catalog');
    expect(itemsTable.columnVisibilityTitle, 'Table Settings');
    expect(itemsTable.search?.advancedFilterButtonLabel, 'Filters');
    expect(itemsTable.search?.advancedFilterTitle, 'Advanced filters');
    expect(itemsTable.columns.length, 4);
    expect(
      itemsTable.columns.any(
        (AppListTableColumn<ReportsWorkspaceItem> column) =>
            column.id == 'next_action',
      ),
      isFalse,
    );
    expect(find.text('Daily census'), findsWidgets);
  });

  testWidgets('writer mounts next_action column on catalog and schedules', (
    WidgetTester tester,
  ) async {
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
          appAccessPolicyProvider.overrideWithValue(_reportsWritePolicy()),
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

    expect(find.text('Create or run report'), findsWidgets);
    await tester.tap(find.text('Browse catalog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final AppListTable<ReportsWorkspaceItem> itemsTable = _itemsTable(tester);
    expect(itemsTable.columns.length, 5);
    expect(
      itemsTable.columns.any(
        (AppListTableColumn<ReportsWorkspaceItem> column) =>
            column.id == 'next_action' && column.alwaysVisible,
      ),
      isTrue,
    );
    expect(find.text('Next action'), findsWidgets);
    expect(find.text('Run report'), findsWidgets);
  });

  testWidgets('complianceLogColumns omits next_action without export', (
    WidgetTester tester,
  ) async {
    late List<AppListTableColumn<ComplianceLogItem>> columns;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              columns = complianceLogColumns(
                context,
                ref,
                AppLocalizations.of(context),
                canExport: false,
                onNextAction: (_, _, _) async {},
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(columns.length, 4);
    expect(
      columns.any(
        (AppListTableColumn<ComplianceLogItem> column) =>
            column.id == 'next_action',
      ),
      isFalse,
    );
  });

  testWidgets('complianceLogColumns exposes five default columns', (
    WidgetTester tester,
  ) async {
    late List<AppListTableColumn<ComplianceLogItem>> columns;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              columns = complianceLogColumns(
                context,
                ref,
                AppLocalizations.of(context),
                canExport: true,
                onNextAction: (_, _, _) async {},
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(columns.length, 5);
    expect(
      columns.any(
        (AppListTableColumn<ComplianceLogItem> column) =>
            column.id == 'next_action' && column.alwaysVisible,
      ),
      isTrue,
    );
  });

  testWidgets('reportItemColumns exposes run action for definitions', (
    WidgetTester tester,
  ) async {
    late List<AppListTableColumn<ReportsWorkspaceItem>> columns;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              columns = reportItemColumns(
                context,
                ref,
                AppLocalizations.of(context),
                canWrite: true,
                canExport: true,
                isSaving: false,
                onNextAction: (_, _, _) async {},
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(columns.length, 5);
    expect(
      reportNextActionLabel(
        AppLocalizationsEn(),
        _definitionItem,
        canWrite: true,
        canExport: true,
      ),
      'Run report',
    );
    expect(
      columns.any(
        (AppListTableColumn<ReportsWorkspaceItem> column) =>
            column.id == 'next_action',
      ),
      isTrue,
    );
  });

  testWidgets('row selection opens report detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpReportsWorkspace(tester, repository: repository);

    await tester.tap(find.text('Browse catalog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final AppListTable<ReportsWorkspaceItem> table = _itemsTable(tester);
    expect(table.onRowSelected, isNotNull);
    table.onRowSelected!(_definitionItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    expect(find.text('REPORT PREVIEW'), findsWidgets);
  });

  testWidgets('matchesReportItemSearch matches hidden column fields', (
    WidgetTester tester,
  ) async {
    late bool matched;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            matched = matchesReportItemSearch(
              context,
              _definitionItem,
              'ops lead',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(matched, isTrue);
  });

  testWidgets('matchesComplianceLogSearch matches user label', (
    WidgetTester tester,
  ) async {
    late bool matched;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            matched = matchesComplianceLogSearch(
              context,
              _auditLog,
              'admin user',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(matched, isTrue);
  });

  testWidgets('reportNextActionLabel prefers run for definitions', (
    WidgetTester tester,
  ) async {
    late String? label;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            label = reportNextActionLabel(
              AppLocalizations.of(context),
              _definitionItem,
              canWrite: true,
              canExport: true,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(label, 'Run report');
  });
}
