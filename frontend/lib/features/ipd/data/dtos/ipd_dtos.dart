import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef IpdJsonMap = Map<String, Object?>;

final class IpdAdmissionPageDto {
  const IpdAdmissionPageDto({required this.page});

  final AppPage<IpdAdmissionSummary> page;

  factory IpdAdmissionPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final IpdJsonMap response = _expectMap(responseData);
    final List<IpdAdmissionSummary> items = _list(response['data'])
        .map(IpdAdmissionSummaryDto.new)
        .map((IpdAdmissionSummaryDto dto) => dto.toEntity())
        .where((IpdAdmissionSummary item) => item.id.isNotEmpty)
        .toList(growable: false);

    return IpdAdmissionPageDto(
      page: AppPage<IpdAdmissionSummary>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class IpdAdmissionSummaryDto {
  const IpdAdmissionSummaryDto(this.json);

  final IpdJsonMap json;

  IpdAdmissionSummary toEntity() {
    final IpdJsonMap flowSummary = _map(json['flow_summary']);
    return IpdAdmissionSummary(
      id:
          _string(json['admission_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      patientId:
          _string(json['patient_display_id']) ?? _string(json['patient_id']),
      patientDisplayName: _string(json['patient_display_name']),
      encounterId: _string(json['encounter_display_id']),
      stage: _string(json['stage']) ?? _string(flowSummary['stage']),
      nextStep: _string(json['next_step']) ?? _string(flowSummary['next_step']),
      transferStatus:
          _string(json['transfer_status']) ??
          _string(flowSummary['transfer_status']),
      hasActiveBed: _bool(
        json['has_active_bed'] ?? flowSummary['has_active_bed'],
      ),
      wardDisplayName: _string(json['ward_display_name']),
      bedId: _string(json['bed_id']),
      bedDisplayLabel: _string(json['bed_display_label']),
      openTransferRequestId: _string(json['open_transfer_request_id']),
      admittedAt: _date(json['admitted_at']),
      dischargedAt: _date(json['discharged_at']),
      dischargeStatus: _string(json['discharge_status']),
      admissionStatus:
          _string(json['admission_status']) ??
          _string(flowSummary['admission_status']),
      icuStatus: _string(json['icu_status']),
      hasCriticalAlert: _bool(json['has_critical_alert']),
      criticalSeverity: _string(json['critical_severity']),
      activeIcuStayId: _string(json['active_icu_stay_id']),
    );
  }
}

final class IpdAdmissionDetailDto {
  const IpdAdmissionDetailDto(this.json);

  final IpdJsonMap json;

  factory IpdAdmissionDetailDto.fromResponse(Object? responseData) {
    final IpdJsonMap response = _expectMap(responseData);
    return IpdAdmissionDetailDto(_map(response['data']));
  }

  IpdAdmissionDetail toEntity() {
    final IpdJsonMap admission = _map(json['admission']);
    final IpdJsonMap patient = _map(json['patient']);
    final IpdJsonMap facility = _map(json['facility']);
    final IpdJsonMap flow = _map(json['flow']);
    final IpdIcuOverlay icu = IpdIcuOverlayDto(_map(json['icu'])).toEntity();
    final IpdAdmissionSummary summary = IpdAdmissionSummary(
      id:
          _string(json['id']) ??
          _string(json['human_friendly_id']) ??
          _string(admission['id']) ??
          '',
      displayId: _string(json['display_id']) ?? _string(admission['id']),
      patientId:
          _string(json['patient_display_id']) ?? _string(patient['id']),
      patientDisplayName: _string(json['patient_display_name']),
      encounterId: _string(json['encounter_display_id']),
      stage: _string(json['stage']) ?? _string(flow['stage']),
      nextStep: _string(json['next_step']) ?? _string(flow['next_step']),
      transferStatus:
          _string(json['transfer_status']) ?? _string(flow['transfer_status']),
      hasActiveBed: _bool(flow['has_active_bed']),
      wardDisplayName: _string(json['ward_display_name']),
      bedId: _string(
        _map(_map(json['active_bed_assignment'])['bed'])['id'],
      ),
      bedDisplayLabel: _string(
        _map(_map(json['active_bed_assignment'])['bed'])['label'],
      ),
      openTransferRequestId: _string(
        _map(json['open_transfer_request'])['id'],
      ),
      admittedAt: _date(admission['admitted_at']),
      dischargedAt: _date(admission['discharged_at']),
      dischargeStatus: _string(_map(json['latest_discharge_summary'])['status']),
      admissionStatus:
          _string(admission['status']) ?? _string(flow['admission_status']),
      icuStatus: _string(json['icu_status']) ?? icu.status,
      hasCriticalAlert: _bool(json['has_critical_alert']) || icu.hasCriticalAlert,
      criticalSeverity: _string(json['critical_severity']) ?? icu.criticalSeverity,
      activeIcuStayId: _string(json['active_icu_stay_id']) ?? icu.activeStayId,
    );

    return IpdAdmissionDetail(
      summary: summary,
      patientFirstName: _string(patient['first_name']),
      patientLastName: _string(patient['last_name']),
      patientGender: _string(patient['gender']),
      patientDateOfBirth: _date(patient['date_of_birth']),
      facilityName: _string(facility['name']),
      activeBedAssignment: IpdBedAssignmentDto.nullable(
        _nullableMap(json['active_bed_assignment']),
      )?.toEntity(),
      openTransferRequest: IpdTransferRequestDto.nullable(
        _nullableMap(json['open_transfer_request']),
      )?.toEntity(),
      latestDischargeSummary: IpdDischargeSummaryDto.nullable(
        _nullableMap(json['latest_discharge_summary']),
      )?.toEntity(),
      transferRequests: _list(json['transfer_requests'])
          .map(IpdTransferRequestDto.new)
          .map((IpdTransferRequestDto dto) => dto.toEntity())
          .where((IpdTransferRequest item) => item.id.isNotEmpty)
          .toList(growable: false),
      dischargeSummaries: _list(json['discharge_summaries'])
          .map(IpdDischargeSummaryDto.new)
          .map((IpdDischargeSummaryDto dto) => dto.toEntity())
          .where((IpdDischargeSummary item) => item.id.isNotEmpty)
          .toList(growable: false),
      wardRounds: _list(json['ward_rounds'])
          .map((IpdJsonMap entry) => IpdClinicalRecordDto(entry, 'ward_round'))
          .map((IpdClinicalRecordDto dto) => dto.toEntity())
          .toList(growable: false),
      nursingNotes: _list(json['nursing_notes'])
          .map((IpdJsonMap entry) => IpdClinicalRecordDto(entry, 'nursing_note'))
          .map((IpdClinicalRecordDto dto) => dto.toEntity())
          .toList(growable: false),
      medicationAdministrations: _list(json['medication_administrations'])
          .map(
            (IpdJsonMap entry) =>
                IpdClinicalRecordDto(entry, 'medication_administration'),
          )
          .map((IpdClinicalRecordDto dto) => dto.toEntity())
          .toList(growable: false),
      medicationSuggestions: _list(json['medication_suggestions'])
          .map(IpdMedicationSuggestionDto.new)
          .map((IpdMedicationSuggestionDto dto) => dto.toEntity())
          .where((IpdMedicationSuggestion item) => item.id.isNotEmpty)
          .toList(growable: false),
      medicationReminders: _list(json['medication_reminders'])
          .map(
            (IpdJsonMap entry) =>
                IpdClinicalRecordDto(entry, 'medication_reminder'),
          )
          .map((IpdClinicalRecordDto dto) => dto.toEntity())
          .toList(growable: false),
      timeline: _list(json['timeline'])
          .map(IpdTimelineItemDto.new)
          .map((IpdTimelineItemDto dto) => dto.toEntity())
          .toList(growable: false),
      icu: icu,
    );
  }
}

final class IpdWardOptionDto {
  const IpdWardOptionDto(this.json);

  final IpdJsonMap json;

  IpdWardOption toEntity() {
    return IpdWardOption(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      name: _string(json['name']),
      wardType: _string(json['ward_type']),
      isActive: _bool(json['is_active'], fallback: true),
    );
  }
}

final class IpdBedOptionDto {
  const IpdBedOptionDto(this.json);

  final IpdJsonMap json;

  IpdBedOption toEntity() {
    final IpdJsonMap ward = _map(json['ward']);
    final IpdJsonMap room = _map(json['room']);
    return IpdBedOption(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      label: _string(json['label']),
      status: _string(json['status']),
      wardId:
          _string(json['ward_human_friendly_id']) ??
          _string(json['ward_id']) ??
          _string(ward['human_friendly_id']) ??
          _string(ward['id']),
      wardName: _string(json['ward_name']) ?? _string(ward['name']),
      roomId:
          _string(json['room_human_friendly_id']) ??
          _string(json['room_id']) ??
          _string(room['human_friendly_id']) ??
          _string(room['id']),
      roomName: _string(json['room_name']) ?? _string(room['name']),
      roomFloor: _string(json['floor']) ?? _string(room['floor']),
    );
  }
}

final class IpdBedAssignmentDto {
  const IpdBedAssignmentDto(this.json);

  final IpdJsonMap json;

  static IpdBedAssignmentDto? nullable(IpdJsonMap? json) {
    if (json == null || json.isEmpty) {
      return null;
    }
    return IpdBedAssignmentDto(json);
  }

  IpdBedAssignment toEntity() {
    return IpdBedAssignment(
      id: _string(json['id']) ?? '',
      assignedAt: _date(json['assigned_at']),
      releasedAt: _date(json['released_at']),
      bed: IpdBedOptionDto(_map(json['bed'])).toEntity(),
    );
  }
}

final class IpdTransferRequestDto {
  const IpdTransferRequestDto(this.json);

  final IpdJsonMap json;

  static IpdTransferRequestDto? nullable(IpdJsonMap? json) {
    if (json == null || json.isEmpty) {
      return null;
    }
    return IpdTransferRequestDto(json);
  }

  IpdTransferRequest toEntity() {
    return IpdTransferRequest(
      id: _string(json['id']) ?? '',
      status: _string(json['status']),
      requestedAt: _date(json['requested_at']),
      fromWard: IpdWardOptionDto(_map(json['from_ward'])).toEntity(),
      toWard: IpdWardOptionDto(_map(json['to_ward'])).toEntity(),
    );
  }
}

final class IpdDischargeSummaryDto {
  const IpdDischargeSummaryDto(this.json);

  final IpdJsonMap json;

  static IpdDischargeSummaryDto? nullable(IpdJsonMap? json) {
    if (json == null || json.isEmpty) {
      return null;
    }
    return IpdDischargeSummaryDto(json);
  }

  IpdDischargeSummary toEntity() {
    return IpdDischargeSummary(
      id: _string(json['id']) ?? '',
      status: _string(json['status']),
      summary: _string(json['summary']),
      dischargedAt: _date(json['discharged_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class IpdClinicalRecordDto {
  const IpdClinicalRecordDto(this.json, this.kind);

  final IpdJsonMap json;
  final String kind;

  IpdClinicalRecord toEntity() {
    final String? dose = _string(json['dose']);
    final String? unit = _string(json['unit']);
    final String? route = _string(json['route']);
    return IpdClinicalRecord(
      id: _string(json['id']) ?? '',
      kind: kind,
      status: _string(json['status']) ?? _string(json['severity']),
      title:
          _string(json['notes']) ??
          _string(json['note']) ??
          _string(json['observation']) ??
          _string(json['message']) ??
          _string(json['medication_label']) ??
          _joinDisplay(<String?>[dose, unit, route]) ??
          _string(json['summary']) ??
          _string(json['id']),
      subtitle: _joinDisplay(<String?>[
        _string(json['nurse_name']),
        _string(json['frequency']),
        _string(json['occurrence']) == null
            ? null
            : '${_string(json['occurrence'])}/${_string(json['total_occurrences']) ?? ''}',
      ]),
      occurredAt:
          _date(json['round_at']) ??
          _date(json['administered_at']) ??
          _date(json['scheduled_at']) ??
          _date(json['observed_at']) ??
          _date(json['created_at']) ??
          _date(json['updated_at']),
    );
  }
}

final class IpdMedicationSuggestionDto {
  const IpdMedicationSuggestionDto(this.json);

  final IpdJsonMap json;

  IpdMedicationSuggestion toEntity() {
    return IpdMedicationSuggestion(
      id: _string(json['id']) ?? '',
      medicationLabel: _string(json['medication_label']),
      dose: _string(json['dose']),
      unit: _string(json['unit']),
      route: _string(json['route']),
      frequency: _string(json['frequency']),
      orderStatus: _string(json['order_status']),
      itemStatus: _string(json['item_status']),
    );
  }
}

final class IpdTimelineItemDto {
  const IpdTimelineItemDto(this.json);

  final IpdJsonMap json;

  IpdTimelineItem toEntity() {
    return IpdTimelineItem(
      type: _string(json['type']) ?? '',
      label: _string(json['label']),
      occurredAt: _date(json['at']) ?? _date(json['occurred_at']),
    );
  }
}

final class IpdIcuOverlayDto {
  const IpdIcuOverlayDto(this.json);

  final IpdJsonMap json;

  IpdIcuOverlay toEntity() {
    final IpdJsonMap activeStay = _map(json['active_stay']);
    final IpdJsonMap latestStay = _map(json['latest_stay']);
    return IpdIcuOverlay(
      status: _string(json['status']),
      hasCriticalAlert: _bool(json['has_critical_alert']),
      criticalSeverity: _string(json['critical_severity']),
      activeStayId: _string(activeStay['id']),
      latestStayId: _string(latestStay['id']),
      recentObservations: _list(json['recent_observations'])
          .map(
            (IpdJsonMap entry) =>
                IpdClinicalRecordDto(entry, 'icu_observation'),
          )
          .map((IpdClinicalRecordDto dto) => dto.toEntity())
          .toList(growable: false),
      recentAlerts: _list(json['recent_alerts'])
          .map((IpdJsonMap entry) => IpdClinicalRecordDto(entry, 'critical_alert'))
          .map((IpdClinicalRecordDto dto) => dto.toEntity())
          .toList(growable: false),
    );
  }
}

List<IpdWardOption> decodeIpdWards(Object? responseData) {
  final IpdJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(IpdWardOptionDto.new)
      .map((IpdWardOptionDto dto) => dto.toEntity())
      .where((IpdWardOption item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<IpdBedOption> decodeIpdBeds(Object? responseData) {
  final IpdJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(IpdBedOptionDto.new)
      .map((IpdBedOptionDto dto) => dto.toEntity())
      .where((IpdBedOption item) => item.id.isNotEmpty)
      .toList(growable: false);
}

IpdJsonMap _expectMap(Object? value) {
  if (value is IpdJsonMap) {
    return value;
  }

  throw const FormatException('Expected response object.');
}

IpdJsonMap _map(Object? value) {
  return value is IpdJsonMap ? value : <String, Object?>{};
}

IpdJsonMap? _nullableMap(Object? value) {
  return value is IpdJsonMap ? value : null;
}

List<IpdJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <IpdJsonMap>[];
  }

  return value.whereType<IpdJsonMap>().toList(growable: false);
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }

  return DateTime.tryParse(normalized);
}

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
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

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}
