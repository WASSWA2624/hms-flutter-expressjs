import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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
  Set<AppPermission> permissions = const <AppPermission>{
    AppPermissions.reportsRead,
  },
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
      permissions: permissions,
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
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository);
  _stubSchedules(repository);
  _stubCompliance(repository);

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

  testWidgets('mobile viewport keeps authorized next-action available', (
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

    expect(find.text('Daily census'), findsWidgets);
    expect(find.text('Run report'), findsWidgets);
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
}
