import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/icu/data/dtos/icu_dtos.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final icuRepositoryProvider = Provider<IcuRepository>((ref) {
  return IcuRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class IcuRepositoryImpl implements IcuRepository {
  const IcuRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<IcuPatientSummary>>> listIcuBoard(
    IcuBoardQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<AppPage<IcuPatientSummary>>(
      ApiEndpoints.collection(HmsApiResource.ipdFlows),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'search': query.search,
        'queue_scope': 'ALL',
        'include_icu': 'true',
        'icu_queue_scope': _icuQueueScope(query.scope),
        'icu_status': query.scope == IcuBoardScope.ended ? 'ENDED' : null,
        'has_critical_alert': query.scope == IcuBoardScope.critical
            ? 'true'
            : null,
        'transfer_status': query.scope == IcuBoardScope.transfer
            ? 'REQUESTED'
            : null,
        'stage': query.scope == IcuBoardScope.discharge
            ? 'DISCHARGE_PLANNED'
            : null,
        'sort_by': 'admitted_at',
        'order': 'desc',
      }),
      decoder: (Object? data) => IcuBoardPageDto.fromResponse(data, request).page,
    );
  }

  @override
  Future<Result<IcuPatientDetail>> loadIcuDetail(IcuPatientSummary summary) {
    return _loadIcuDetailByAdmissionId(summary.apiAdmissionId);
  }

  @override
  Future<Result<IcuReferenceData>> loadReferenceData() async {
    final Result<List<IcuWardOption>> wardsResult =
        await _apiClient.get<List<IcuWardOption>>(
          ApiEndpoints.collection(HmsApiResource.wards),
          queryParameters: const <String, Object?>{
            'page': 1,
            'limit': 100,
            'sort_by': 'name',
            'order': 'asc',
          },
          decoder: decodeIcuWardOptions,
        );

    return Result<IcuReferenceData>.success(
      IcuReferenceData(
        wards: wardsResult.when(
          success: (List<IcuWardOption> wards) => wards,
          failure: (_) => const <IcuWardOption>[],
        ),
      ),
    );
  }

  @override
  Future<Result<IcuPatientDetail>> recordObservation({
    required IcuPatientDetail detail,
    required String observation,
    DateTime? observedAt,
  }) {
    return _postIpdAction(
      detail.summary,
      <String>['add-icu-observation'],
      <String, Object?>{
        'icu_stay_id': detail.activeStay?.id,
        'observed_at': observedAt?.toUtc().toIso8601String(),
        'observation': observation,
      },
    );
  }

  @override
  Future<Result<IcuPatientDetail>> recordVitals({
    required IcuPatientDetail detail,
    required IcuVitalsInput input,
  }) async {
    final String? encounterId = detail.summary.encounterId;
    if (encounterId == null || !input.hasAnyValue) {
      return Result<IcuPatientDetail>.failure(AppFailure.validation());
    }
    if (_hasPartialBloodPressure(input)) {
      return Result<IcuPatientDetail>.failure(AppFailure.validation());
    }

    final List<Map<String, Object?>> payloads = _vitalPayloads(
      encounterId: encounterId,
      input: input,
    );

    for (final Map<String, Object?> payload in payloads) {
      final String vitalType = payload['vital_type'].toString();
      final IcuVitalSign? existing = detail.vitalSigns
          .where((IcuVitalSign item) => item.vitalType == vitalType)
          .firstOrNull;
      final Result<void> result = existing == null
          ? await _apiClient.post<void>(
              ApiEndpoints.collection(HmsApiResource.vitalSigns),
              data: _withoutEmpty(payload),
              decoder: (_) {},
            )
          : await _apiClient.put<void>(
              ApiEndpoints.byId(HmsApiResource.vitalSigns, existing.id),
              data: _withoutEmpty(payload),
              decoder: (_) {},
            );

      final AppFailure? failure = result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      if (failure != null) {
        return Result<IcuPatientDetail>.failure(failure);
      }
    }

    return _loadIcuDetailByAdmissionId(detail.summary.apiAdmissionId);
  }

  @override
  Future<Result<IcuPatientDetail>> addCriticalAlert({
    required IcuPatientDetail detail,
    required String severity,
    required String message,
  }) {
    return _postIpdAction(
      detail.summary,
      <String>['add-critical-alert'],
      <String, Object?>{
        'icu_stay_id': detail.activeStay?.id,
        'severity': severity,
        'message': message,
      },
    );
  }

  @override
  Future<Result<IcuPatientDetail>> acknowledgeAlert({
    required IcuPatientDetail detail,
    required String alertId,
  }) {
    return _postIpdAction(
      detail.summary,
      <String>['resolve-critical-alert'],
      <String, Object?>{'critical_alert_id': alertId},
    );
  }

  @override
  Future<Result<IcuPatientDetail>> addRoundNote({
    required IcuPatientDetail detail,
    required String notes,
    DateTime? roundAt,
  }) {
    return _postIpdAction(
      detail.summary,
      <String>['add-ward-round'],
      <String, Object?>{
        'round_at': roundAt?.toUtc().toIso8601String(),
        'notes': notes,
      },
    );
  }

  @override
  Future<Result<IcuPatientDetail>> requestTransfer({
    required IcuPatientDetail detail,
    required String toWardId,
    String? fromWardId,
  }) {
    return _postIpdAction(
      detail.summary,
      <String>['request-transfer'],
      <String, Object?>{
        'from_ward_id': fromWardId,
        'to_ward_id': toWardId,
        'requested_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<Result<IcuPatientDetail>> markDischargeReady({
    required IcuPatientDetail detail,
    required String summary,
    DateTime? dischargedAt,
  }) {
    return _postIpdAction(
      detail.summary,
      <String>['plan-discharge'],
      <String, Object?>{
        'summary': summary,
        'discharged_at': dischargedAt?.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<Result<IcuPatientDetail>> transferOut({
    required IcuPatientDetail detail,
    DateTime? endedAt,
  }) {
    return _postIpdAction(
      detail.summary,
      <String>['end-icu-stay'],
      <String, Object?>{
        'icu_stay_id': detail.activeStay?.id,
        'ended_at': endedAt?.toUtc().toIso8601String(),
      },
    );
  }

  Future<Result<IcuPatientDetail>> _loadIcuDetailByAdmissionId(
    String admissionId,
  ) async {
    final Result<IcuPatientDetail> detailResult =
        await _apiClient.get<IcuPatientDetail>(
          ApiEndpoints.byId(
            HmsApiResource.ipdFlows,
            admissionId,
            queryParameters: const <String, String>{'include_icu': 'true'},
          ),
          decoder: (Object? data) =>
              IcuPatientDetailDto.fromResponse(data).toEntity(),
        );

    return detailResult.when(
      success: _withVitals,
      failure: (AppFailure failure) async =>
          Result<IcuPatientDetail>.failure(failure),
    );
  }

  Future<Result<IcuPatientDetail>> _postIpdAction(
    IcuPatientSummary summary,
    List<String> pathSegments,
    Map<String, Object?> payload,
  ) async {
    final Result<IcuPatientDetail> result =
        await _apiClient.post<IcuPatientDetail>(
          ApiEndpoints.nested(
            HmsApiResource.ipdFlows,
            summary.apiAdmissionId,
            pathSegments,
          ),
          data: _withoutEmpty(payload),
          decoder: (Object? data) =>
              IcuPatientDetailDto.fromResponse(data).toEntity(),
        );

    return result.when(
      success: _withVitals,
      failure: (AppFailure failure) async =>
          Result<IcuPatientDetail>.failure(failure),
    );
  }

  Future<Result<IcuPatientDetail>> _withVitals(IcuPatientDetail detail) async {
    final String? encounterId = detail.summary.encounterId;
    if (encounterId == null) {
      return Result<IcuPatientDetail>.success(detail);
    }

    final Result<List<IcuVitalSign>> vitalsResult =
        await _apiClient.get<List<IcuVitalSign>>(
          ApiEndpoints.collection(HmsApiResource.vitalSigns),
          queryParameters: <String, Object?>{
            'encounter_id': encounterId,
            'page': 1,
            'limit': 20,
            'sort_by': 'recorded_at',
            'order': 'desc',
          },
          decoder: decodeIcuVitalSigns,
        );

    return Result<IcuPatientDetail>.success(
      detail.copyWith(
        vitalSigns: vitalsResult.when(
          success: (List<IcuVitalSign> value) => value,
          failure: (_) => const <IcuVitalSign>[],
        ),
      ),
    );
  }

  String _icuQueueScope(IcuBoardScope scope) {
    return switch (scope) {
      IcuBoardScope.all || IcuBoardScope.ended => 'WITH_ICU',
      _ => 'ACTIVE',
    };
  }

  bool _hasPartialBloodPressure(IcuVitalsInput input) {
    final bool hasSystolic = (input.systolic ?? '').trim().isNotEmpty;
    final bool hasDiastolic = (input.diastolic ?? '').trim().isNotEmpty;
    return hasSystolic != hasDiastolic;
  }

  List<Map<String, Object?>> _vitalPayloads({
    required String encounterId,
    required IcuVitalsInput input,
  }) {
    final String? recordedAt = input.recordedAt?.toUtc().toIso8601String();
    final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
    void addVital(String type, String? value, String unit) {
      final String normalized = value?.trim() ?? '';
      if (normalized.isEmpty) {
        return;
      }
      payloads.add(<String, Object?>{
        'encounter_id': encounterId,
        'vital_type': type,
        'value': normalized,
        'unit': unit,
        'recorded_at': recordedAt,
      });
    }

    addVital('TEMPERATURE', input.temperature, 'C');
    addVital('HEART_RATE', input.heartRate, 'bpm');
    addVital('RESPIRATORY_RATE', input.respiratoryRate, '/min');
    addVital('OXYGEN_SATURATION', input.oxygenSaturation, '%');

    final String systolic = input.systolic?.trim() ?? '';
    final String diastolic = input.diastolic?.trim() ?? '';
    if (systolic.isNotEmpty && diastolic.isNotEmpty) {
      payloads.add(<String, Object?>{
        'encounter_id': encounterId,
        'vital_type': 'BLOOD_PRESSURE',
        'systolic_value': systolic,
        'diastolic_value': diastolic,
        'unit': 'mmHg',
        'recorded_at': recordedAt,
      });
    }

    return payloads;
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
}
