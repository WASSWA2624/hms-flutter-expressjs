import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef LabJsonMap = Map<String, Object?>;

final class LabWorkbenchDto {
  const LabWorkbenchDto({required this.bundle});

  final LabWorkbenchBundle bundle;

  factory LabWorkbenchDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final LabJsonMap response = _expectMap(responseData);
    final LabJsonMap data = _map(response['data']);
    final List<LabOrderSummary> items = _list(data['worklist'])
        .map(LabOrderSummaryDto.new)
        .map((LabOrderSummaryDto dto) => dto.toEntity())
        .where((LabOrderSummary item) => item.id.isNotEmpty)
        .toList(growable: false);

    return LabWorkbenchDto(
      bundle: LabWorkbenchBundle(
        summary: LabWorkbenchSummaryDto(_map(data['summary'])).toEntity(),
        worklist: AppPage<LabOrderSummary>(
          items: items,
          request: request,
          totalItemCount: _int(_map(data['pagination'])['total']),
        ),
      ),
    );
  }
}

final class LabWorkbenchSummaryDto {
  const LabWorkbenchSummaryDto(this.json);

  final LabJsonMap json;

  LabWorkbenchSummary toEntity() {
    return LabWorkbenchSummary(
      totalOrders: _int(json['total_orders']),
      collectionQueue: _int(json['collection_queue']),
      processingQueue: _int(json['processing_queue']),
      resultsQueue: _int(json['results_queue']),
      criticalResults: _int(json['critical_results']),
      completedOrders: _int(json['completed_orders']),
      cancelledOrders: _int(json['cancelled_orders']),
      rejectedSamples: _int(json['rejected_samples']),
    );
  }
}

final class LabCatalogItemDto {
  const LabCatalogItemDto(this.json, this.type);

  final LabJsonMap json;
  final LabCatalogItemType type;

