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
import 'package:hosspi_hms/features/reports/presentation/reports_billing_inventory.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockReportsRepository extends Mock implements ReportsRepository {}

const ReportsWorkspaceItem _definitionItem = ReportsWorkspaceItem(
  id: 'definition-1',
  kind: ReportItemKind.definition,
  title: 'Daily census',
  subtitle: 'Census export',
  status: 'ACTIVE',
  reference: 'RPT-001',
);

const ReportsWorkspaceItem _completedRun = ReportsWorkspaceItem(
  id: 'run-done',
  kind: ReportItemKind.run,
  title: 'Census run',
  status: 'COMPLETED',
  reference: 'RUN-001',
  downloadAvailable: true,
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

void _stubWorkspace(
  _MockReportsRepository repository, {
  List<ReportsWorkspaceItem> items = const <ReportsWorkspaceItem>[_definitionItem],
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
  List<ReportsWorkspaceItem> items = const <ReportsWorkspaceItem>[_definitionItem],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  if (stubDefaults) {
    _stubWorkspace(repository, items: items);
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

  setUpAll(() {
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

  setUp(() {
    repository = _MockReportsRepository();
  });

  group('Reports financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(ReportsBillingInventory.reportsTabHasNoBillableActions, isTrue);
      expect(ReportsBillingInventory.allMountedAtomsExplicitlyNotBillable, isTrue);
      expect(ReportsBillingInventory.atoms, isNotEmpty);
      expect(ReportsBillingInventory.billableClasses, isEmpty);

      for (final ReportsFinancialAtom atom in ReportsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<ReportsFinancialClass>[
            ReportsFinancialClass.notRequired,
            ReportsFinancialClass.notBilled,
            ReportsFinancialClass.noCharge,
          ]),
          reason: atom.id,
        );
        expect(atom.auditCode, isIn(<String>['NOT_REQUIRED', 'NOT_BILLED', 'NO_CHARGE']),
            reason: atom.id);
      }
    });

    test('KPI value display is NOT_BILLED analytics, not ledger balance', () {
      final ReportsFinancialAtom kpiAtom = ReportsBillingInventory.atoms
          .singleWhere((ReportsFinancialAtom atom) => atom.id == 'kpi_value_display');
      expect(kpiAtom.financialClass, ReportsFinancialClass.notBilled);
      expect(kpiAtom.auditCode, 'NOT_BILLED');
    });

    test('unmounted payment/invoice atoms document absence of billing bypass', () {
      expect(
        ReportsBillingInventory.atoms
            .singleWhere((ReportsFinancialAtom atom) => atom.id == 'collect_payment')
            .mounted,
        isFalse,
      );
      expect(
        ReportsBillingInventory.atoms
            .singleWhere((ReportsFinancialAtom atom) => atom.id == 'issue_invoice_adjust_refund')
            .mounted,
        isFalse,
      );
    });
  });

  group('Reports billing bypass (AC2–AC5)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpReports(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{
            AppPermissions.reportsRead,
            AppPermissions.reportsWrite,
            AppPermissions.evidenceExport,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('report detail dialog has no financial controls', (
      WidgetTester tester,
    ) async {
      await _pumpReports(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{
            AppPermissions.reportsRead,
            AppPermissions.reportsWrite,
            AppPermissions.evidenceExport,
          },
        ),
      );

      final AppListTable<ReportsWorkspaceItem> table = tester
          .widgetList<AppListTable<ReportsWorkspaceItem>>(
            find.byType(AppListTable<ReportsWorkspaceItem>),
          )
          .first;
      table.onRowSelected!(_definitionItem);
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.text('Print'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('run mutation syncs worklist without billing gate', (
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
      );

      when(() => repository.runReportDefinitionNow(any(), any())).thenAnswer(
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
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('unauthorized reader cannot reach write or export chrome', (
      WidgetTester tester,
    ) async {
      await _pumpReports(
        tester,
        repository: repository,
        policy: _policy(),
      );

      expect(canWriteReports(_policy()), isFalse);
      expect(canExportEvidence(_policy()), isFalse);
      expect(find.text('Run report'), findsNothing);
      expect(find.text('Download'), findsNothing);
      expect(find.text('Export evidence'), findsNothing);
    });

    testWidgets('download uses evidence export path, not billing collect', (
      WidgetTester tester,
    ) async {
      await _pumpReports(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{
            AppPermissions.reportsRead,
            AppPermissions.evidenceExport,
          },
        ),
        items: const <ReportsWorkspaceItem>[_completedRun],
      );

      when(() => repository.downloadReportRun(any())).thenAnswer(
        (_) async => const Result<List<int>>.success(<int>[1, 2, 3]),
      );

      await tester.tap(find.text('Download').first);
      await tester.pumpAndSettle();

      verify(() => repository.downloadReportRun('run-done')).called(1);
      verifyNever(() => repository.runReportDefinitionNow(any(), any()));
      expect(find.textContaining('Receive payment'), findsNothing);
    });
  });

  group('Reports section layout (AC5)', () {
    testWidgets('desktop catalog: flat sibling sections', (
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
        viewport: const Size(1920, 1200),
      );

      expect(find.text('Schedules'), findsOneWidget);
      expect(find.text('Recent report activity'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('mobile catalog: flat sections', (WidgetTester tester) async {
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
      expectFlatSections(tester);
    });

    testWidgets('compliance panel: flat sections', (WidgetTester tester) async {
      await _pumpReports(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{AppPermissions.complianceRead},
        ),
      );
      expect(find.text('EXPORT | REPORT_RUN'), findsWidgets);
      expect(find.text('Schedules'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('run dialog: flat sections', (WidgetTester tester) async {
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

      await tester.tap(find.text('Run report').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('schedule dialog: flat sections', (WidgetTester tester) async {
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

      final AppListTable<ReportsWorkspaceItem> table = tester
          .widgetList<AppListTable<ReportsWorkspaceItem>>(
            find.byType(AppListTable<ReportsWorkspaceItem>),
          )
          .first;
      table.onRowSelected!(_definitionItem);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Schedule'),
        ),
      );
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
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
        themeMode: ThemeMode.light,
      );
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
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
        themeMode: ThemeMode.dark,
      );
      expectFlatSections(tester);
    });
  });

  group('Reports sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      when(() => repository.getWorkspace(any())).thenAnswer((invocation) async {
        final ReportsWorkspaceQuery query =
            invocation.positionalArguments.single as ReportsWorkspaceQuery;
        return Result<ReportsWorkspaceOverview>.success(
          ReportsWorkspaceOverview(
            items: AppPage<ReportsWorkspaceItem>(
              items: const <ReportsWorkspaceItem>[],
              request: query.pageRequest,
              totalItemCount: 0,
            ),
          ),
        );
      });
      _stubSchedules(repository);
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

      expect(find.text('No report records'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      when(() => repository.getWorkspace(any())).thenAnswer(
        (_) async => const Result<ReportsWorkspaceOverview>.failure(
          AppFailure.network(),
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

      expect(find.textContaining('Try again'), findsWidgets);
    });
  });
}
