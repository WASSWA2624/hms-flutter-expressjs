import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef TheaterJsonMap = Map<String, Object?>;

final class TheaterCasePageDto {
  const TheaterCasePageDto({required this.page});

  final AppPage<TheaterCase> page;

  factory TheaterCasePageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final TheaterJsonMap response = _expectMap(responseData);
    final List<TheaterCase> items = _list(response['data'])
        .map(TheaterCaseDto.new)
        .map((TheaterCaseDto dto) => dto.toEntity())
        .where((TheaterCase item) => item.id.isNotEmpty)
        .toList(growable: false);

    return TheaterCasePageDto(
      page: AppPage<TheaterCase>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class TheaterCaseDto {
  const TheaterCaseDto(this.json);

  final TheaterJsonMap json;

  factory TheaterCaseDto.fromResponse(Object? responseData) {
    final TheaterJsonMap response = _expectMap(responseData);
    return TheaterCaseDto(_map(response['data']));
  }

  TheaterCase toEntity() {
    final TheaterJsonMap checklistSummary = _map(json['checklist_summary']);
    final TheaterJsonMap flowSummary = _map(json['flow_summary']);
    final String id =
        _string(json['id']) ??
        _string(json['display_id']) ??
        _string(json['human_friendly_id']) ??
        '';

    return TheaterCase(
      id: id,
      displayId:
          _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['theatre_case_display_id']),
      scheduledAt: _date(json['scheduled_at']),
      startedAt: _date(json['started_at']),
      completedAt: _date(json['completed_at']),
      cancelledAt: _date(json['cancelled_at']),
      status: _string(json['status']) ?? _string(flowSummary['status']),
      workflowStage:
          _string(json['workflow_stage']) ?? _string(flowSummary['stage']),
      stageNotes: _string(json['stage_notes']),
      encounterDisplayId: _string(json['encounter_display_id']),
      patientDisplayId: _string(json['patient_display_id']),
      patientDisplayName: _string(json['patient_display_name']),
      roomDisplayId: _string(json['room_display_id']),
      roomDisplayLabel: _string(json['room_display_label']),
      surgeonUserDisplayId: _string(json['surgeon_user_display_id']),
      surgeonDisplayName: _string(json['surgeon_display_name']),
      anesthetistUserDisplayId: _string(json['anesthetist_user_display_id']),
      anesthetistDisplayName: _string(json['anesthetist_display_name']),
      anesthesiaRecordDisplayId: _string(json['anesthesia_record_display_id']),
      postOpNoteDisplayId: _string(json['post_op_note_display_id']),
      anesthesiaStatus:
          _string(json['anesthesia_status']) ??
          _string(flowSummary['anesthesia_status']),
      postOpStatus:
          _string(json['post_op_status']) ??
          _string(flowSummary['post_op_status']),
      checklistCompleted:
          _int(checklistSummary['completed']) ??
          _int(flowSummary['checklist_completed']) ??
          0,
      checklistTotal:
          _int(checklistSummary['total']) ??
          _int(flowSummary['checklist_total']) ??
          0,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      checklistItems: _list(json['checklist_items'])
          .map(TheaterChecklistItemDto.new)
          .map((TheaterChecklistItemDto dto) => dto.toEntity())
          .where((TheaterChecklistItem item) => item.id.isNotEmpty)
          .toList(growable: false),
      resourceAllocations: _list(json['resource_allocations'])
          .map(TheaterResourceAllocationDto.new)
          .map((TheaterResourceAllocationDto dto) => dto.toEntity())
          .where((TheaterResourceAllocation item) => item.id.isNotEmpty)
          .toList(growable: false),
      anesthesiaObservations: _list(json['anesthesia_observations'])
          .map(TheaterAnesthesiaObservationDto.new)
          .map((TheaterAnesthesiaObservationDto dto) => dto.toEntity())
          .where((TheaterAnesthesiaObservation item) => item.id.isNotEmpty)
          .toList(growable: false),
      anesthesiaRecords: _list(json['anesthesia_records'])
          .map(TheaterClinicalRecordDto.new)
          .map((TheaterClinicalRecordDto dto) => dto.toEntity())
          .where((TheaterClinicalRecord item) => item.id.isNotEmpty)
          .toList(growable: false),
      postOpNotes: _list(json['post_op_notes'])
          .map(TheaterClinicalRecordDto.new)
          .map((TheaterClinicalRecordDto dto) => dto.toEntity())
          .where((TheaterClinicalRecord item) => item.id.isNotEmpty)
          .toList(growable: false),
      timeline: _list(json['timeline'])
          .map(TheaterTimelineItemDto.new)
          .map((TheaterTimelineItemDto dto) => dto.toEntity())
          .where((TheaterTimelineItem item) => item.label.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class TheaterChecklistItemDto {
  const TheaterChecklistItemDto(this.json);

  final TheaterJsonMap json;

  TheaterChecklistItem toEntity() {
    return TheaterChecklistItem(
      id:
          _string(json['id']) ??
          _string(json['display_id']) ??
          _string(json['item_code']) ??
          '',
      phase: _string(json['phase']),
      itemCode: _string(json['item_code']),
      itemLabel: _string(json['item_label']),
      isChecked: _bool(json['is_checked']),
      checkedAt: _date(json['checked_at']),
      notes: _string(json['notes']),
    );
  }
}

final class TheaterResourceAllocationDto {
  const TheaterResourceAllocationDto(this.json);

  final TheaterJsonMap json;

  TheaterResourceAllocation toEntity() {
    return TheaterResourceAllocation(
      id:
          _string(json['id']) ??
          _string(json['display_id']) ??
          _string(json['resource_display_id']) ??
          '',
      resourceType: _string(json['resource_type']),
      resourceDisplayId: _string(json['resource_display_id']),
      resourceLabel: _string(json['resource_label']),
      assignedAt: _date(json['assigned_at']),
      releasedAt: _date(json['released_at']),
      notes: _string(json['notes']),
    );
  }
}

final class TheaterAnesthesiaObservationDto {
  const TheaterAnesthesiaObservationDto(this.json);

  final TheaterJsonMap json;

  TheaterAnesthesiaObservation toEntity() {
    return TheaterAnesthesiaObservation(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      observedAt: _date(json['observed_at']),
      observationType: _string(json['observation_type']),
      metricKey: _string(json['metric_key']),
      metricValue: _string(json['metric_value']),
      unit: _string(json['unit']),
      notes: _string(json['notes']),
    );
  }
}

final class TheaterClinicalRecordDto {
  const TheaterClinicalRecordDto(this.json);

  final TheaterJsonMap json;

  TheaterClinicalRecord toEntity() {
    return TheaterClinicalRecord(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      recordStatus: _string(json['record_status']),
      notes: _string(json['notes']) ?? _string(json['note']),
      anesthetistDisplayName: _string(json['anesthetist_display_name']),
      finalizedAt: _date(json['finalized_at']),
      reopenedAt: _date(json['reopened_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class TheaterTimelineItemDto {
  const TheaterTimelineItemDto(this.json);

  final TheaterJsonMap json;

  TheaterTimelineItem toEntity() {
    return TheaterTimelineItem(
      type: _string(json['type']) ?? '',
      label: _string(json['label']) ?? '',
      occurredAt: _date(json['at']) ?? _date(json['occurred_at']),
    );
  }
}

TheaterJsonMap _expectMap(Object? value) {
  if (value is TheaterJsonMap) {
    return value;
  }

  throw const FormatException('Expected theater response object.');
}

TheaterJsonMap _map(Object? value) {
  return value is TheaterJsonMap ? value : <String, Object?>{};
}

List<TheaterJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <TheaterJsonMap>[];
  }

  return value.whereType<TheaterJsonMap>().toList(growable: false);
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
