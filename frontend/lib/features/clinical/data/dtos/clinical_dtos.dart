import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef ClinicalJsonMap = Map<String, Object?>;

final class ClinicalWorklistPageDto {
  const ClinicalWorklistPageDto({required this.page});

  final AppPage<ClinicalWorklistEntry> page;

  factory ClinicalWorklistPageDto.fromEncounterResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final ClinicalJsonMap response = _expectMap(responseData);
    final List<ClinicalWorklistEntry> items = _list(response['data'])
        .map(ClinicalEncounterDto.new)
        .map((ClinicalEncounterDto dto) => dto.toWorklistEntry())
        .where((ClinicalWorklistEntry item) => item.encounterId.isNotEmpty)
        .toList(growable: false);

    return ClinicalWorklistPageDto(
      page: AppPage<ClinicalWorklistEntry>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }

  factory ClinicalWorklistPageDto.fromAdmissionResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final ClinicalJsonMap response = _expectMap(responseData);
    final List<ClinicalWorklistEntry> items = _list(response['data'])
        .map(ClinicalAdmissionDto.new)
        .map((ClinicalAdmissionDto dto) => dto.toWorklistEntry())
        .where((ClinicalWorklistEntry item) => item.encounterId.isNotEmpty)
        .toList(growable: false);

