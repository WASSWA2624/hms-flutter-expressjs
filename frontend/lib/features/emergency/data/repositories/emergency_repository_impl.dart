import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/emergency/data/dtos/emergency_dtos.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/domain/repositories/emergency_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  return EmergencyRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class EmergencyRepositoryImpl implements EmergencyRepository {
  const EmergencyRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<AppPage<EmergencyCaseSummary>>> listEmergencyBoard(
    EmergencyBoardQuery query,
  ) async {
    final AppPageRequest request = query.pageRequest;
    final Result<AppPage<EmergencyCaseSummary>> caseResult = await _apiClient
        .get<AppPage<EmergencyCaseSummary>>(
          ApiEndpoints.collection(HmsApiResource.emergencyCases),
          queryParameters: _withoutEmpty(<String, Object?>{
            'page': request.pageIndex + 1,
            'limit': request.pageSize,
            'search': query.search,
            'status': _caseStatusForScope(query.scope),
            'severity': query.scope == EmergencyBoardScope.critical
                ? 'CRITICAL'
                : null,
            'sort_by': 'created_at',
            'order': 'desc',
          }),
          decoder: (Object? data) =>
              EmergencyCasePageDto.fromResponse(data, request).page,
        );

    final AppPage<EmergencyCaseSummary>? cases = _successOrNull(caseResult);
    if (cases == null) {
      return Result<AppPage<EmergencyCaseSummary>>.failure(
        _failureOrNull(caseResult)!,
      );
    }

    final triagesFuture = _listTriageAssessments();
    final responsesFuture = _listEmergencyResponses();
    final dispatchesFuture = _listAmbulanceDispatches();
    final tripsFuture = _listAmbulanceTrips();

    final List<EmergencyTriageAssessment> triages = _successOrEmpty(
      await triagesFuture,
    );
    final List<EmergencyResponseRecord> responses = _successOrEmpty(
      await responsesFuture,
    );
    final List<EmergencyAmbulanceDispatch> dispatches = _successOrEmpty(
      await dispatchesFuture,
    );
    final List<EmergencyAmbulanceTrip> trips = _successOrEmpty(
      await tripsFuture,
    );

    final List<EmergencyCaseSummary> merged = cases.items
        .map(
          (EmergencyCaseSummary item) => _mergeBoardItem(
            item,
            triages: triages,
            responses: responses,
            dispatches: dispatches,
            trips: trips,
          ),
        )
        .where((EmergencyCaseSummary item) => _belongsToScope(item, query.scope))
        .toList(growable: false);

    return Result<AppPage<EmergencyCaseSummary>>.success(
      AppPage<EmergencyCaseSummary>(
        items: merged,
        request: cases.request,
        totalItemCount: _usesClientScopeFilter(query.scope)
            ? merged.length
            : cases.totalItemCount,
      ),
    );
  }

  @override
  Future<Result<EmergencyReferenceData>> loadReferenceData() async {
    final Result<List<EmergencyAmbulance>> result = await _apiClient
        .get<List<EmergencyAmbulance>>(
          ApiEndpoints.collection(HmsApiResource.ambulances),
          queryParameters: const <String, Object?>{
            'page': 1,
            'limit': 100,
            'sort_by': 'identifier',
            'order': 'asc',
          },
          decoder: decodeAmbulances,
        );

    return Result<EmergencyReferenceData>.success(
      EmergencyReferenceData(ambulances: _successOrEmpty(result)),
    );
  }

  @override
  Future<Result<EmergencyCaseDetail>> loadEmergencyDetail(
    EmergencyCaseSummary summary,
  ) async {
    final Result<EmergencyCaseSummary> caseResult = await _apiClient
        .get<EmergencyCaseSummary>(
          ApiEndpoints.byId(HmsApiResource.emergencyCases, summary.apiId),
          decoder: (Object? data) =>
              EmergencyCaseDto.fromResponse(data).toEntity(),
        );
    final EmergencyCaseSummary? loadedCase = _successOrNull(caseResult);
    if (loadedCase == null) {
      return Result<EmergencyCaseDetail>.failure(_failureOrNull(caseResult)!);
    }

    return _loadDetailForCase(loadedCase);
  }

  @override
  Future<Result<EmergencyCaseDetail>> createQuickArrival(
    EmergencyQuickArrivalInput input,
  ) async {
    final DateTime registeredAt = DateTime.now().toUtc();
    final String firstName = input.firstName.trim().isEmpty
        ? 'Emergency'
        : input.firstName.trim();
    final String lastName = input.lastName.trim().isEmpty
        ? 'Patient ${registeredAt.millisecondsSinceEpoch}'
        : input.lastName.trim();

    final Result<_EmergencyCreatedPatient> patientResult = await _apiClient
        .post<_EmergencyCreatedPatient>(
          ApiEndpoints.collection(HmsApiResource.patients),
          data: _withoutEmpty(<String, Object?>{
            'tenant_id': input.tenantId,
            'facility_id': input.facilityId,
            'first_name': firstName,
            'last_name': lastName,
            'gender': 'UNKNOWN',
            'primary_phone': input.phone,
            'is_active': true,
            'extension_json': <String, Object?>{
              'registration': <String, Object?>{
                'source': 'EMERGENCY',
                'status': 'INCOMPLETE',
                'requires_completion': true,
                'registered_at': registeredAt.toIso8601String(),
                'notes': input.notes,
              },
            },
          }),
          decoder: (Object? data) =>
              _EmergencyCreatedPatient.fromJson(decodeDataMap(data)),
        );

    final _EmergencyCreatedPatient? patient = _successOrNull(patientResult);
    if (patient == null) {
      return Result<EmergencyCaseDetail>.failure(
        _failureOrNull(patientResult)!,
      );
    }

    final String? tenantId = patient.tenantId ?? input.tenantId;
    if ((tenantId ?? '').trim().isEmpty) {
      return Result<EmergencyCaseDetail>.failure(
        AppFailure.validation(validationFields: const <String>{'tenant_id'}),
      );
    }

    final Result<EmergencyCaseSummary> emergencyCaseResult = await _apiClient
        .post<EmergencyCaseSummary>(
          ApiEndpoints.collection(HmsApiResource.emergencyCases),
          data: _withoutEmpty(<String, Object?>{
            'tenant_id': tenantId,
            'facility_id': patient.facilityId ?? input.facilityId,
            'patient_id': patient.id,
            'severity': input.severity,
            'status': 'OPEN',
          }),
          decoder: (Object? data) =>
              EmergencyCaseDto.fromResponse(data).toEntity(),
        );

    final EmergencyCaseSummary? emergencyCase = _successOrNull(
      emergencyCaseResult,
    );
    if (emergencyCase == null) {
      return Result<EmergencyCaseDetail>.failure(
        _failureOrNull(emergencyCaseResult)!,
      );
    }

    final String? triageLevel = _nonEmpty(input.triageLevel);
    if (triageLevel != null) {
      final Result<EmergencyTriageAssessment> triageResult = await _apiClient
          .post<EmergencyTriageAssessment>(
            ApiEndpoints.collection(HmsApiResource.triageAssessments),
            data: _withoutEmpty(<String, Object?>{
              'emergency_case_id': emergencyCase.apiId,
              'triage_level': triageLevel,
              'notes': input.notes,
            }),
            decoder: (Object? data) =>
                EmergencyTriageAssessmentDto(decodeDataMap(data)).toEntity(),
          );
      final AppFailure? triageFailure = _failureOrNull(triageResult);
      if (triageFailure != null) {
        return Result<EmergencyCaseDetail>.failure(triageFailure);
      }
    }

    final String? notes = _nonEmpty(input.notes);
    if (notes != null) {
      final Result<EmergencyResponseRecord> responseResult = await _apiClient
          .post<EmergencyResponseRecord>(
            ApiEndpoints.collection(HmsApiResource.emergencyResponses),
            data: <String, Object?>{
              'emergency_case_id': emergencyCase.apiId,
              'response_at': registeredAt.toIso8601String(),
              'notes': notes,
            },
            decoder: (Object? data) =>
                EmergencyResponseRecordDto(decodeDataMap(data)).toEntity(),
          );
      final AppFailure? responseFailure = _failureOrNull(responseResult);
      if (responseFailure != null) {
        return Result<EmergencyCaseDetail>.failure(responseFailure);
      }
    }

    return _loadDetailForCase(emergencyCase);
  }

  @override
  Future<Result<EmergencyCaseDetail>> updateCasePriority({
    required EmergencyCaseDetail detail,
    required String severity,
  }) async {
    final Result<EmergencyCaseSummary> result = await _apiClient
        .put<EmergencyCaseSummary>(
          ApiEndpoints.byId(
            HmsApiResource.emergencyCases,
            detail.summary.apiId,
          ),
          data: <String, Object?>{'severity': severity},
          decoder: (Object? data) =>
              EmergencyCaseDto.fromResponse(data).toEntity(),
        );
    final EmergencyCaseSummary? summary = _successOrNull(result);
    if (summary == null) {
      return Result<EmergencyCaseDetail>.failure(_failureOrNull(result)!);
    }
    return _loadDetailForCase(summary);
  }

  @override
  Future<Result<EmergencyCaseDetail>> recordTriage({
    required EmergencyCaseDetail detail,
    required String triageLevel,
    String? notes,
  }) async {
    final EmergencyTriageAssessment? existing = detail.latestTriage;
    final Result<EmergencyTriageAssessment> result = existing == null
        ? await _apiClient.post<EmergencyTriageAssessment>(
            ApiEndpoints.collection(HmsApiResource.triageAssessments),
            data: _withoutEmpty(<String, Object?>{
              'emergency_case_id': detail.summary.apiId,
              'triage_level': triageLevel,
              'notes': notes,
            }),
            decoder: (Object? data) =>
                EmergencyTriageAssessmentDto(decodeDataMap(data)).toEntity(),
          )
        : await _apiClient.put<EmergencyTriageAssessment>(
            ApiEndpoints.byId(HmsApiResource.triageAssessments, existing.id),
            data: _withoutEmpty(<String, Object?>{
              'triage_level': triageLevel,
              'notes': notes,
            }),
            decoder: (Object? data) =>
                EmergencyTriageAssessmentDto(decodeDataMap(data)).toEntity(),
          );

    final AppFailure? failure = _failureOrNull(result);
    if (failure != null) {
      return Result<EmergencyCaseDetail>.failure(failure);
    }
    return _loadDetailForCase(detail.summary);
  }

  @override
  Future<Result<EmergencyCaseDetail>> markResponse({
    required EmergencyCaseDetail detail,
    required String notes,
    DateTime? responseAt,
  }) async {
    final Result<EmergencyResponseRecord> result = await _apiClient
        .post<EmergencyResponseRecord>(
          ApiEndpoints.collection(HmsApiResource.emergencyResponses),
          data: _withoutEmpty(<String, Object?>{
            'emergency_case_id': detail.summary.apiId,
            'response_at': (responseAt ?? DateTime.now())
                .toUtc()
                .toIso8601String(),
            'notes': notes,
          }),
          decoder: (Object? data) =>
              EmergencyResponseRecordDto(decodeDataMap(data)).toEntity(),
        );
    final AppFailure? failure = _failureOrNull(result);
    if (failure != null) {
      return Result<EmergencyCaseDetail>.failure(failure);
    }
    return _loadDetailForCase(detail.summary);
  }

  @override
  Future<Result<EmergencyCaseDetail>> dispatchAmbulance({
    required EmergencyCaseDetail detail,
    required String ambulanceId,
    String status = 'DISPATCHED',
    DateTime? dispatchedAt,
  }) async {
    final Result<EmergencyAmbulanceDispatch> result = await _apiClient
        .post<EmergencyAmbulanceDispatch>(
          ApiEndpoints.collection(HmsApiResource.ambulanceDispatches),
          data: _withoutEmpty(<String, Object?>{
            'ambulance_id': ambulanceId,
            'emergency_case_id': detail.summary.apiId,
            'dispatched_at': (dispatchedAt ?? DateTime.now())
                .toUtc()
                .toIso8601String(),
            'status': status,
          }),
          decoder: (Object? data) =>
              EmergencyAmbulanceDispatchDto(decodeDataMap(data)).toEntity(),
        );
    final AppFailure? failure = _failureOrNull(result);
    if (failure != null) {
      return Result<EmergencyCaseDetail>.failure(failure);
    }
    return _loadDetailForCase(detail.summary);
  }

  @override
  Future<Result<EmergencyCaseDetail>> updateDispatchStatus({
    required EmergencyCaseDetail detail,
    required String dispatchId,
    required String status,
  }) async {
    final Result<EmergencyAmbulanceDispatch> result = await _apiClient
        .put<EmergencyAmbulanceDispatch>(
          ApiEndpoints.byId(HmsApiResource.ambulanceDispatches, dispatchId),
          data: <String, Object?>{'status': status},
          decoder: (Object? data) =>
              EmergencyAmbulanceDispatchDto(decodeDataMap(data)).toEntity(),
        );
    final AppFailure? failure = _failureOrNull(result);
    if (failure != null) {
      return Result<EmergencyCaseDetail>.failure(failure);
    }
    return _loadDetailForCase(detail.summary);
  }

  @override
  Future<Result<EmergencyCaseDetail>> startAmbulanceTrip({
    required EmergencyCaseDetail detail,
    required String ambulanceId,
    DateTime? startedAt,
  }) async {
    final Result<EmergencyAmbulanceTrip> result = await _apiClient
        .post<EmergencyAmbulanceTrip>(
          ApiEndpoints.collection(HmsApiResource.ambulanceTrips),
          data: _withoutEmpty(<String, Object?>{
            'ambulance_id': ambulanceId,
            'emergency_case_id': detail.summary.apiId,
            'started_at': (startedAt ?? DateTime.now())
                .toUtc()
                .toIso8601String(),
          }),
          decoder: (Object? data) =>
              EmergencyAmbulanceTripDto(decodeDataMap(data)).toEntity(),
        );
    final AppFailure? failure = _failureOrNull(result);
    if (failure != null) {
      return Result<EmergencyCaseDetail>.failure(failure);
    }
    return _loadDetailForCase(detail.summary);
  }

  @override
  Future<Result<EmergencyCaseDetail>> completeAmbulanceTrip({
    required EmergencyCaseDetail detail,
    required String tripId,
    DateTime? endedAt,
  }) async {
    final Result<EmergencyAmbulanceTrip> result = await _apiClient
        .put<EmergencyAmbulanceTrip>(
          ApiEndpoints.byId(HmsApiResource.ambulanceTrips, tripId),
          data: <String, Object?>{
            'ended_at': (endedAt ?? DateTime.now()).toUtc().toIso8601String(),
          },
          decoder: (Object? data) =>
              EmergencyAmbulanceTripDto(decodeDataMap(data)).toEntity(),
        );
    final AppFailure? failure = _failureOrNull(result);
    if (failure != null) {
      return Result<EmergencyCaseDetail>.failure(failure);
    }
    return _loadDetailForCase(detail.summary);
  }

  @override
  Future<Result<EmergencyCaseDetail>> recordHandoff({
    required EmergencyCaseDetail detail,
    required String destination,
    String? notes,
    bool closeCase = true,
  }) async {
    final String handoffNote = _joinDisplay(<String?>[
          'Handoff to $destination.',
          notes,
        ]) ??
        'Handoff to $destination.';
    final Result<EmergencyResponseRecord> responseResult = await _apiClient
        .post<EmergencyResponseRecord>(
          ApiEndpoints.collection(HmsApiResource.emergencyResponses),
          data: <String, Object?>{
            'emergency_case_id': detail.summary.apiId,
            'response_at': DateTime.now().toUtc().toIso8601String(),
            'notes': handoffNote,
          },
          decoder: (Object? data) =>
              EmergencyResponseRecordDto(decodeDataMap(data)).toEntity(),
        );
    final AppFailure? responseFailure = _failureOrNull(responseResult);
    if (responseFailure != null) {
      return Result<EmergencyCaseDetail>.failure(responseFailure);
    }

    if (!closeCase) {
      return _loadDetailForCase(detail.summary);
    }

    final Result<EmergencyCaseSummary> caseResult = await _apiClient
        .put<EmergencyCaseSummary>(
          ApiEndpoints.byId(
            HmsApiResource.emergencyCases,
            detail.summary.apiId,
          ),
          data: const <String, Object?>{'status': 'CLOSED'},
          decoder: (Object? data) =>
              EmergencyCaseDto.fromResponse(data).toEntity(),
        );
    final EmergencyCaseSummary? updated = _successOrNull(caseResult);
    if (updated == null) {
      return Result<EmergencyCaseDetail>.failure(_failureOrNull(caseResult)!);
    }
    return _loadDetailForCase(updated);
  }

  Future<Result<EmergencyCaseDetail>> _loadDetailForCase(
    EmergencyCaseSummary summary,
  ) async {
    final triagesFuture = _listTriageAssessments(
      emergencyCaseId: summary.apiId,
    );
    final responsesFuture = _listEmergencyResponses(
      emergencyCaseId: summary.apiId,
    );
    final dispatchesFuture = _listAmbulanceDispatches(
      emergencyCaseId: summary.apiId,
    );
    final tripsFuture = _listAmbulanceTrips(emergencyCaseId: summary.apiId);

    final List<EmergencyTriageAssessment> triages = _successOrEmpty(
      await triagesFuture,
    );
    final List<EmergencyResponseRecord> responses = _successOrEmpty(
      await responsesFuture,
    );
    final List<EmergencyAmbulanceDispatch> dispatches = _successOrEmpty(
      await dispatchesFuture,
    );
    final List<EmergencyAmbulanceTrip> trips = _successOrEmpty(
      await tripsFuture,
    );

    final EmergencyCaseSummary merged = _mergeBoardItem(
      summary,
      triages: triages,
      responses: responses,
      dispatches: dispatches,
      trips: trips,
    );

    return Result<EmergencyCaseDetail>.success(
      EmergencyCaseDetail(
        summary: merged,
        triageAssessments: triages,
        responses: responses,
        dispatches: dispatches,
        trips: trips,
      ),
    );
  }

  Future<Result<List<EmergencyTriageAssessment>>> _listTriageAssessments({
    String? emergencyCaseId,
  }) {
    return _apiClient.get<List<EmergencyTriageAssessment>>(
      ApiEndpoints.collection(HmsApiResource.triageAssessments),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': emergencyCaseId == null ? 100 : 20,
        'emergency_case_id': emergencyCaseId,
        'sort_by': 'created_at',
        'order': 'desc',
      }),
      decoder: decodeTriageAssessments,
    );
  }

  Future<Result<List<EmergencyResponseRecord>>> _listEmergencyResponses({
    String? emergencyCaseId,
  }) {
    return _apiClient.get<List<EmergencyResponseRecord>>(
      ApiEndpoints.collection(HmsApiResource.emergencyResponses),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': emergencyCaseId == null ? 100 : 20,
        'emergency_case_id': emergencyCaseId,
        'sort_by': 'response_at',
        'order': 'desc',
      }),
      decoder: decodeEmergencyResponses,
    );
  }

  Future<Result<List<EmergencyAmbulanceDispatch>>> _listAmbulanceDispatches({
    String? emergencyCaseId,
  }) {
    return _apiClient.get<List<EmergencyAmbulanceDispatch>>(
      ApiEndpoints.collection(HmsApiResource.ambulanceDispatches),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': emergencyCaseId == null ? 100 : 20,
        'emergency_case_id': emergencyCaseId,
        'sort_by': 'dispatched_at',
        'order': 'desc',
      }),
      decoder: decodeAmbulanceDispatches,
    );
  }

  Future<Result<List<EmergencyAmbulanceTrip>>> _listAmbulanceTrips({
    String? emergencyCaseId,
  }) {
    return _apiClient.get<List<EmergencyAmbulanceTrip>>(
      ApiEndpoints.collection(HmsApiResource.ambulanceTrips),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': 1,
        'limit': emergencyCaseId == null ? 100 : 20,
        'emergency_case_id': emergencyCaseId,
        'sort_by': 'started_at',
        'order': 'desc',
      }),
      decoder: decodeAmbulanceTrips,
    );
  }

  EmergencyCaseSummary _mergeBoardItem(
    EmergencyCaseSummary item, {
    required List<EmergencyTriageAssessment> triages,
    required List<EmergencyResponseRecord> responses,
    required List<EmergencyAmbulanceDispatch> dispatches,
    required List<EmergencyAmbulanceTrip> trips,
  }) {
    return item.copyWith(
      latestTriage: triages
          .where(
            (EmergencyTriageAssessment triage) =>
                _matchesCase(item, triage.emergencyCaseId) ||
                _matchesCase(item, triage.emergencyCaseDisplayId),
          )
          .firstOrNull,
      latestResponse: responses
          .where(
            (EmergencyResponseRecord response) =>
                _matchesCase(item, response.emergencyCaseId) ||
                _matchesCase(item, response.emergencyCaseDisplayId),
          )
          .firstOrNull,
      latestDispatch: dispatches
          .where(
            (EmergencyAmbulanceDispatch dispatch) =>
                _matchesCase(item, dispatch.emergencyCaseId) ||
                _matchesCase(item, dispatch.emergencyCaseDisplayId),
          )
          .firstOrNull,
      activeTrip: trips
          .where(
            (EmergencyAmbulanceTrip trip) =>
                trip.isActive &&
                (_matchesCase(item, trip.emergencyCaseId) ||
                    _matchesCase(item, trip.emergencyCaseDisplayId)),
          )
          .firstOrNull,
    );
  }

  bool _matchesCase(EmergencyCaseSummary item, String? relatedCaseId) {
    final String normalized = relatedCaseId?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return normalized == item.id.toLowerCase() ||
        normalized == (item.displayId ?? '').toLowerCase();
  }

  String? _caseStatusForScope(EmergencyBoardScope scope) {
    return switch (scope) {
      EmergencyBoardScope.closed => 'CLOSED',
      EmergencyBoardScope.all => null,
      _ => 'OPEN',
    };
  }

  bool _belongsToScope(EmergencyCaseSummary item, EmergencyBoardScope scope) {
    return switch (scope) {
      EmergencyBoardScope.active => item.isOpen,
      EmergencyBoardScope.critical => item.isOpen && item.isCritical,
      EmergencyBoardScope.ambulance => item.hasAmbulanceActivity,
      EmergencyBoardScope.handoff => item.isReadyForHandoff,
      EmergencyBoardScope.closed => !item.isOpen,
      EmergencyBoardScope.all => true,
    };
  }

  bool _usesClientScopeFilter(EmergencyBoardScope scope) {
    return switch (scope) {
      EmergencyBoardScope.ambulance || EmergencyBoardScope.handoff => true,
      _ => false,
    };
  }

  T? _successOrNull<T>(Result<T> result) {
    return result.when(success: (T value) => value, failure: (_) => null);
  }

  List<T> _successOrEmpty<T>(Result<List<T>> result) {
    return result.when(
      success: (List<T> value) => value,
      failure: (_) => const <T>[],
    );
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
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

final class _EmergencyCreatedPatient {
  const _EmergencyCreatedPatient({
    required this.id,
    this.tenantId,
    this.facilityId,
  });

  final String id;
  final String? tenantId;
  final String? facilityId;

  factory _EmergencyCreatedPatient.fromJson(EmergencyJsonMap json) {
    return _EmergencyCreatedPatient(
      id: _string(json['id']) ?? _string(json['human_friendly_id']) ?? '',
      tenantId: _string(json['tenant_id']),
      facilityId: _string(json['facility_id']),
    );
  }
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

String? _nonEmpty(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' ');
  return joined.isEmpty ? null : joined;
}
