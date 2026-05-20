import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef PhysiotherapyJsonMap = Map<String, Object?>;

final class PhysiotherapyEncounterSummary {
  const PhysiotherapyEncounterSummary({
    required this.encounterId,
    required this.id,
    this.encounterPublicId,
    this.patientId,
    this.patientPublicId,
    this.patientDisplayName,
    this.patientPhone,
    this.patientGender,
    this.encounterType,
    this.status,
    this.providerUserId,
    this.providerName,
    this.startedAt,
    this.updatedAt,
  });

  final String encounterId;
  final String id;
  final String? encounterPublicId;
  final String? patientId;
  final String? patientPublicId;
  final String? patientDisplayName;
  final String? patientPhone;
  final String? patientGender;
  final String? encounterType;
  final String? status;
  final String? providerUserId;
  final String? providerName;
  final DateTime? startedAt;
  final DateTime? updatedAt;

  TherapyWorkItem toBaseWorkItem() {
    return TherapyWorkItem(
      id: id,
      encounterId: encounterId,
      encounterPublicId: encounterPublicId,
      patientId: patientId,
      patientPublicId: patientPublicId,
      patientDisplayName: patientDisplayName,
      patientPhone: patientPhone,
      patientGender: patientGender,
      encounterType: encounterType,
      therapistUserId: providerUserId,
      therapistName: providerName,
      lastActivityAt: updatedAt ?? startedAt,
    );
  }
}

final class PhysiotherapyEncounterPageDto {
  const PhysiotherapyEncounterPageDto({required this.page});

  final AppPage<PhysiotherapyEncounterSummary> page;

  factory PhysiotherapyEncounterPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final PhysiotherapyJsonMap response = _expectMap(responseData);
    final List<PhysiotherapyEncounterSummary> items = _list(response['data'])
        .map(PhysiotherapyEncounterDto.new)
        .map((PhysiotherapyEncounterDto dto) => dto.toEntity())
        .where(
          (PhysiotherapyEncounterSummary item) =>
              item.encounterId.trim().isNotEmpty,
        )
        .toList(growable: false);

