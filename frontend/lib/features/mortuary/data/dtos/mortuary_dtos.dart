import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef MortuaryJsonMap = Map<String, Object?>;

final class MortuaryWorkspacePayloadDto {
  const MortuaryWorkspacePayloadDto({required this.payload});

  final MortuaryWorkspacePayload payload;

  factory MortuaryWorkspacePayloadDto.fromResponse(
    Object? responseData,
    MortuaryWorkspaceQuery requestQuery,
  ) {
    final MortuaryJsonMap response = _expectMap(responseData);
    final MortuaryJsonMap data = _map(response['data']);
    final MortuaryJsonMap pagination = _map(data['pagination']);
    final MortuaryWorkspaceQuery? filters = _filters(data['filters']);
    final AppPageRequest request = requestQuery.pageRequest;
    final List<MortuaryWorkspaceItem> items = _list(data['items'])
        .map(MortuaryWorkspaceItemDto.new)
        .map((MortuaryWorkspaceItemDto dto) => dto.toEntity())
        .where((MortuaryWorkspaceItem item) => item.id.isNotEmpty)
        .toList(growable: false);

    return MortuaryWorkspacePayloadDto(
      payload: MortuaryWorkspacePayload(
        items: AppPage<MortuaryWorkspaceItem>(
          items: items,
          request: request,
          totalItemCount: _int(pagination['total']),
        ),
        summary: _list(data['summary'])
            .map(MortuarySummaryItemDto.new)
            .map((MortuarySummaryItemDto dto) => dto.toEntity())
            .where((MortuarySummaryItem item) => item.id.isNotEmpty)
            .toList(growable: false),
        queues: _list(data['queue_summaries'])
            .map(MortuaryQueueSummaryDto.new)
            .map((MortuaryQueueSummaryDto dto) => dto.toEntity())
            .where((MortuaryQueueSummary item) => item.queue.isNotEmpty)
            .toList(growable: false),
        panels: _list(data['panel_summaries'])
            .map(MortuaryPanelSummaryDto.new)
            .map((MortuaryPanelSummaryDto dto) => dto.toEntity())
            .where((MortuaryPanelSummary item) => item.id.isNotEmpty)
            .toList(growable: false),
        spotlight: _list(data['spotlight'])
            .map(MortuaryQueueSummaryDto.new)
            .map((MortuaryQueueSummaryDto dto) => dto.toEntity())
            .where((MortuaryQueueSummary item) => item.queue.isNotEmpty)
            .toList(growable: false),
        lookups: MortuaryLookupDataDto(_map(data['lookups'])).toEntity(),
        filters: filters,
        lastUpdatedAt: _date(data['last_updated_at']),
      ),
    );
  }
}

final class MortuaryLookupDataDto {
  const MortuaryLookupDataDto(this.json);

  final MortuaryJsonMap json;

  factory MortuaryLookupDataDto.fromResponse(Object? responseData) {
    final MortuaryJsonMap response = _expectMap(responseData);
    return MortuaryLookupDataDto(_map(response['data']));
  }

  MortuaryLookupData toEntity() {
    return MortuaryLookupData(
      facilities: _options(json['facilities']),
      storageUnits: _options(json['storage_units']),
      storageSlots: _options(json['storage_slots']),
      deceasedProfiles: _options(json['deceased_profiles']),
      patients: _options(json['patients']),
      sourceWorkflows: _options(json['source_workflows']),
      statuses: _options(json['statuses']),
      identificationStatuses: _options(json['identification_statuses']),
      storageSlotStatuses: _options(json['storage_slot_statuses']),
      postMortemStatuses: _options(json['post_mortem_statuses']),
      releaseStatuses: _options(json['release_statuses']),
      queues: _options(json['queues']),
    );
  }

  List<MortuaryLookupOption> _options(Object? value) {
    return _list(value)
        .map(MortuaryLookupOptionDto.new)
        .map((MortuaryLookupOptionDto dto) => dto.toEntity())
        .where((MortuaryLookupOption item) => item.hasValue)
        .toList(growable: false);
  }
}

final class MortuaryLookupOptionDto {
  const MortuaryLookupOptionDto(this.json);

  final MortuaryJsonMap json;

  MortuaryLookupOption toEntity() {
    return MortuaryLookupOption(
      id: _string(json['id']) ?? '',
      label: _string(json['label']) ?? '',
      subtitle: _string(json['subtitle']),
      meta: _map(json['meta']),
    );
  }
}

final class MortuarySummaryItemDto {
  const MortuarySummaryItemDto(this.json);

