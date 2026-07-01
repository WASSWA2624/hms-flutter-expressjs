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
      id:
          _string(json['display_id']) ??
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
      units: _options(json['units']),
      rooms: _options(json['rooms']),
      staffProfiles: _options(json['staff_profiles']),
      staffPositions: _options(json['staff_positions']),
      rosters: _options(json['rosters']),
      payrollRuns: _options(json['payroll_runs']),
      shiftTemplates: _options(json['shift_templates']),
      shifts: _options(json['shifts']),
      roles: _options(json['roles']),
      users: _options(json['users']),
      shiftTypes: _options(json['shift_types']),
      leaveTypes: _options(json['leave_types']),
      leaveHalfDayPeriods: _options(json['leave_half_day_periods']),
      practitionerTypes: _options(json['practitioner_types']),
      compensationPayTypes: _options(json['compensation_pay_types']),
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
      id:
          _string(json['id']) ??
          _string(json['display_id']) ??
          _string(json['staff_number']) ??
          '',
      displayId:
          _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['staff_number']),
      tenantId: _string(json['tenant_id']),
      tenantDisplayId:
          _string(json['tenant_display_id']) ??
          _string(_map(json['tenant'])['human_friendly_id']),
      userId: _string(json['user_id']),
      userDisplayId: _string(json['user_display_id']),
      userFullName: _string(json['user_full_name']) ?? fallbackName,
      userEmail: _string(user['email']),
      departmentId: _string(json['department_id']),
      departmentDisplayId:
          _string(json['department_display_id']) ??
          _string(department['human_friendly_id']),
      departmentName:
          _string(department['name']) ?? _string(department['short_name']),
      staffNumber: _string(json['staff_number']),
      position: _string(json['position']),
      practitionerType: _string(json['practitioner_type']),
      consultationFee: _number(json['consultation_fee']),
      consultationCurrency: _string(json['consultation_currency']),
      compensations: _list(json['compensations'])
          .map(HrStaffCompensationDto.new)
          .map((HrStaffCompensationDto dto) => dto.toEntity())
          .where((HrStaffCompensation item) => item.id.isNotEmpty)
          .toList(growable: false),
      hireDate: _date(json['hire_date']),
      status: _string(json['status']) ?? 'ACTIVE',
      updatedAt: _date(json['timeline_at']) ?? _date(json['updated_at']),
    );
  }
}

final class HrStaffCompensationDto {
  const HrStaffCompensationDto(this.json);

  final HrJsonMap json;

