import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef NursingJsonMap = Map<String, Object?>;

final class NursingPatientSummaryPageDto {
  const NursingPatientSummaryPageDto({required this.page});

  final AppPage<NursingPatientSummary> page;

  factory NursingPatientSummaryPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final NursingJsonMap response = _expectMap(responseData);
    final List<NursingPatientSummary> items = _list(response['data'])
        .map(NursingPatientSummaryDto.new)
        .map((NursingPatientSummaryDto dto) => dto.toEntity())
        .where((NursingPatientSummary item) => item.admissionId.isNotEmpty)
        .toList(growable: false);

    return NursingPatientSummaryPageDto(
      page: AppPage<NursingPatientSummary>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class NursingPatientSummaryDto {
  const NursingPatientSummaryDto(this.json);

  final NursingJsonMap json;

  NursingPatientSummary toEntity() {
    final String id =
        _string(json['id']) ?? _string(json['admission_id']) ?? '';
    final NursingJsonMap flowSummary = _map(json['flow_summary']);

    return NursingPatientSummary(
      id: id,
      admissionId: _string(json['admission_id']) ?? id,
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      patientId: _string(json['patient_id']),
      patientDisplayId: _string(json['patient_display_id']),
      patientDisplayName: _string(json['patient_display_name']),
      encounterDisplayId: _string(json['encounter_display_id']),
      stage: _string(json['stage']) ?? _string(flowSummary['stage']),
      nextStep: _string(json['next_step']) ?? _string(flowSummary['next_step']),
      admissionStatus:
          _string(json['admission_status']) ??
          _string(flowSummary['admission_status']),
      transferStatus:
          _string(json['transfer_status']) ??
          _string(flowSummary['transfer_status']),
      wardDisplayName: _string(json['ward_display_name']),
      bedId: _string(json['bed_id']),
      bedDisplayLabel: _string(json['bed_display_label']),
      openTransferRequestId: _string(json['open_transfer_request_id']),
      admittedAt: _date(json['admitted_at']),
      dischargedAt: _date(json['discharged_at']),
      dischargeStatus: _string(json['discharge_status']),
      icuStatus: _string(json['icu_status']),
      hasCriticalAlert: _bool(json['has_critical_alert']),
      criticalSeverity: _string(json['critical_severity']),
      activeIcuStayId: _string(json['active_icu_stay_id']),
      hasActiveBed:
          _bool(json['has_active_bed']) || _bool(flowSummary['has_active_bed']),
      medicationDueCount: _int(json['medication_due_count']),
      pendingHandoverCount: _int(json['pending_handover_count']),
      lastObservation: _string(json['last_observation']),
      lastObservationAt: _date(json['last_observation_at']),
    );
  }
}

final class NursingPatientDetailDto {
  const NursingPatientDetailDto(this.json, this.fallback);

  final NursingJsonMap json;
  final NursingPatientSummary fallback;

  factory NursingPatientDetailDto.fromResponse(
    Object? responseData,
    NursingPatientSummary fallback,
  ) {
    final NursingJsonMap response = _expectMap(responseData);
    return NursingPatientDetailDto(_map(response['data']), fallback);
  }

  NursingPatientDetail toEntity() {
    final NursingJsonMap admission = _map(json['admission']);
    final NursingJsonMap patient = _map(json['patient']);
    final NursingJsonMap encounter = _map(json['encounter']);
    final NursingJsonMap facility = _map(json['facility']);
    final NursingJsonMap flow = _map(json['flow']);
    final NursingJsonMap activeBedAssignment = _map(
      json['active_bed_assignment'],
    );
    final NursingJsonMap activeBed = _map(activeBedAssignment['bed']);
    final NursingJsonMap ward = _map(activeBed['ward']);
    final NursingJsonMap openTransfer = _map(json['open_transfer_request']);
    final NursingJsonMap latestDischarge = _map(
      json['latest_discharge_summary'],
    );
    final NursingJsonMap icu = _map(json['icu']);

    final String id =
        _string(json['id']) ?? _string(admission['id']) ?? fallback.admissionId;
    final String? patientId =
        _string(json['patient_display_id']) ?? _string(patient['id']);
    final String? encounterId =
        _string(json['encounter_display_id']) ?? _string(encounter['id']);

    final NursingPatientSummary summary = NursingPatientSummary(
      id: id,
      admissionId: id,
      displayId: _string(json['display_id']) ?? fallback.displayId,
      patientId: patientId,
      patientDisplayId: patientId,
      patientDisplayName:
          _string(json['patient_display_name']) ?? _patientName(patient),
      encounterDisplayId: encounterId,
      stage: _string(json['stage']) ?? _string(flow['stage']),
      nextStep: _string(json['next_step']) ?? _string(flow['next_step']),
      admissionStatus: _string(admission['status']),
      transferStatus:
          _string(json['transfer_status']) ??
          _string(flow['transfer_status']) ??
          _string(openTransfer['status']),
      wardDisplayName:
          _string(json['ward_display_name']) ?? _string(ward['name']),
      bedId: _string(activeBed['id']),
      bedDisplayLabel: _string(activeBed['label']),
      openTransferRequestId: _string(openTransfer['id']),
      admittedAt: _date(admission['admitted_at']),
      dischargedAt: _date(admission['discharged_at']),
      dischargeStatus: _string(latestDischarge['status']),
      icuStatus: _string(json['icu_status']) ?? _string(icu['status']),
      hasCriticalAlert:
          _bool(json['has_critical_alert']) || _bool(icu['has_critical_alert']),
      criticalSeverity:
          _string(json['critical_severity']) ??
          _string(icu['critical_severity']),
      activeIcuStayId: _string(json['active_icu_stay_id']),
      hasActiveBed:
          _bool(flow['has_active_bed']) || activeBedAssignment.isNotEmpty,
    );

    return NursingPatientDetail(
      summary: summary,
      patientGender: _string(patient['gender']),
      patientDateOfBirth: _date(patient['date_of_birth']),
      facilityName: _string(facility['name']),
      encounterType: _string(encounter['encounter_type']),
      encounterStatus: _string(encounter['status']),
      activeTransfer: NursingTransferRequestDto(openTransfer).toEntityOrNull(),
      latestDischarge: NursingDischargeSummaryDto(
        latestDischarge,
      ).toEntityOrNull(),
      nursingNotes: _list(json['nursing_notes'])
          .map(NursingNoteRecordDto.new)
          .map((NursingNoteRecordDto dto) => dto.toEntity())
          .where((NursingNoteRecord item) => item.id.isNotEmpty)
          .toList(growable: false),
      medicationAdministrations: _list(json['medication_administrations'])
          .map(MedicationAdministrationRecordDto.new)
          .map((MedicationAdministrationRecordDto dto) => dto.toEntity())
          .where((MedicationAdministrationRecord item) => item.id.isNotEmpty)
          .toList(growable: false),
      medicationSuggestions: _list(json['medication_suggestions'])
          .map(MedicationSuggestionDto.new)
          .map((MedicationSuggestionDto dto) => dto.toEntity())
          .where((MedicationSuggestion item) => item.id.isNotEmpty)
          .toList(growable: false),
      medicationReminders: _list(json['medication_reminders'])
          .map(MedicationReminderDto.new)
          .map((MedicationReminderDto dto) => dto.toEntity())
          .where((MedicationReminder item) => item.id.isNotEmpty)
          .toList(growable: false),
      timeline: _list(json['timeline'])
          .map(NursingTimelineItemDto.new)
          .map((NursingTimelineItemDto dto) => dto.toEntity())
          .where((NursingTimelineItem item) => item.label.isNotEmpty)
          .toList(growable: false),
      icuObservations: _list(icu['recent_observations'])
          .map(NursingTimelineItemDto.fromIcuObservation)
          .map((NursingTimelineItemDto dto) => dto.toEntity())
          .where((NursingTimelineItem item) => item.label.isNotEmpty)
          .toList(growable: false),
      criticalAlerts: _list(icu['recent_alerts'])
          .map(NursingCriticalAlertDto.new)
          .map((NursingCriticalAlertDto dto) => dto.toEntity())
          .where((NursingCriticalAlert item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class NursingNoteRecordDto {
  const NursingNoteRecordDto(this.json);

  final NursingJsonMap json;

  NursingNoteRecord toEntity() {
    return NursingNoteRecord(
      id: _string(json['id']) ?? _string(json['human_friendly_id']) ?? '',
      nurseUserId: _string(json['nurse_user_id']),
      nurseName: _string(json['nurse_name']),
      note: _string(json['note']),
      createdAt: _date(json['created_at']),
    );
  }
}

final class MedicationAdministrationRecordDto {
  const MedicationAdministrationRecordDto(this.json);

  final NursingJsonMap json;

  MedicationAdministrationRecord toEntity() {
    return MedicationAdministrationRecord(
      id: _string(json['id']) ?? _string(json['human_friendly_id']) ?? '',
      prescriptionId: _string(json['prescription_id']),
      administeredAt: _date(json['administered_at']),
      dose: _string(json['dose']),
      unit: _string(json['unit']),
      route: _string(json['route']),
      createdAt: _date(json['created_at']),
    );
  }
}

final class MedicationSuggestionDto {
  const MedicationSuggestionDto(this.json);

  final NursingJsonMap json;

  MedicationSuggestion toEntity() {
    return MedicationSuggestion(
      id: _string(json['id']) ?? _string(json['prescription_id']) ?? '',
      medicationLabel: _string(json['medication_label']),
      drugName: _string(json['drug_name']),
      dose: _string(json['dose']),
      unit: _string(json['unit']),
      route: _string(json['route']),
      frequency: _string(json['frequency']),
      orderStatus: _string(json['order_status']),
      itemStatus: _string(json['item_status']),
      orderedAt: _date(json['ordered_at']),
    );
  }
}

final class MedicationReminderDto {
  const MedicationReminderDto(this.json);

  final NursingJsonMap json;

  MedicationReminder toEntity() {
    return MedicationReminder(
      id: _string(json['id']) ?? '',
      scheduledAt: _date(json['scheduled_at']),
      status: _string(json['status']),
      medicationLabel: _string(json['medication_label']),
      dose: _string(json['dose']),
      unit: _string(json['unit']),
      route: _string(json['route']),
      frequency: _string(json['frequency']),
      prescriptionId: _string(json['prescription_id']),
    );
  }
}

final class NursingVitalSignDto {
  const NursingVitalSignDto(this.json);

  final NursingJsonMap json;

  NursingVitalSign toEntity() {
    return NursingVitalSign(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      vitalType: _string(json['vital_type']) ?? '',
      value: _string(json['value']),
      unit: _string(json['unit']),
      systolicValue: _num(json['systolic_value']),
      diastolicValue: _num(json['diastolic_value']),
      mapValue: _num(json['map_value']),
      recordedAt: _date(json['recorded_at']) ?? _date(json['created_at']),
    );
  }
}

final class NursingCarePlanDto {
  const NursingCarePlanDto(this.json);

  final NursingJsonMap json;

  NursingCarePlan toEntity() {
    return NursingCarePlan(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      plan: _string(json['plan']),
      status: _string(json['status']),
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      createdAt: _date(json['created_at']),
    );
  }
}

final class NursingHandoverDto {
  const NursingHandoverDto(this.json);

  final NursingJsonMap json;

  NursingHandover toEntity() {
    final String? admissionId = _handoverAdmissionId(json['items_json']);
    return NursingHandover(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      status: _string(json['status']),
      admissionId: admissionId,
      fromUserId: _string(json['from_user_id']),
      toUserId: _string(json['to_user_id']),
      signoffNotes: _string(json['signoff_notes']),
      acceptedNotes: _string(json['accepted_notes']),
      createdAt: _date(json['created_at']),
      acceptedAt: _date(json['accepted_at']),
    );
  }
}

final class NursingRosterAssignmentDto {
  const NursingRosterAssignmentDto(this.json);

  final NursingJsonMap json;

  NursingRosterAssignment toEntity() {
    return NursingRosterAssignment(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      status: _string(json['status']),
      periodStart: _date(json['period_start']),
      periodEnd: _date(json['period_end']),
      facilityId: _string(json['facility_id']),
      departmentId: _string(json['department_id']),
    );
  }
}

final class NursingTransferRequestDto {
  const NursingTransferRequestDto(this.json);

  final NursingJsonMap json;

  NursingTransferRequest? toEntityOrNull() {
    final String? id = _string(json['id']);
    if (id == null) {
      return null;
    }
    return NursingTransferRequest(
      id: id,
      status: _string(json['status']),
      requestedAt: _date(json['requested_at']),
      fromWardName: _string(_map(json['from_ward'])['name']),
      toWardName: _string(_map(json['to_ward'])['name']),
    );
  }
}

final class NursingDischargeSummaryDto {
  const NursingDischargeSummaryDto(this.json);

  final NursingJsonMap json;

  NursingDischargeSummary? toEntityOrNull() {
    final String? id = _string(json['id']);
    if (id == null) {
      return null;
    }
    return NursingDischargeSummary(
      id: id,
      status: _string(json['status']),
      summary: _string(json['summary']),
      dischargedAt: _date(json['discharged_at']),
    );
  }
}

final class NursingTimelineItemDto {
  const NursingTimelineItemDto(this.json);

  NursingTimelineItemDto.fromIcuObservation(NursingJsonMap json)
    : this(<String, Object?>{
        'type': 'ICU_OBSERVATION',
        'label': json['observation'],
        'at': json['observed_at'] ?? json['created_at'],
      });

  final NursingJsonMap json;

  NursingTimelineItem toEntity() {
    return NursingTimelineItem(
      type: _string(json['type']) ?? '',
      label: _string(json['label']) ?? '',
      occurredAt: _date(json['at']) ?? _date(json['occurred_at']),
    );
  }
}

final class NursingCriticalAlertDto {
  const NursingCriticalAlertDto(this.json);

  final NursingJsonMap json;

  NursingCriticalAlert toEntity() {
    return NursingCriticalAlert(
      id: _string(json['id']) ?? '',
      severity: _string(json['severity']),
      message: _string(json['message']),
      createdAt: _date(json['created_at']),
    );
  }
}

List<NursingNoteRecord> decodeNursingNotes(Object? responseData) {
  return _list(_expectMap(responseData)['data'])
      .map(NursingNoteRecordDto.new)
      .map((NursingNoteRecordDto dto) => dto.toEntity())
      .where((NursingNoteRecord item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<MedicationAdministrationRecord> decodeMedicationAdministrations(
  Object? responseData,
) {
  return _list(_expectMap(responseData)['data'])
      .map(MedicationAdministrationRecordDto.new)
      .map((MedicationAdministrationRecordDto dto) => dto.toEntity())
      .where((MedicationAdministrationRecord item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<NursingVitalSign> decodeNursingVitals(Object? responseData) {
  return _list(_expectMap(responseData)['data'])
      .map(NursingVitalSignDto.new)
      .map((NursingVitalSignDto dto) => dto.toEntity())
      .where((NursingVitalSign item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<NursingCarePlan> decodeNursingCarePlans(Object? responseData) {
  return _list(_expectMap(responseData)['data'])
      .map(NursingCarePlanDto.new)
      .map((NursingCarePlanDto dto) => dto.toEntity())
      .where((NursingCarePlan item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<NursingHandover> decodeNursingHandovers(Object? responseData) {
  return _list(_expectMap(responseData)['data'])
      .map(NursingHandoverDto.new)
      .map((NursingHandoverDto dto) => dto.toEntity())
      .where((NursingHandover item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<NursingRosterAssignment> decodeNursingRosters(Object? responseData) {
  return _list(_expectMap(responseData)['data'])
      .map(NursingRosterAssignmentDto.new)
      .map((NursingRosterAssignmentDto dto) => dto.toEntity())
      .where((NursingRosterAssignment item) => item.id.isNotEmpty)
      .toList(growable: false);
}

NursingJsonMap _expectMap(Object? value) {
  if (value is NursingJsonMap) {
    return value;
  }
  throw const FormatException('Expected response object.');
}

NursingJsonMap _map(Object? value) {
  return value is NursingJsonMap ? value : <String, Object?>{};
}

List<NursingJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <NursingJsonMap>[];
  }
  return value.whereType<NursingJsonMap>().toList(growable: false);
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

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value.trim());
  }
  return null;
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return switch (value.trim().toLowerCase()) {
      'true' || '1' || 'yes' => true,
      _ => false,
    };
  }
  return false;
}

String? _patientName(NursingJsonMap patient) {
  final String joined = <String?>[
    _string(patient['first_name']),
    _string(patient['last_name']),
  ].whereType<String>().join(' ').trim();
  return joined.isEmpty ? null : joined;
}

String? _handoverAdmissionId(Object? value) {
  final NursingJsonMap map = _map(value);
  final String? direct = _string(map['admission_id']);
  if (direct != null) {
    return direct;
  }
  if (value is List) {
    for (final Object? item in value) {
      final String? itemAdmissionId = _string(_map(item)['admission_id']);
      if (itemAdmissionId != null) {
        return itemAdmissionId;
      }
    }
  }
  return null;
}
