import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/features/reports/presentation/controllers/reports_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockReportsRepository extends Mock implements ReportsRepository {}

const List<AppModuleEntitlement> _reportsModule = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'reporting-analytics', licenseStatus: 'ACTIVE'),
];

AppAccessPolicy _policy(Set<AppPermission> permissions) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: <String>['REPORTING'],
      ),
      permissions: permissions,
      moduleEntitlements: _reportsModule,
      isAuthorizationHydrated: true,
    ),
  ).copyWithPermissions(permissions);
}

void main() {
  setUpAll(() {
    registerFallbackValue(const ReportsWorkspaceQuery());
    registerFallbackValue(const ReportRunDraft());
    registerFallbackValue(
      const ReportScheduleDraft(
        reportDefinitionId: 'definition-1',
        name: 'Daily census',
        frequency: 'DAILY',
      ),
    );
  });

  group('ReportsWorkspaceController', () {
    test(
      'loads workspace, schedules, and selects the first report item',
      () async {
        final _MockReportsRepository repository = _MockReportsRepository();
        _stubWorkspace(repository);
        _stubSchedules(repository);

        final ProviderContainer container = _container(
          repository: repository,
          policy: _policy(<AppPermission>{AppPermissions.reportsRead}),
        );
        addTearDown(container.dispose);

        final ReportsWorkspaceState state = await _readState(container);

        expect(state.overview.items.items.single.id, 'run-1');
        expect(state.overview.schedules.items.single.id, 'schedule-1');
        expect(state.selectedItem?.id, 'run-1');
        verify(() => repository.getWorkspace(any())).called(1);
        verify(() => repository.listSchedules(any())).called(1);
        verifyNever(() => repository.listComplianceLogs(any()));
      },
    );

    test(
      'compliance-only initial load skips catalog workspace APIs (∪ read)',
      () async {
        final _MockReportsRepository repository = _MockReportsRepository();
        when(() => repository.listComplianceLogs(any())).thenAnswer((
          invocation,
        ) async {
          final ReportsWorkspaceQuery query =
              invocation.positionalArguments.single as ReportsWorkspaceQuery;
          expect(query.panel, ReportsWorkspacePanel.audit);
          return Result<AppPage<ComplianceLogItem>>.success(
            AppPage<ComplianceLogItem>(
              items: const <ComplianceLogItem>[
                ComplianceLogItem(
                  id: 'audit-1',
                  kind: ComplianceLogKind.audit,
                  title: 'EXPORT | REPORT_RUN',
                ),
              ],
              request: query.pageRequest,
              totalItemCount: 1,
            ),
          );
        });

        final ProviderContainer container = _container(
          repository: repository,
          policy: _policy(<AppPermission>{AppPermissions.complianceRead}),
        );
        addTearDown(container.dispose);

        final ReportsWorkspaceState state = await _readState(container);

        expect(state.query.panel, ReportsWorkspacePanel.audit);
        expect(state.complianceLogs.items.single.id, 'audit-1');
        expect(state.overview.items.items, isEmpty);
        verify(() => repository.listComplianceLogs(any())).called(1);
        verifyNever(() => repository.getWorkspace(any()));
        verifyNever(() => repository.listSchedules(any()));
      },
    );

    test('refuses unauthorized panel switches without fetching', () async {
      final _MockReportsRepository repository = _MockReportsRepository();
      _stubWorkspace(repository);
      _stubSchedules(repository);

      final ProviderContainer container = _container(
        repository: repository,
        policy: _policy(<AppPermission>{AppPermissions.reportsRead}),
      );
      addTearDown(container.dispose);
      await container.read(reportsWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(reportsWorkspaceControllerProvider.notifier)
          .applyPanel(ReportsWorkspacePanel.audit);
      final ReportsWorkspaceState state = _currentState(container);

      expect(failure, isNull);
      expect(state.query.panel.isCompliance, isFalse);
      verifyNever(() => repository.listComplianceLogs(any()));
    });

    test('switches to audit panel and loads compliance logs', () async {
      final _MockReportsRepository repository = _MockReportsRepository();
      _stubWorkspace(repository);
      _stubSchedules(repository);
      when(() => repository.listComplianceLogs(any())).thenAnswer((
        invocation,
      ) async {
        final ReportsWorkspaceQuery query =
            invocation.positionalArguments.single as ReportsWorkspaceQuery;
        expect(query.panel, ReportsWorkspacePanel.audit);
        return Result<AppPage<ComplianceLogItem>>.success(
          AppPage<ComplianceLogItem>(
            items: const <ComplianceLogItem>[
              ComplianceLogItem(
                id: 'audit-1',
                kind: ComplianceLogKind.audit,
                title: 'EXPORT | REPORT_RUN',
              ),
            ],
            request: query.pageRequest,
            totalItemCount: 1,
          ),
        );
      });

      final ProviderContainer container = _container(
        repository: repository,
        policy: _policy(<AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.complianceRead,
        }),
      );
      addTearDown(container.dispose);
      await container.read(reportsWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(reportsWorkspaceControllerProvider.notifier)
          .applyPanel(ReportsWorkspacePanel.audit);
      final ReportsWorkspaceState state = _currentState(container);

      expect(failure, isNull);
      expect(state.query.panel, ReportsWorkspacePanel.audit);
      expect(state.complianceLogs.items.single.id, 'audit-1');
      expect(state.selectedComplianceLog?.id, 'audit-1');
      expect(state.selectedItem, isNull);
      verify(() => repository.listComplianceLogs(any())).called(1);
    });

    test('runs selected definition and refreshes delivery runs', () async {
      final _MockReportsRepository repository = _MockReportsRepository();
      _stubWorkspace(repository);
      _stubSchedules(repository, items: const <ReportsWorkspaceItem>[]);
      when(
        () => repository.runReportDefinitionNow('definition-1', any()),
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

      final ProviderContainer container = _container(
        repository: repository,
        policy: _policy(<AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.reportsWrite,
        }),
      );
      addTearDown(container.dispose);
      await container.read(reportsWorkspaceControllerProvider.future);
      await container
          .read(reportsWorkspaceControllerProvider.notifier)
          .applyPanel(ReportsWorkspacePanel.catalog);
      final ReportsWorkspaceState catalogState = _currentState(container);
      expect(catalogState.selectedItem?.id, 'definition-1');
      expect(catalogState.selectedItem?.canRun, isTrue);

      final AppFailure? failure = await container
          .read(reportsWorkspaceControllerProvider.notifier)
          .runSelectedDefinition(const ReportRunDraft(format: 'PDF'));
      final ReportsWorkspaceState state = _currentState(container);

      expect(failure, isNull);
      expect(state.query.panel, ReportsWorkspacePanel.delivery);
      expect(state.query.resource, ReportsWorkspaceResource.reportRuns);
      expect(state.selectedItem?.id, 'run-1');
      expect(state.selectedItem?.kind, ReportItemKind.run);
      verify(
        () => repository.runReportDefinitionNow('definition-1', any()),
      ).called(1);
      verify(() => repository.getWorkspace(any())).called(2);
    });
  });
}

ProviderContainer _container({
  required _MockReportsRepository repository,
  required AppAccessPolicy policy,
}) {
  return ProviderContainer(
    overrides: [
      reportsRepositoryProvider.overrideWithValue(repository),
      appAccessPolicyProvider.overrideWithValue(policy),
      initialSessionStateProvider.overrideWithValue(const SessionState.ready()),
    ],
  );
}

Future<ReportsWorkspaceState> _readState(ProviderContainer container) async {
  final Result<ReportsWorkspaceState> result = await container.read(
    reportsWorkspaceControllerProvider.future,
  );
  return result.when(
    success: (ReportsWorkspaceState value) => value,
    failure: (AppFailure failure) => fail(failure.code),
  );
}

ReportsWorkspaceState _currentState(ProviderContainer container) {
  return container
      .read(reportsWorkspaceControllerProvider)
      .requireValue
      .when(
        success: (ReportsWorkspaceState value) => value,
        failure: (AppFailure failure) => fail(failure.code),
      );
}

void _stubWorkspace(_MockReportsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((invocation) async {
    final ReportsWorkspaceQuery query =
        invocation.positionalArguments.single as ReportsWorkspaceQuery;
    final List<ReportsWorkspaceItem> items =
        query.resource == ReportsWorkspaceResource.reportRuns
        ? const <ReportsWorkspaceItem>[
            ReportsWorkspaceItem(
              id: 'run-1',
              kind: ReportItemKind.run,
              title: 'Daily census',
              status: 'QUEUED',
            ),
          ]
        : const <ReportsWorkspaceItem>[
            ReportsWorkspaceItem(
              id: 'definition-1',
              kind: ReportItemKind.definition,
              title: 'Daily census',
              status: 'ACTIVE',
            ),
          ];
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

void _stubSchedules(
  _MockReportsRepository repository, {
  List<ReportsWorkspaceItem> items = const <ReportsWorkspaceItem>[
    ReportsWorkspaceItem(
      id: 'schedule-1',
      kind: ReportItemKind.schedule,
      title: 'Daily census email',
      status: 'ACTIVE',
    ),
  ],
}) {
  when(() => repository.listSchedules(any())).thenAnswer((invocation) async {
    final ReportsWorkspaceQuery query =
        invocation.positionalArguments.single as ReportsWorkspaceQuery;
    return Result<AppPage<ReportsWorkspaceItem>>.success(
      AppPage<ReportsWorkspaceItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
}