    return PhysiotherapyEncounterPageDto(
      page: AppPage<PhysiotherapyEncounterSummary>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class PhysiotherapyEncounterDto {
  const PhysiotherapyEncounterDto(this.json);

  final PhysiotherapyJsonMap json;

  PhysiotherapyEncounterSummary toEntity() {
    final PhysiotherapyJsonMap? patient = _nullableMap(json['patient']);
    final PhysiotherapyJsonMap? provider = _nullableMap(json['provider']);
    final String encounterId = _string(json['id']) ?? '';
    final String? encounterPublicId = _string(json['human_friendly_id']);

    return PhysiotherapyEncounterSummary(
      id: encounterPublicId ?? encounterId,
      encounterId: encounterId,
      encounterPublicId: encounterPublicId,
      patientId: _string(json['patient_id']) ?? _string(patient?['id']),
      patientPublicId:
          _string(json['patient_human_friendly_id']) ??
          _string(patient?['human_friendly_id']),
      patientDisplayName:
          _string(json['patient_display_name']) ?? _patientDisplayName(patient),
      patientPhone:
          _string(json['patient_primary_phone']) ??
          _string(patient?['primary_phone']) ??
          _string(patient?['phone']),
      patientGender:
          _string(json['patient_gender']) ?? _string(patient?['gender']),
      encounterType: _string(json['encounter_type']),
      status: _string(json['status']),
      providerUserId: _string(json['provider_user_id']),
      providerName:
          _string(json['provider_display_name']) ?? _providerDisplayName(provider),
      startedAt: _date(json['started_at']),
      updatedAt: _date(json['updated_at']) ?? _date(json['ended_at']),
    );
  }
}

final class PhysiotherapyRecordDto {
  const PhysiotherapyRecordDto(this.json, this.kind);

  final PhysiotherapyJsonMap json;
  final PhysiotherapyRecordKind kind;

  PhysiotherapyRecord toEntity() {
    return switch (kind) {
      PhysiotherapyRecordKind.appointment => _appointment(),
      PhysiotherapyRecordKind.procedure => _procedure(),
      PhysiotherapyRecordKind.carePlan => _carePlan(),
      PhysiotherapyRecordKind.clinicalNote => _clinicalNote(),
      PhysiotherapyRecordKind.followUp => _followUp(),
    };
  }

  PhysiotherapyRecord _appointment() {
    final PhysiotherapyJsonMap? patient = _nullableMap(json['patient']);
    final PhysiotherapyJsonMap? provider = _nullableMap(json['provider']);
    final String apiId = _string(json['id']) ?? '';
    final String displayId = _string(json['human_friendly_id']) ?? apiId;
    final DateTime? startAt = _date(json['scheduled_start']);
    final DateTime? endAt = _date(json['scheduled_end']);
    final String? reason = _string(json['reason']);

    return PhysiotherapyRecord(
      id: displayId,
      apiId: apiId,
      kind: kind,
      status: _string(json['status']),
      title: reason ?? displayId,
      subtitle: _joinDisplay(<String?>[
        _string(json['patient_display_name']) ?? _patientDisplayName(patient),
        _string(json['provider_display_name']) ?? _providerDisplayName(provider),
      ]),
      description: reason,
      patientId: _string(json['patient_id']) ?? _string(patient?['id']),
      patientPublicId:
          _string(json['patient_human_friendly_id']) ??
          _string(patient?['human_friendly_id']),
      patientDisplayName:
          _string(json['patient_display_name']) ?? _patientDisplayName(patient),
      providerUserId: _string(json['provider_user_id']),
      providerName:
          _string(json['provider_display_name']) ?? _providerDisplayName(provider),
      startAt: startAt,
      endAt: endAt,
      occurredAt: startAt,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  PhysiotherapyRecord _procedure() {
    final String apiId = _string(json['id']) ?? '';
    final String displayId = _string(json['human_friendly_id']) ?? apiId;
    final String? code = _string(json['code']);
    final String? description = _string(json['description']);

    return PhysiotherapyRecord(
      id: displayId,
      apiId: apiId,
      kind: kind,
      status: _string(json['status']),
      code: code,
      title: description ?? code ?? displayId,
      subtitle: _joinDisplay(<String?>[code, _string(json['status'])]),
      description: description,
      occurredAt: _date(json['performed_at']) ?? _date(json['recorded_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  PhysiotherapyRecord _carePlan() {
    final String apiId = _string(json['id']) ?? '';
    final String displayId = _string(json['human_friendly_id']) ?? apiId;
    final String? plan = _string(json['plan']);
    final DateTime? startAt = _date(json['start_date']);
    final DateTime? endAt = _date(json['end_date']);

    return PhysiotherapyRecord(
      id: displayId,
      apiId: apiId,
      kind: kind,
      status: _string(json['status']),
      title: plan ?? displayId,
      subtitle: _joinDisplay(<String?>[
        _dateDisplay(startAt),
        _dateDisplay(endAt),
        _string(json['status']),
      ]),
      description: plan,
      startAt: startAt,
      endAt: endAt,
      occurredAt: startAt,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  PhysiotherapyRecord _clinicalNote() {
    final String apiId = _string(json['id']) ?? '';
    final String displayId = _string(json['human_friendly_id']) ?? apiId;
    final String? note = _string(json['note']);

    return PhysiotherapyRecord(
      id: displayId,
      apiId: apiId,
      kind: kind,
      status: _string(json['status']),
      title: note ?? displayId,
      subtitle: _string(json['author_display_name']) ?? _string(json['author_user_id']),
      description: note,
      providerUserId: _string(json['author_user_id']),
      providerName: _string(json['author_display_name']),
      occurredAt: _date(json['recorded_at']) ?? _date(json['created_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  PhysiotherapyRecord _followUp() {
    final String apiId = _string(json['id']) ?? '';
    final String displayId = _string(json['human_friendly_id']) ?? apiId;
    final DateTime? scheduledAt = _date(json['scheduled_at']);
    final String? notes = _string(json['notes']) ?? _string(json['reason']);

    return PhysiotherapyRecord(
      id: displayId,
      apiId: apiId,
      kind: kind,
      status: _string(json['status']),
      title: notes ?? _string(json['status']) ?? displayId,
      subtitle: _joinDisplay(<String?>[_dateDisplay(scheduledAt), _string(json['status'])]),
      description: notes,
      startAt: scheduledAt,
      occurredAt: scheduledAt,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

AppPage<PhysiotherapyRecord> decodeAppointmentPage(
  Object? responseData,
  AppPageRequest request,
) {
  final PhysiotherapyJsonMap response = _expectMap(responseData);
  final List<PhysiotherapyRecord> items = _list(response['data'])
      .map(
        (PhysiotherapyJsonMap json) => PhysiotherapyRecordDto(
          json,
          PhysiotherapyRecordKind.appointment,
        ),
      )
      .map((PhysiotherapyRecordDto dto) => dto.toEntity())
      .where((PhysiotherapyRecord item) => item.apiId.trim().isNotEmpty)
      .toList(growable: false);

  return AppPage<PhysiotherapyRecord>(
    items: items,
    request: request,
    totalItemCount: _int(_map(response['pagination'])['total']),
  );
}

List<PhysiotherapyRecord> decodePhysiotherapyRecords(
  Object? responseData,
  PhysiotherapyRecordKind kind,
) {
  final PhysiotherapyJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map((PhysiotherapyJsonMap json) => PhysiotherapyRecordDto(json, kind))
      .map((PhysiotherapyRecordDto dto) => dto.toEntity())
      .where((PhysiotherapyRecord item) => item.apiId.trim().isNotEmpty)
      .toList(growable: false);
}

PhysiotherapyJsonMap _expectMap(Object? value) {
  if (value is PhysiotherapyJsonMap) {
    return value;
  }

  throw const FormatException('Expected response object.');
}

PhysiotherapyJsonMap _map(Object? value) {
  return value is PhysiotherapyJsonMap ? value : <String, Object?>{};
}

PhysiotherapyJsonMap? _nullableMap(Object? value) {
  return value is PhysiotherapyJsonMap ? value : null;
}

List<PhysiotherapyJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <PhysiotherapyJsonMap>[];
  }

  return value.whereType<PhysiotherapyJsonMap>().toList(growable: false);
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

String? _patientDisplayName(PhysiotherapyJsonMap? patient) {
  if (patient == null) {
    return null;
  }
  final String? direct =
      _string(patient['display_name']) ?? _string(patient['full_name']);
  if (direct != null) {
    return direct;
  }
  return _joinDisplay(<String?>[
    _string(patient['first_name']),
    _string(patient['middle_name']),
    _string(patient['last_name']),
  ]);
}

String? _providerDisplayName(PhysiotherapyJsonMap? provider) {
  if (provider == null) {
    return null;
  }
  final String? direct =
      _string(provider['display_name']) ?? _string(provider['full_name']);
  if (direct != null) {
    return direct;
  }
  return _joinDisplay(<String?>[
    _string(provider['first_name']),
    _string(provider['last_name']),
  ]);
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' • ');
  return joined.isEmpty ? null : joined;
}

String? _dateDisplay(DateTime? value) {
  if (value == null) {
    return null;
  }
  final DateTime local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