  LabCatalogItem toEntity() {
    return LabCatalogItem(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      type: type,
      name: _string(json['name']),
      code: _string(json['code']),
      category: _string(json['category']),
      specimenType: _string(json['specimen_type']),
      resultKind: _string(json['result_kind']),
      unit: _string(json['unit']),
      description: _string(json['description']),
      referenceRange: _string(json['reference_range']),
      referenceRangeCount: _int(json['reference_range_count']),
      unitOptions: _list(json['unit_options'])
          .map(LabUnitOptionDto.new)
          .map((LabUnitOptionDto dto) => dto.toEntity())
          .where((LabUnitOption item) => item.id.isNotEmpty)
          .toList(growable: false),
      resultOptions: _list(json['result_options'])
          .map(LabResultOptionDto.new)
          .map((LabResultOptionDto dto) => dto.toEntity())
          .where((LabResultOption item) => item.id.isNotEmpty)
          .toList(growable: false),
      panelItems: _list(json['panel_items'])
          .map(LabPanelItemDto.new)
          .map((LabPanelItemDto dto) => dto.toEntity())
          .where((LabPanelItem item) => item.id.isNotEmpty)
          .toList(growable: false),
      testCount: _int(json['test_count']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class LabPanelItemDto {
  const LabPanelItemDto(this.json);

  final LabJsonMap json;

  LabPanelItem toEntity() {
    return LabPanelItem(
      id: _string(json['id']) ?? '',
      labTestId: _string(json['lab_test_id']),
      testDisplayName: _string(json['test_display_name']),
      testCode: _string(json['test_code']),
      unit: _string(json['unit']),
      instructions: _string(json['instructions']),
      isRequired: _bool(json['is_required'], fallback: true),
      sortOrder: _int(json['sort_order']),
    );
  }
}

final class LabUnitOptionDto {
  const LabUnitOptionDto(this.json);

  final LabJsonMap json;

  LabUnitOption toEntity() {
    return LabUnitOption(
      id: _string(json['id']) ?? '',
      label: _string(json['label']),
      unit: _string(json['unit']),
      ucumCode: _string(json['ucum_code']),
      isDefault: _bool(json['is_default']),
      sortOrder: _int(json['sort_order']),
    );
  }
}

final class LabResultOptionDto {
  const LabResultOptionDto(this.json);

  final LabJsonMap json;

  LabResultOption toEntity() {
    return LabResultOption(
      id: _string(json['id']) ?? '',
      value: _string(json['value']),
      label: _string(json['label']),
      status: _string(json['status']),
      resultFlag: _string(json['result_flag']),
      isPositive: _bool(json['is_positive']),
      sortOrder: _int(json['sort_order']),
    );
  }
}

final class LabOrderSummaryDto {
  const LabOrderSummaryDto(this.json);

  final LabJsonMap json;

  LabOrderSummary toEntity() {
    return LabOrderSummary(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      status: _string(json['status']),
      statusRank: _int(json['status_rank']),
      encounterId: _string(json['encounter_id']),
      patientId: _string(json['patient_id']),
      patientDisplayName: _string(json['patient_display_name']),
      orderedAt: _date(json['ordered_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      itemCount: _int(json['item_count']),
      pendingItemCount: _int(json['pending_item_count']),
      inProcessItemCount: _int(json['in_process_item_count']),
      completedItemCount: _int(json['completed_item_count']),
      sampleCount: _int(json['sample_count']),
      items: _list(json['items'])
          .map(LabOrderItemDto.new)
          .map((LabOrderItemDto dto) => dto.toEntity())
          .where((LabOrderItem item) => item.id.isNotEmpty)
          .toList(growable: false),
      samples: _list(json['samples'])
          .map(LabSampleDto.new)
          .map((LabSampleDto dto) => dto.toEntity())
          .where((LabSample item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class LabOrderItemDto {
  const LabOrderItemDto(this.json);

  final LabJsonMap json;

  LabOrderItem toEntity() {
    return LabOrderItem(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      status: _string(json['status']),
      resultStatus: _string(json['result_status']),
      labOrderId: _string(json['lab_order_id']),
      labTestId: _string(json['lab_test_id']),
      testDisplayName: _string(json['test_display_name']),
      testCode: _string(json['test_code']),
      unit: _string(json['unit']),
      unitOptions: _list(json['unit_options'])
          .map(LabUnitOptionDto.new)
          .map((LabUnitOptionDto dto) => dto.toEntity())
          .where((LabUnitOption item) => item.id.isNotEmpty)
          .toList(growable: false),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class LabSampleDto {
  const LabSampleDto(this.json);

  final LabJsonMap json;

  LabSample toEntity() {
    return LabSample(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      status: _string(json['status']),
      labOrderId: _string(json['lab_order_id']),
      patientId: _string(json['patient_id']),
      patientDisplayName: _string(json['patient_display_name']),
      collectedAt: _date(json['collected_at']),
      receivedAt: _date(json['received_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class LabResultDto {
  const LabResultDto(this.json);

  final LabJsonMap json;

  LabResult toEntity() {
    return LabResult(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      status: _string(json['status']),
      resultValue: _string(json['result_value']),
      resultUnit: _string(json['result_unit']),
      resultFlag: _string(json['result_flag']),
      isPositive: _bool(json['is_positive']),
      referenceRangeLabel: _string(json['reference_range_label']),
      referenceRangeSummary: _string(json['reference_range_summary']),
      resultText: _string(json['result_text']),
      reportedAt: _date(json['reported_at']),
      labOrderItemId: _string(json['lab_order_item_id']),
      labOrderId: _string(json['lab_order_id']),
      labTestId: _string(json['lab_test_id']),
      patientId: _string(json['patient_id']),
      patientDisplayName: _string(json['patient_display_name']),
      testDisplayName: _string(json['test_display_name']),
      testCode: _string(json['test_code']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class LabQcLogDto {
  const LabQcLogDto(this.json);

  final LabJsonMap json;

  LabQcLog toEntity() {
    return LabQcLog(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      displayId: _string(json['display_id']),
      status: _string(json['status']),
      notes: _string(json['notes']),
      labTestId: _string(json['lab_test_id']),
      testDisplayName: _string(json['test_display_name']),
      testCode: _string(json['test_code']),
      loggedAt: _date(json['logged_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class LabOrderWorkflowDto {
  const LabOrderWorkflowDto(this.json);

  final LabJsonMap json;

  factory LabOrderWorkflowDto.fromResponse(Object? responseData) {
    final LabJsonMap response = _expectMap(responseData);
    final LabJsonMap data = _map(response['data']);
    final LabJsonMap workflow = _map(data['workflow']);
    return LabOrderWorkflowDto(workflow.isEmpty ? data : workflow);
  }

  LabOrderWorkflow toEntity() {
    return LabOrderWorkflow(
      order: LabOrderSummaryDto(_map(json['order'])).toEntity(),
      results: _list(json['results'])
          .map(LabResultDto.new)
          .map((LabResultDto dto) => dto.toEntity())
          .where((LabResult item) => item.id.isNotEmpty)
          .toList(growable: false),
      timeline: _list(json['timeline'])
          .map(LabTimelineItemDto.new)
          .map((LabTimelineItemDto dto) => dto.toEntity())
          .where((LabWorkflowTimelineItem item) => item.id.isNotEmpty)
          .toList(growable: false),
      nextActions: LabWorkflowNextActionsDto(
        _map(json['next_actions']),
      ).toEntity(),
    );
  }
}

final class LabTimelineItemDto {
  const LabTimelineItemDto(this.json);

  final LabJsonMap json;

  LabWorkflowTimelineItem toEntity() {
    final String? id = _string(json['id']);
    final String? type = _string(json['type']);
    return LabWorkflowTimelineItem(
      id: id ?? type ?? '',
      type: type,
      label: _string(json['label']),
      occurredAt: _date(json['at']) ?? _date(json['occurred_at']),
    );
  }
}

final class LabWorkflowNextActionsDto {
  const LabWorkflowNextActionsDto(this.json);

  final LabJsonMap json;

  LabWorkflowNextActions toEntity() {
    return LabWorkflowNextActions(
      canCollect: _bool(json['can_collect']),
      canReceiveSample: _bool(json['can_receive_sample']),
      canReleaseResult: _bool(json['can_release_result']),
      canReverseWorkflow: _bool(json['can_reverse_workflow']),
    );
  }
}

List<LabCatalogItem> decodeLabTests(Object? responseData) {
  return _decodeCatalogItems(responseData, LabCatalogItemType.test);
}

List<LabCatalogItem> decodeLabPanels(Object? responseData) {
  return _decodeCatalogItems(responseData, LabCatalogItemType.panel);
}

List<LabCatalogItem> _decodeCatalogItems(
  Object? responseData,
  LabCatalogItemType type,
) {
  final LabJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map((LabJsonMap json) => LabCatalogItemDto(json, type))
      .map((LabCatalogItemDto dto) => dto.toEntity())
      .where((LabCatalogItem item) => item.id.isNotEmpty)
      .toList(growable: false);
}

List<LabQcLog> decodeLabQcLogs(Object? responseData) {
  final LabJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(LabQcLogDto.new)
      .map((LabQcLogDto dto) => dto.toEntity())
      .where((LabQcLog item) => item.id.isNotEmpty)
      .toList(growable: false);
}

LabJsonMap _expectMap(Object? value) {
  if (value is LabJsonMap) {
    return value;
  }

  throw const FormatException('Expected lab response object.');
}

LabJsonMap _map(Object? value) {
  return value is LabJsonMap ? value : <String, Object?>{};
}

List<LabJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <LabJsonMap>[];
  }

  return value.whereType<LabJsonMap>().toList(growable: false);
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

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
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
