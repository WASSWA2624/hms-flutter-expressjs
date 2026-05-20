import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/housekeeping/data/dtos/housekeeping_dtos.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/domain/repositories/housekeeping_repository.dart';

final housekeepingRepositoryProvider = Provider<HousekeepingRepository>((ref) {
  return HousekeepingRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class HousekeepingRepositoryImpl implements HousekeepingRepository {
  const HousekeepingRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<HousekeepingWorkspaceLoad>> getWorkspace(
    HousekeepingWorkspaceQuery query,
  ) {
    final request = query.pageRequest;
    return _apiClient.get<HousekeepingWorkspaceLoad>(
      ApiEndpoints.collection(HmsApiResource.housekeeping),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'panel': query.resource.panel,
        'resource': query.resource.serverValue,
        'queue': query.queue == HousekeepingQueue.all
            ? null
            : query.queue.serverValue,
        'search': query.search,
        'status': query.status,
        'facility_id': query.facilityId,
        'room_id': query.roomId,
        'assignee_id': query.assigneeId,
        'date_preset': query.datePreset.serverValue,
      }),
      decoder: (Object? data) {
        return HousekeepingWorkspaceDto.fromResponse(
          data,
          request,
        ).toEntity(request);
      },
    );
  }

  @override
  Future<Result<void>> createTask(HousekeepingTaskDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.housekeepingTasks),
      data: _withoutEmpty(<String, Object?>{
        'facility_id': draft.facilityId,
        'room_id': draft.roomId,
        'assigned_to_staff_id': draft.assigneeId,
        'status': draft.status,
        'scheduled_at': _dateTime(draft.scheduledAt),
        'completed_at': _dateTime(draft.completedAt),
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> updateTask(
    String taskId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.housekeepingTasks, taskId),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createSchedule(HousekeepingScheduleDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.housekeepingSchedules),
      data: _withoutEmpty(<String, Object?>{
        'facility_id': draft.facilityId,
        'room_id': draft.roomId,
        'frequency': draft.frequency,
        'start_date': _dateTime(draft.startDate),
        'end_date': _dateTime(draft.endDate),
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createMaintenanceRequest(
    HousekeepingMaintenanceRequestDraft draft,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.maintenanceRequests),
      data: _withoutEmpty(<String, Object?>{
        'facility_id': draft.facilityId,
        'asset_id': draft.assetId,
        'status': draft.status,
        'description': draft.description,
        'reported_at': _dateTime(draft.reportedAt),
        'resolved_at': _dateTime(draft.resolvedAt),
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> updateMaintenanceRequest(
    String requestId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.maintenanceRequests, requestId),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> triageMaintenanceRequest(
    String requestId,
    HousekeepingMaintenanceTriageDraft draft,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.maintenanceRequests,
        requestId,
        const <String>['triage'],
      ),
      data: _withoutEmpty(<String, Object?>{
        'status': draft.status,
        'triage_summary': draft.summary,
        'sla_hours': draft.slaHours,
      }),
      decoder: (_) {},
    );
  }
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

String? _dateTime(DateTime? value) {
  return value?.toUtc().toIso8601String();
}
