import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef EmergencyJsonMap = Map<String, Object?>;

final class EmergencyCasePageDto {
  const EmergencyCasePageDto({required this.page});

  final AppPage<EmergencyCaseSummary> page;

  factory EmergencyCasePageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final EmergencyJsonMap response = _expectMap(responseData);
    final List<EmergencyCaseSummary> items = _list(response['data'])
        .map(EmergencyCaseDto.new)
        .map((EmergencyCaseDto dto) => dto.toEntity())
        .where((EmergencyCaseSummary item) => item.id.isNotEmpty)
        .toList(growable: false);
    final EmergencyJsonMap pagination = _map(response['pagination']);

    return EmergencyCasePageDto(
      page: AppPage<EmergencyCaseSummary>(
        items: items,
        request: request,
        totalItemCount: _int(pagination['total']),
      ),
    );
  }
}

final class EmergencyCaseDto {
  const EmergencyCaseDto(this.json);

  final EmergencyJsonMap json;

  factory EmergencyCaseDto.fromResponse(Object? responseData) {
    return EmergencyCaseDto(decodeDataMap(responseData));
  }

  EmergencyCaseSummary toEntity() {
    final EmergencyJsonMap tenant = _map(json['tenant']);
    final EmergencyJsonMap facility = _map(json['facility']);
    final EmergencyJsonMap patient = _map(json['patient']);
    final String id = _string(json['id']) ?? _string(json['display_id']) ?? '';
    final String? firstName = _string(patient['first_name']);
    final String? lastName = _string(patient['last_name']);
    final String? nestedPatientName = _joinDisplay(<String?>[
      firstName,
      lastName,
    ]);

    return EmergencyCaseSummary(
      id: id,
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      tenantLabel:
          _string(json['tenant_display_id']) ??
          _string(tenant['human_friendly_id']) ??
          _string(tenant['name']),
      facilityId: _string(json['facility_id']),
      facilityLabel:
          _string(json['facility_display_id']) ??
          _string(facility['human_friendly_id']) ??
          _string(facility['name']),
      patientId: _string(json['patient_id']) ?? _string(patient['id']),
      patientDisplayId:
          _string(json['patient_display_id']) ??
          _string(patient['human_friendly_id']),
      patientDisplayName:
          _string(json['patient_display_name']) ?? nestedPatientName,
      severity: _string(json['severity']),
      status: _string(json['status']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class EmergencyTriageAssessmentDto {
  const EmergencyTriageAssessmentDto(this.json);

  final EmergencyJsonMap json;

  EmergencyTriageAssessment toEntity() {
    return EmergencyTriageAssessment(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      emergencyCaseId: _string(json['emergency_case_id']),
      emergencyCaseDisplayId: _string(json['emergency_case_display_id']),
      patientDisplayId: _string(json['patient_display_id']),
      patientDisplayName: _string(json['patient_display_name']),
      triageLevel: _string(json['triage_level']),
      notes: _string(json['notes']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class EmergencyResponseRecordDto {
  const EmergencyResponseRecordDto(this.json);

  final EmergencyJsonMap json;

  EmergencyResponseRecord toEntity() {
    return EmergencyResponseRecord(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      emergencyCaseId: _string(json['emergency_case_id']),
      emergencyCaseDisplayId: _string(json['emergency_case_display_id']),
      patientDisplayId: _string(json['patient_display_id']),
      patientDisplayName: _string(json['patient_display_name']),
      responseAt: _date(json['response_at']),
      notes: _string(json['notes']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class EmergencyAmbulanceDto {
  const EmergencyAmbulanceDto(this.json);

  final EmergencyJsonMap json;

  EmergencyAmbulance toEntity() {
    final EmergencyJsonMap facility = _map(json['facility']);
    return EmergencyAmbulance(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      identifier:
          _string(json['ambulance_label']) ?? _string(json['identifier']),
      status: _string(json['status']),
      facilityId: _string(json['facility_id']),
      facilityLabel:
          _string(json['facility_display_id']) ??
          _string(facility['human_friendly_id']) ??
          _string(facility['name']),
    );
  }
}

final class EmergencyAmbulanceDispatchDto {
  const EmergencyAmbulanceDispatchDto(this.json);

  final EmergencyJsonMap json;

  EmergencyAmbulanceDispatch toEntity() {
    return EmergencyAmbulanceDispatch(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      emergencyCaseId: _string(json['emergency_case_id']),
      emergencyCaseDisplayId: _string(json['emergency_case_display_id']),
      ambulanceId: _string(json['ambulance_id']),
      ambulanceDisplayId: _string(json['ambulance_display_id']),
      ambulanceLabel:
          _string(json['ambulance_display_label']) ??
          _string(_map(json['ambulance'])['identifier']),
      patientDisplayId: _string(json['patient_display_id']),
      patientDisplayName: _string(json['patient_display_name']),
      status: _string(json['status']),
      dispatchedAt: _date(json['dispatched_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class EmergencyAmbulanceTripDto {
  const EmergencyAmbulanceTripDto(this.json);

  final EmergencyJsonMap json;

  EmergencyAmbulanceTrip toEntity() {
    return EmergencyAmbulanceTrip(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      emergencyCaseId: _string(json['emergency_case_id']),
      emergencyCaseDisplayId: _string(json['emergency_case_display_id']),
      ambulanceId: _string(json['ambulance_id']),
      ambulanceDisplayId: _string(json['ambulance_display_id']),
      ambulanceLabel:
          _string(json['ambulance_display_label']) ??
          _string(_map(json['ambulance'])['identifier']),
      patientDisplayId: _string(json['patient_display_id']),
      patientDisplayName: _string(json['patient_display_name']),
      startedAt: _date(json['started_at']),
      endedAt: _date(json['ended_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

List<EmergencyTriageAssessment> decodeTriageAssessments(Object? responseData) {
  return decodeDataList(responseData)
      .map(EmergencyTriageAssessmentDto.new)
      .map((EmergencyTriageAssessmentDto dto) => dto.toEntity())
      .where((EmergencyTriageAssessment item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<EmergencyResponseRecord> decodeEmergencyResponses(Object? responseData) {
  return decodeDataList(responseData)
      .map(EmergencyResponseRecordDto.new)
      .map((EmergencyResponseRecordDto dto) => dto.toEntity())
      .where((EmergencyResponseRecord item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<EmergencyAmbulance> decodeAmbulances(Object? responseData) {
  return decodeDataList(responseData)
      .map(EmergencyAmbulanceDto.new)
      .map((EmergencyAmbulanceDto dto) => dto.toEntity())
      .where((EmergencyAmbulance item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<EmergencyAmbulanceDispatch> decodeAmbulanceDispatches(
  Object? responseData,
) {
  return decodeDataList(responseData)
      .map(EmergencyAmbulanceDispatchDto.new)
      .map((EmergencyAmbulanceDispatchDto dto) => dto.toEntity())
      .where((EmergencyAmbulanceDispatch item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<EmergencyAmbulanceTrip> decodeAmbulanceTrips(Object? responseData) {
  return decodeDataList(responseData)
      .map(EmergencyAmbulanceTripDto.new)
      .map((EmergencyAmbulanceTripDto dto) => dto.toEntity())
      .where((EmergencyAmbulanceTrip item) => item.id.isNotEmpty)
      .toList(growable: false);
}

EmergencyJsonMap decodeDataMap(Object? responseData) {
  final EmergencyJsonMap response = _expectMap(responseData);
  return _map(response['data']);
}

List<EmergencyJsonMap> decodeDataList(Object? responseData) {
  final EmergencyJsonMap response = _expectMap(responseData);
  return _list(response['data']);
}

EmergencyJsonMap _expectMap(Object? value) {
  if (value is EmergencyJsonMap) {
    return value;
  }

  throw const FormatException('Expected response object.');
}

EmergencyJsonMap _map(Object? value) {
  return value is EmergencyJsonMap ? value : <String, Object?>{};
}

List<EmergencyJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <EmergencyJsonMap>[];
  }

  return value.whereType<EmergencyJsonMap>().toList(growable: false);
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' ');
  return joined.isEmpty ? null : joined;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }

  return DateTime.tryParse(normalized);
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
