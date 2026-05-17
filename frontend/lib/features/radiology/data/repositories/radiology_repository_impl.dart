import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/radiology/data/dtos/radiology_dtos.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final radiologyRepositoryProvider = Provider<RadiologyRepository>((ref) {
  return RadiologyRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class RadiologyRepositoryImpl implements RadiologyRepository {
  const RadiologyRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<RadiologyWorkbench>> getWorkbench(
    RadiologyWorkspaceQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<RadiologyWorkbench>(
      _radiologyEndpoint(<String>['workbench']),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'stage': query.stage == 'ALL' ? null : query.stage,
        'status': query.status,
        'modality': query.modality,
        'from': _iso(query.from),
        'to': _iso(query.to),
        'patient_id': query.patientId,
        'encounter_id': query.encounterId,
        'search': query.search,
        'sort_by': 'ordered_at',
        'order': 'desc',
      }),
      decoder: (Object? data) {
        return RadiologyWorkbenchDto.fromResponse(data, request).workbench;
      },
    );
  }

  @override
  Future<Result<RadiologyReferenceData>> getReferenceData({
    String? search,
    String? patientId,
    int limit = 20,
  }) {
    return _apiClient.get<RadiologyReferenceData>(
      _radiologyEndpoint(<String>['reference-data']),
      queryParameters: _withoutEmpty(<String, Object?>{
        'search': search,
        'patient_id': patientId,
        'limit': limit,
      }),
      decoder: (Object? data) {
        return RadiologyReferenceDataDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<RadiologyWorkflow>> getWorkflow(String orderId) {
    return _apiClient.get<RadiologyWorkflow>(
      _radiologyEndpoint(<String>['orders', orderId, 'workflow']),
      decoder: _decodeWorkflow,
    );
  }

  @override
  Future<Result<RadiologyWorkflow>> createOrder(Map<String, Object?> payload) {
    return _apiClient.post<RadiologyWorkflow>(
      _radiologyEndpoint(<String>['orders']),
      data: _withoutEmpty(payload),
      decoder: _decodeWorkflow,
    );
  }

  @override
  Future<Result<RadiologyWorkflow>> assignOrder(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _postOrderAction(orderId, 'assign', payload);
  }

  @override
  Future<Result<RadiologyWorkflow>> startOrder(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _postOrderAction(orderId, 'start', payload);
  }

  @override
  Future<Result<RadiologyWorkflow>> completeOrder(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _postOrderAction(orderId, 'complete', payload);
  }

  @override
  Future<Result<RadiologyWorkflow>> cancelOrder(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _postOrderAction(orderId, 'cancel', payload);
  }

  @override
  Future<Result<RadiologyWorkflow>> createStudy(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<RadiologyWorkflow>(
      _radiologyEndpoint(<String>['orders', orderId, 'studies']),
      data: _withoutEmpty(payload),
      decoder: _decodeWorkflow,
    );
  }

  @override
  Future<Result<RadiologyWorkflow>> draftResult(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<RadiologyWorkflow>(
      _radiologyEndpoint(<String>['orders', orderId, 'results', 'draft']),
      data: _withoutEmpty(payload),
      decoder: _decodeWorkflow,
    );
  }

  @override
  Future<Result<RadiologyWorkflow>> finalizeResult(
    String resultId,
    Map<String, Object?> payload,
  ) {
    return _postResultAction(resultId, 'finalize', payload);
  }

  @override
  Future<Result<RadiologyWorkflow>> requestFinalization(
    String resultId,
    Map<String, Object?> payload,
  ) {
    return _postResultAction(resultId, 'request-finalization', payload);
  }

  @override
  Future<Result<RadiologyWorkflow>> attestFinalization(
    String resultId,
    Map<String, Object?> payload,
  ) {
    return _postResultAction(resultId, 'attest-finalization', payload);
  }

  @override
  Future<Result<RadiologyWorkflow>> addendumResult(
    String resultId,
    Map<String, Object?> payload,
  ) {
    return _postResultAction(resultId, 'addendum', payload);
  }

  @override
  Future<Result<RadiologyWorkflow>> syncStudyToPacs(
    String studyId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<RadiologyWorkflow>(
      _radiologyEndpoint(<String>['studies', studyId, 'pacs-sync']),
      data: _withoutEmpty(payload),
      decoder: _decodeWorkflow,
    );
  }

  Future<Result<RadiologyWorkflow>> _postOrderAction(
    String orderId,
    String action,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<RadiologyWorkflow>(
      _radiologyEndpoint(<String>['orders', orderId, action]),
      data: _withoutEmpty(payload),
      decoder: _decodeWorkflow,
    );
  }

  Future<Result<RadiologyWorkflow>> _postResultAction(
    String resultId,
    String action,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<RadiologyWorkflow>(
      _radiologyEndpoint(<String>['results', resultId, action]),
      data: _withoutEmpty(payload),
      decoder: _decodeWorkflow,
    );
  }

  RadiologyWorkflow _decodeWorkflow(Object? data) {
    return RadiologyWorkflowDto.fromResponse(data).toEntity();
  }
}

Uri _radiologyEndpoint(List<String> segments) {
  return ApiEndpoints.apiV1(<String>[
    HmsApiResource.radiology.path,
    ...segments,
  ]);
}

String? _iso(DateTime? value) {
  return value?.toUtc().toIso8601String();
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
