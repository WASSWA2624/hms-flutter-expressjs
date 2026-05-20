import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/operations/data/dtos/operations_dtos.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/features/operations/domain/repositories/operations_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final operationsRepositoryProvider = Provider<OperationsRepository>((ref) {
  return OperationsRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class OperationsRepositoryImpl implements OperationsRepository {
  const OperationsRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<OperationsWorkItem>>> listRequests(
    OperationsWorkItemQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<OperationsWorkItem>>(
      ApiEndpoints.collection(HmsApiResource.maintenanceRequests),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'sort_by': 'created_at',
        'order': 'desc',
        'search': query.search,
        'status': query.status,
        'facility_id': query.facilityId,
        'asset_id': query.assetId,
      }),
      decoder: (Object? data) => OperationsWorkItemPageDto.fromResponse(
        data,
        request,
        priority: query.priority,
        reportedFrom: query.reportedFrom,
        reportedTo: query.reportedTo,
      ).page,
    );
  }

  @override
  Future<Result<OperationsWorkItem>> getRequest(String requestId) {
    return _apiClient.get<OperationsWorkItem>(
      ApiEndpoints.byId(HmsApiResource.maintenanceRequests, requestId),
      decoder: (Object? data) =>
          OperationsWorkItemDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<AppPage<OperationsAsset>>> listAssets(
    OperationsAssetQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<OperationsAsset>>(
      ApiEndpoints.collection(HmsApiResource.facilityAssets),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'sort_by': 'updated_at',
        'order': 'desc',
        'search': query.search,
        'status': query.status,
      }),
      decoder: (Object? data) =>
          OperationsAssetPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<AppPage<OperationsServiceLog>>> listServiceLogs(
    OperationsServiceLogQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<OperationsServiceLog>>(
      ApiEndpoints.collection(HmsApiResource.assetServiceLogs),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'sort_by': 'serviced_at',
        'order': 'desc',
        'asset_id': query.assetId,
        'search': query.search,
      }),
      decoder: (Object? data) =>
          OperationsServiceLogPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<OperationsWorkItem>> createRequest(
    OperationsRequestDraft draft,
  ) {
    return _apiClient.post<OperationsWorkItem>(
      ApiEndpoints.collection(HmsApiResource.maintenanceRequests),
      data: _withoutEmpty(<String, Object?>{
        'facility_id': draft.facilityId,
        'asset_id': draft.assetId,
        'status': 'OPEN',
        'description': _buildRequestDescription(draft),
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      }),
      decoder: (Object? data) =>
          OperationsWorkItemDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OperationsWorkItem>> triageRequest(
    String requestId,
    OperationsTriageDraft draft,
  ) {
    return _apiClient.post<OperationsWorkItem>(
      ApiEndpoints.nested(HmsApiResource.maintenanceRequests, requestId, <String>[
        'triage',
      ]),
      data: _withoutEmpty(<String, Object?>{
        'status': 'IN_PROGRESS',
        'assigned_engineer': draft.assignedEngineer,
        'triage_summary': draft.triageSummary,
        'sla_hours': draft.slaHours,
      }),
      decoder: (Object? data) =>
          OperationsWorkItemDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OperationsWorkItem>> updateRequestStatus(
    OperationsWorkItem request,
    OperationsStatusUpdateDraft draft,
  ) {
    final String normalizedStatus = draft.status.trim().toUpperCase();
    final bool terminalStatus = normalizedStatus == 'COMPLETED';
    return _apiClient.put<OperationsWorkItem>(
      ApiEndpoints.byId(
        HmsApiResource.maintenanceRequests,
        request.effectiveDisplayId,
      ),
      data: _withoutEmpty(<String, Object?>{
        'status': normalizedStatus,
        'description': _appendNote(
          request.description,
          'STATUS',
          draft.notes,
        ),
        'resolved_at': terminalStatus
            ? (draft.resolvedAt ?? DateTime.now()).toUtc().toIso8601String()
            : null,
      }),
      decoder: (Object? data) =>
          OperationsWorkItemDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OperationsWorkItem>> appendRequestNote(
    OperationsWorkItem request,
    OperationsRequestNoteDraft draft,
  ) {
    return _apiClient.put<OperationsWorkItem>(
      ApiEndpoints.byId(
        HmsApiResource.maintenanceRequests,
        request.effectiveDisplayId,
      ),
      data: _withoutEmpty(<String, Object?>{
        'description': _appendNote(
          request.description,
          draft.kind,
          draft.note,
        ),
      }),
      decoder: (Object? data) =>
          OperationsWorkItemDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<OperationsServiceLog>> addServiceLog(
    OperationsServiceLogDraft draft,
  ) {
    return _apiClient.post<OperationsServiceLog>(
      ApiEndpoints.collection(HmsApiResource.assetServiceLogs),
      data: _withoutEmpty(<String, Object?>{
        'asset_id': draft.assetId,
        'serviced_at': (draft.servicedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'notes': draft.notes,
      }),
      decoder: (Object? data) =>
          OperationsServiceLogDto.fromResponse(data).toEntity(),
    );
  }
}

String _buildRequestDescription(OperationsRequestDraft draft) {
  final List<String> lines = <String>[
    'Category: ${_apiLabel(draft.category)}',
    'Priority: ${_apiLabel(draft.priority)}',
    'Issue: ${draft.issue.trim()}',
    if (_nonEmpty(draft.location) != null) 'Location: ${draft.location!.trim()}',
    if (_nonEmpty(draft.notes) != null) 'Notes: ${draft.notes!.trim()}',
  ];
  return lines.join('\n');
}

String? _appendNote(String? existing, String kind, String? note) {
  final String? normalizedNote = _nonEmpty(note);
  if (normalizedNote == null) {
    return existing;
  }

  final String marker = kind.trim().toUpperCase().replaceAll(' ', '_');
  final String entry =
      '[$marker] ${DateTime.now().toUtc().toIso8601String()} $normalizedNote';
  final String? normalizedExisting = _nonEmpty(existing);
  if (normalizedExisting == null) {
    return entry;
  }
  return '$normalizedExisting\n\n$entry';
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

String _apiLabel(String value) {
  return value
      .trim()
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
