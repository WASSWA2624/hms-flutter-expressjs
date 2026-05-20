import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef HrJsonMap = Map<String, Object?>;

final class HrWorkspaceOverviewDto {
  const HrWorkspaceOverviewDto(this.json);

  final HrJsonMap json;

  factory HrWorkspaceOverviewDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrWorkspaceOverviewDto(_map(response['data']));
  }

  HrWorkspaceOverview toEntity() {
    final HrJsonMap timeline = _map(json['timeline']);
    return HrWorkspaceOverview(
      summary: HrWorkspaceSummaryDto(_map(json['summary'])).toEntity(),
      queueSummaries: _list(json['queue_summaries'])
          .map(HrQueueSummaryDto.new)
          .map((HrQueueSummaryDto dto) => dto.toEntity())
          .whereType<HrQueueSummary>()
          .toList(growable: false),
      timeline: _list(timeline['items'])
          .map(HrTimelineItemDto.new)
          .map((HrTimelineItemDto dto) => dto.toEntity())
          .where((HrTimelineItem item) => item.id.isNotEmpty)
          .toList(growable: false),
      generatedAt: _date(json['generated_at']),
    );
  }
}

final class HrWorkspaceSummaryDto {
  const HrWorkspaceSummaryDto(this.json);

  final HrJsonMap json;

  HrWorkspaceSummary toEntity() {
    return HrWorkspaceSummary(
      totalStaff: _int(json['total_staff']) ?? 0,
      leaveRequests: _int(json['leave_requests']) ?? 0,
      swapRequests: _int(json['swap_requests']) ?? 0,
      draftRosters: _int(json['draft_rosters']) ?? 0,
      unassignedShifts: _int(json['unassigned_shifts']) ?? 0,
      payrollDraftRuns: _int(json['payroll_draft_runs']) ?? 0,
      overdueShifts: _int(json['overdue_shifts']) ?? 0,
    );
  }
}

final class HrQueueSummaryDto {
  const HrQueueSummaryDto(this.json);

  final HrJsonMap json;

  HrQueueSummary? toEntity() {
    final HrQueue? queue = HrQueue.fromValue(_string(json['queue']));
    if (queue == null) {
      return null;
    }
    return HrQueueSummary(
      queue: queue,
      count: _int(json['count']) ?? 0,
      panel: _string(json['panel']),
      resource: _string(json['resource']),
    );
  }
}

final class HrTimelineItemDto {
  const HrTimelineItemDto(this.json);

  final HrJsonMap json;

  HrTimelineItem toEntity() {
    return HrTimelineItem(
      id: _string(json['display_id']) ??
          _string(json['backend_identifier']) ??
          _string(json['id']) ??
          '',
      type: _string(json['type']),
      action: _string(json['action']),
      status: _string(json['status']),
      at: _date(json['timeline_at']),
    );
  }
}

final class HrReferenceDataDto {
  const HrReferenceDataDto(this.json);

  final HrJsonMap json;

  factory HrReferenceDataDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrReferenceDataDto(_map(response['data']));
  }

  HrReferenceData toEntity() {
    return HrReferenceData(
      facilities: _options(json['facilities']),
      departments: _options(json['departments']),
      staffProfiles: _options(json['staff_profiles']),
      staffPositions: _options(json['staff_positions']),
      rosters: _options(json['rosters']),
      payrollRuns: _options(json['payroll_runs']),
      shiftTemplates: _options(json['shift_templates']),
      roles: _options(json['roles']),
      shiftTypes: _options(json['shift_types']),
      practitionerTypes: _options(json['practitioner_types']),
      resourceStatuses: _resourceStatuses(json['resource_statuses']),
    );
  }
}

final class HrStaffProfilePageDto {
  const HrStaffProfilePageDto({required this.page});

  final AppPage<HrStaffProfile> page;

  factory HrStaffProfilePageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final HrJsonMap response = _expectMap(responseData);
    final List<HrStaffProfile> items = _list(response['data'])
        .map(HrStaffProfileDto.new)
        .map((HrStaffProfileDto dto) => dto.toEntity())
        .where((HrStaffProfile item) => item.id.isNotEmpty)
        .toList(growable: false);

