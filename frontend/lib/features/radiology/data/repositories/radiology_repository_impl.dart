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
        'view': query.view == RadiologyWorkbenchView.patients
            ? 'PATIENTS'
            : 'ORDERS',
        'status': query.status,
        'modality': query.modality,
        'priority': query.priority,
        'billing_gate': query.billingGate,
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
  Future<Result<List<RadiologyCatalogProcedure>>> listRadiologyCatalogProcedures({
    String? search,
    String? tenantId,
    bool includeStandardCatalog = true,
    bool includeDeleted = false,
    int limit = 100,
  }) {
    return _apiClient.get<List<RadiologyCatalogProcedure>>(
      ApiEndpoints.collection(HmsApiResource.radiologyProcedures),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'search': search,
        'tenant_id': tenantId,
        'include_standard_catalog': includeStandardCatalog,
        'include_deleted': includeDeleted ? true : null,
        'limit': limit,
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: RadiologyCatalogProcedureDto.listFromResponse,
    );
  }

  @override
  Future<Result<List<RadiologyCatalogProcedure>>> listFacilityRadiologyProcedures({
    String? tenantId,
    String? facilityId,
    String? search,
    int page = 1,
    int limit = 100,
    bool offeredOnly = false,
  }) {
    return _apiClient.get<List<RadiologyCatalogProcedure>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityRadiologyCatalog.path,
        'tests',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
        'page': page,
        'limit': limit,
        'search': search,
        'offered_only': offeredOnly ? 'true' : 'false',
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: RadiologyCatalogProcedureDto.listFromResponse,
    );
  }

  @override
  Future<Result<List<RadiologyCatalogProcedure>>> searchFacilityRadiologyCatalog({
    String? tenantId,
    String? facilityId,
    String? query,
    int limit = 25,
  }) {
    return _apiClient.get<List<RadiologyCatalogProcedure>>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityRadiologyCatalog.path,
        'search',
      ]),
      queryParameters: _withoutEmpty(<String, Object?>{
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
        'term_type': 'RADIOLOGY_TEST',
        'q': query,
        'limit': limit,
        'offered_only': 'false',
      }),
      decoder: RadiologyCatalogProcedureDto.listFromResponse,
    );
  }

  @override
  Future<Result<RadiologyCatalogProcedure>> upsertFacilityRadiologyProcedureOffering(
    String procedureId,
    Map<String, Object?> payload, {
    String? tenantId,
    String? facilityId,
  }) {
    return _apiClient.put<RadiologyCatalogProcedure>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityRadiologyCatalog.path,
        'tests',
        procedureId,
      ]),
      data: _withoutEmpty(<String, Object?>{
        ...payload,
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
      }),
      decoder: radiologyCatalogProcedureFromResponse,
    );
  }

  @override
  Future<Result<void>> disableFacilityRadiologyProcedureOffering(
    String procedureId,
    String reason, {
    String? tenantId,
    String? facilityId,
  }) {
    return _apiClient.delete<void>(
      ApiEndpoints.apiV1(<String>[
        HmsApiResource.facilityRadiologyCatalog.path,
        'tests',
        procedureId,
      ]),
      data: _withoutEmpty(<String, Object?>{
        'reason': reason,
        ..._catalogScopeParams(tenantId: tenantId, facilityId: facilityId),
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<RadiologyCatalogProcedure>> createRadiologyCatalogProcedure(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<RadiologyCatalogProcedure>(
      ApiEndpoints.collection(HmsApiResource.radiologyProcedures),
      data: _withoutEmpty(payload),
      decoder: radiologyCatalogProcedureFromResponse,
    );
  }

  @override
  Future<Result<RadiologyCatalogProcedure>> updateRadiologyCatalogProcedure(
    String procedureId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<RadiologyCatalogProcedure>(
      ApiEndpoints.byId(HmsApiResource.radiologyProcedures, procedureId),
      data: _withoutEmpty(payload),
      decoder: radiologyCatalogProcedureFromResponse,
    );
  }

  @override
  Future<Result<RadiologyCatalogProcedure>> deleteRadiologyCatalogProcedure(
    String procedureId,
  ) {
    return _apiClient.delete<RadiologyCatalogProcedure>(
      ApiEndpoints.byId(HmsApiResource.radiologyProcedures, procedureId),
      decoder: radiologyCatalogProcedureFromResponse,
    );
  }

  @override
  Future<Result<RadiologyCatalogProcedure>> restoreRadiologyCatalogProcedure(
    String procedureId,
  ) {
    return _apiClient.post<RadiologyCatalogProcedure>(
      ApiEndpoints.nested(
        HmsApiResource.radiologyProcedures,
        procedureId,
        const <String>['restore'],
      ),
      decoder: radiologyCatalogProcedureFromResponse,
    );
  }

  @override
  Future<Result<void>> permanentDeleteRadiologyCatalogProcedure(
    String procedureId,
  ) {
    return _apiClient.delete<void>(
      ApiEndpoints.nested(
        HmsApiResource.radiologyProcedures,
        procedureId,
        const <String>['permanent'],
      ),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<List<RadiologyEquipmentRecord>>> listEquipmentRecords({
    String? search,
  }) {
    return _apiClient.get<List<RadiologyEquipmentRecord>>(
      ApiEndpoints.collection(HmsApiResource.equipmentRegistries),
      queryParameters: _withoutEmpty(<String, Object?>{
        'search': search,
        'limit': 100,
        'sort_by': 'equipment_name',
        'order': 'asc',
      }),
      decoder: RadiologyEquipmentRecordDto.listFromResponse,
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
  Future<Result<RadiologyWorkflow>> updateOrderRequestDetails(
    String orderId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<RadiologyWorkflow>(
      _radiologyEndpoint(<String>['orders', orderId, 'request-details']),
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
  Future<Result<RadiologyWorkflow>> undoStudy(String studyId) {
    return _apiClient.delete<RadiologyWorkflow>(
      _radiologyEndpoint(<String>['studies', studyId]),
      decoder: _decodeWorkflow,
    );
  }

  @override
  Future<Result<RadiologyWorkflow>> undoDraftResult(String resultId) {
    return _apiClient.delete<RadiologyWorkflow>(
      _radiologyEndpoint(<String>['results', resultId]),
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

  @override
  Future<Result<StudyAssetUploadSession>> initStudyAssetUpload(
    String studyId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<StudyAssetUploadSession>(
      _radiologyEndpoint(<String>['studies', studyId, 'assets', 'init-upload']),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        final Map<String, Object?> json = data is Map
            ? Map<String, Object?>.from(data)
            : const <String, Object?>{};
        String? readString(Object? value) {
          if (value is String) {
            final String trimmed = value.trim();
            return trimmed.isEmpty ? null : trimmed;
          }
          return null;
        }

        return StudyAssetUploadSession(
          storageKey: readString(json['storage_key']) ?? '',
          uploadToken: readString(json['upload_token']) ?? '',
          uploadUrl: readString(json['upload_url']),
        );
      },
    );
  }

  @override
  Future<Result<RadiologyWorkflow>> commitStudyAssetUpload(
    String studyId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<RadiologyWorkflow>(
      _radiologyEndpoint(<String>[
        'studies',
        studyId,
        'assets',
        'commit-upload',
      ]),
      data: _withoutEmpty(payload),
      decoder: _decodeWorkflow,
    );
  }

  @override
  Future<Result<void>> deleteStudyAsset(String assetId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.imagingAssets, assetId),
      decoder: (_) {},
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

Map<String, Object?> _catalogScopeParams({
  String? tenantId,
  String? facilityId,
}) {
  return <String, Object?>{
    if (tenantId != null && tenantId.trim().isNotEmpty) 'tenant_id': tenantId,
    if (facilityId != null && facilityId.trim().isNotEmpty)
      'facility_id': facilityId,
  };
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