  final MortuaryJsonMap json;

  MortuarySummaryItem toEntity() {
    return MortuarySummaryItem(
      id: _string(json['id']) ?? '',
      value: _int(json['value']) ?? 0,
      labelKey: _string(json['label_key']),
    );
  }
}

final class MortuaryQueueSummaryDto {
  const MortuaryQueueSummaryDto(this.json);

  final MortuaryJsonMap json;

  MortuaryQueueSummary toEntity() {
    return MortuaryQueueSummary(
      queue: _string(json['queue']) ?? _string(json['id']) ?? '',
      count: _int(json['count']) ?? 0,
      labelKey: _string(json['label_key']),
      panel: _string(json['panel']),
      resource: _string(json['resource']),
      targetPath: _string(json['target_path']),
    );
  }
}

final class MortuaryPanelSummaryDto {
  const MortuaryPanelSummaryDto(this.json);

  final MortuaryJsonMap json;

  MortuaryPanelSummary toEntity() {
    return MortuaryPanelSummary(
      id: _string(json['id']) ?? '',
      count: _int(json['count']) ?? 0,
      labelKey: _string(json['label_key']),
      defaultResource: _string(json['default_resource']),
      targetPath: _string(json['target_path']),
    );
  }
}

final class MortuaryWorkspaceItemDto {
  const MortuaryWorkspaceItemDto(this.json);

  final MortuaryJsonMap json;

