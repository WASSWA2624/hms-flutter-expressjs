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
import 'package:hosspi_hms/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/features/reports/presentation/pages/reports_workspace_page.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
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

AppAccessPolicy _policy({
  Set<AppPermission>? permissions,
  bool includeModule = true,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: <String>['REPORTING'],
      ),
      permissions: permissions ?? <AppPermission>{AppPermissions.reportsRead},
      moduleEntitlements: includeModule
          ? const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'reporting-analytics',
                licenseStatus: 'ACTIVE',
              ),
            ]
          : const <AppModuleEntitlement>[],
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
          items: const <ReportsWorkspaceItem>[_definitionItem],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
        timeline: const <ReportsTimelineItem>[
          ReportsTimelineItem(
            id: 'tl-1',
            title: 'Run queued',
            resource: ReportsWorkspaceResource.reportRuns,
            status: 'QUEUED',
          ),
        ],
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

void _stubCompliance(_MockReportsRepository repository) {
  when(() => repository.listComplianceLogs(any())).thenAnswer((
    invocation,
  ) async {
    final ReportsWorkspaceQuery query =
        invocation.positionalArguments.single as ReportsWorkspaceQuery;
    return Result<AppPage<ComplianceLogItem>>.success(
      AppPage<ComplianceLogItem>(
        items: const <ComplianceLogItem>[_auditLog],
        request: query.pageRequest,
        totalItemCount: 1,
      ),
    );
  });
}

