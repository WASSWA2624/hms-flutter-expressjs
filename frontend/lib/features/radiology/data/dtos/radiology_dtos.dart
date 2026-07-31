import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef RadiologyJsonMap = Map<String, Object?>;

final class RadiologyWorkbenchDto {
  const RadiologyWorkbenchDto({required this.workbench});

  final RadiologyWorkbench workbench;

  factory RadiologyWorkbenchDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final RadiologyJsonMap response = _expectMap(responseData);
    final RadiologyJsonMap data = _map(response['data']);
    final List<RadiologyOrder> orders = _list(data['worklist'])
        .map(RadiologyOrderDto.new)
        .map((RadiologyOrderDto dto) => dto.toEntity())
        .where((RadiologyOrder item) => item.id.isNotEmpty)
        .toList(growable: false);
    final RadiologyJsonMap pagination = _map(data['pagination']);

    return RadiologyWorkbenchDto(
      workbench: RadiologyWorkbench(
        summary: RadiologySummaryDto(_map(data['summary'])).toEntity(),
        orders: AppPage<RadiologyOrder>(
          items: orders,
          request: request,
          totalItemCount: _int(pagination['total']),
        ),
      ),
    );
  }
}

final class RadiologyReferenceDataDto {
  const RadiologyReferenceDataDto(this.json);

  final RadiologyJsonMap json;

  factory RadiologyReferenceDataDto.fromResponse(Object? responseData) {
    final RadiologyJsonMap response = _expectMap(responseData);
    return RadiologyReferenceDataDto(_map(response['data']));
  }

  RadiologyReferenceData toEntity() {
    return RadiologyReferenceData(
      patients: _referenceList(json['patients']),
      encounters: _referenceList(json['encounters']),
      radiologyProcedures: _referenceList(json['radiology_tests']),
      assignees: _referenceList(json['assignees']),
    );
  }
}

final class RadiologyWorkflowDto {
  const RadiologyWorkflowDto(this.json);

  final RadiologyJsonMap json;

  factory RadiologyWorkflowDto.fromResponse(Object? responseData) {
    final RadiologyJsonMap response = _expectMap(responseData);
    final RadiologyJsonMap data = _map(response['data']);
    final RadiologyJsonMap workflow = _map(data['workflow']);

    if (workflow.isNotEmpty) {
      return RadiologyWorkflowDto(workflow);
    }

    return RadiologyWorkflowDto(data);
  }

  RadiologyWorkflow toEntity() {
    final RadiologyOrder order = RadiologyOrderDto(
      _map(json['order']),
    ).toEntity();
    final List<RadiologyResult> results = _list(json['results'])
        .map(RadiologyResultDto.new)
        .map((RadiologyResultDto dto) => dto.toEntity())
        .where((RadiologyResult item) => item.id.isNotEmpty)
        .toList(growable: false);
    final List<ImagingStudy> studies = _list(json['studies'])
        .map(ImagingStudyDto.new)
        .map((ImagingStudyDto dto) => dto.toEntity())
        .where((ImagingStudy item) => item.id.isNotEmpty)
        .toList(growable: false);

    return RadiologyWorkflow(
      order: order,
      results: results.isEmpty ? order.results : results,
      studies: studies.isEmpty ? order.imagingStudies : studies,
      timeline: _list(json['timeline'])
          .map(RadiologyTimelineItemDto.new)
          .map((RadiologyTimelineItemDto dto) => dto.toEntity())
          .where((RadiologyTimelineItem item) => item.id.isNotEmpty)
          .toList(growable: false),
      nextActions: RadiologyNextActionsDto(
        _map(json['next_actions']),
      ).toEntity(),
    );
  }
}

final class RadiologyCatalogProcedureDto {
  const RadiologyCatalogProcedureDto(this.json);

  final RadiologyJsonMap json;