    return HrStaffProfilePageDto(
      page: AppPage<HrStaffProfile>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class HrStaffProfileDto {
  const HrStaffProfileDto(this.json);

  final HrJsonMap json;

  factory HrStaffProfileDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrStaffProfileDto(_map(response['data']));
  }

  HrStaffProfile toEntity() {
    final HrJsonMap user = _map(json['user']);
    final HrJsonMap profile = _map(user['profile']);
    final HrJsonMap department = _map(json['department']);
    final String? firstName = _string(profile['first_name']);
    final String? middleName = _string(profile['middle_name']);
    final String? lastName = _string(profile['last_name']);
    final String? fallbackName = _joinDisplay(<String?>[
      firstName,
      middleName,
      lastName,
    ]);

    return HrStaffProfile(
      id: _string(json['id']) ??
          _string(json['display_id']) ??
          _string(json['staff_number']) ??
          '',
      displayId: _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['staff_number']),
      tenantId: _string(json['tenant_display_id']) ?? _string(json['tenant_id']),
      userId: _string(json['user_id']),
      userDisplayId: _string(json['user_display_id']),
      userFullName: _string(json['user_full_name']) ?? fallbackName,
      userEmail: _string(user['email']),
      departmentId: _string(json['department_id']),
      departmentDisplayId: _string(json['department_display_id']) ??
          _string(department['human_friendly_id']),
      departmentName: _string(department['name']) ??
          _string(department['short_name']),
      staffNumber: _string(json['staff_number']),
      position: _string(json['position']),
      practitionerType: _string(json['practitioner_type']),
      consultationFee: _number(json['consultation_fee']),
      consultationCurrency: _string(json['consultation_currency']),
      hireDate: _date(json['hire_date']),
      status: _string(json['status']) ?? 'ACTIVE',
      updatedAt: _date(json['timeline_at']) ?? _date(json['updated_at']),
    );
  }
}

final class HrStaffAssignmentPageDto {
  const HrStaffAssignmentPageDto({required this.items});

  final List<HrStaffAssignment> items;

  factory HrStaffAssignmentPageDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrStaffAssignmentPageDto(
      items: _list(response['data'])
          .map(HrStaffAssignmentDto.new)
          .map((HrStaffAssignmentDto dto) => dto.toEntity())
          .where((HrStaffAssignment item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class HrStaffAssignmentDto {
  const HrStaffAssignmentDto(this.json);

  final HrJsonMap json;

  HrStaffAssignment toEntity() {
    return HrStaffAssignment(
      id: _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      displayId: _string(json['display_id']) ?? _string(json['human_friendly_id']),
      staffProfileId: _string(json['staff_profile_id']),
      departmentId: _string(json['department_id']),
      unitId: _string(json['unit_id']),
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
    );
  }
}

final class HrStaffLeavePageDto {
  const HrStaffLeavePageDto({required this.items});

  final List<HrStaffLeave> items;

  factory HrStaffLeavePageDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrStaffLeavePageDto(
      items: _list(response['data'])
          .map(HrStaffLeaveDto.new)
          .map((HrStaffLeaveDto dto) => dto.toEntity())
          .where((HrStaffLeave item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class HrStaffLeaveDto {
  const HrStaffLeaveDto(this.json);

  final HrJsonMap json;

  HrStaffLeave toEntity() {
    return HrStaffLeave(
      id: _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      displayId: _string(json['display_id']) ?? _string(json['human_friendly_id']),
      staffProfileId: _string(json['staff_profile_id']),
      status: _string(json['status']),
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      reason: _string(json['reason']),
    );
  }
}

final class HrStaffAvailabilityPageDto {
  const HrStaffAvailabilityPageDto({required this.items});

  final List<HrStaffAvailability> items;

  factory HrStaffAvailabilityPageDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrStaffAvailabilityPageDto(
      items: _list(response['data'])
          .map(HrStaffAvailabilityDto.new)
          .map((HrStaffAvailabilityDto dto) => dto.toEntity())
          .where((HrStaffAvailability item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class HrStaffAvailabilityDto {
  const HrStaffAvailabilityDto(this.json);

  final HrJsonMap json;

  HrStaffAvailability toEntity() {
    return HrStaffAvailability(
      id: _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      displayId: _string(json['display_id']) ?? _string(json['human_friendly_id']),
      staffProfileId: _string(json['staff_profile_id']),
      dayOfWeek: _int(json['day_of_week']),
      startTime: _string(json['start_time']),
      endTime: _string(json['end_time']),
      preference: _string(json['preference']),
      effectiveFrom: _date(json['effective_from']),
      effectiveTo: _date(json['effective_to']),
    );
  }
}

final class HrShiftAssignmentPageDto {
  const HrShiftAssignmentPageDto({required this.items});

  final List<HrShiftAssignment> items;

  factory HrShiftAssignmentPageDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrShiftAssignmentPageDto(
      items: _list(response['data'])
          .map(HrShiftAssignmentDto.new)
          .map((HrShiftAssignmentDto dto) => dto.toEntity())
          .where((HrShiftAssignment item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class HrShiftAssignmentDto {
  const HrShiftAssignmentDto(this.json);

  final HrJsonMap json;

  HrShiftAssignment toEntity() {
    return HrShiftAssignment(
      id: _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      displayId: _string(json['display_id']) ?? _string(json['human_friendly_id']),
      shiftId: _string(json['shift_id']),
      staffProfileId: _string(json['staff_profile_id']),
      assignedAt: _date(json['assigned_at']),
    );
  }
}

final class HrWorkItemPageDto {
  const HrWorkItemPageDto({required this.page});

  final AppPage<HrWorkItem> page;

  factory HrWorkItemPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final HrJsonMap response = _expectMap(responseData);
    final HrJsonMap data = _map(response['data']);
    final List<HrWorkItem> items = _list(data['items'])
        .map(HrWorkItemDto.new)
        .map((HrWorkItemDto dto) => dto.toEntity())
        .where((HrWorkItem item) => item.id.isNotEmpty)
        .toList(growable: false);

    return HrWorkItemPageDto(
      page: AppPage<HrWorkItem>(
        items: items,
        request: request,
        totalItemCount: _int(_map(data['pagination'])['total']),
      ),
    );
  }
}

final class HrWorkItemDto {
  const HrWorkItemDto(this.json);

  final HrJsonMap json;

  HrWorkItem toEntity() {
    final HrQueue queue =
        HrQueue.fromValue(_string(json['queue'])) ?? HrQueue.leaveRequests;
    return HrWorkItem(
      id: _string(json['id']) ?? _string(json['display_id']) ?? '',
      queue: queue,
      displayId: _string(json['display_id']),
      backendIdentifier: _string(json['backend_identifier']),
      status: _string(json['status']),
      staffProfileId: _string(json['staff_profile_display_id']) ??
          _string(json['staff_profile_id']) ??
          _string(json['requester_staff_display_id']) ??
          _string(json['requester_staff_id']),
      staffName: _string(json['staff_name']),
      staffNumber: _string(json['staff_number']) ??
          _string(json['requester_staff_number']),
      staffPosition: _string(json['staff_position']),
      shiftId: _string(json['shift_display_id']) ?? _string(json['shift_id']),
      shiftType: _string(json['shift_type']),
      rosterId: _string(json['nurse_roster_display_id']) ??
          _string(json['nurse_roster_id']) ??
          _string(json['display_id']),
      payrollRunId: queue == HrQueue.payrollDrafts
          ? _string(json['display_id'])
          : null,
      periodLabel: _string(json['period_label']),
      startAt: _date(json['start_date']) ?? _date(json['start_time']),
      endAt: _date(json['end_date']) ?? _date(json['end_time']),
      timelineAt: _date(json['timeline_at']),
      assignmentCount: _int(json['assignment_count']) ?? 0,
      reason: _string(json['reason']),
    );
  }
}

Object? passthroughResponseData(Object? responseData) {
  if (responseData is HrJsonMap) {
    return responseData['data'];
  }
  return responseData;
}

List<HrOption> _options(Object? value) {
  return _list(value)
      .map(HrOptionDto.new)
      .map((HrOptionDto dto) => dto.toEntity())
      .where((HrOption option) => option.value.isNotEmpty)
      .toList(growable: false);
}

Map<String, List<HrOption>> _resourceStatuses(Object? value) {
  final HrJsonMap source = _map(value);
  return <String, List<HrOption>>{
    for (final MapEntry<String, Object?> entry in source.entries)
      entry.key: _options(entry.value),
  };
}

final class HrOptionDto {
  const HrOptionDto(this.json);

  final HrJsonMap json;

  HrOption toEntity() {
    final String value = _string(json['value']) ??
        _string(json['display_id']) ??
        _string(json['id']) ??
        '';
    return HrOption(
      value: value,
      label: _string(json['label']) ?? value,
      displayId: _string(json['display_id']),
      extra: <String, Object?>{
        for (final MapEntry<String, Object?> entry in json.entries)
          if (!<String>{'value', 'label', 'display_id', 'id'}.contains(entry.key))
            entry.key: entry.value,
      },
    );
  }
}

HrJsonMap _expectMap(Object? value) {
  if (value is HrJsonMap) {
    return value;
  }
  throw const FormatException('Expected HR response object.');
}

HrJsonMap _map(Object? value) {
  return value is HrJsonMap ? value : <String, Object?>{};
}

List<HrJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <HrJsonMap>[];
  }
  return value.whereType<HrJsonMap>().toList(growable: false);
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

num? _number(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
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

String? _joinDisplay(Iterable<String?> values) {
  final String value = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' ');
  return value.isEmpty ? null : value;
}