    return ClinicalWorklistPageDto(
      page: AppPage<ClinicalWorklistEntry>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class ClinicalEncounterDto {
  const ClinicalEncounterDto(this.json);

  final ClinicalJsonMap json;

  ClinicalWorklistEntry toWorklistEntry({String sourceQueue = 'ENCOUNTER'}) {
    final ClinicalJsonMap? patient = _nullableMap(json['patient']);
    final ClinicalJsonMap? provider = _nullableMap(json['provider']);
    final DateTime? patientDateOfBirth =
        _date(json['patient_date_of_birth']) ??
        _date(patient?['date_of_birth']);
    final String? patientGender =
        _string(json['patient_gender']) ?? _string(patient?['gender']);
    final DateTime? updatedAt =
        _date(json['updated_at']) ?? _date(json['ended_at']);

    return ClinicalWorklistEntry(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      sourceQueue: sourceQueue,
      encounterId: _string(json['id']) ?? '',
      encounterPublicId: _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      facilityId: _string(json['facility_id']),
      patientId: _string(json['patient_id']) ?? _string(patient?['id']),
      patientPublicId: _string(patient?['human_friendly_id']),
      patientDisplayName:
          _patientDisplayName(patient) ?? _string(json['patient_display_name']),
      patientPhone:
          _string(patient?['primary_phone']) ??
          _string(patient?['phone']) ??
          _string(json['patient_primary_phone']),
      patientAgeSex: _string(json['patient_age_sex']),
      patientDateOfBirth: patientDateOfBirth,
      patientGender: patientGender,
      encounterType: _string(json['encounter_type']),
      status: _string(json['status']),
      currentLocation: _string(json['current_location']),
      providerUserId: _string(json['provider_user_id']),
      providerDisplayName:
          _providerDisplayName(provider) ??
          _string(json['provider_display_name']),
      startedAt: _date(json['started_at']),
      updatedAt: updatedAt,
      isUrgent: _isUrgentEncounter(json),
    );
  }
}

final class ClinicalAdmissionDto {
  const ClinicalAdmissionDto(this.json);

  final ClinicalJsonMap json;

  ClinicalWorklistEntry toWorklistEntry() {
    final ClinicalJsonMap? patient = _nullableMap(json['patient']);
    final ClinicalJsonMap? encounter = _nullableMap(json['encounter']);
    final ClinicalJsonMap? activeAssignment = _list(
      json['bed_assignments'],
    ).cast<ClinicalJsonMap?>().firstOrNull;
    final ClinicalJsonMap? bed = _nullableMap(activeAssignment?['bed']);
    final ClinicalJsonMap? ward = _nullableMap(bed?['ward']);
    final ClinicalJsonMap? room = _nullableMap(bed?['room']);
    final String? location = _joinDisplay(<String?>[
      _string(ward?['name']),
      _string(room?['name']),
      _string(bed?['label']),
    ]);

    return ClinicalWorklistEntry(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      sourceQueue: 'IPD',
      encounterId: _string(json['encounter_id']) ?? '',
      encounterPublicId:
          _string(json['encounter_human_friendly_id']) ??
          _string(encounter?['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      facilityId: _string(json['facility_id']),
      patientId: _string(json['patient_id']),
      patientPublicId:
          _string(json['patient_human_friendly_id']) ??
          _string(patient?['human_friendly_id']),
      patientDisplayName:
          _string(json['patient_display_name']) ?? _patientDisplayName(patient),
      patientPhone:
          _string(json['patient_primary_phone']) ??
          _string(patient?['primary_phone']) ??
          _string(patient?['phone']),
      patientAgeSex: _string(json['patient_age_sex']),
      patientDateOfBirth:
          _date(json['patient_date_of_birth']) ??
          _date(patient?['date_of_birth']),
      patientGender:
          _string(json['patient_gender']) ?? _string(patient?['gender']),
      encounterType:
          _string(json['encounter_type']) ??
          _string(encounter?['encounter_type']),
      status: _string(json['status']),
      stage: _string(json['status']),
      currentLocation: location,
      startedAt: _date(json['admitted_at']),
      updatedAt: _date(json['updated_at']) ?? _date(json['admitted_at']),
      admissionId: _string(json['id']),
      admissionPublicId: _string(json['human_friendly_id']),
    );
  }
}

final class ClinicalRelatedRecordDto {
  const ClinicalRelatedRecordDto(this.json, this.kind);

  final ClinicalJsonMap json;
  final String kind;

  ClinicalRelatedRecord toEntity() {
    if (kind == 'lab_order') {
      return _toLabOrderEntity();
    }
    if (kind == 'radiology_order') {
      return _toRadiologyOrderEntity();
    }

    return ClinicalRelatedRecord(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      kind: kind,
      status: _string(json['status']),
      title:
          _string(json['description']) ??
          _string(json['note']) ??
          _string(json['plan']) ??
          _string(json['reason']) ??
          _string(json['external_facility_name']) ??
          _string(json['name']) ??
          _string(json['title']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']),
      subtitle: _joinDisplay(<String?>[
        _string(json['diagnosis_type']),
        _string(json['code']),
        _string(json['external_facility_name']),
        _string(json['referral_reason_code']),
      ]),
      occurredAt:
          _date(json['recorded_at']) ??
          _date(json['performed_at']) ??
          _date(json['ordered_at']) ??
          _date(json['scheduled_at']) ??
          _date(json['admitted_at']) ??
          _date(json['start_date']) ??
          _date(json['created_at']) ??
          _date(json['updated_at']),
    );
  }

  ClinicalRelatedRecord _toLabOrderEntity() {
    final List<ClinicalLabOrderItem> items = _list(json['items'])
        .map(_labOrderItemFromJson)
        .where((ClinicalLabOrderItem item) => item.id.isNotEmpty)
        .toList(growable: false);
    final String? title = _joinDisplay(
      items.take(3).map((ClinicalLabOrderItem item) => item.displayTitle),
    );
    return ClinicalRelatedRecord(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      kind: kind,
      status: _string(json['status']),
      title:
          title ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      occurredAt:
          _date(json['ordered_at']) ??
          _date(json['created_at']) ??
          _date(json['updated_at']),
      labOrderItems: items,
      itemCount: _int(json['item_count']) == 0
          ? items.length
          : _int(json['item_count']),
      pendingItemCount: _int(json['pending_item_count']),
      inProcessItemCount: _int(json['in_process_item_count']),
      completedItemCount: _int(json['completed_item_count']),
      sampleCount: _int(json['sample_count']),
    );
  }

  ClinicalLabOrderItem _labOrderItemFromJson(ClinicalJsonMap json) {
    final String? labTestId = _string(json['lab_test_id']);
    final String? testDisplayName = _string(json['test_display_name']);
    final String? testCode = _string(json['test_code']);
    return ClinicalLabOrderItem(
      id:
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          _string(json['display_id']) ??
          _string(json['lab_order_item_id']) ??
          labTestId ??
          testCode ??
          testDisplayName ??
          '',
      status: _string(json['status']),
      resultStatus: _string(json['result_status']),
      labTestId: labTestId,
      testDisplayName: testDisplayName,
      testCode: testCode,
      category: _string(json['category']),
      specimenType: _string(json['specimen_type']),
      unit: _string(json['unit']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  ClinicalRelatedRecord _toRadiologyOrderEntity() {
    final List<ClinicalJsonMap> requestedTests = _list(json['requested_tests']);
    final String? requestedTitle = _joinDisplay(
      requestedTests
          .take(3)
          .map(
            (ClinicalJsonMap item) =>
                _string(item['radiology_test_display_name']) ??
                _string(item['test_display_name']) ??
                _string(item['radiology_test_id']),
          ),
    );

    return ClinicalRelatedRecord(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      kind: kind,
      status: _string(json['status']),
      title:
          requestedTitle ??
          _string(json['radiology_test_display_name']) ??
          _string(json['test_display_name']) ??
          _string(json['name']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']),
      subtitle: _joinDisplay(<String?>[
        _string(json['modality']),
        _string(json['clinical_note']),
      ]),
      occurredAt:
          _date(json['ordered_at']) ??
          _date(json['created_at']) ??
          _date(json['updated_at']),
      itemCount: requestedTests.isEmpty ? 1 : requestedTests.length,
    );
  }
}

final class ClinicalCatalogOptionDto {
  const ClinicalCatalogOptionDto(this.json);

  final ClinicalJsonMap json;

  ClinicalCatalogOption toEntity() {
    final List<ClinicalJsonMap> panelItems = _list(json['panel_items']);
    return ClinicalCatalogOption(
      id: _string(json['id']) ?? '',
      publicId: _string(json['human_friendly_id']),
      name:
          _string(json['name']) ??
          _string(json['description']) ??
          _string(json['label']) ??
          _string(json['value']),
      code: _string(json['code']),
      category:
          _string(json['category']) ??
          _string(json['modality']) ??
          _string(json['ward_type']),
      secondaryText:
          _string(json['specimen_type']) ??
          _joinDisplay(<String?>[
            _string(json['equipment']),
            _string(json['body_region']),
            _string(json['laterality']),
            _string(json['procedure_type']),
          ]) ??
          _string(json['form']) ??
          _string(json['strength']) ??
          _string(json['floor']),
      status: _string(json['status']),
      parentId:
          _string(json['ward_id']) ??
          _string(json['room_id']) ??
          _string(json['facility_id']),
      secondaryId: _string(json['room_id']),
      searchText: _joinDisplay(<String?>[
        _string(json['search_text']),
        _string(json['equipment']),
        _string(json['body_region']),
        _string(json['laterality']),
        _string(json['procedure_type']),
        _string(json['source']),
      ]),
      childIds: panelItems
          .map((ClinicalJsonMap item) => _string(item['lab_test_id']))
          .whereType<String>()
          .toList(growable: false),
      childCodes: panelItems
          .map((ClinicalJsonMap item) => _string(item['test_code']))
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

final class ClinicalTermOptionDto {
  const ClinicalTermOptionDto(this.json);

  final ClinicalJsonMap json;

  ClinicalCatalogOption toEntity() {
    return ClinicalCatalogOption(
      id:
          _string(json['id']) ??
          _string(json['code']) ??
          _string(json['description']) ??
          '',
      publicId: _string(json['human_friendly_id']),
      name:
          _string(json['description']) ??
          _string(json['term']) ??
          _string(json['name']),
      code: _string(json['code']),
      category: _string(json['term_type']),
      secondaryText: _string(json['source']),
    );
  }
}

ClinicalEncounterBundle decodeEncounterBundle(
  ClinicalWorklistEntry entry, {
  required Object? notes,
  required Object? diagnoses,
  required Object? procedures,
  required Object? carePlans,
  required Object? labOrders,
  required Object? radiologyOrders,
  required Object? pharmacyOrders,
  required Object? referrals,
  required Object? followUps,
  required Object? admissions,
}) {
  return ClinicalEncounterBundle(
    entry: entry,
    clinicalNotes: decodeRelatedRecords(notes, 'clinical_note'),
    diagnoses: decodeRelatedRecords(diagnoses, 'diagnosis'),
    procedures: decodeRelatedRecords(procedures, 'procedure'),
    carePlans: decodeRelatedRecords(carePlans, 'care_plan'),
    labOrders: decodeRelatedRecords(labOrders, 'lab_order'),
    radiologyOrders: decodeRelatedRecords(radiologyOrders, 'radiology_order'),
    pharmacyOrders: decodeRelatedRecords(pharmacyOrders, 'pharmacy_order'),
    referrals: decodeRelatedRecords(referrals, 'referral'),
    followUps: decodeRelatedRecords(followUps, 'follow_up'),
    admissions: decodeRelatedRecords(admissions, 'admission'),
  );
}

List<ClinicalRelatedRecord> decodeRelatedRecords(
  Object? responseData,
  String kind,
) {
  final ClinicalJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map((ClinicalJsonMap json) => ClinicalRelatedRecordDto(json, kind))
      .map((ClinicalRelatedRecordDto dto) => dto.toEntity())
      .where((ClinicalRelatedRecord item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<ClinicalCatalogOption> decodeCatalogOptions(Object? responseData) {
  final ClinicalJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(ClinicalCatalogOptionDto.new)
      .map((ClinicalCatalogOptionDto dto) => dto.toEntity())
      .where((ClinicalCatalogOption item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<ClinicalCatalogOption> decodeClinicalTermOptions(Object? responseData) {
  final ClinicalJsonMap response = _expectMap(responseData);
  final Object? data = response['data'];
  final List<ClinicalJsonMap> items = data is ClinicalJsonMap
      ? _list(data['suggestions'])
      : _list(data);
  return items
      .map(ClinicalTermOptionDto.new)
      .map((ClinicalTermOptionDto dto) => dto.toEntity())
      .where((ClinicalCatalogOption item) => item.id.isNotEmpty)
      .toList(growable: false);
}

ClinicalWorklistEntry decodeEncounter(Object? responseData) {
  final ClinicalJsonMap response = _expectMap(responseData);
  return ClinicalEncounterDto(_map(response['data'])).toWorklistEntry();
}

ClinicalJsonMap _expectMap(Object? value) {
  if (value is ClinicalJsonMap) {
    return value;
  }

  throw const FormatException('Expected response object.');
}

ClinicalJsonMap _map(Object? value) {
  return value is ClinicalJsonMap ? value : <String, Object?>{};
}

ClinicalJsonMap? _nullableMap(Object? value) {
  return value is ClinicalJsonMap ? value : null;
}

List<ClinicalJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <ClinicalJsonMap>[];
  }

  return value.whereType<ClinicalJsonMap>().toList(growable: false);
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

bool _isUrgentEncounter(ClinicalJsonMap json) {
  final String values = <String?>[
    _string(json['encounter_type']),
    _string(json['status']),
    _string(json['triage_level']),
    _string(json['priority']),
  ].whereType<String>().join(' ').toUpperCase();
  return values.contains('EMERGENCY') ||
      values.contains('URGENT') ||
      values.contains('CRITICAL');
}

String? _patientDisplayName(ClinicalJsonMap? patient) {
  if (patient == null) {
    return null;
  }

  return _joinDisplay(<String?>[
        _string(patient['first_name']),
        _string(patient['last_name']),
      ]) ??
      _string(patient['display_name']) ??
      _string(patient['human_friendly_id']);
}

String? _providerDisplayName(ClinicalJsonMap? provider) {
  if (provider == null) {
    return null;
  }

  final ClinicalJsonMap? profile = _nullableMap(provider['profile']);
  return _joinDisplay(<String?>[
        _string(profile?['first_name']),
        _string(profile?['middle_name']),
        _string(profile?['last_name']),
      ]) ??
      _string(provider['display_name']) ??
      _string(provider['email']) ??
      _string(provider['human_friendly_id']);
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}
