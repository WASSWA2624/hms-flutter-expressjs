import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/ipd/data/dtos/ipd_dtos.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final ipdRepositoryProvider = Provider<IpdRepository>((ref) {
  return IpdRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class IpdRepositoryImpl implements IpdRepository {
  const IpdRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<IpdAdmissionSummary>>> listAdmissions(
    IpdAdmissionQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<IpdAdmissionSummary>>(
      ApiEndpoints.collection(HmsApiResource.ipdFlows),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'queue_scope': _queueScopeFor(query.scope),
        'stage': _stageFor(query.scope),
        'ward_id': query.wardId,
        'include_icu': 'true',
        'sort_by': 'admitted_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          IpdAdmissionPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<IpdAdmissionDetail>> getAdmission(String admissionId) {
    return _apiClient.get<IpdAdmissionDetail>(
      ApiEndpoints.byId(
        HmsApiResource.ipdFlows,
        admissionId,
        queryParameters: const <String, String>{'include_icu': 'true'},
      ),
      decoder: (Object? data) =>
          IpdAdmissionDetailDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<List<IpdWardOption>>> listWards({String? search}) {
    return _apiClient.get<List<IpdWardOption>>(
      ApiEndpoints.collection(HmsApiResource.wards),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 100,
        'search': search,
        'is_active': 'true',
        'sort_by': 'name',
        'order': 'asc',
      }),
      decoder: decodeIpdWards,
    );
  }

  @override
  Future<Result<List<IpdBedOption>>> listBeds({
    String? search,
    String? status,
    String? wardId,
  }) {
    return _apiClient.get<List<IpdBedOption>>(
      ApiEndpoints.collection(HmsApiResource.beds),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': 100,
        'search': search,
        'status': status,
        'ward_id': wardId,
        'sort_by': 'label',
        'order': 'asc',
      }),
      decoder: decodeIpdBeds,
    );
  }

  @override
  Future<Result<IpdAdmissionDetail>> startAdmission(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<IpdAdmissionDetail>(
      ApiEndpoints.apiV1(<String>[HmsApiResource.ipdFlows.path, 'start']),
      data: _withoutEmpty(payload),
      queryParameters: const <String, Object?>{'include_icu': 'true'},
      decoder: (Object? data) =>
          IpdAdmissionDetailDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<IpdAdmissionDetail>> assignBed(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _postAction(admissionId, <String>['assign-bed'], payload);
  }

  @override
  Future<Result<IpdAdmissionDetail>> releaseBed(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _postAction(admissionId, <String>['release-bed'], payload);
  }

  @override
  Future<Result<IpdAdmissionDetail>> rejectAdmission(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _postAction(admissionId, <String>['reject-admission'], payload);
  }

  @override
  Future<Result<IpdAdmissionDetail>> requestTransfer(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _postAction(admissionId, <String>['request-transfer'], payload);
  }

  @override
  Future<Result<IpdAdmissionDetail>> updateTransfer(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _postAction(admissionId, <String>['update-transfer'], payload);
  }

  @override
  Future<Result<IpdAdmissionDetail>> addWardRound(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _postAction(admissionId, <String>['add-ward-round'], payload);
  }

  @override
  Future<Result<IpdAdmissionDetail>> addNursingNote(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _postAction(admissionId, <String>['add-nursing-note'], payload);
  }

  @override
  Future<Result<IpdAdmissionDetail>> addMedicationAdministration(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _postAction(admissionId, <String>[
      'add-medication-administration',
    ], payload);
  }

  @override
  Future<Result<IpdAdmissionDetail>> planDischarge(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _postAction(admissionId, <String>['plan-discharge'], payload);
  }

  @override
  Future<Result<IpdAdmissionDetail>> finalizeDischarge(
    String admissionId,
    Map<String, Object?> payload,
  ) {
    return _postAction(admissionId, <String>['finalize-discharge'], payload);
  }

  Future<Result<IpdAdmissionDetail>> _postAction(
    String admissionId,
    List<String> pathSegments,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<IpdAdmissionDetail>(
      ApiEndpoints.nested(HmsApiResource.ipdFlows, admissionId, pathSegments),
      data: _withoutEmpty(payload),
      queryParameters: const <String, Object?>{'include_icu': 'true'},
      decoder: (Object? data) =>
          IpdAdmissionDetailDto.fromResponse(data).toEntity(),
    );
  }
}

String _queueScopeFor(IpdQueueScope scope) {
  return switch (scope) {
    IpdQueueScope.all || IpdQueueScope.discharged => 'ALL',
    _ => 'ACTIVE',
  };
}

String? _stageFor(IpdQueueScope scope) {
  return switch (scope) {
    IpdQueueScope.admissionQueue => 'ADMITTED_PENDING_BED',
    IpdQueueScope.activePatients => 'ADMITTED_IN_BED',
    IpdQueueScope.transferPending => 'TRANSFER_REQUESTED',
    IpdQueueScope.dischargePlanned ||
    IpdQueueScope.awaitingClearance => 'DISCHARGE_PLANNED',
    IpdQueueScope.discharged => 'DISCHARGED',
    IpdQueueScope.all => null,
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
