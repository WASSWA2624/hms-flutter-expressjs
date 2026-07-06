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
    if (kind == 'pharmacy_order') {
      return _toPharmacyOrderEntity();
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
    final List<ClinicalJsonMap> rawItems = _list(json['items']);
    final List<ClinicalJsonMap> requestedTests = _list(json['requested_tests']);
    final List<ClinicalJsonMap> itemRows = rawItems.isEmpty
        ? requestedTests
        : rawItems;
    final List<ClinicalLabOrderItem> items = itemRows
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
    final ClinicalJsonMap labTest = _map(json['lab_test']);
    final String? labTestId =
        _string(json['lab_test_id']) ??
        _string(labTest['human_friendly_id']) ??
        _string(labTest['id']);
    final String? testDisplayName =
        _string(json['test_display_name']) ??
        _string(json['lab_test_display_name']) ??
        _string(labTest['name']) ??
        _string(labTest['description']);
    final String? testCode =
        _string(json['test_code']) ?? _string(labTest['code']);
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
      category: _string(json['category']) ?? _string(labTest['category']),
      specimenType:
          _string(json['specimen_type']) ?? _string(labTest['specimen_type']),
      unit: _string(json['unit']) ?? _string(labTest['unit']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  ClinicalRelatedRecord _toRadiologyOrderEntity() {
    final List<ClinicalJsonMap> requestedTests = _list(json['requested_tests']);
    final List<ClinicalJsonMap> requestedItems = requestedTests.isEmpty
        ? <ClinicalJsonMap>[json]
        : requestedTests;
    final List<ClinicalRadiologyOrderItem> items = requestedItems
        .map(_radiologyOrderItemFromJson)
        .where((ClinicalRadiologyOrderItem item) => item.id.isNotEmpty)
        .toList(growable: false);
    final String? requestedTitle = _joinDisplay(
      items.take(3).map((ClinicalRadiologyOrderItem item) => item.displayTitle),
    );
    final ClinicalJsonMap requestDetails = _map(json['request_details']);

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
        _string(requestDetails['body_region']),
        _string(requestDetails['laterality']),
        _string(json['clinical_note']),
      ]),
      occurredAt:
          _date(json['ordered_at']) ??
          _date(json['created_at']) ??
          _date(json['updated_at']),
      radiologyOrderItems: items,
      itemCount: items.isEmpty ? 1 : items.length,
    );
  }

  ClinicalRadiologyOrderItem _radiologyOrderItemFromJson(ClinicalJsonMap item) {
    final ClinicalJsonMap parentRequestDetails = _map(json['request_details']);
    final ClinicalJsonMap itemRequestDetails = _map(item['request_details']);
    final ClinicalJsonMap radiologyTest = _map(item['radiology_test']);
    final String? radiologyTestId =
        _string(item['radiology_test_id']) ??
        _string(radiologyTest['human_friendly_id']) ??
        _string(radiologyTest['id']) ??
        _string(json['radiology_test_id']);
    final String? testDisplayName =
        _string(item['radiology_test_display_name']) ??
        _string(item['test_display_name']) ??
        _string(radiologyTest['name']) ??
        _string(radiologyTest['description']) ??
        _string(json['radiology_test_display_name']) ??
        _string(json['test_display_name']);
    final String? modality =
        _string(item['modality']) ??
        _string(itemRequestDetails['modality']) ??
        _string(radiologyTest['modality']) ??
        _string(json['modality']) ??
        _string(parentRequestDetails['modality']);
    return ClinicalRadiologyOrderItem(
      id:
          _string(item['human_friendly_id']) ??
          _string(item['display_id']) ??
          _string(item['id']) ??
          radiologyTestId ??
          testDisplayName ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      testDisplayName: testDisplayName,
      modality: modality,
      bodyRegion:
          _string(item['body_region']) ??
          _string(itemRequestDetails['body_region']) ??
          _string(radiologyTest['body_region']) ??
          _string(parentRequestDetails['body_region']),
      laterality:
          _string(item['laterality']) ??
          _string(itemRequestDetails['laterality']) ??
          _string(radiologyTest['laterality']) ??
          _string(parentRequestDetails['laterality']),
      priority:
          _string(item['priority']) ??
          _string(itemRequestDetails['priority']) ??
          _string(parentRequestDetails['priority']),
      clinicalNote:
          _string(item['clinical_note']) ??
          _string(itemRequestDetails['clinical_note']) ??
          _string(json['clinical_note']),
    );
  }

  ClinicalRelatedRecord _toPharmacyOrderEntity() {
    final List<ClinicalJsonMap> rawItems = _list(json['items']);
    final List<ClinicalJsonMap> orderItems = _list(json['order_items']);
    final List<ClinicalJsonMap> itemRows = rawItems.isEmpty
        ? orderItems
        : rawItems;
    final List<ClinicalPharmacyOrderItem> items = itemRows
        .map(_pharmacyOrderItemFromJson)
        .where((ClinicalPharmacyOrderItem item) => item.id.isNotEmpty)
        .toList(growable: false);
    final String? title = _joinDisplay(
      items.take(3).map((ClinicalPharmacyOrderItem item) => item.displayTitle),
    );

    return ClinicalRelatedRecord(
      id: _string(json['human_friendly_id']) ?? _string(json['id']) ?? '',
      kind: kind,
      status: _string(json['status']),
      title:
          title ??
          _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      subtitle: _joinDisplay(<String?>[
        _string(json['order_source']),
        _string(json['priority']),
      ]),
      occurredAt:
          _date(json['ordered_at']) ??
          _date(json['created_at']) ??
          _date(json['updated_at']),
      pharmacyOrderItems: items,
      itemCount: _int(json['item_count']) == 0
          ? items.length
          : _int(json['item_count']),
    );
  }

  ClinicalPharmacyOrderItem _pharmacyOrderItemFromJson(ClinicalJsonMap item) {
    final ClinicalJsonMap drug = _map(item['drug']);
    final String? drugDisplayName =
        _string(item['drug_display_name']) ??
        _string(item['medicine_name']) ??
        _string(item['drug_name']) ??
        _string(item['name']) ??
        _string(drug['name']) ??
        _string(drug['generic_name']);
    final String? drugId =
        _string(item['drug_id']) ??
        _string(drug['human_friendly_id']) ??
        _string(drug['id']);
    return ClinicalPharmacyOrderItem(
      id:
          _string(item['human_friendly_id']) ??
          _string(item['display_id']) ??
          _string(item['id']) ??
          drugId ??
          drugDisplayName ??
          '',
      status: _string(item['status']),
      drugId: drugId,
      drugDisplayName: drugDisplayName,
      customPrescription: _string(item['custom_prescription']),
      dosage: _string(item['dosage']),
      doseAmount: _string(item['dose_amount']),
      doseUnit: _string(item['dose_unit']),
      route: _string(item['route']),
      frequency: _string(item['frequency']),
      durationValue: _string(item['duration_value']),
      durationUnit: _string(item['duration_unit']),
      quantity: _string(item['quantity']),
      quantityUnit: _string(item['quantity_unit']),
      instructions: _string(item['instructions']),
      createdAt: _date(item['created_at']),
      updatedAt: _date(item['updated_at']),
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
      unitPrice: _num(json['unit_price']) ?? _num(json['price']),
      currency: _string(json['currency']),
      metadata: _withoutNullValues(<String, Object?>{
        'modality': _string(json['modality']),
        'body_region': _string(json['body_region']),
        'laterality': _string(json['laterality']),
        'equipment': _string(json['equipment']),
        'procedure_type': _string(json['procedure_type']),
        'ward_name': _string(_map(json['ward'])['name']),
        'room_name': _string(_map(json['room'])['name']),
        'unit_price': _num(json['unit_price']) ?? _num(json['price']),
        'currency': _string(json['currency']),
      }),
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
    final String? code = _string(json['code']);
    final String? description =
        _string(json['description']) ??
        _string(json['term']) ??
        _string(json['name']);
    final String? category =
        _string(json['category']) ?? _string(json['term_type']);
    final String? source = _string(json['source']) ?? _string(json['origin']);
    final ClinicalJsonMap metadataJson = _map(json['metadata']);
    return ClinicalCatalogOption(
      id:
          _string(json['item_id']) ??
          _string(json['id']) ??
          _joinDisplay(<String?>[code, description]) ??
          description ??
          code ??
          '',
      publicId: _string(json['human_friendly_id']) ?? _string(json['item_id']),
      name: _string(json['name']) ?? description,
      code: code,
      category: category,
      secondaryText: source,
      searchText: _joinDisplay(<String?>[
        _string(json['name']),
        description,
        code,
        category,
        source,
        _string(metadataJson['body_region']),
        _string(metadataJson['modality']),
        _string(metadataJson['laterality']),
      ]),
      unitPrice: _num(json['unit_price']) ?? _num(json['price']),
      currency: _string(json['currency']),
      metadata: _withoutNullValues(<String, Object?>{
        'source': source,
        'item_id': _string(json['item_id']),
        'term_type': _string(json['term_type']),
        'unit_price': _num(json['unit_price']) ?? _num(json['price']),
        'currency': _string(json['currency']),
        'modality': _string(metadataJson['modality']) ?? category,
        'body_region': _string(metadataJson['body_region']),
        'bodyRegion': _string(metadataJson['body_region']),
        'laterality': _string(metadataJson['laterality']),
        'priority': _string(metadataJson['priority']),
        'equipment': _string(metadataJson['equipment']),
        'procedure_type': _string(metadataJson['procedure_type']),
        if (metadataJson['specimen_type'] != null)
          'specimen_type': _string(metadataJson['specimen_type']),
      }),
    );
  }
}

ClinicalJsonMap _withoutNullValues(Map<String, Object?> json) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in json.entries)
      if (entry.value != null) entry.key: entry.value,
  };
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

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value.trim());
  }
  return null;
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
