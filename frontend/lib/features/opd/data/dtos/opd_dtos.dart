import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef OpdJsonMap = Map<String, Object?>;

final class OpdAppointmentPageDto {
  const OpdAppointmentPageDto({required this.page});

  final AppPage<OpdAppointment> page;

  factory OpdAppointmentPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final OpdJsonMap response = _expectMap(responseData);
    final List<OpdAppointment> items = _list(response['data'])
        .map(OpdAppointmentDto.new)
        .map((OpdAppointmentDto dto) => dto.toEntity())
        .where((OpdAppointment item) => item.id.isNotEmpty)
        .toList(growable: false);

    return OpdAppointmentPageDto(
      page: AppPage<OpdAppointment>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class OpdAppointmentDto {
  const OpdAppointmentDto(this.json);

  final OpdJsonMap json;

  OpdAppointment toEntity() {
    return OpdAppointment(
      id: _string(json['id']) ?? '',
      publicId: _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      facilityId: _string(json['facility_id']),
      patientId: _string(json['patient_id']),
      providerUserId: _string(json['provider_user_id']),
      status: _string(json['status']),
      scheduledStart: _date(json['scheduled_start']),
      scheduledEnd: _date(json['scheduled_end']),
      reason: _string(json['reason']),
      patientDisplayName:
          _string(json['patient_display_name']) ??
          _patientDisplayName(_nullableMap(json['patient'])),
      patientIdentifier:
          _string(json['patient_primary_identifier']) ??
          _string(_nullableMap(json['patient'])?['human_friendly_id']),
      patientPhone: _string(json['patient_primary_phone']),
      providerDisplayName:
          _string(json['provider_display_name']) ??
          _providerDisplayName(_nullableMap(json['provider'])),
      facilityName:
          _string(json['facility_name']) ??
          _string(_nullableMap(json['facility'])?['name']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class OpdQueuePageDto {
  const OpdQueuePageDto({required this.page});

  final AppPage<OpdQueueEntry> page;

  factory OpdQueuePageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final OpdJsonMap response = _expectMap(responseData);
    final List<OpdQueueEntry> items = _list(response['data'])
        .map(OpdQueueEntryDto.new)
        .map((OpdQueueEntryDto dto) => dto.toEntity())
        .where((OpdQueueEntry item) => item.id.isNotEmpty)
        .toList(growable: false);

    return OpdQueuePageDto(
      page: AppPage<OpdQueueEntry>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class OpdQueueEntryDto {
  const OpdQueueEntryDto(this.json);

  final OpdJsonMap json;

  OpdQueueEntry toEntity() {
    return OpdQueueEntry(
      id: _string(json['id']) ?? '',
      publicId: _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      facilityId: _string(json['facility_id']),
      patientId: _string(json['patient_id']),
      appointmentId:
          _string(json['appointment_human_friendly_id']) ??
          _string(json['appointment_id']),
      providerUserId: _string(json['provider_user_id']),
      status: _string(json['status']),
      queuedAt: _date(json['queued_at']),
      patientDisplayName:
          _string(json['patient_display_name']) ??
          _patientDisplayName(_nullableMap(json['patient'])),
      patientIdentifier:
          _string(json['patient_primary_identifier']) ??
          _string(_nullableMap(json['patient'])?['human_friendly_id']),
      patientPhone: _string(json['patient_primary_phone']),
      appointmentReason: _string(json['appointment_reason']),
      providerDisplayName:
          _string(json['provider_display_name']) ??
          _providerDisplayName(_nullableMap(json['provider'])),
      paymentStatus: _string(json['payment_status']),
      amountToPay: _number(json['amount_to_pay']),
      currency: _string(json['currency']),
    );
  }
}

final class OpdFlowPageDto {
  const OpdFlowPageDto({required this.page});

  final AppPage<OpdFlowSummary> page;

  factory OpdFlowPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final OpdJsonMap response = _expectMap(responseData);
    final List<OpdFlowSummary> items = _list(response['data'])
        .map(OpdFlowSummaryDto.fromListEntry)
        .map((OpdFlowSummaryDto dto) => dto.toEntity())
        .where((OpdFlowSummary item) => item.id.isNotEmpty)
        .toList(growable: false);

    return OpdFlowPageDto(
      page: AppPage<OpdFlowSummary>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class OpdFlowSummaryDto {
  const OpdFlowSummaryDto({required this.encounter, required this.flow});

  final OpdJsonMap encounter;
  final OpdJsonMap flow;

  factory OpdFlowSummaryDto.fromListEntry(OpdJsonMap json) {
    return OpdFlowSummaryDto(
      encounter: _map(json['encounter']),
      flow: _map(json['flow']),
    );
  }

  factory OpdFlowSummaryDto.fromDetail(OpdJsonMap json) {
    return OpdFlowSummaryDto(
      encounter: _map(json['encounter']),
      flow: _map(json['flow']),
    );
  }

  OpdFlowSummary toEntity() {
    final OpdJsonMap? patient = _nullableMap(encounter['patient']);
    final OpdJsonMap? provider = _nullableMap(encounter['provider']);
    final OpdJsonMap? facility = _nullableMap(encounter['facility']);

    return OpdFlowSummary(
      id: _string(encounter['id']) ?? '',
      publicId: _string(encounter['human_friendly_id']),
      tenantId: _string(encounter['tenant_id']),
      facilityId: _string(encounter['facility_id']),
      patientId: _string(encounter['patient_id']),
      providerUserId: _string(encounter['provider_user_id']),
      encounterType: _string(encounter['encounter_type']),
      status: _string(encounter['status']),
      startedAt: _date(encounter['started_at']),
      endedAt: _date(encounter['ended_at']),
      stage: _string(flow['stage']),
      nextStep: _string(flow['next_step']),
      patientDisplayName: _patientDisplayName(patient),
      patientIdentifier: _string(patient?['human_friendly_id']),
      patientPhone: _string(patient?['primary_phone']),
      providerDisplayName: _providerDisplayName(provider),
      appointmentId: _string(flow['appointment_id']),
      visitQueueId: _string(flow['visit_queue_id']),
      facilityName: _string(facility?['name']),
    );
  }
}

final class OpdFlowDetailDto {
  const OpdFlowDetailDto(this.json);

  final OpdJsonMap json;

  factory OpdFlowDetailDto.fromResponse(Object? responseData) {
    final OpdJsonMap response = _expectMap(responseData);
    return OpdFlowDetailDto(_map(response['data']));
  }

  OpdFlowDetail toEntity() {
    final OpdJsonMap flow = _map(json['flow']);
    final OpdJsonMap consultation = _map(flow['consultation']);
    final OpdFlowSummary summary = OpdFlowSummaryDto.fromDetail(
      json,
    ).toEntity();

    return OpdFlowDetail(
      summary: summary,
      consultationInvoiceId: _string(consultation['invoice_id']),
      consultationPaymentId: _string(consultation['payment_id']),
      consultationPaid: _bool(consultation['paid']),
      consultationPaymentRequired: _bool(
        consultation['payment_required'] ?? consultation['required'],
      ),
      timeline: _list(flow['timeline'])
          .map(OpdTimelineItemDto.new)
          .map((OpdTimelineItemDto dto) => dto.toEntity())
          .toList(growable: false),
      referrals: _list(json['referrals'])
          .map((OpdJsonMap entry) => OpdRelatedRecordDto(entry, 'referral'))
          .map((OpdRelatedRecordDto dto) => dto.toEntity())
          .toList(growable: false),
      followUps: _list(json['follow_ups'])
          .map((OpdJsonMap entry) => OpdRelatedRecordDto(entry, 'follow_up'))
          .map((OpdRelatedRecordDto dto) => dto.toEntity())
          .toList(growable: false),
      clinicalAlerts: _list(json['clinical_alerts'])
          .map((OpdJsonMap entry) => OpdRelatedRecordDto(entry, 'alert'))
          .map((OpdRelatedRecordDto dto) => dto.toEntity())
          .toList(growable: false),
    );
  }
}

final class OpdTimelineItemDto {
  const OpdTimelineItemDto(this.json);

  final OpdJsonMap json;

  OpdTimelineItem toEntity() {
    return OpdTimelineItem(
      action: _string(json['action']) ?? _string(json['event']) ?? '',
      stage: _string(json['stage']) ?? _string(json['stage_to']),
      notes: _string(json['notes']) ?? _string(json['reason']),
      occurredAt:
          _date(json['occurred_at']) ??
          _date(json['created_at']) ??
          _date(json['updated_at']),
    );
  }
}

final class OpdRelatedRecordDto {
  const OpdRelatedRecordDto(this.json, this.kind);

  final OpdJsonMap json;
  final String kind;

  OpdRelatedRecord toEntity() {
    return OpdRelatedRecord(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      kind: kind,
      status: _string(json['status']),
      title:
          _string(json['reason']) ??
          _string(json['notes']) ??
          _string(json['title']) ??
          _string(json['external_facility_name']),
      subtitle:
          _string(json['external_facility_name']) ??
          _string(json['referral_reason_code']),
      occurredAt:
          _date(json['scheduled_at']) ??
          _date(json['created_at']) ??
          _date(json['updated_at']),
    );
  }
}

final class OpdProviderScheduleDto {
  const OpdProviderScheduleDto(this.json);

  final OpdJsonMap json;

  OpdProviderSchedule toEntity() {
    return OpdProviderSchedule(
      id: _string(json['id']) ?? '',
      publicId: _string(json['human_friendly_id']),
      providerUserId: _string(json['provider_user_id']),
      providerPublicId: _string(json['provider_human_friendly_id']),
      providerDisplayName:
          _string(json['provider_display_name']) ??
          _providerDisplayName(_nullableMap(json['provider'])),
      facilityName:
          _string(json['facility_name']) ??
          _string(_nullableMap(json['facility'])?['name']),
      scheduleType: _string(json['schedule_type']),
      dayOfWeek: _intOrNull(json['day_of_week']),
      startTime: _date(json['start_time']),
      endTime: _date(json['end_time']),
      timezone: _string(json['timezone']),
      slotCount: _list(json['slots']).length,
    );
  }
}

final class OpdAvailabilitySlotDto {
  const OpdAvailabilitySlotDto(this.json);

  final OpdJsonMap json;

  OpdAvailabilitySlot toEntity() {
    return OpdAvailabilitySlot(
      id: _string(json['id']) ?? '',
      publicId: _string(json['human_friendly_id']),
      scheduleId:
          _string(json['schedule_human_friendly_id']) ??
          _string(json['schedule_id']),
      providerDisplayName: _string(json['provider_display_name']),
      startTime: _date(json['start_time']),
      endTime: _date(json['end_time']),
      isAvailable: _bool(json['is_available']),
    );
  }
}

List<OpdProviderSchedule> decodeProviderSchedules(Object? responseData) {
  final OpdJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(OpdProviderScheduleDto.new)
      .map((OpdProviderScheduleDto dto) => dto.toEntity())
      .where((OpdProviderSchedule item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<OpdAvailabilitySlot> decodeAvailabilitySlots(Object? responseData) {
  final OpdJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(OpdAvailabilitySlotDto.new)
      .map((OpdAvailabilitySlotDto dto) => dto.toEntity())
      .where((OpdAvailabilitySlot item) => item.id.isNotEmpty)
      .toList(growable: false);
}

OpdJsonMap decodeDataMap(Object? responseData) {
  final OpdJsonMap response = _expectMap(responseData);
  return _map(response['data']);
}

OpdJsonMap _expectMap(Object? value) {
  if (value is OpdJsonMap) {
    return value;
  }

  throw const FormatException('Expected response object.');
}

OpdJsonMap _map(Object? value) {
  return value is OpdJsonMap ? value : <String, Object?>{};
}

OpdJsonMap? _nullableMap(Object? value) {
  return value is OpdJsonMap ? value : null;
}

List<OpdJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <OpdJsonMap>[];
  }

  return value.whereType<OpdJsonMap>().toList(growable: false);
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
    return value.toLowerCase() == 'true';
  }
  return fallback;
}

int _int(Object? value) {
  return _intOrNull(value) ?? 0;
}

int? _intOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
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

String? _patientDisplayName(OpdJsonMap? patient) {
  if (patient == null) {
    return null;
  }

  return _join(<String?>[
        _string(patient['first_name']),
        _string(patient['last_name']),
      ]) ??
      _string(patient['display_name']) ??
      _string(patient['human_friendly_id']);
}

String? _providerDisplayName(OpdJsonMap? provider) {
  if (provider == null) {
    return null;
  }

  final OpdJsonMap? profile = _nullableMap(provider['profile']);
  return _join(<String?>[
        _string(profile?['first_name']),
        _string(profile?['middle_name']),
        _string(profile?['last_name']),
      ]) ??
      _string(provider['email']) ??
      _string(provider['human_friendly_id']);
}

String? _join(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' ');
  return joined.isEmpty ? null : joined;
}