  HrStaffCompensation toEntity() {
    return HrStaffCompensation(
      id:
          _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      staffProfileId: _string(json['staff_profile_id']),
      payType: _string(json['pay_type']),
      rate: _number(json['rate']),
      currency: _string(json['currency']),
      effectiveFrom: _date(json['effective_from']),
      effectiveTo: _date(json['effective_to']),
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
    final HrJsonMap department = _map(json['department']);
    final HrJsonMap unit = _map(json['unit']);
    final HrJsonMap room = _map(json['room']);
    final DateTime? endDate = _date(json['end_date']);
    final bool isActive = endDate == null || endDate.isAfter(DateTime.now());
    return HrStaffAssignment(
      id:
          _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      staffProfileId: _string(json['staff_profile_id']),
      departmentId: _string(json['department_id']),
      departmentName:
          _string(department['name']) ?? _string(department['short_name']),
      departmentDisplayId:
          _string(json['department_display_id']) ??
          _string(department['human_friendly_id']),
      unitId: _string(json['unit_id']),
      unitName: _string(unit['name']),
      unitDisplayId: _string(unit['human_friendly_id']),
      roomId: _string(json['room_id']),
      roomName: _string(room['name']),
      roomDisplayId: _string(room['human_friendly_id']),
      startDate: _date(json['start_date']),
      endDate: endDate,
      isPrimary: json['is_primary'] == true,
      isActive: isActive,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
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
      id:
          _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      staffProfileId: _string(json['staff_profile_id']),
      leaveType: _string(json['leave_type']),
      status: _string(json['status']),
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      isHalfDay: json['is_half_day'] == true,
      halfDayPeriod: _string(json['half_day_period']),
      reason: _string(json['reason']),
      handoverNotes: _string(json['handover_notes']),
      coveringStaffProfileId:
          _string(json['covering_staff_display_id']) ??
          _string(json['covering_staff_profile_id']),
      coveringStaffName: _string(json['covering_staff_name']),
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
      id:
          _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      staffProfileId: _string(json['staff_profile_id']),
      dayOfWeek: _int(json['day_of_week']),
      startTime: _string(json['start_time']),
      endTime: _string(json['end_time']),
      timeSlots:
          _availabilitySlots(json['time_slots']) +
          _availabilitySlots(json['time_slots_json']),
      preference: _string(json['preference']),
      status: _string(json['status']),
      effectiveFrom: _date(json['effective_from']),
      effectiveTo: _date(json['effective_to']),
    );
  }
}

List<HrAvailabilitySlot> _availabilitySlots(Object? value) {
  final List<HrJsonMap> slots = _list(value);
  return slots
      .map(
        (HrJsonMap slot) => HrAvailabilitySlot(
          startTime: _string(slot['start_time']) ?? '',
          endTime: _string(slot['end_time']) ?? '',
        ),
      )
      .where(
        (HrAvailabilitySlot slot) =>
            slot.startTime.trim().isNotEmpty && slot.endTime.trim().isNotEmpty,
      )
      .toList(growable: false);
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
    final HrJsonMap shift = _map(json['shift']);
    return HrShiftAssignment(
      id:
          _string(json['display_id']) ??
          _string(json['human_friendly_id']) ??
          _string(json['id']) ??
          '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      shiftId: _string(json['shift_id']),
      shiftName: _string(shift['name']) ??
          _string(shift['shift_type']) ??
          _string(shift['human_friendly_id']),
      shiftType: _string(shift['shift_type']),
      shiftStatus: _string(shift['status']),
      rosterPeriodLabel: _string(shift['roster_period_label']),
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
      staffProfileId:
          _string(json['staff_profile_display_id']) ??
          _string(json['staff_profile_id']) ??
          _string(json['requester_staff_display_id']) ??
          _string(json['requester_staff_id']),
      staffName: _string(json['staff_name']),
      staffNumber:
          _string(json['staff_number']) ??
          _string(json['requester_staff_number']),
      staffPosition: _string(json['staff_position']),
      leaveType: _string(json['leave_type']),
      isHalfDay: json['is_half_day'] == true,
      halfDayPeriod: _string(json['half_day_period']),
      shiftId: _string(json['shift_display_id']) ?? _string(json['shift_id']),
      shiftType: _string(json['shift_type']),
      rosterId:
          _string(json['nurse_roster_display_id']) ??
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

final class HrStaffAccessSummaryDto {
  const HrStaffAccessSummaryDto(this.json);

  final HrJsonMap json;

  factory HrStaffAccessSummaryDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrStaffAccessSummaryDto(_map(response['data']));
  }

  HrStaffAccessSummary toEntity() {
    final HrJsonMap linkedUser = _map(json['linked_user']);
    return HrStaffAccessSummary(
      staffProfileId: _string(json['staff_profile_id']),
      linkedUserDisplayId: _string(linkedUser['display_id']),
      linkedUserEmail: _string(linkedUser['email']),
      linkedUserFullName: _string(linkedUser['full_name']),
      userRoles: _list(json['user_roles'])
          .map(HrUserRoleDto.new)
          .map((HrUserRoleDto dto) => dto.toEntity())
          .where((HrUserRole item) => item.id.isNotEmpty)
          .toList(growable: false),
      moduleAccess: _list(json['module_access'])
          .map(HrModuleAccessDto.new)
          .map((HrModuleAccessDto dto) => dto.toEntity())
          .where((HrModuleAccess item) => item.slug.isNotEmpty)
          .toList(growable: false),
      effectivePermissions: _list(json['effective_permissions'])
          .map((Object? value) => _string(value))
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

final class HrUserRoleDto {
  const HrUserRoleDto(this.json);

  final HrJsonMap json;

  HrUserRole toEntity() {
    final HrJsonMap role = _map(json['role']);
    return HrUserRole(
      id:
          _string(json['display_id']) ??
          _string(json['id']) ??
          _string(json['backend_identifier']) ??
          '',
      displayId: _string(json['display_id']),
      backendIdentifier:
          _string(json['backend_identifier']) ?? _string(json['id']),
      roleId:
          _string(json['role_id']) ??
          _string(role['display_id']) ??
          _string(role['id']),
      roleName: _string(json['role_name']) ?? _string(role['name']),
      facilityId: _string(json['facility_id']),
      facilityName: _string(json['facility_name']),
      facilityDisplayId: _string(json['facility_display_id']),
      tenantId: _string(json['tenant_id']),
    );
  }
}

final class HrModuleAccessDto {
  const HrModuleAccessDto(this.json);

  final HrJsonMap json;

  HrModuleAccess toEntity() {
    return HrModuleAccess(
      slug: _string(json['slug']) ?? '',
      label: _string(json['label']),
      moduleGroup: _string(json['module_group']),
      granted: json['granted'] == true,
    );
  }
}

final class HrPayrollPreviewDto {
  const HrPayrollPreviewDto(this.json);

  final HrJsonMap json;

  factory HrPayrollPreviewDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrPayrollPreviewDto(_map(response['data']));
  }

  HrPayrollPreview toEntity() {
    final HrJsonMap runSummary = _map(json['run_summary']);
    final HrJsonMap totals = _map(json['totals']);
    return HrPayrollPreview(
      runId: _string(runSummary['backend_identifier']),
      runDisplayId:
          _string(runSummary['display_id']) ?? _string(runSummary['id']),
      status: _string(runSummary['status']),
      periodStart: _date(runSummary['period_start']),
      periodEnd: _date(runSummary['period_end']),
      items: _list(json['proposed_items'])
          .map(HrPayrollPreviewItemDto.new)
          .map((HrPayrollPreviewItemDto dto) => dto.toEntity())
          .toList(growable: false),
      totalAmount: _number(totals['total_amount']) ?? 0,
      totalHours: _number(totals['total_hours']) ?? 0,
      staffCount: _int(totals['staff_count']) ?? 0,
      currency: _string(totals['currency']),
    );
  }
}

final class HrPayrollPreviewItemDto {
  const HrPayrollPreviewItemDto(this.json);

  final HrJsonMap json;

  HrPayrollPreviewItem toEntity() {
    return HrPayrollPreviewItem(
      staffProfileId: _string(json['staff_profile_id']),
      staffProfileDisplayId: _string(json['staff_profile_display_id']),
      staffNumber: _string(json['staff_number']),
      staffName: _string(json['staff_name']),
      assignmentCount: _int(json['assignment_count']) ?? 0,
      totalHours: _number(json['total_hours']) ?? 0,
      amount: _number(json['amount']) ?? 0,
      currency: _string(json['currency']),
    );
  }
}

final class HrRosterGenerateResultDto {
  const HrRosterGenerateResultDto(this.json);

  final HrJsonMap json;

  factory HrRosterGenerateResultDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrRosterGenerateResultDto(_map(response['data']));
  }

  HrRosterGenerateResult toEntity() {
    final HrJsonMap roster = _map(json['roster']);
    final HrJsonMap coverage = _map(json['coverage']);
    final List<HrJsonMap> gaps = _list(json['gaps']);
    return HrRosterGenerateResult(
      rosterDisplayId:
          _string(roster['display_id']) ?? _string(roster['human_friendly_id']),
      dryRun: json['dry_run'] == true,
      assignmentCount: _int(json['assignment_count']) ?? 0,
      coveragePercent: _number(coverage['coverage_percent']),
      gapCount: gaps.length,
      summary: _string(json['summary']),
    );
  }
}

final class HrOptionDto {
  const HrOptionDto(this.json);

  final HrJsonMap json;

  HrOption toEntity() {
    final String value =
        _string(json['value']) ??
        _string(json['display_id']) ??
        _string(json['id']) ??
        '';
    return HrOption(
      value: value,
      label: _string(json['label']) ?? value,
      displayId: _string(json['display_id']),
      labelKey: _string(json['label_key']),
      extra: <String, Object?>{
        for (final MapEntry<String, Object?> entry in json.entries)
          if (!<String>{
            'value',
            'label',
            'display_id',
            'id',
            'label_key',
          }.contains(entry.key))
            entry.key: entry.value,
      },
    );
  }
}

final class HrAccessUserPageDto {
  const HrAccessUserPageDto({required this.page});

  final AppPage<HrAccessUser> page;

  factory HrAccessUserPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final HrJsonMap response = _expectMap(responseData);
    final List<HrAccessUser> items = _list(response['data'])
        .map(HrAccessUserDto.new)
        .map((HrAccessUserDto dto) => dto.toEntity())
        .where((HrAccessUser item) => item.id.isNotEmpty)
        .toList(growable: false);

    return HrAccessUserPageDto(
      page: AppPage<HrAccessUser>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class HrAccessUserDto {
  const HrAccessUserDto(this.json);

  final HrJsonMap json;

  HrAccessUser toEntity() {
    final HrJsonMap staffProfile = _map(json['staff_profile']);
    final List<String> roleNames = <String>[];
    final List<String> roleIds = <String>[];
    for (final Object? entry in _list(json['roles'])) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final HrJsonMap role = _map(entry['role']);
      final String? roleName = _string(role['name']) ?? _string(entry['name']);
      final String? roleId =
          _string(role['display_id']) ??
          _string(role['id']) ??
          _string(entry['role_id']);
      if (roleName != null) {
        roleNames.add(roleName);
      }
      if (roleId != null) {
        roleIds.add(roleId);
      }
    }
    final List<String> directPermissionNames = _list(json['permissions'])
        .map((Object? entry) {
          if (entry is! Map<String, Object?>) {
            return null;
          }
          final HrJsonMap permission = _map(entry['permission']);
          return _string(permission['name']) ?? _string(entry['name']);
        })
        .whereType<String>()
        .toList(growable: false);

    return HrAccessUser(
      id: _string(json['display_id']) ?? _string(json['id']) ?? '',
      displayId: _string(json['display_id']),
      email: _string(json['email']),
      phone: _string(json['phone']),
      positionTitle: _string(json['position_title']),
      status: _string(json['status']),
      profileName: _string(json['profile_name']),
      roleNames: roleNames,
      roleIds: roleIds,
      directPermissionNames: directPermissionNames,
      staffProfileId:
          _string(staffProfile['display_id']) ??
          _string(staffProfile['human_friendly_id']) ??
          _string(json['staff_profile_id']),
      staffProfileName:
          _string(staffProfile['display_name']) ??
          _string(staffProfile['name']) ??
          _string(staffProfile['staff_number']),
    );
  }
}

final class HrAccessUserDetailDto {
  const HrAccessUserDetailDto(this.json);

  final HrJsonMap json;

  factory HrAccessUserDetailDto.fromResponse(Object? responseData) {
    final HrJsonMap response = _expectMap(responseData);
    return HrAccessUserDetailDto(_map(response['data']));
  }

  HrAccessUserDetail toEntity() {
    final HrJsonMap staffProfile = _map(json['staff_profile']);
    final List<HrAccessPermission> directPermissions =
        _list(json['permissions'])
            .map((Object? entry) {
              if (entry is! Map<String, Object?>) {
                return null;
              }
              final HrJsonMap permission = _map(entry['permission']);
              if (permission.isEmpty) {
                return null;
              }
              return HrAccessPermission(
                id:
                    _string(permission['display_id']) ??
                    _string(permission['id']) ??
                    '',
                displayId: _string(permission['display_id']),
                name: _string(permission['name']),
                description: _string(permission['description']),
              );
            })
            .whereType<HrAccessPermission>()
            .where((HrAccessPermission item) => item.id.isNotEmpty)
            .toList(growable: false);
    final List<String> effectivePermissionLabels =
        _list(json['effective_permissions'])
            .map((Object? value) => _string(value))
            .whereType<String>()
            .toList(growable: false);

    return HrAccessUserDetail(
      id: _string(json['display_id']) ?? _string(json['id']) ?? '',
      displayId: _string(json['display_id']),
      email: _string(json['email']),
      phone: _string(json['phone']),
      positionTitle: _string(json['position_title']),
      status: _string(json['status']),
      profileName: _string(json['profile_name']),
      staffProfileId:
          _string(staffProfile['display_id']) ??
          _string(staffProfile['human_friendly_id']) ??
          _string(json['staff_profile_id']),
      staffProfileName:
          _string(staffProfile['display_name']) ??
          _string(staffProfile['name']) ??
          _string(staffProfile['staff_number']),
      directPermissions: directPermissions,
      effectivePermissionLabels: effectivePermissionLabels,
    );
  }
}

final class HrAccessRolePageDto {
  const HrAccessRolePageDto({required this.page});

  final AppPage<HrAccessRole> page;

  factory HrAccessRolePageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final HrJsonMap response = _expectMap(responseData);
    final List<HrAccessRole> items = _list(response['data'])
        .map(HrAccessRoleDto.new)
        .map((HrAccessRoleDto dto) => dto.toEntity())
        .where((HrAccessRole item) => item.id.isNotEmpty)
        .toList(growable: false);

    return HrAccessRolePageDto(
      page: AppPage<HrAccessRole>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class HrAccessRoleDto {
  const HrAccessRoleDto(this.json);

  final HrJsonMap json;

  HrAccessRole toEntity() {
    return HrAccessRole(
      id: _string(json['display_id']) ?? _string(json['id']) ?? '',
      displayId: _string(json['display_id']),
      name: _string(json['name']),
      description: _string(json['description']),
      permissionCount: _int(json['permission_count']) ?? 0,
      userCount:
          _int(json['user_count']) ?? _int(_map(json['_count'])['users']) ?? 0,
      isSystemCritical: json['is_system_critical'] == true,
    );
  }
}

final class HrAccessPermissionPageDto {
  const HrAccessPermissionPageDto({required this.page});

  final AppPage<HrAccessPermission> page;

  factory HrAccessPermissionPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final HrJsonMap response = _expectMap(responseData);
    final List<HrAccessPermission> items = _list(response['data'])
        .map(HrAccessPermissionDto.new)
        .map((HrAccessPermissionDto dto) => dto.toEntity())
        .where((HrAccessPermission item) => item.id.isNotEmpty)
        .toList(growable: false);

    return HrAccessPermissionPageDto(
      page: AppPage<HrAccessPermission>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class HrAccessPermissionDto {
  const HrAccessPermissionDto(this.json);

  final HrJsonMap json;

  HrAccessPermission toEntity() {
    return HrAccessPermission(
      id: _string(json['display_id']) ?? _string(json['id']) ?? '',
      displayId: _string(json['display_id']),
      name: _string(json['name']),
      description: _string(json['description']),
      roleCount:
          _int(json['role_count']) ?? _int(_map(json['_count'])['roles']) ?? 0,
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
