import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/nursing/data/dtos/nursing_dtos.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/domain/repositories/nursing_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final nursingRepositoryProvider = Provider<NursingRepository>((ref) {
  return NursingRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class NursingRepositoryImpl implements NursingRepository {
  const NursingRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<NursingPatientSummary>>> listWardPatients(
    NursingWorklistQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<NursingPatientSummary>>(
      ApiEndpoints.collection(HmsApiResource.ipdFlows),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'queue_scope': query.scope == NursingQueueScope.all ? 'ALL' : 'ACTIVE',
        'include_icu': 'true',
        'sort_by': 'admitted_at',
        'order': 'desc',
      }),
      decoder: (Object? data) =>
          NursingPatientSummaryPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<NursingPatientDetail>> loadPatientDetail(
    NursingPatientSummary summary,
  ) async {
    final Result<NursingPatientDetail> snapshotResult = await _loadIpdSnapshot(
      summary,
    );

    return snapshotResult.when(
      success: (NursingPatientDetail detail) async {
        final List<NursingVitalSign> vitals = await _relatedVitals(detail);
        final List<NursingCarePlan> carePlans = await _relatedCarePlans(detail);
        final List<NursingHandover> handovers = await _relatedHandovers(detail);

        return Result<NursingPatientDetail>.success(
          detail.copyWith(
            vitalSigns: vitals,
            carePlans: carePlans,
            handovers: handovers,
          ),
        );
      },
      failure: (AppFailure failure) async {
        return Result<NursingPatientDetail>.failure(failure);
      },
    );
  }

  @override
  Future<Result<List<NursingHandover>>> listPendingHandovers() {
    return _apiClient.get<List<NursingHandover>>(
      ApiEndpoints.collection(HmsApiResource.handovers),
      queryParameters: const <String, Object?>{
        'page': 1,
        'limit': 50,
        'status': 'PENDING',
        'sort_by': 'created_at',
        'order': 'desc',
      },
      decoder: decodeNursingHandovers,
    );
  }

  @override
  Future<Result<List<NursingRosterAssignment>>> listCurrentRosters() {
    return _apiClient.get<List<NursingRosterAssignment>>(
      ApiEndpoints.collection(HmsApiResource.nurseRosters),
      queryParameters: const <String, Object?>{
        'page': 1,
        'limit': 8,
        'status': 'PUBLISHED',
        'sort_by': 'period_start',
        'order': 'desc',
      },
      decoder: decodeNursingRosters,
    );
  }

  @override
  Future<Result<NursingPatientDetail>> recordVitals(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  ) async {
    final Result<void> result = await _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.vitalSigns),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
    return _reloadAfterMutation(result, summary);
  }

  @override
  Future<Result<NursingPatientDetail>> addNursingNote(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  ) async {
    final Result<void> result = await _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.ipdFlows,
        summary.apiAdmissionId,
        <String>['add-nursing-note'],
      ),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
    return _reloadAfterMutation(result, summary);
  }

  @override
  Future<Result<NursingPatientDetail>> addMedicationAdministration(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  ) async {
    final Result<void> result = await _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.ipdFlows,
        summary.apiAdmissionId,
        <String>['add-medication-administration'],
      ),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
    return _reloadAfterMutation(result, summary);
  }

  @override
  Future<Result<NursingPatientDetail>> addCarePlan(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  ) async {
    final Result<void> result = await _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.carePlans),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
    return _reloadAfterMutation(result, summary);
  }

  @override
  Future<Result<NursingPatientDetail>> createHandover(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  ) async {
    final Result<void> result = await _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.handovers),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
    return _reloadAfterMutation(result, summary);
  }

  @override
  Future<Result<void>> acceptHandover(
    String handoverId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(HmsApiResource.handovers, handoverId, <String>[
        'accept',
      ]),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<NursingPatientDetail>> updateTransfer(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  ) async {
    final Result<void> result = await _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.ipdFlows,
        summary.apiAdmissionId,
        <String>['update-transfer'],
      ),
      data: _withoutEmpty(payload),
      decoder: (_) {},
    );
    return _reloadAfterMutation(result, summary);
  }

  Future<Result<NursingPatientDetail>> _loadIpdSnapshot(
    NursingPatientSummary summary,
  ) {
    return _apiClient.get<NursingPatientDetail>(
      ApiEndpoints.byId(
        HmsApiResource.ipdFlows,
        summary.apiAdmissionId,
        queryParameters: const <String, String>{'include_icu': 'true'},
      ),
      decoder: (Object? data) =>
          NursingPatientDetailDto.fromResponse(data, summary).toEntity(),
    );
  }

  Future<List<NursingVitalSign>> _relatedVitals(
    NursingPatientDetail detail,
  ) async {
    final String? encounterId = detail.summary.encounterDisplayId;
    if (!_isNonEmpty(encounterId)) {
      return const <NursingVitalSign>[];
    }

    final Result<List<NursingVitalSign>> result = await _apiClient
        .get<List<NursingVitalSign>>(
          ApiEndpoints.collection(HmsApiResource.vitalSigns),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': 25,
            'encounter_id': encounterId,
            'sort_by': 'recorded_at',
            'order': 'desc',
          }),
          decoder: decodeNursingVitals,
        );

    return _listOrEmptyOnDenied(result);
  }

  Future<List<NursingCarePlan>> _relatedCarePlans(
    NursingPatientDetail detail,
  ) async {
    final String? encounterId = detail.summary.encounterDisplayId;
    if (!_isNonEmpty(encounterId)) {
      return const <NursingCarePlan>[];
    }

    final Result<List<NursingCarePlan>> result = await _apiClient
        .get<List<NursingCarePlan>>(
          ApiEndpoints.collection(HmsApiResource.carePlans),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': 20,
            'encounter_id': encounterId,
            'sort_by': 'created_at',
            'order': 'desc',
          }),
          decoder: decodeNursingCarePlans,
        );

    return _listOrEmptyOnDenied(result);
  }

  Future<List<NursingHandover>> _relatedHandovers(
    NursingPatientDetail detail,
  ) async {
    final Result<List<NursingHandover>> result = await listPendingHandovers();
    final List<NursingHandover> handovers = _listOrEmptyOnDenied(result);
    return handovers
        .where(
          (NursingHandover item) =>
              item.admissionId == null ||
              item.admissionId == detail.summary.admissionId,
        )
        .toList(growable: false);
  }

  Future<Result<NursingPatientDetail>> _reloadAfterMutation(
    Result<void> mutation,
    NursingPatientSummary summary,
  ) {
    return mutation.when(
      success: (_) => loadPatientDetail(summary),
      failure: (AppFailure failure) async =>
          Result<NursingPatientDetail>.failure(failure),
    );
  }

  List<T> _listOrEmptyOnDenied<T>(Result<List<T>> result) {
    return result.when(
      success: (List<T> value) => value,
      failure: (AppFailure failure) {
        if (_isAccessDenied(failure) ||
            failure.category == AppFailureCategory.validation) {
          return <T>[];
        }
        return <T>[];
      },
    );
  }

  bool _isAccessDenied(AppFailure failure) {
    return failure.category == AppFailureCategory.unauthorized ||
        failure.category == AppFailureCategory.forbidden;
  }

  Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in payload.entries)
        if (!_isEmpty(entry.value)) entry.key: entry.value,
    };
  }

  bool _isEmpty(Object? value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is Iterable<Object?>) {
      return value.isEmpty;
    }
    if (value is Map<Object?, Object?>) {
      return value.isEmpty;
    }
    return false;
  }

  bool _isNonEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
