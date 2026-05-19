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
        'stage': _backendStage(query.status),
        'transfer_status': _backendTransferStatus(query.transferStatus),
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
        final List<NursingNoteRecord> nursingNotes = await _relatedNursingNotes(
          detail,
        );
        final List<MedicationAdministrationRecord> administrations =
            await _relatedMedicationAdministrations(detail);
        final List<NursingVitalSign> vitals = await _relatedVitals(detail);
        final List<NursingCarePlan> carePlans = await _relatedCarePlans(detail);
        final List<NursingHandover> handovers = await _relatedHandovers(detail);

        return Result<NursingPatientDetail>.success(
          detail.copyWith(
            nursingNotes: nursingNotes.isEmpty
                ? detail.nursingNotes
                : nursingNotes,
            medicationAdministrations: administrations.isEmpty
                ? detail.medicationAdministrations
                : administrations,
            vitalSigns: vitals,
            carePlans: carePlans,
            handovers: handovers.isEmpty ? detail.handovers : handovers,
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
    final Map<String, NursingVitalSign> existingVitals =
        await _latestVitalsByType(payload['encounter_id']);
    final Result<void> result = await _upsertVitalPayload(
      payload,
      existingVitals,
    );
    return _reloadAfterMutation(result, summary);
  }

  @override
  Future<Result<NursingPatientDetail>> recordVitalSet(
    NursingPatientSummary summary,
    List<Map<String, Object?>> payloads,
  ) async {
    final Map<String, NursingVitalSign> existingVitals =
        await _latestVitalsByType(payloads.firstOrNull?['encounter_id']);

    for (final Map<String, Object?> payload in payloads) {
      final Result<void> result = await _upsertVitalPayload(
        payload,
        existingVitals,
      );
      final AppFailure? failure = result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      if (failure != null) {
        return Result<NursingPatientDetail>.failure(failure);
      }
    }
    return loadPatientDetail(summary);
  }

  Future<Result<void>> _upsertVitalPayload(
    Map<String, Object?> payload,
    Map<String, NursingVitalSign> existingVitals,
  ) async {
    final String vitalType = _vitalType(payload);
    if (vitalType.isEmpty) {
      return Result<void>.failure(
        AppFailure.validation(validationFields: const <String>{'vital_type'}),
      );
    }

    final NursingVitalSign? existing = existingVitals[vitalType];
    final Result<void> result = await _writeVitalPayload(payload, existing);
    final AppFailure? failure = result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );

    if (existing != null || failure?.statusCode != 409) {
      return result;
    }

    final Map<String, NursingVitalSign> refreshedVitals =
        await _latestVitalsByType(payload['encounter_id']);
    final NursingVitalSign? refreshedExisting = refreshedVitals[vitalType];
    if (refreshedExisting == null) {
      return result;
    }

    return _writeVitalPayload(payload, refreshedExisting);
  }

  Future<Result<void>> _writeVitalPayload(
    Map<String, Object?> payload,
    NursingVitalSign? existing,
  ) {
    final Map<String, Object?> data = _withoutEmpty(payload);
    if (existing == null) {
      return _apiClient.post<void>(
        ApiEndpoints.collection(HmsApiResource.vitalSigns),
        data: data,
        decoder: (_) {},
      );
    }

    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.vitalSigns, existing.id),
      data: data,
      decoder: (_) {},
    );
  }

  @override
  Future<Result<NursingPatientDetail>> addNursingNote(
    NursingPatientSummary summary,
    Map<String, Object?> payload,
  ) async {
    final Result<void> result = await _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.nursingNotes),
      data: _withoutEmpty(<String, Object?>{
        'admission_id': summary.apiAdmissionId,
        ...payload,
      }),
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
      ApiEndpoints.collection(HmsApiResource.medicationAdministrations),
      data: _withoutEmpty(<String, Object?>{
        'admission_id': summary.apiAdmissionId,
        'prescription_id': payload['prescription_id'],
        'administered_at': payload['administered_at'],
        'dose': payload['dose'],
        'unit': payload['unit'],
        'route': payload['route'],
      }),
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

  Future<List<NursingNoteRecord>> _relatedNursingNotes(
    NursingPatientDetail detail,
  ) async {
    final Result<List<NursingNoteRecord>> result = await _apiClient
        .get<List<NursingNoteRecord>>(
          ApiEndpoints.collection(HmsApiResource.nursingNotes),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': 25,
            'admission_id': detail.summary.admissionId,
            'sort_by': 'created_at',
            'order': 'desc',
          }),
          decoder: decodeNursingNotes,
        );

    return _listOrEmptyOnDenied(result);
  }

  Future<List<MedicationAdministrationRecord>>
  _relatedMedicationAdministrations(NursingPatientDetail detail) async {
    final Result<List<MedicationAdministrationRecord>> result = await _apiClient
        .get<List<MedicationAdministrationRecord>>(
          ApiEndpoints.collection(HmsApiResource.medicationAdministrations),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': 25,
            'admission_id': detail.summary.admissionId,
            'sort_by': 'administered_at',
            'order': 'desc',
          }),
          decoder: decodeMedicationAdministrations,
        );

    return _listOrEmptyOnDenied(result);
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

  Future<Map<String, NursingVitalSign>> _latestVitalsByType(
    Object? encounterId,
  ) async {
    final String? normalizedEncounterId = encounterId?.toString();
    if (!_isNonEmpty(normalizedEncounterId)) {
      return const <String, NursingVitalSign>{};
    }

    final Result<List<NursingVitalSign>> result = await _apiClient
        .get<List<NursingVitalSign>>(
          ApiEndpoints.collection(HmsApiResource.vitalSigns),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': 1,
            'limit': 50,
            'encounter_id': normalizedEncounterId,
            'sort_by': 'recorded_at',
            'order': 'desc',
          }),
          decoder: decodeNursingVitals,
        );

    final Map<String, NursingVitalSign> latestVitals =
        <String, NursingVitalSign>{};
    for (final NursingVitalSign vital in _listOrEmptyOnDenied(result)) {
      final String vitalType = vital.vitalType.trim().toUpperCase();
      if (vitalType.isNotEmpty && !latestVitals.containsKey(vitalType)) {
        latestVitals[vitalType] = vital;
      }
    }
    return latestVitals;
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

  String? _backendStage(String status) {
    final String value = status.trim().toUpperCase();
    const Set<String> supported = <String>{
      'ADMITTED_PENDING_BED',
      'ADMITTED_IN_BED',
      'TRANSFER_REQUESTED',
      'TRANSFER_IN_PROGRESS',
      'DISCHARGE_PLANNED',
      'DISCHARGED',
      'CANCELLED',
    };
    return supported.contains(value) ? value : null;
  }

  String? _backendTransferStatus(String transferStatus) {
    final String value = transferStatus.trim().toUpperCase();
    const Set<String> supported = <String>{
      'REQUESTED',
      'APPROVED',
      'IN_PROGRESS',
      'COMPLETED',
      'CANCELLED',
    };
    return supported.contains(value) ? value : null;
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

  String _vitalType(Map<String, Object?> payload) {
    return payload['vital_type']?.toString().trim().toUpperCase() ?? '';
  }
}
