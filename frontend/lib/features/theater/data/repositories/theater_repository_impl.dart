import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/theater/data/dtos/theater_dtos.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/domain/repositories/theater_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final theaterRepositoryProvider = Provider<TheaterRepository>((ref) {
  return TheaterRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class TheaterRepositoryImpl implements TheaterRepository {
  const TheaterRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<TheaterCase>>> listCases(TheaterCaseQuery query) {
    final AppPageRequest request = query.pageRequest;
    final _DateRange? range = _dateRange(query.scheduledDate);
    return _apiClient.get<AppPage<TheaterCase>>(
      ApiEndpoints.collection(HmsApiResource.theatreFlows),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'queue_scope': query.queueScope,
        'search': query.search,
        'status': query.status,
        'stage': query.stage,
        'room_id': query.roomId,
        'surgeon_user_id': query.surgeonUserId,
        'anesthetist_user_id': query.anesthetistUserId,
        'scheduled_from': range?.from.toUtc().toIso8601String(),
        'scheduled_to': range?.to.toUtc().toIso8601String(),
        'sort_by': 'scheduled_at',
        'order': 'asc',
      }),
      decoder: (Object? data) =>
          TheaterCasePageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<TheaterCase>> getCase(String caseId) {
    return _apiClient.get<TheaterCase>(
      ApiEndpoints.byId(
        HmsApiResource.theatreFlows,
        caseId,
        queryParameters: <String, String>{'include_timeline': 'true'},
      ),
      decoder: (Object? data) => TheaterCaseDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<TheaterCase>> scheduleCase(Map<String, Object?> payload) {
    return _apiClient.post<TheaterCase>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.theatreFlows.path, 'start']),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => TheaterCaseDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<TheaterCase>> updateCaseSchedule(
    String caseId,
    Map<String, Object?> payload,
  ) async {
    final Result<TheaterCase> updateResult = await _apiClient.put<TheaterCase>(
      ApiEndpoints.byId(HmsApiResource.theatreCases, caseId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => TheaterCaseDto.fromResponse(data).toEntity(),
    );

    return updateResult.when(
      success: (_) => getCase(caseId),
      failure: (failure) => Result<TheaterCase>.failure(failure),
    );
  }

  @override
  Future<Result<TheaterCase>> updateStage(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'update-stage', payload);
  }

  @override
  Future<Result<TheaterCase>> upsertAnesthesiaRecord(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'upsert-anesthesia-record', payload);
  }

  @override
  Future<Result<TheaterCase>> addAnesthesiaObservation(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'add-anesthesia-observation', payload);
  }

  @override
  Future<Result<TheaterCase>> upsertPostOpNote(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'upsert-post-op-note', payload);
  }

  @override
  Future<Result<TheaterCase>> toggleChecklistItem(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'toggle-checklist-item', payload);
  }

  @override
  Future<Result<TheaterCase>> assignResource(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'assign-resource', payload);
  }

  @override
  Future<Result<TheaterCase>> releaseResource(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'release-resource', payload);
  }

  @override
  Future<Result<TheaterCase>> finalizeRecord(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'finalize-record', payload);
  }

  @override
  Future<Result<TheaterCase>> reopenRecord(
    String caseId,
    Map<String, Object?> payload,
  ) {
    return _postCaseAction(caseId, 'reopen-record', payload);
  }

  Future<Result<TheaterCase>> _postCaseAction(
    String caseId,
    String action,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<TheaterCase>(
      ApiEndpoints.nested(HmsApiResource.theatreFlows, caseId, <String>[
        action,
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => TheaterCaseDto.fromResponse(data).toEntity(),
    );
  }
}

final class _DateRange {
  const _DateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

_DateRange? _dateRange(DateTime? date) {
  if (date == null) {
    return null;
  }

  final DateTime from = DateTime(date.year, date.month, date.day);
  final DateTime to = from.add(const Duration(days: 1));
  return _DateRange(from: from, to: to);
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