  RadiologyCatalogProcedure toEntity() {
    final String id =
        _string(json['id']) ??
        _string(json['display_id']) ??
        _string(json['human_friendly_id']) ??
        '';
    return RadiologyCatalogProcedure(
      id: id,
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      name: _string(json['name']) ?? _string(json['code']) ?? id,
      code: _string(json['code']),
      modality: _string(json['modality']),
      bodyRegion: _string(json['body_region']) ?? _string(json['bodyRegion']),
      laterality: _string(json['laterality']),
      procedureType: _string(json['procedure_type']),
      equipment: _string(json['equipment']),
      status: _string(json['status']),
      source: _string(json['source']),
      searchText: _string(json['search_text']),
      unitPrice: _num(json['unit_price']) ?? _num(json['price']),
      currency: _string(json['currency']),
      isOfferedAtFacility:
          json['is_offered_at_facility'] == true ||
          json['offering_is_active'] == true,
      facilityOfferingId: _string(json['facility_offering_id']),
      tenantId: _string(json['tenant_id']) ??
          _string(_map(json['tenant'])['id']),
      tenantName: _string(json['tenant_name']) ??
          _string(_map(json['tenant'])['name']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      deletedAt: _date(json['deleted_at']),
    );
  }

  static List<RadiologyCatalogProcedure> listFromResponse(Object? responseData) {
    return _entityRows(responseData)
        .map(RadiologyCatalogProcedureDto.new)
        .map((RadiologyCatalogProcedureDto dto) => dto.toEntity())
        .where((RadiologyCatalogProcedure item) => item.id.isNotEmpty)
        .toList(growable: false);
  }
}

final class RadiologyEquipmentRecordDto {
  const RadiologyEquipmentRecordDto(this.json);

  final RadiologyJsonMap json;

  RadiologyEquipmentRecord toEntity() {
    final RadiologyJsonMap category = _map(json['equipment_category']);
    final String id =
        _string(json['id']) ??
        _string(json['display_id']) ??
        _string(json['human_friendly_id']) ??
        '';
    return RadiologyEquipmentRecord(
      id: id,
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      equipmentName:
          _string(json['equipment_name']) ??
          _string(json['name']) ??
          _string(json['equipment_code']) ??
          id,
      equipmentCode: _string(json['equipment_code']),
      serialNumber: _string(json['serial_number']),
      manufacturer: _string(json['manufacturer']),
      modelNumber: _string(json['model_number']),
      status: _string(json['status']),
      facilityId: _string(json['facility_id']),
      categoryId: _string(json['equipment_category_id']),
      categoryName:
          _string(category['name']) ?? _string(category['category_name']),
    );
  }

  static List<RadiologyEquipmentRecord> listFromResponse(Object? responseData) {
    return _entityRows(responseData)
        .map(RadiologyEquipmentRecordDto.new)
        .map((RadiologyEquipmentRecordDto dto) => dto.toEntity())
        .where((RadiologyEquipmentRecord item) => item.id.isNotEmpty)
        .toList(growable: false);
  }
}

RadiologyCatalogProcedure radiologyCatalogProcedureFromResponse(Object? responseData) {
  final RadiologyJsonMap response = _expectMap(responseData);
  final Object? data = response['data'];
  final RadiologyJsonMap row = data is RadiologyJsonMap ? data : response;
  return RadiologyCatalogProcedureDto(row).toEntity();
}

final class RadiologySummaryDto {
  const RadiologySummaryDto(this.json);

  final RadiologyJsonMap json;

  RadiologySummary toEntity() {
    return RadiologySummary(
      totalOrders: _int(json['total_orders']) ?? 0,
      orderedQueue: _int(json['ordered_queue']) ?? 0,
      processingQueue: _int(json['processing_queue']) ?? 0,
      draftReports: _int(json['draft_reports']) ?? 0,
      finalizedReports: _int(json['finalized_reports']) ?? 0,
      amendedReports: _int(json['amended_reports']) ?? 0,
      completedOrders: _int(json['completed_orders']) ?? 0,
      cancelledOrders: _int(json['cancelled_orders']) ?? 0,
      studiesTotal: _int(json['studies_total']) ?? 0,
      unsyncedStudies: _int(json['unsynced_studies']) ?? 0,
      actionableOrders: _int(json['actionable_orders']) ?? 0,
      reportingOrders: _int(json['reporting_orders']) ?? 0,
      historyOrders: _int(json['history_orders']) ?? 0,
      totalPatients: _int(json['total_patients']) ?? 0,
      actionablePatients: _int(json['actionable_patients']) ?? 0,
      orderedPatients: _int(json['ordered_patients']) ?? 0,
      processingPatients: _int(json['processing_patients']) ?? 0,
      reportingPatients: _int(json['reporting_patients']) ?? 0,
      releasedPatients: _int(json['released_patients']) ?? 0,
      completedPatients: _int(json['completed_patients']) ?? 0,
      cancelledPatients: _int(json['cancelled_patients']) ?? 0,
    );
  }
}

final class RadiologyOrderDto {
  const RadiologyOrderDto(this.json);