Future<void> _pumpReports(
  WidgetTester tester, {
  required _MockReportsRepository repository,
  required AppAccessPolicy policy,
  Size viewport = const Size(1920, 1200),
  ThemeMode themeMode = ThemeMode.light,
  bool stubDefaults = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  if (stubDefaults) {
    _stubWorkspace(repository);
    _stubSchedules(repository);
    _stubCompliance(repository);
  }

  tester.view.physicalSize = viewport;
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
        appAccessPolicyProvider.overrideWithValue(policy),
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
  late _MockReportsRepository repository;

  setUp(() {
    repository = _MockReportsRepository();
    registerFallbackValue(const ReportsWorkspaceQuery());
    registerFallbackValue(const ReportRunDraft());
    registerFallbackValue(
      const ReportScheduleDraft(
        reportDefinitionId: 'definition-1',
        name: 'Schedule',
        frequency: 'DAILY',
      ),
    );
  });

  testWidgets('read-only user has no Run next-action (∩ write denial)', (
    WidgetTester tester,
  ) async {
    await _pumpReports(
      tester,
      repository: repository,
      policy: _policy(),
    );

    expect(canWriteReports(_policy()), isFalse);
    expect(find.text('Run report'), findsNothing);
    expect(find.text('Daily census'), findsWidgets);
    expect(find.text('Daily census email'), findsOneWidget);
  });

  testWidgets('writer sees Run next-action (∩ write present)', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.reportsRead,
        AppPermissions.reportsWrite,
      },
    );
    await _pumpReports(tester, repository: repository, policy: writer);

    expect(canWriteReports(writer), isTrue);
    expect(find.text('Run report'), findsWidgets);
  });

  testWidgets('compliance-only user hides catalog panels and schedules', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy complianceOnly = _policy(
      permissions: <AppPermission>{AppPermissions.complianceRead},
    );
    await _pumpReports(
      tester,
      repository: repository,
      policy: complianceOnly,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(canReadReportsCatalog(complianceOnly), isFalse);
    expect(canReadReportsCompliance(complianceOnly), isTrue);
    expect(find.text('Daily census email'), findsNothing);
    expect(find.text('Run report'), findsNothing);
    expect(find.text('EXPORT | REPORT_RUN'), findsWidgets);

    final List<AppListTable<ComplianceLogItem>> complianceTables = tester
        .widgetList<AppListTable<ComplianceLogItem>>(
          find.byType(AppListTable<ComplianceLogItem>),
        )
        .toList();
    expect(complianceTables, isNotEmpty);
    expect(
      complianceTables.first.search?.filterGroups
          .expand((AppSearchBarFilterGroup group) => group.choices)
          .any((AppSearchBarFilterChoice choice) => choice.label == 'Catalog'),
      isFalse,
    );
    expect(
      complianceTables.first.search?.filterGroups
          .expand((AppSearchBarFilterGroup group) => group.choices)
          .any(
            (AppSearchBarFilterChoice choice) => choice.label == 'Audit logs',
          ),
      isTrue,
    );
  });

  testWidgets('catalog-only filters omit compliance Audit panel choice', (
    WidgetTester tester,
  ) async {
    await _pumpReports(tester, repository: repository, policy: _policy());

    final AppListTable<ReportsWorkspaceItem> itemsTable = tester
        .widgetList<AppListTable<ReportsWorkspaceItem>>(
          find.byType(AppListTable<ReportsWorkspaceItem>),
        )
        .first;
    expect(
      itemsTable.search?.filterGroups
          .expand((AppSearchBarFilterGroup group) => group.choices)
          .any(
            (AppSearchBarFilterChoice choice) => choice.label == 'Audit logs',
          ),
      isFalse,
    );
    expect(
      itemsTable.search?.filterGroups
          .expand((AppSearchBarFilterGroup group) => group.choices)
          .any((AppSearchBarFilterChoice choice) => choice.label == 'Catalog'),
      isTrue,
    );
  });

  testWidgets('export next-action absent without evidence:export', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy complianceReader = _policy(
      permissions: <AppPermission>{AppPermissions.complianceRead},
    );
    await _pumpReports(
      tester,
      repository: repository,
      policy: complianceReader,
    );
    await tester.pumpAndSettle();

    expect(canExportEvidence(complianceReader), isFalse);
    expect(find.text('Export evidence'), findsNothing);
    final List<AppListTable<ComplianceLogItem>> complianceTables = tester
        .widgetList<AppListTable<ComplianceLogItem>>(
          find.byType(AppListTable<ComplianceLogItem>),
        )
        .toList();
    expect(complianceTables, isNotEmpty);
    expect(
      complianceTables.first.columns.any(
        (AppListTableColumn<ComplianceLogItem> column) =>
            column.id == 'next_action',
      ),
      isFalse,
    );
  });

  testWidgets('export next-action present with evidence:export (∪ export)', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy exporter = _policy(
      permissions: <AppPermission>{
        AppPermissions.complianceRead,
        AppPermissions.evidenceExport,
      },
    );
    await _pumpReports(tester, repository: repository, policy: exporter);
    await tester.pumpAndSettle();

    expect(canExportEvidence(exporter), isTrue);
    expect(find.text('Export evidence'), findsWidgets);
    expect(find.text('EXPORT | REPORT_RUN'), findsWidgets);
  });

  testWidgets('detail Print absent without export; present with export', (
    WidgetTester tester,
  ) async {
    await _pumpReports(tester, repository: repository, policy: _policy());

    final AppListTable<ReportsWorkspaceItem> table = tester
        .widgetList<AppListTable<ReportsWorkspaceItem>>(
          find.byType(AppListTable<ReportsWorkspaceItem>),
        )
        .first;
    table.onRowSelected!(_definitionItem);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Print'),
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final AppAccessPolicy exporter = _policy(
      permissions: <AppPermission>{
        AppPermissions.reportsRead,
        AppPermissions.evidenceExport,
      },
    );
    await _pumpReports(tester, repository: repository, policy: exporter);
    final AppListTable<ReportsWorkspaceItem> exportTable = tester
        .widgetList<AppListTable<ReportsWorkspaceItem>>(
          find.byType(AppListTable<ReportsWorkspaceItem>),
        )
        .first;
    exportTable.onRowSelected!(_definitionItem);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Print'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('read-only omits next_action column (∩ write denial chrome)', (
    WidgetTester tester,
  ) async {
    await _pumpReports(tester, repository: repository, policy: _policy());

    final AppListTable<ReportsWorkspaceItem> itemsTable = tester
        .widgetList<AppListTable<ReportsWorkspaceItem>>(
          find.byType(AppListTable<ReportsWorkspaceItem>),
        )
        .first;
    expect(
      itemsTable.columns.any(
        (AppListTableColumn<ReportsWorkspaceItem> column) =>
            column.id == 'next_action',
      ),
      isFalse,
    );
    expect(find.text('Schedule'), findsNothing);
  });

  testWidgets('authorized writer keeps empty worklist state observable', (
    WidgetTester tester,
  ) async {
    when(() => repository.getWorkspace(any())).thenAnswer((invocation) async {
      final ReportsWorkspaceQuery query =
          invocation.positionalArguments.single as ReportsWorkspaceQuery;
      return Result<ReportsWorkspaceOverview>.success(
        ReportsWorkspaceOverview(
          summary: const <ReportsSummaryCard>[],
          items: AppPage<ReportsWorkspaceItem>(
            items: const <ReportsWorkspaceItem>[],
            request: query.pageRequest,
            totalItemCount: 0,
          ),
        ),
      );
    });
    when(() => repository.listSchedules(any())).thenAnswer((invocation) async {
      final ReportsWorkspaceQuery query =
          invocation.positionalArguments.single as ReportsWorkspaceQuery;
      return Result<AppPage<ReportsWorkspaceItem>>.success(
        AppPage<ReportsWorkspaceItem>(
          items: const <ReportsWorkspaceItem>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
      );
    });
    _stubCompliance(repository);

    await _pumpReports(
      tester,
      repository: repository,
      policy: _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.reportsWrite,
        },
      ),
      stubDefaults: false,
    );

    expect(find.text('Run report'), findsNothing);
    expect(find.byType(AppListTable<ReportsWorkspaceItem>), findsWidgets);
  });

  testWidgets('desktop light and dark themes render authorized catalog', (
    WidgetTester tester,
  ) async {
    for (final ThemeMode mode in <ThemeMode>[
      ThemeMode.light,
      ThemeMode.dark,
    ]) {
      await _pumpReports(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{
            AppPermissions.reportsRead,
            AppPermissions.reportsWrite,
          },
        ),
        themeMode: mode,
      );
      expect(find.text('Daily census'), findsWidgets);
      expect(find.text('Run report'), findsWidgets);
    }
  });

  testWidgets('mobile viewport keeps authorized catalog worklist', (
    WidgetTester tester,
  ) async {
    await _pumpReports(
      tester,
      repository: repository,
      policy: _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.reportsWrite,
        },
      ),
      viewport: const Size(390, 844),
    );

    expect(find.byType(ReportsWorkspacePage), findsOneWidget);
    expect(find.byType(AppListTable<ReportsWorkspaceItem>), findsWidgets);
    expect(find.text('Run report'), findsWidgets);
    expect(canWriteReports(_policy(
      permissions: <AppPermission>{
        AppPermissions.reportsRead,
        AppPermissions.reportsWrite,
      },
    )), isTrue);
  });

  testWidgets('authorized error surface keeps Try again retry', (
    WidgetTester tester,
  ) async {
    when(() => repository.getWorkspace(any())).thenAnswer(
      (_) async => Result<ReportsWorkspaceOverview>.failure(
        const AppFailure.network(),
      ),
    );
    when(() => repository.listSchedules(any())).thenAnswer((invocation) async {
      final ReportsWorkspaceQuery query =
          invocation.positionalArguments.single as ReportsWorkspaceQuery;
      return Result<AppPage<ReportsWorkspaceItem>>.success(
        AppPage<ReportsWorkspaceItem>(
          items: const <ReportsWorkspaceItem>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
      );
    });

    await _pumpReports(
      tester,
      repository: repository,
      policy: _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.reportsWrite,
        },
      ),
      stubDefaults: false,
    );

    expect(find.textContaining('Try again'), findsWidgets);
  });

  testWidgets('module strip hides write affordances despite permission string', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy stripped = _policy(
      permissions: <AppPermission>{
        AppPermissions.reportsRead,
        AppPermissions.reportsWrite,
      },
      includeModule: false,
    );
    await _pumpReports(tester, repository: repository, policy: stripped);

    expect(canWriteReports(stripped), isFalse);
    expect(find.text('Run report'), findsNothing);
  });

  testWidgets(
    'union of reports:read + compliance:read shows Catalog and Audit filters',
    (WidgetTester tester) async {
      final AppAccessPolicy both = _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.complianceRead,
        },
      );
      await _pumpReports(tester, repository: repository, policy: both);

      final AppListTable<ReportsWorkspaceItem> itemsTable = tester
          .widgetList<AppListTable<ReportsWorkspaceItem>>(
            find.byType(AppListTable<ReportsWorkspaceItem>),
          )
          .first;
      final Iterable<String> panelLabels = itemsTable.search!.filterGroups
          .expand((AppSearchBarFilterGroup group) => group.choices)
          .map((AppSearchBarFilterChoice choice) => choice.label);

      expect(panelLabels, contains('Catalog'));
      expect(panelLabels, contains('Audit logs'));
      expect(find.text('Daily census'), findsWidgets);
      expect(find.text('Daily census email'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized run mutates, shows success snackbar, and syncs worklist',
    (WidgetTester tester) async {
      await _pumpReports(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{
            AppPermissions.reportsRead,
            AppPermissions.reportsWrite,
          },
        ),
      );

      when(
        () => repository.runReportDefinitionNow(any(), any()),
      ).thenAnswer(
        (_) async => const Result<ReportsWorkspaceItem>.success(
          ReportsWorkspaceItem(
            id: 'run-1',
            kind: ReportItemKind.run,
            title: 'Daily census',
            status: 'QUEUED',
          ),
        ),
      );

      await tester.tap(find.text('Run report').first);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.widgetWithText(AppButton, 'Run report'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reports workspace updated.'), findsOneWidget);
      verify(() => repository.runReportDefinitionNow(any(), any())).called(1);
      // Local merge sync: delivery worklist shows the queued run next-action.
      expect(find.text('Cancel run'), findsWidgets);
      expect(find.text('Queued'), findsWidgets);
    },
  );

  testWidgets(
    'authorized schedule dialog keeps validation when name cleared',
    (WidgetTester tester) async {
      await _pumpReports(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{
            AppPermissions.reportsRead,
            AppPermissions.reportsWrite,
          },
        ),
      );

      final AppListTable<ReportsWorkspaceItem> itemsTable = tester
          .widgetList<AppListTable<ReportsWorkspaceItem>>(
            find.byType(AppListTable<ReportsWorkspaceItem>),
          )
          .first;
      itemsTable.onRowSelected!(_definitionItem);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Schedule'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(TextFormField),
        ).first,
        '',
      );
      await tester.tap(find.text('Create schedule'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text('Create schedule'), findsOneWidget);
      verifyNever(() => repository.createSchedule(any()));
    },
  );

  testWidgets(
    'schedule next-action absent without reports:write (∩ create denial)',
    (WidgetTester tester) async {
      await _pumpReports(tester, repository: repository, policy: _policy());

      expect(find.text('Schedule'), findsNothing);
      expect(find.text('Create schedule'), findsNothing);

      final AppListTable<ReportsWorkspaceItem> schedulesTable = tester
          .widgetList<AppListTable<ReportsWorkspaceItem>>(
            find.byType(AppListTable<ReportsWorkspaceItem>),
          )
          .last;
      expect(
        schedulesTable.columns.any(
          (AppListTableColumn<ReportsWorkspaceItem> column) =>
              column.id == 'next_action',
        ),
        isFalse,
      );
    },
  );

  testWidgets('mobile read-only omits Run next-action (∩ denial)', (
    WidgetTester tester,
  ) async {
    await _pumpReports(
      tester,
      repository: repository,
      policy: _policy(),
      viewport: const Size(390, 844),
    );

    expect(find.text('Run report'), findsNothing);
    expect(find.text('Daily census'), findsWidgets);
    final List<AppListTable<ReportsWorkspaceItem>> tables = tester
        .widgetList<AppListTable<ReportsWorkspaceItem>>(
          find.byType(AppListTable<ReportsWorkspaceItem>),
        )
        .toList();
    expect(tables, isNotEmpty);
    expect(
      tables.first.columns.any(
        (AppListTableColumn<ReportsWorkspaceItem> column) =>
            column.id == 'next_action',
      ),
      isFalse,
    );
  });

  testWidgets('module strip hides export affordances despite evidence:export', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy stripped = _policy(
      permissions: <AppPermission>{
        AppPermissions.complianceRead,
        AppPermissions.evidenceExport,
      },
      includeModule: false,
    );
    await _pumpReports(tester, repository: repository, policy: stripped);

    expect(canExportEvidence(stripped), isFalse);
    expect(find.text('Export evidence'), findsNothing);
  });

  testWidgets(
    'compliance:review alone opens compliance panels (∪ compliance read)',
    (WidgetTester tester) async {
      final AppAccessPolicy reviewer = _policy(
        permissions: <AppPermission>{AppPermissions.complianceReview},
      );
      await _pumpReports(tester, repository: repository, policy: reviewer);
      await tester.pumpAndSettle();

      expect(canReadReportsCompliance(reviewer), isTrue);
      expect(canReadReportsCatalog(reviewer), isFalse);
      expect(find.text('Daily census email'), findsNothing);
      expect(find.text('EXPORT | REPORT_RUN'), findsWidgets);
    },
  );

  testWidgets(
    'compliance-only hides schedules and timeline; catalog shows both',
    (WidgetTester tester) async {
      final AppAccessPolicy complianceOnly = _policy(
        permissions: <AppPermission>{AppPermissions.complianceRead},
      );
      await _pumpReports(
        tester,
        repository: repository,
        policy: complianceOnly,
      );
      await tester.pumpAndSettle();

      expect(find.text('Schedules'), findsNothing);
      expect(find.text('Recent report activity'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await _pumpReports(tester, repository: repository, policy: _policy());
      expect(find.text('Schedules'), findsOneWidget);
      expect(find.text('Recent report activity'), findsOneWidget);
      expect(find.text('Run queued'), findsOneWidget);
    },
  );

  testWidgets(
    'Download next-action gated by evidence:export (∪ export)',
    (WidgetTester tester) async {
      const ReportsWorkspaceItem completedRun = ReportsWorkspaceItem(
        id: 'run-done',
        kind: ReportItemKind.run,
        title: 'Census run',
        status: 'COMPLETED',
        downloadAvailable: true,
      );

      when(() => repository.getWorkspace(any())).thenAnswer((
        invocation,
      ) async {
        final ReportsWorkspaceQuery query =
            invocation.positionalArguments.single as ReportsWorkspaceQuery;
        return Result<ReportsWorkspaceOverview>.success(
          ReportsWorkspaceOverview(
            summary: const <ReportsSummaryCard>[],
            items: AppPage<ReportsWorkspaceItem>(
              items: const <ReportsWorkspaceItem>[completedRun],
              request: query.pageRequest,
              totalItemCount: 1,
            ),
          ),
        );
      });
      _stubSchedules(repository);
      _stubCompliance(repository);

      await _pumpReports(
        tester,
        repository: repository,
        policy: _policy(),
        stubDefaults: false,
      );
      expect(find.text('Download'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final AppAccessPolicy exporter = _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.evidenceExport,
        },
      );
      await _pumpReports(
        tester,
        repository: repository,
        policy: exporter,
        stubDefaults: false,
      );
      expect(find.text('Download'), findsWidgets);

      final AppListTable<ReportsWorkspaceItem> table = tester
          .widgetList<AppListTable<ReportsWorkspaceItem>>(
            find.byType(AppListTable<ReportsWorkspaceItem>),
          )
          .first;
      table.onRowSelected!(completedRun);
      await tester.pumpAndSettle();

      // Download is the row next-action; detail omits it but keeps Print.
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Download'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Print'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('compliance detail Print absent without export; present with', (
    WidgetTester tester,
  ) async {
    await _pumpReports(
      tester,
      repository: repository,
      policy: _policy(permissions: <AppPermission>{AppPermissions.complianceRead}),
    );
    await tester.pumpAndSettle();

    final AppListTable<ComplianceLogItem> table = tester
        .widgetList<AppListTable<ComplianceLogItem>>(
          find.byType(AppListTable<ComplianceLogItem>),
        )
        .first;
    table.onRowSelected!(_auditLog);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Print'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Export evidence'),
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final AppAccessPolicy exporter = _policy(
      permissions: <AppPermission>{
        AppPermissions.complianceRead,
        AppPermissions.evidenceExport,
      },
    );
    await _pumpReports(tester, repository: repository, policy: exporter);
    await tester.pumpAndSettle();

    final AppListTable<ComplianceLogItem> exportTable = tester
        .widgetList<AppListTable<ComplianceLogItem>>(
          find.byType(AppListTable<ComplianceLogItem>),
        )
        .first;
    exportTable.onRowSelected!(_auditLog);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Print'),
      ),
      findsOneWidget,
    );
    // Export evidence is the row next-action, so detail omits the duplicate.
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Export evidence'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'export-only catalog mounts next_action for Download, not Run',
    (WidgetTester tester) async {
      const ReportsWorkspaceItem completedRun = ReportsWorkspaceItem(
        id: 'run-done',
        kind: ReportItemKind.run,
        title: 'Census run',
        status: 'COMPLETED',
        downloadAvailable: true,
      );

      when(() => repository.getWorkspace(any())).thenAnswer((
        invocation,
      ) async {
        final ReportsWorkspaceQuery query =
            invocation.positionalArguments.single as ReportsWorkspaceQuery;
        return Result<ReportsWorkspaceOverview>.success(
          ReportsWorkspaceOverview(
            summary: const <ReportsSummaryCard>[],
            items: AppPage<ReportsWorkspaceItem>(
              items: const <ReportsWorkspaceItem>[
                _definitionItem,
                completedRun,
              ],
              request: query.pageRequest,
              totalItemCount: 2,
            ),
          ),
        );
      });
      _stubSchedules(repository);
      _stubCompliance(repository);

      final AppAccessPolicy exportOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.evidenceExport,
        },
      );
      await _pumpReports(
        tester,
        repository: repository,
        policy: exportOnly,
        stubDefaults: false,
      );

      expect(find.text('Run report'), findsNothing);
      expect(find.text('Download'), findsWidgets);
      final AppListTable<ReportsWorkspaceItem> itemsTable = tester
          .widgetList<AppListTable<ReportsWorkspaceItem>>(
            find.byType(AppListTable<ReportsWorkspaceItem>),
          )
          .first;
      expect(
        itemsTable.columns.any(
          (AppListTableColumn<ReportsWorkspaceItem> column) =>
              column.id == 'next_action',
        ),
        isTrue,
      );
    },
  );
}
