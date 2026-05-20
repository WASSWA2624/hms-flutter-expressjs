import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract interface class ReportsRepository {
  Future<Result<ReportsWorkspaceOverview>> getWorkspace(
    ReportsWorkspaceQuery query,
  );

  Future<Result<AppPage<ReportsWorkspaceItem>>> listSchedules(
    ReportsWorkspaceQuery query,
  );

  Future<Result<AppPage<ComplianceLogItem>>> listComplianceLogs(
    ReportsWorkspaceQuery query,
  );

  Future<Result<ReportsWorkspaceItem>> runReportDefinitionNow(
    String reportDefinitionId,
    ReportRunDraft draft,
  );

  Future<Result<ReportsWorkspaceItem>> retryReportRun(
    String reportRunId,
    ReportRunDraft draft,
  );

  Future<Result<ReportsWorkspaceItem>> cancelReportRun(String reportRunId);

  Future<Result<ReportsWorkspaceItem>> createSchedule(
    ReportScheduleDraft draft,
  );

  Future<Result<ReportsWorkspaceItem>> pauseSchedule(String scheduleId);

  Future<Result<ReportsWorkspaceItem>> resumeSchedule(String scheduleId);

  Future<Result<List<int>>> downloadReportRun(String reportRunId);
}