  final RadiologyJsonMap json;

  RadiologyOrder toEntity() {
    final String id = _string(json['id']) ?? _string(json['display_id']) ?? '';

    return RadiologyOrder(
      id: id,
      displayId: _string(json['display_id']) ?? _string(json['order_number']),
      status: _string(json['status']),
      encounterId: _string(json['encounter_id']),
      patientId: _string(json['patient_id']),
      patientDisplayName: _string(json['patient_display_name']),
      radiologyTestId: _string(json['radiology_test_id']),
      testDisplayName:
          _string(json['test_display_name']) ??
          _string(json['radiology_test_display_name']),
      modality: _string(json['modality']),
      clinicalNote: _string(json['clinical_note']) ?? _string(json['notes']),
      paymentStatus:
          _string(json['payment_status']) ??
          _string(_map(json['billing'])['payment_status']) ??
          _string(
            _map(_map(json['request_details'])['billing'])['payment_status'],
          ),
      authorizationStatus:
          _string(json['authorization_status']) ??
          _string(_map(json['billing'])['authorization_status']),
      assignedUserId: _string(json['assigned_user_id']),
      assignedUserDisplayName: _string(json['assigned_user_display_name']),
      scheduledAt: _date(json['scheduled_at']),
      room: _string(json['room']),
      equipmentRegistryId: _string(json['equipment_registry_id']),
      equipmentDisplayName: _string(json['equipment_display_name']),
      billingGateBlocked: _bool(json['billing_gate_blocked']),
      requestDetails: _map(json['request_details']),
      requestedTests: _list(json['requested_tests'])
          .map(RadiologyRequestedTestDto.new)
          .map((RadiologyRequestedTestDto dto) => dto.toEntity())
          .toList(growable: false),
      orderedAt: _date(json['ordered_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      resultCount: _int(json['result_count']) ?? 0,
      draftResultCount: _int(json['draft_result_count']) ?? 0,
      finalResultCount: _int(json['final_result_count']) ?? 0,
      amendedResultCount: _int(json['amended_result_count']) ?? 0,
      studyCount: _int(json['study_count']) ?? 0,
      unsyncedStudyCount: _int(json['unsynced_study_count']) ?? 0,
      isPatientGroup: _bool(json['patient_worklist']),
      activeOrderCount: _int(json['active_order_count']) ?? 0,
      orderCount: _int(json['order_count']) ?? 1,
      orderIds: _stringList(json['order_ids']),
      orderDisplayIds: _stringList(json['order_display_ids']),
      testsSummary: _string(json['tests_summary']),
      results: _list(json['results'])
          .map(RadiologyResultDto.new)
          .map((RadiologyResultDto dto) => dto.toEntity())
          .where((RadiologyResult item) => item.id.isNotEmpty)
          .toList(growable: false),
      imagingStudies: _list(json['imaging_studies'])
          .map(ImagingStudyDto.new)
          .map((ImagingStudyDto dto) => dto.toEntity())
          .where((ImagingStudy item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class RadiologyRequestedTestDto {
  const RadiologyRequestedTestDto(this.json);

  final RadiologyJsonMap json;

  RadiologyRequestedTest toEntity() {
    return RadiologyRequestedTest(
      radiologyTestId: _string(json['radiology_test_id']),
      testDisplayName:
          _string(json['test_display_name']) ??
          _string(json['radiology_test_display_name']),
      modality: _string(json['modality']),
      bodyRegion: _string(json['body_region']),
      laterality: _string(json['laterality']),
      priority: _string(json['priority']),
    );
  }
}

final class RadiologyResultDto {
  const RadiologyResultDto(this.json);

  final RadiologyJsonMap json;

  RadiologyResult toEntity() {
    final String id = _string(json['id']) ?? _string(json['display_id']) ?? '';

    return RadiologyResult(
      id: id,
      displayId: _string(json['display_id']),
      radiologyOrderId: _string(json['radiology_order_id']),
      parentResultId: _string(json['parent_result_id']),
      patientId: _string(json['patient_id']),
      patientDisplayName: _string(json['patient_display_name']),
      radiologyTestId: _string(json['radiology_test_id']),
      testDisplayName: _string(json['test_display_name']),
      modality: _string(json['modality']),
      status: _string(json['status']),
      reportText: _string(json['report_text']),
      addendumText: _string(json['addendum_text']),
      reportVersion: _int(json['report_version']) ?? 1,
      finalization: RadiologyResultFinalizationDto(
        _map(json['finalization']),
      ).toEntity(),
      attestations: _list(json['attestations'])
          .map(RadiologyResultAttestationDto.new)
          .map((RadiologyResultAttestationDto dto) => dto.toEntity())
          .where((RadiologyResultAttestation item) => item.id.isNotEmpty)
          .toList(growable: false),
      reportedAt: _date(json['reported_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class RadiologyResultFinalizationDto {
  const RadiologyResultFinalizationDto(this.json);

  final RadiologyJsonMap json;

  RadiologyResultFinalization toEntity() {
    return RadiologyResultFinalization(
      requested: _bool(json['requested']),
      requestedAt: _date(json['requested_at']),
      requestedByRole: _string(json['requested_by_role']),
      attested: _bool(json['attested']),
      attestedAt: _date(json['attested_at']),
      attestedByRole: _string(json['attested_by_role']),
      pendingAttestation: _bool(json['pending_attestation']),
    );
  }
}

final class RadiologyResultAttestationDto {
  const RadiologyResultAttestationDto(this.json);

  final RadiologyJsonMap json;

  RadiologyResultAttestation toEntity() {
    final String id = _string(json['id']) ?? _string(json['display_id']) ?? '';

    return RadiologyResultAttestation(
      id: id,
      displayId: _string(json['display_id']),
      radiologyResultId: _string(json['radiology_result_id']),
      phase: _string(json['phase']),
      attestedByUserId: _string(json['attested_by_user_id']),
      attestedRole: _string(json['attested_role']),
      statement: _string(json['statement']),
      reason: _string(json['reason']),
      attestedAt: _date(json['attested_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class ImagingStudyDto {
  const ImagingStudyDto(this.json);

  final RadiologyJsonMap json;

  ImagingStudy toEntity() {
    final String id = _string(json['id']) ?? _string(json['display_id']) ?? '';

    return ImagingStudy(
      id: id,
      displayId: _string(json['display_id']),
      radiologyOrderId: _string(json['radiology_order_id']),
      modality: _string(json['modality']),
      room: _string(json['room']),
      equipmentRegistryId: _string(json['equipment_registry_id']),
      equipmentDisplayName: _string(json['equipment_display_name']),
      performedAt: _date(json['performed_at']),
      startedAt: _date(json['started_at']),
      completedAt: _date(json['completed_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      assetCount: _int(json['asset_count']) ?? 0,
      pacsLinkCount: _int(json['pacs_link_count']) ?? 0,
      lastPacsUrl: _string(json['last_pacs_url']),
      assets: _list(json['assets'])
          .map(ImagingAssetDto.new)
          .map((ImagingAssetDto dto) => dto.toEntity())
          .where((ImagingAsset item) => item.id.isNotEmpty)
          .toList(growable: false),
      pacsLinks: _list(json['pacs_links'])
          .map(PacsLinkDto.new)
          .map((PacsLinkDto dto) => dto.toEntity())
          .where((PacsLink item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class ImagingAssetDto {
  const ImagingAssetDto(this.json);

  final RadiologyJsonMap json;

  ImagingAsset toEntity() {
    final String id = _string(json['id']) ?? _string(json['display_id']) ?? '';

    return ImagingAsset(
      id: id,
      displayId: _string(json['display_id']),
      imagingStudyId: _string(json['imaging_study_id']),
      storageKey: _string(json['storage_key']),
      fileName: _string(json['file_name']),
      contentType: _string(json['content_type']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class PacsLinkDto {
  const PacsLinkDto(this.json);

  final RadiologyJsonMap json;

  PacsLink toEntity() {
    final String id = _string(json['id']) ?? _string(json['display_id']) ?? '';

    return PacsLink(
      id: id,
      displayId: _string(json['display_id']),
      imagingStudyId: _string(json['imaging_study_id']),
      url: _string(json['url']),
      expiresAt: _date(json['expires_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class RadiologyNextActionsDto {
  const RadiologyNextActionsDto(this.json);

  final RadiologyJsonMap json;

  RadiologyNextActions toEntity() {
    return RadiologyNextActions(
      canAssign: _bool(json['can_assign']),
      canStart: _bool(json['can_start']),
      canComplete: _bool(json['can_complete']),
      canCancel: _bool(json['can_cancel']),
      canCreateStudy: _bool(json['can_create_study']),
      canCreateDraftResult: _bool(json['can_create_draft_result']),
      canFinalizeResult: _bool(json['can_finalize_result']),
      canRequestFinalization: _bool(json['can_request_finalization']),
      canAttestFinalization: _bool(json['can_attest_finalization']),
      canAddAddendum: _bool(json['can_add_addendum']),
      canPacsSync: _bool(json['can_pacs_sync']),
      billingGateBlocked: _bool(json['billing_gate_blocked']),
      hasAssignment: _bool(json['has_assignment']),
    );
  }
}

final class RadiologyTimelineItemDto {
  const RadiologyTimelineItemDto(this.json);

  final RadiologyJsonMap json;

  RadiologyTimelineItem toEntity() {
    final String id =
        _string(json['id']) ??
        _string(json['type']) ??
        _string(json['label']) ??
        '';

    return RadiologyTimelineItem(
      id: id,
      type: _string(json['type']) ?? '',
      label: _string(json['label']) ?? '',
      occurredAt: _date(json['at']) ?? _date(json['occurred_at']),
    );
  }
}

List<RadiologyReferenceOption> _referenceList(Object? value) {
  return _list(value)
      .map(RadiologyReferenceOptionDto.new)
      .map((RadiologyReferenceOptionDto dto) => dto.toEntity())
      .where((RadiologyReferenceOption item) => item.value.isNotEmpty)
      .toList(growable: false);
}

final class RadiologyReferenceOptionDto {
  const RadiologyReferenceOptionDto(this.json);

  final RadiologyJsonMap json;

  RadiologyReferenceOption toEntity() {
    return RadiologyReferenceOption(
      value: _string(json['value']) ?? '',
      label: _string(json['label']) ?? _string(json['value']) ?? '',
      subtitle: _string(json['subtitle']),
      patientId: _string(json['patient_id']),
    );
  }
}

List<RadiologyJsonMap> _entityRows(Object? responseData) {
  final RadiologyJsonMap response = _expectMap(responseData);
  final Object? data = response['data'];
  if (data is List) {
    return data.whereType<RadiologyJsonMap>().toList(growable: false);
  }
  if (data is RadiologyJsonMap) {
    for (final String key in <String>[
      'items',
      'data',
      'rows',
      'results',
      'radiologyProcedures',
      'radiology_procedures',
      'radiologyTests',
      'radiology_tests',
      'equipmentRegistries',
      'equipment_registries',
    ]) {
      final Object? value = data[key];
      if (value is List) {
        return value.whereType<RadiologyJsonMap>().toList(growable: false);
      }
    }
  }
  return const <RadiologyJsonMap>[];
}

RadiologyJsonMap _expectMap(Object? value) {
  if (value is RadiologyJsonMap) {
    return value;
  }

  throw const FormatException('Expected radiology response object.');
}

RadiologyJsonMap _map(Object? value) {
  return value is RadiologyJsonMap ? value : <String, Object?>{};
}

List<RadiologyJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <RadiologyJsonMap>[];
  }

  return value.whereType<RadiologyJsonMap>().toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }

  return value
      .map(_string)
      .whereType<String>()
      .where((String item) => item.trim().isNotEmpty)
      .toList(growable: false);
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
  if (value is num) {
    return value != 0;
  }
  return fallback;
}

int? _int(Object? value) {
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

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}