  MortuaryWorkspaceItem toEntity() {
    final String resource = _string(json['resource']) ?? mortuaryResourceCases;
    final String id =
        _string(json['id']) ??
        _string(json['human_friendly_id']) ??
        _string(json['slot_code']) ??
        '';
    final MortuaryStorageAssignment? activeStorageAssignment =
        _storageAssignment(json['active_storage_assignment']) ??
        (resource == mortuaryResourceStorageAssignments
            ? MortuaryStorageAssignmentDto(json).toEntity()
            : null);

    return MortuaryWorkspaceItem(
      id: id,
      displayId: _string(json['human_friendly_id']) ?? _string(json['display_id']),
      resource: resource,
      title: _string(json['title']),
      subtitle: _string(json['subtitle']),
      status: _string(json['status']),
      identificationStatus: _string(json['identification_status']),
      billingStatus: _string(json['billing_status']),
      billingReferenceId: _string(json['billing_reference_id']),
      releaseStatus: _string(json['release_status']),
      facilityId: _string(json['facility_id']),
      facilityLabel: _string(json['facility_label']),
      patientId: _string(json['patient_id']),
      patientLabel: _string(json['patient_label']),
      deceasedProfileId: _string(json['deceased_profile_id']),
      deceasedProfileLabel: _string(json['deceased_profile_label']),
      sourceWorkflow: _string(json['source_workflow']),
      sourceDepartment: _string(json['source_department']),
      sourceReferenceId: _string(json['source_reference_id']),
      receivedFrom: _string(json['received_from']),
      receivedAt: _date(json['received_at']),
      releaseReadyAt: _date(json['release_ready_at']),
      releasedAt: _date(json['released_at']),
      closedAt: _date(json['closed_at']),
      storageUnitId: _string(json['storage_unit_id']),
      storageUnitLabel: _string(json['storage_unit_label']),
      storageSlotId: _string(json['storage_slot_id']),
      storageSlotLabel: _string(json['storage_slot_label']),
      storageSlotStatus: _string(json['storage_slot_status']),
      storageAssignment: activeStorageAssignment,
      mortuaryCase: _caseSummary(json['mortuary_case']),
      unitType: _string(json['unit_type']),
      capacity: _int(json['capacity']),
      slotCount: _int(json['slot_count']),
      assignmentCount: _int(json['assignment_count']),
      slotCode: _string(json['slot_code']),
      temperatureZone: _string(json['temperature_zone']),
      isActive: _nullableBool(json['is_active']),
      eventType: _string(json['event_type']),
      eventAt: _date(json['event_at']) ?? _date(json['occurred_at']),
      actorName: _string(json['actor_name']),
      actorRole: _string(json['actor_role']),
      locationLabel: _string(json['location_label']),
      reason: _string(json['reason']),
      notes: _string(json['notes']),
      scheduledAt: _date(json['scheduled_at']),
      authorisedByName: _string(json['authorised_by_name']),
      attendeeSummary: _string(json['attendee_summary']),
      completedAt: _date(json['completed_at']),
      requestedByName: _string(json['requested_by_name']),
      requestReason: _string(json['request_reason']),
      diagnosticsReferenceId: _string(json['diagnostics_reference_id']),
      reportReceivedAt: _date(json['report_received_at']),
      recipientName: _string(json['recipient_name']),
      recipientRelationship: _string(json['recipient_relationship']),
      verificationReference: _string(json['verification_reference']),
      funeralServiceName: _string(json['funeral_service_name']),
      releaseMethod: _string(json['release_method']),
      approvedByName: _string(json['approved_by_name']),
      approvedAt: _date(json['approved_at']),
      description: _string(json['description']),
      amountText: _string(json['amount']),
      currency: _string(json['currency']),
      chargedAt: _date(json['charged_at']),
      settledAt: _date(json['settled_at']),
      custodyEvents: _list(json['custody_events'])
          .map(MortuaryTimelineEventDto.new)
          .map((MortuaryTimelineEventDto dto) => dto.toEntity())
          .where((MortuaryTimelineEvent item) => item.id.isNotEmpty)
          .toList(growable: false),
      viewings: _list(json['viewings'])
          .map(MortuaryViewingDto.new)
          .map((MortuaryViewingDto dto) => dto.toEntity())
          .where((MortuaryViewing item) => item.id.isNotEmpty)
          .toList(growable: false),
      postMortemRequests: _list(json['post_mortem_requests'])
          .map(MortuaryPostMortemRequestDto.new)
          .map((MortuaryPostMortemRequestDto dto) => dto.toEntity())
          .where((MortuaryPostMortemRequest item) => item.id.isNotEmpty)
          .toList(growable: false),
      releaseAuthorisations: _list(json['release_authorisations'])
          .map(MortuaryReleaseAuthorisationDto.new)
          .map((MortuaryReleaseAuthorisationDto dto) => dto.toEntity())
          .where((MortuaryReleaseAuthorisation item) => item.id.isNotEmpty)
          .toList(growable: false),
      billableEvents: _list(json['billable_events'])
          .map(MortuaryBillableEventDto.new)
          .map((MortuaryBillableEventDto dto) => dto.toEntity())
          .where((MortuaryBillableEvent item) => item.id.isNotEmpty)
          .toList(growable: false),
      targetPath: _string(json['target_path']),
      timelineAt: _date(json['timeline_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class MortuaryCaseSummaryDto {
  const MortuaryCaseSummaryDto(this.json);

  final MortuaryJsonMap json;

  MortuaryCaseSummary toEntity() {
    return MortuaryCaseSummary(
      id: _string(json['id']) ?? _string(json['human_friendly_id']),
      status: _string(json['status']),
      identificationStatus: _string(json['identification_status']),
      receivedAt: _date(json['received_at']),
      releaseReadyAt: _date(json['release_ready_at']),
      releasedAt: _date(json['released_at']),
      billingStatus: _string(json['billing_status']),
      deceasedProfileId: _string(json['deceased_profile_id']),
      deceasedProfileLabel: _string(json['deceased_profile_label']),
    );
  }
}

final class MortuaryStorageAssignmentDto {
  const MortuaryStorageAssignmentDto(this.json);

  final MortuaryJsonMap json;

  MortuaryStorageAssignment toEntity() {
    return MortuaryStorageAssignment(
      id: _string(json['id']) ?? _string(json['human_friendly_id']),
      status: _string(json['assignment_status']) ?? _string(json['status']),
      assignedAt: _date(json['assigned_at']),
      endedAt: _date(json['ended_at']),
      reason: _string(json['reason']),
      storageUnitId: _string(json['storage_unit_id']),
      storageUnitLabel: _string(json['storage_unit_label']),
      storageSlotId: _string(json['storage_slot_id']),
      storageSlotLabel: _string(json['storage_slot_label']),
      storageSlotStatus: _string(json['storage_slot_status']),
    );
  }
}

final class MortuaryTimelineEventDto {
  const MortuaryTimelineEventDto(this.json);

  final MortuaryJsonMap json;

  MortuaryTimelineEvent toEntity() {
    return MortuaryTimelineEvent(
      id: _string(json['id']) ?? _string(json['human_friendly_id']) ?? '',
      eventType: _string(json['event_type']),
      eventAt: _date(json['event_at']) ?? _date(json['occurred_at']),
      actorName: _string(json['actor_name']),
      actorRole: _string(json['actor_role']),
      locationLabel: _string(json['location_label']),
      reason: _string(json['reason']),
      notes: _string(json['notes']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class MortuaryViewingDto {
  const MortuaryViewingDto(this.json);

  final MortuaryJsonMap json;

  MortuaryViewing toEntity() {
    return MortuaryViewing(
      id: _string(json['id']) ?? _string(json['human_friendly_id']) ?? '',
      scheduledAt: _date(json['scheduled_at']),
      status: _string(json['status']),
      authorisedByName: _string(json['authorised_by_name']),
      attendeeSummary: _string(json['attendee_summary']),
      completedAt: _date(json['completed_at']),
    );
  }
}

final class MortuaryPostMortemRequestDto {
  const MortuaryPostMortemRequestDto(this.json);

  final MortuaryJsonMap json;

  MortuaryPostMortemRequest toEntity() {
    return MortuaryPostMortemRequest(
      id: _string(json['id']) ?? _string(json['human_friendly_id']) ?? '',
      requestedByName: _string(json['requested_by_name']),
      requestReason: _string(json['request_reason']),
      status: _string(json['status']),
      diagnosticsReferenceId: _string(json['diagnostics_reference_id']),
      scheduledAt: _date(json['scheduled_at']),
      completedAt: _date(json['completed_at']),
      reportReceivedAt: _date(json['report_received_at']),
    );
  }
}

final class MortuaryReleaseAuthorisationDto {
  const MortuaryReleaseAuthorisationDto(this.json);

  final MortuaryJsonMap json;

  MortuaryReleaseAuthorisation toEntity() {
    return MortuaryReleaseAuthorisation(
      id: _string(json['id']) ?? _string(json['human_friendly_id']) ?? '',
      recipientName: _string(json['recipient_name']),
      recipientRelationship: _string(json['recipient_relationship']),
      verificationReference: _string(json['verification_reference']),
      funeralServiceName: _string(json['funeral_service_name']),
      releaseMethod: _string(json['release_method']),
      status: _string(json['status']),
      approvedByName: _string(json['approved_by_name']),
      approvedAt: _date(json['approved_at']),
      releasedAt: _date(json['released_at']),
    );
  }
}

final class MortuaryBillableEventDto {
  const MortuaryBillableEventDto(this.json);

  final MortuaryJsonMap json;

  MortuaryBillableEvent toEntity() {
    return MortuaryBillableEvent(
      id: _string(json['id']) ?? _string(json['human_friendly_id']) ?? '',
      eventType: _string(json['event_type']),
      description: _string(json['description']),
      amountText: _string(json['amount']),
      currency: _string(json['currency']),
      status: _string(json['status']),
      billingReferenceId: _string(json['billing_reference_id']),
      chargedAt: _date(json['charged_at']),
      settledAt: _date(json['settled_at']),
    );
  }
}

MortuaryWorkspaceQuery? _filters(Object? value) {
  final MortuaryJsonMap json = _map(value);
  if (json.isEmpty) {
    return null;
  }

  return MortuaryWorkspaceQuery(
    panel: _string(json['panel']) ?? mortuaryPanelOverview,
    resource: _string(json['resource']) ?? mortuaryResourceCases,
    queue: _string(json['queue']),
    search: _string(json['search']) ?? '',
    status: _string(json['status']),
    identificationStatus: _string(json['identification_status']),
    facilityId: _string(json['facility_id']),
    storageUnitId: _string(json['storage_unit_id']),
    storageSlotId: _string(json['storage_slot_id']),
    datePreset: _string(json['date_preset']),
    id: _string(json['id']),
    action: _string(json['action']),
  );
}

MortuaryStorageAssignment? _storageAssignment(Object? value) {
  final MortuaryJsonMap json = _map(value);
  if (json.isEmpty) {
    return null;
  }
  return MortuaryStorageAssignmentDto(json).toEntity();
}

MortuaryCaseSummary? _caseSummary(Object? value) {
  final MortuaryJsonMap json = _map(value);
  if (json.isEmpty) {
    return null;
  }
  return MortuaryCaseSummaryDto(json).toEntity();
}

MortuaryJsonMap _expectMap(Object? value) {
  final MortuaryJsonMap result = _map(value);
  if (result.isNotEmpty || value is Map) {
    return result;
  }

  throw const FormatException('Expected mortuary response object.');
}

MortuaryJsonMap _map(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
  return <String, Object?>{};
}

List<MortuaryJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <MortuaryJsonMap>[];
  }

  return value.map(_map).where((MortuaryJsonMap item) {
    return item.isNotEmpty;
  }).toList(growable: false);
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

bool? _nullableBool(Object? value) {
  if (value == null) {
    return null;
  }
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
  return null;
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
