import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef IcuJsonMap = Map<String, Object?>;

final class IcuBoardPageDto {
  const IcuBoardPageDto({required this.page});

  final AppPage<IcuPatientSummary> page;

  factory IcuBoardPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final IcuJsonMap response = _expectMap(responseData);
    final List<IcuPatientSummary> items = _list(response['data'])
        .map(IcuPatientSummaryDto.fromBoardEntry)
        .map((IcuPatientSummaryDto dto) => dto.toEntity())
        .where((IcuPatientSummary item) => item.admissionId.isNotEmpty)
        .toList(growable: false);

    return IcuBoardPageDto(
      page: AppPage<IcuPatientSummary>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class IcuPatientDetailDto {
  const IcuPatientDetailDto(this.json);

  final IcuJsonMap json;

  factory IcuPatientDetailDto.fromResponse(Object? responseData) {
    final IcuJsonMap response = _expectMap(responseData);
    return IcuPatientDetailDto(_map(response['data']));
  }

  IcuPatientDetail toEntity() {
    final IcuJsonMap admission = _map(json['admission']);
    final IcuJsonMap patient = _map(json['patient']);
    final IcuJsonMap facility = _map(json['facility']);
    final IcuJsonMap icu = _map(json['icu']);
    final IcuPatientSummary summary = IcuPatientSummaryDto.fromDetail(
      json,
    ).toEntity();

    return IcuPatientDetail(
      summary: summary,
      facilityName: _string(facility['name']),
      patientGender: _string(patient['gender']),
      patientDateOfBirth: _date(patient['date_of_birth']),
      activeStay: IcuStaySummaryDto(_map(icu['active_stay'])).toEntityOrNull(),
      latestStay: IcuStaySummaryDto(_map(icu['latest_stay'])).toEntityOrNull(),
      recentStays: _list(icu['recent_stays'])
          .map(IcuStaySummaryDto.new)
          .map((IcuStaySummaryDto dto) => dto.toEntityOrNull())
          .whereType<IcuStaySummary>()
          .toList(growable: false),
      observations: _list(icu['recent_observations'])
          .map(IcuObservationDto.new)
          .map((IcuObservationDto dto) => dto.toEntity())
          .where((IcuObservation item) => item.id.isNotEmpty)
          .toList(growable: false),
      alerts: _list(icu['recent_alerts'])
          .map(IcuCriticalAlertDto.new)
          .map((IcuCriticalAlertDto dto) => dto.toEntity())
          .where((IcuCriticalAlert item) => item.id.isNotEmpty)
          .toList(growable: false),
      alertSummary: IcuCriticalAlertSummaryDto(
        _map(icu['critical_alert_summary']),
      ).toEntity(),
      transferRequests: _list(json['transfer_requests'])
          .map(IcuTransferRequestDto.new)
          .map((IcuTransferRequestDto dto) => dto.toEntity())
          .where((IcuTransferRequest item) => item.id.isNotEmpty)
          .toList(growable: false),
      dischargeSummaries: _list(json['discharge_summaries'])
          .map(IcuDischargeSummaryDto.new)
          .map((IcuDischargeSummaryDto dto) => dto.toEntity())
          .where((IcuDischargeSummary item) => item.id.isNotEmpty)
          .toList(growable: false),
      roundNotes: _list(json['ward_rounds'])
          .map(IcuRoundNoteDto.new)
          .map((IcuRoundNoteDto dto) => dto.toEntity())
          .where((IcuRoundNote item) => item.id.isNotEmpty)
          .toList(growable: false),
      nursingNotes: _list(json['nursing_notes'])
          .map(IcuNursingNoteDto.new)
          .map((IcuNursingNoteDto dto) => dto.toEntity())
          .where((IcuNursingNote item) => item.id.isNotEmpty)
          .toList(growable: false),
      medicationTasks: _list(json['medication_reminders'])
          .map(IcuMedicationTaskDto.new)
          .map((IcuMedicationTaskDto dto) => dto.toEntity())
          .where((IcuMedicationTask item) => item.id.isNotEmpty)
          .toList(growable: false),
      medicationAdministrations: _list(json['medication_administrations'])
          .map(IcuMedicationAdministrationDto.new)
          .map((IcuMedicationAdministrationDto dto) => dto.toEntity())
          .where((IcuMedicationAdministration item) => item.id.isNotEmpty)
          .toList(growable: false),
      timeline: _list(json['timeline'])
          .map(IcuTimelineItemDto.new)
          .map((IcuTimelineItemDto dto) => dto.toEntity())
          .where((IcuTimelineItem item) => item.label.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class IcuPatientSummaryDto {
  const IcuPatientSummaryDto(this.json);

  final IcuJsonMap json;

  factory IcuPatientSummaryDto.fromBoardEntry(IcuJsonMap json) {
    return IcuPatientSummaryDto(json);
  }

  factory IcuPatientSummaryDto.fromDetail(IcuJsonMap json) {
    return IcuPatientSummaryDto(json);
  }

  IcuPatientSummary toEntity() {
    final IcuJsonMap admission = _map(json['admission']);
    final IcuJsonMap activeBed = _map(json['active_bed_assignment']);
    final IcuJsonMap activeBedValue = _map(activeBed['bed']);
    final IcuJsonMap activeWard = _map(activeBedValue['ward']);
    final IcuJsonMap flow = _map(json['flow']);
    final IcuJsonMap flowSummary = _map(json['flow_summary']);
    final IcuJsonMap discharge = _map(json['latest_discharge_summary']);

    final String admissionId =
        _string(json['admission_id']) ??
        _string(json['id']) ??
        _string(admission['id']) ??
        '';

    return IcuPatientSummary(
      id: _string(json['id']) ?? admissionId,
      admissionId: admissionId,
      displayId: _string(json['display_id']) ?? _string(admission['id']),
      patientId:
          _string(json['patient_display_id']) ??
          _string(json['patient_id']) ??
          _string(_map(json['patient'])['id']),
      patientDisplayName: _string(json['patient_display_name']),
      encounterId:
          _string(json['encounter_display_id']) ??
          _string(_map(json['encounter'])['id']),
      wardName:
          _string(json['ward_display_name']) ?? _string(activeWard['name']),
      bedLabel:
          _string(json['bed_display_label']) ?? _string(activeBedValue['label']),
      stage:
          _string(json['stage']) ??
          _string(flow['stage']) ??
          _string(flowSummary['stage']),
      nextStep:
          _string(json['next_step']) ??
          _string(flow['next_step']) ??
          _string(flowSummary['next_step']),
      transferStatus:
          _string(json['transfer_status']) ??
          _string(flow['transfer_status']) ??
          _string(flowSummary['transfer_status']),
      admissionStatus:
          _string(json['admission_status']) ??
          _string(admission['status']) ??
          _string(flowSummary['admission_status']),
      dischargeStatus:
          _string(json['discharge_status']) ?? _string(discharge['status']),
      icuStatus: _string(json['icu_status']) ?? _string(_map(json['icu'])['status']),
      activeIcuStayId: _string(json['active_icu_stay_id']),
      latestIcuStayId: _string(json['latest_icu_stay_id']),
      criticalSeverity: _string(json['critical_severity']),
      hasCriticalAlert: _bool(json['has_critical_alert']),
      hasActiveBed:
          _bool(json['has_active_bed']) || _bool(flowSummary['has_active_bed']),
      admittedAt: _date(json['admitted_at']) ?? _date(admission['admitted_at']),
      dischargedAt:
          _date(json['discharged_at']) ?? _date(admission['discharged_at']),
    );
  }
}

final class IcuStaySummaryDto {
  const IcuStaySummaryDto(this.json);

  final IcuJsonMap json;

  IcuStaySummary? toEntityOrNull() {
    final String? id = _string(json['id']) ?? _string(json['display_id']);
    if (id == null) {
      return null;
    }

    return IcuStaySummary(
      id: id,
      displayId: _string(json['display_id']),
      startedAt: _date(json['started_at']),
      endedAt: _date(json['ended_at']),
      createdAt: _date(json['created_at']),
    );
  }
}

final class IcuObservationDto {
  const IcuObservationDto(this.json);

  final IcuJsonMap json;

  IcuObservation toEntity() {
    return IcuObservation(
      id: _string(json['id']) ?? '',
      displayId: _string(json['display_id']),
      icuStayId: _string(json['icu_stay_id']),
      observedAt: _date(json['observed_at']),
      observation: _string(json['observation']),
      createdAt: _date(json['created_at']),
    );
  }
}

final class IcuCriticalAlertDto {
  const IcuCriticalAlertDto(this.json);

  final IcuJsonMap json;

  IcuCriticalAlert toEntity() {
    return IcuCriticalAlert(
      id: _string(json['id']) ?? '',
      displayId: _string(json['display_id']),
      icuStayId: _string(json['icu_stay_id']),
      severity: _string(json['severity']),
      message: _string(json['message']),
      createdAt: _date(json['created_at']),
    );
  }
}

final class IcuCriticalAlertSummaryDto {
  const IcuCriticalAlertSummaryDto(this.json);

  final IcuJsonMap json;

  IcuCriticalAlertSummary toEntity() {
    final IcuJsonMap bySeverity = _map(json['by_severity']);
    return IcuCriticalAlertSummary(
      total: _int(json['total']),
      highestSeverity: _string(json['highest_severity']),
      low: _int(bySeverity['LOW']),
      medium: _int(bySeverity['MEDIUM']),
      high: _int(bySeverity['HIGH']),
      critical: _int(bySeverity['CRITICAL']),
      recent: _list(json['recent'])
          .map(IcuCriticalAlertDto.new)
          .map((IcuCriticalAlertDto dto) => dto.toEntity())
          .where((IcuCriticalAlert item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class IcuTransferRequestDto {
  const IcuTransferRequestDto(this.json);

  final IcuJsonMap json;

  IcuTransferRequest toEntity() {
    return IcuTransferRequest(
      id: _string(json['id']) ?? '',
      status: _string(json['status']),
      requestedAt: _date(json['requested_at']),
      fromWardName: _string(_map(json['from_ward'])['name']),
      toWardName: _string(_map(json['to_ward'])['name']),
    );
  }
}

final class IcuDischargeSummaryDto {
  const IcuDischargeSummaryDto(this.json);

  final IcuJsonMap json;

  IcuDischargeSummary toEntity() {
    return IcuDischargeSummary(
      id: _string(json['id']) ?? '',
      status: _string(json['status']),
      summary: _string(json['summary']),
      dischargedAt: _date(json['discharged_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class IcuRoundNoteDto {
  const IcuRoundNoteDto(this.json);

  final IcuJsonMap json;

  IcuRoundNote toEntity() {
    return IcuRoundNote(
      id: _string(json['id']) ?? '',
      roundAt: _date(json['round_at']),
      notes: _string(json['notes']),
      createdAt: _date(json['created_at']),
    );
  }
}

final class IcuNursingNoteDto {
  const IcuNursingNoteDto(this.json);

  final IcuJsonMap json;

  IcuNursingNote toEntity() {
    return IcuNursingNote(
      id: _string(json['id']) ?? '',
      nurseName: _string(json['nurse_name']),
      note: _string(json['note']),
      createdAt: _date(json['created_at']),
    );
  }
}

final class IcuMedicationTaskDto {
  const IcuMedicationTaskDto(this.json);

  final IcuJsonMap json;

  IcuMedicationTask toEntity() {
    return IcuMedicationTask(
      id: _string(json['id']) ?? '',
      scheduledAt: _date(json['scheduled_at']),
      status: _string(json['status']),
      note: _string(json['note']),
      medicationLabel: _string(json['medication_label']),
      dose: _string(json['dose']),
      unit: _string(json['unit']),
      route: _string(json['route']),
      frequency: _string(json['frequency']),
    );
  }
}

final class IcuMedicationAdministrationDto {
  const IcuMedicationAdministrationDto(this.json);

  final IcuJsonMap json;

  IcuMedicationAdministration toEntity() {
    return IcuMedicationAdministration(
      id: _string(json['id']) ?? '',
      administeredAt: _date(json['administered_at']),
      dose: _string(json['dose']),
      unit: _string(json['unit']),
      route: _string(json['route']),
    );
  }
}

final class IcuVitalSignDto {
  const IcuVitalSignDto(this.json);

  final IcuJsonMap json;

  IcuVitalSign toEntity() {
    return IcuVitalSign(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      vitalType: _string(json['vital_type']) ?? '',
      value: _string(json['value']),
      unit: _string(json['unit']),
      systolicValue: _number(json['systolic_value']),
      diastolicValue: _number(json['diastolic_value']),
      mapValue: _number(json['map_value']),
      recordedAt: _date(json['recorded_at']),
    );
  }
}

final class IcuTimelineItemDto {
  const IcuTimelineItemDto(this.json);

  final IcuJsonMap json;

  IcuTimelineItem toEntity() {
    return IcuTimelineItem(
      type: _string(json['type']) ?? '',
      label: _string(json['label']) ?? '',
      at: _date(json['at']),
    );
  }
}

final class IcuWardOptionDto {
  const IcuWardOptionDto(this.json);

  final IcuJsonMap json;

  IcuWardOption toEntity() {
    return IcuWardOption(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      name: _string(json['name']),
      wardType: _string(json['ward_type']),
    );
  }
}

List<IcuVitalSign> decodeIcuVitalSigns(Object? responseData) {
  final IcuJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(IcuVitalSignDto.new)
      .map((IcuVitalSignDto dto) => dto.toEntity())
      .where((IcuVitalSign item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<IcuWardOption> decodeIcuWardOptions(Object? responseData) {
  final IcuJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(IcuWardOptionDto.new)
      .map((IcuWardOptionDto dto) => dto.toEntity())
      .where((IcuWardOption item) => item.id.isNotEmpty)
      .toList(growable: false);
}

IcuJsonMap decodeDataMap(Object? responseData) {
  final IcuJsonMap response = _expectMap(responseData);
  return _map(response['data']);
}

IcuJsonMap _expectMap(Object? value) {
  if (value is IcuJsonMap) {
    return value;
  }

  throw const FormatException('Expected response object.');
}

IcuJsonMap _map(Object? value) {
  return value is IcuJsonMap ? value : <String, Object?>{};
}

List<IcuJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <IcuJsonMap>[];
  }

  return value.whereType<IcuJsonMap>().toList(growable: false);
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
    if (<String>['true', '1', 'yes', 'on'].contains(normalized)) {
      return true;
    }
    if (<String>['false', '0', 'no', 'off'].contains(normalized)) {
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

num? _number(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}
