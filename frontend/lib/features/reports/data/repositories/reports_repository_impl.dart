import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/reports/data/dtos/reports_dtos.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class ReportsRepositoryImpl implements ReportsRepository {
  const ReportsRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<ReportsWorkspaceOverview>> getWorkspace(
    ReportsWorkspaceQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<ReportsWorkspaceOverview>(
      ApiEndpoints.collection(HmsApiResource.reportsWorkspace),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'panel': query.panel.serverValue,
        'resource': query.resource.serverValue,
        'search': query.search,
        'status': query.status,
        'format': query.format,
        'dataset': query.dataset,
        'trigger': query.trigger,
        'datePreset': query.datePreset,
        'from': query.from?.toUtc().toIso8601String(),
        'to': query.to?.toUtc().toIso8601String(),
      }),
      decoder: (Object? data) {
        return ReportsWorkspaceOverviewDto.fromResponse(
          data,
          request: request,
        ).toEntity();
      },
    );
  }

  @override
  Future<Result<AppPage<ReportsWorkspaceItem>>> listSchedules(
    ReportsWorkspaceQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<ReportsWorkspaceItem>>(
      ApiEndpoints.collection(HmsApiResource.reportSchedules),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'status': query.status,
      }),
      decoder: (Object? data) {
        return ReportsWorkspaceItemPageDto.schedulesFromPaginatedResponse(
          data,
          request: request,
        ).page;
      },
    );
  }

  @override
  Future<Result<AppPage<ComplianceLogItem>>> listComplianceLogs(
    ReportsWorkspaceQuery query,
  ) {
    final ComplianceLogKind kind = query.complianceLogKind;
    final AppPageRequest request = query.pageRequest;
    final HmsApiResource resource = switch (kind) {
      ComplianceLogKind.audit => HmsApiResource.auditLogs,
      ComplianceLogKind.phiAccess => HmsApiResource.phiAccessLogs,
      ComplianceLogKind.dataProcessing => HmsApiResource.dataProcessingLogs,
    };
    return _apiClient.get<AppPage<ComplianceLogItem>>(
      ApiEndpoints.collection(resource),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'action': kind == ComplianceLogKind.audit ? query.status : null,
        'access_scope': kind == ComplianceLogKind.phiAccess
            ? query.status
            : null,
        'purpose': kind == ComplianceLogKind.dataProcessing
            ? query.status
            : null,
        'date_from': query.from?.toUtc().toIso8601String(),
        'date_to': query.to?.toUtc().toIso8601String(),
      }),
      decoder: (Object? data) {
        return ComplianceLogItemPageDto.fromPaginatedResponse(
          data,
          request: request,
          kind: kind,
        ).page;
      },
    );
  }

  @override
  Future<Result<ReportsWorkspaceItem>> runReportDefinitionNow(
    String reportDefinitionId,
    ReportRunDraft draft,
  ) {
    return _apiClient.post<ReportsWorkspaceItem>(
      ApiEndpoints.nested(
        HmsApiResource.reportDefinitions,
        reportDefinitionId,
        const <String>['run-now'],
      ),
      data: _reportRunPayload(draft),
      decoder: decodeReportRun,
    );
  }

  @override
  Future<Result<ReportsWorkspaceItem>> retryReportRun(
    String reportRunId,
    ReportRunDraft draft,
  ) {
    return _apiClient.post<ReportsWorkspaceItem>(
      ApiEndpoints.nested(
        HmsApiResource.reportRuns,
        reportRunId,
        const <String>['retry'],
      ),
      data: _reportRunPayload(draft),
      decoder: decodeReportRun,
    );
  }

  @override
  Future<Result<ReportsWorkspaceItem>> cancelReportRun(String reportRunId) {
    return _apiClient.post<ReportsWorkspaceItem>(
      ApiEndpoints.nested(
        HmsApiResource.reportRuns,
        reportRunId,
        const <String>['cancel'],
      ),
      data: const <String, Object?>{},
      decoder: decodeReportRun,
    );
  }

  @override
  Future<Result<ReportsWorkspaceItem>> createSchedule(
    ReportScheduleDraft draft,
  ) {
    return _apiClient.post<ReportsWorkspaceItem>(
      ApiEndpoints.collection(HmsApiResource.reportSchedules),
      data: _withoutEmpty(<String, Object?>{
        'report_definition_id': draft.reportDefinitionId,
        'name': draft.name,
        'frequency': draft.frequency,
        'time_of_day': draft.timeOfDay,
        'day_of_week': draft.dayOfWeek,
        'day_of_month': draft.dayOfMonth,
        'timezone': draft.timezone,
        'format': draft.format,
        'retention_days': draft.retentionDays,
      }),
      decoder: decodeReportSchedule,
    );
  }

  @override
  Future<Result<ReportsWorkspaceItem>> pauseSchedule(String scheduleId) {
    return _apiClient.post<ReportsWorkspaceItem>(
      ApiEndpoints.nested(
        HmsApiResource.reportSchedules,
        scheduleId,
        const <String>['pause'],
      ),
      decoder: decodeReportSchedule,
    );
  }

  @override
  Future<Result<ReportsWorkspaceItem>> resumeSchedule(String scheduleId) {
    return _apiClient.post<ReportsWorkspaceItem>(
      ApiEndpoints.nested(
        HmsApiResource.reportSchedules,
        scheduleId,
        const <String>['resume'],
      ),
      decoder: decodeReportSchedule,
    );
  }

  @override
  Future<Result<List<int>>> downloadReportRun(String reportRunId) {
    return _apiClient.get<List<int>>(
      ApiEndpoints.nested(
        HmsApiResource.reportRuns,
        reportRunId,
        const <String>['download'],
      ),
      options: Options(responseType: ResponseType.bytes),
      decoder: (Object? data) {
        if (data is List<int>) {
          return data;
        }
        if (data is List) {
          return data.whereType<int>().toList(growable: false);
        }
        return const <int>[];
      },
    );
  }
}

Map<String, Object?> _reportRunPayload(ReportRunDraft draft) {
  return _withoutEmpty(<String, Object?>{
    'format': draft.format,
    'retention_days': draft.retentionDays,
  });
}

Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_isEmptyPayloadValue(entry.value)) entry.key: entry.value,
  };
}

bool _isEmptyPayloadValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable) {
    return value.isEmpty;
  }
  if (value is Map) {
    return value.isEmpty;
  }
  return false;
}
