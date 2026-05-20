import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum HrQueue {
  leaveRequests('LEAVE_REQUESTS'),
  swapRequests('SWAP_REQUESTS'),
  rosterDrafts('ROSTER_DRAFTS'),
  unassignedShifts('UNASSIGNED_SHIFTS'),
  payrollDrafts('PAYROLL_DRAFTS'),
  overdueShifts('OVERDUE_SHIFTS');

  const HrQueue(this.value);

  final String value;

  static HrQueue? fromValue(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    for (final HrQueue queue in values) {
      if (queue.value == normalized) {
        return queue;
      }
    }
    return null;
  }
}

@immutable
final class HrStaffQuery {
  const HrStaffQuery({
    this.search = '',
    this.departmentId,
    this.position,
    this.practitionerType,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final String? departmentId;
  final String? position;
  final String? practitionerType;
  final AppPageRequest pageRequest;

  HrStaffQuery copyWith({
    String? search,
    String? departmentId,
    String? position,
    String? practitionerType,
    AppPageRequest? pageRequest,
    bool clearDepartmentId = false,
    bool clearPosition = false,
    bool clearPractitionerType = false,
  }) {
    return HrStaffQuery(
      search: search ?? this.search,
      departmentId: clearDepartmentId
          ? null
          : departmentId ?? this.departmentId,
      position: clearPosition ? null : position ?? this.position,
      practitionerType: clearPractitionerType
          ? null
          : practitionerType ?? this.practitionerType,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class HrWorkItemsQuery {
  const HrWorkItemsQuery({
    this.queue = HrQueue.leaveRequests,
    this.search = '',
    this.status,
    this.departmentId,
    this.facilityId,
    this.pageRequest = const AppPageRequest(pageSize: 10),
  });

  final HrQueue queue;
  final String search;
  final String? status;
  final String? departmentId;
  final String? facilityId;
  final AppPageRequest pageRequest;

  HrWorkItemsQuery copyWith({
    HrQueue? queue,
    String? search,
    String? status,
    String? departmentId,
    String? facilityId,
    AppPageRequest? pageRequest,
    bool clearStatus = false,
    bool clearDepartmentId = false,
    bool clearFacilityId = false,
  }) {
    return HrWorkItemsQuery(
      queue: queue ?? this.queue,
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      departmentId: clearDepartmentId
          ? null
          : departmentId ?? this.departmentId,
      facilityId: clearFacilityId ? null : facilityId ?? this.facilityId,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class HrWorkspaceOverview {
  const HrWorkspaceOverview({
    this.summary = const HrWorkspaceSummary(),
    this.queueSummaries = const <HrQueueSummary>[],
    this.timeline = const <HrTimelineItem>[],
    this.generatedAt,
  });

  final HrWorkspaceSummary summary;
  final List<HrQueueSummary> queueSummaries;
  final List<HrTimelineItem> timeline;
  final DateTime? generatedAt;

  HrWorkspaceOverview copyWith({
    HrWorkspaceSummary? summary,
    List<HrQueueSummary>? queueSummaries,
    List<HrTimelineItem>? timeline,
    DateTime? generatedAt,
  }) {
    return HrWorkspaceOverview(
      summary: summary ?? this.summary,
      queueSummaries: queueSummaries ?? this.queueSummaries,
      timeline: timeline ?? this.timeline,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

@immutable
final class HrWorkspaceSummary {
  const HrWorkspaceSummary({
    this.totalStaff = 0,
    this.leaveRequests = 0,
    this.swapRequests = 0,
    this.draftRosters = 0,
    this.unassignedShifts = 0,
    this.payrollDraftRuns = 0,
    this.overdueShifts = 0,
  });

  final int totalStaff;
  final int leaveRequests;
  final int swapRequests;
  final int draftRosters;
  final int unassignedShifts;
  final int payrollDraftRuns;
  final int overdueShifts;

  int get workloadCount {
    return leaveRequests +
        swapRequests +
        draftRosters +
        unassignedShifts +
        payrollDraftRuns +
        overdueShifts;
  }
}

@immutable
final class HrQueueSummary {
  const HrQueueSummary({
    required this.queue,
    this.count = 0,
    this.panel,
    this.resource,
  });

  final HrQueue queue;
  final int count;
  final String? panel;
  final String? resource;
}

@immutable
final class HrTimelineItem {
  const HrTimelineItem({
    required this.id,
    this.type,
    this.action,
    this.status,
    this.at,
  });

  final String id;
  final String? type;
  final String? action;
  final String? status;
  final DateTime? at;
}

@immutable
final class HrOption {
  const HrOption({
    required this.value,
    required this.label,
    this.displayId,
    this.extra = const <String, Object?>{},
  });

  final String value;
  final String label;
  final String? displayId;
  final Map<String, Object?> extra;
}

@immutable
final class HrReferenceData {
  const HrReferenceData({
    this.facilities = const <HrOption>[],
    this.departments = const <HrOption>[],
    this.staffProfiles = const <HrOption>[],
    this.staffPositions = const <HrOption>[],
    this.rosters = const <HrOption>[],
    this.payrollRuns = const <HrOption>[],
    this.shiftTemplates = const <HrOption>[],
    this.roles = const <HrOption>[],
    this.shiftTypes = const <HrOption>[],
    this.practitionerTypes = const <HrOption>[],
    this.resourceStatuses = const <String, List<HrOption>>{},
  });

  final List<HrOption> facilities;
  final List<HrOption> departments;
  final List<HrOption> staffProfiles;
  final List<HrOption> staffPositions;
  final List<HrOption> rosters;
  final List<HrOption> payrollRuns;
  final List<HrOption> shiftTemplates;
  final List<HrOption> roles;
  final List<HrOption> shiftTypes;
  final List<HrOption> practitionerTypes;
  final Map<String, List<HrOption>> resourceStatuses;
}

@immutable
final class HrStaffProfile {
  const HrStaffProfile({
    required this.id,
    this.displayId,
    this.tenantId,
    this.userId,
    this.userDisplayId,
    this.userFullName,
    this.userEmail,
    this.departmentId,
    this.departmentDisplayId,
    this.departmentName,
    this.staffNumber,
    this.position,
    this.practitionerType,
    this.consultationFee,
    this.consultationCurrency,
    this.hireDate,
    this.status,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? tenantId;
  final String? userId;
  final String? userDisplayId;
  final String? userFullName;
  final String? userEmail;
  final String? departmentId;
  final String? departmentDisplayId;
  final String? departmentName;
  final String? staffNumber;
  final String? position;
  final String? practitionerType;
  final num? consultationFee;
  final String? consultationCurrency;
  final DateTime? hireDate;
  final String? status;
  final DateTime? updatedAt;

  String get effectiveId => displayId ?? id;

  String get displayName {
    return _firstNonEmpty(<String?>[
          userFullName,
          userEmail,
          staffNumber,
          displayId,
          id,
        ]) ??
        id;
  }

  String get assignmentLine {
    return _joinDisplay(<String?>[
      position,
      practitionerType,
      departmentName ?? departmentDisplayId ?? departmentId,
    ]);
  }

  HrStaffProfile copyWith({
    String? displayId,
    String? tenantId,
    String? userId,
    String? userDisplayId,
    String? userFullName,
    String? userEmail,
    String? departmentId,
    String? departmentDisplayId,
    String? departmentName,
    String? staffNumber,
    String? position,
    String? practitionerType,
    num? consultationFee,
    String? consultationCurrency,
    DateTime? hireDate,
    String? status,
    DateTime? updatedAt,
  }) {
    return HrStaffProfile(
      id: id,
      displayId: displayId ?? this.displayId,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      userDisplayId: userDisplayId ?? this.userDisplayId,
      userFullName: userFullName ?? this.userFullName,
      userEmail: userEmail ?? this.userEmail,
      departmentId: departmentId ?? this.departmentId,
      departmentDisplayId: departmentDisplayId ?? this.departmentDisplayId,
      departmentName: departmentName ?? this.departmentName,
      staffNumber: staffNumber ?? this.staffNumber,
      position: position ?? this.position,
      practitionerType: practitionerType ?? this.practitionerType,
      consultationFee: consultationFee ?? this.consultationFee,
      consultationCurrency: consultationCurrency ?? this.consultationCurrency,
      hireDate: hireDate ?? this.hireDate,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
final class HrStaffDetail {
  const HrStaffDetail({
    required this.profile,
    this.assignments = const <HrStaffAssignment>[],
    this.leaves = const <HrStaffLeave>[],
    this.availabilities = const <HrStaffAvailability>[],
    this.shiftAssignments = const <HrShiftAssignment>[],
  });

  final HrStaffProfile profile;
  final List<HrStaffAssignment> assignments;
  final List<HrStaffLeave> leaves;
  final List<HrStaffAvailability> availabilities;
  final List<HrShiftAssignment> shiftAssignments;

  HrStaffDetail copyWith({
    HrStaffProfile? profile,
    List<HrStaffAssignment>? assignments,
    List<HrStaffLeave>? leaves,
    List<HrStaffAvailability>? availabilities,
    List<HrShiftAssignment>? shiftAssignments,
  }) {
    return HrStaffDetail(
      profile: profile ?? this.profile,
      assignments: assignments ?? this.assignments,
      leaves: leaves ?? this.leaves,
      availabilities: availabilities ?? this.availabilities,
      shiftAssignments: shiftAssignments ?? this.shiftAssignments,
    );
  }
}

@immutable
final class HrStaffAssignment {
  const HrStaffAssignment({
    required this.id,
    this.displayId,
    this.staffProfileId,
    this.departmentId,
    this.unitId,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String? displayId;
  final String? staffProfileId;
  final String? departmentId;
  final String? unitId;
  final DateTime? startDate;
  final DateTime? endDate;
}

@immutable
final class HrStaffLeave {
  const HrStaffLeave({
    required this.id,
    this.displayId,
    this.staffProfileId,
    this.status,
    this.startDate,
    this.endDate,
    this.reason,
  });

  final String id;
  final String? displayId;
  final String? staffProfileId;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? reason;

  String get effectiveId => displayId ?? id;
}

@immutable
final class HrStaffAvailability {
  const HrStaffAvailability({
    required this.id,
    this.displayId,
    this.staffProfileId,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.preference,
    this.effectiveFrom,
    this.effectiveTo,
  });

  final String id;
  final String? displayId;
  final String? staffProfileId;
  final int? dayOfWeek;
  final String? startTime;
  final String? endTime;
  final String? preference;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
}

@immutable
final class HrShiftAssignment {
  const HrShiftAssignment({
    required this.id,
    this.displayId,
    this.shiftId,
    this.staffProfileId,
    this.assignedAt,
  });

  final String id;
  final String? displayId;
  final String? shiftId;
  final String? staffProfileId;
  final DateTime? assignedAt;
}

@immutable
final class HrWorkItem {
  const HrWorkItem({
    required this.id,
    required this.queue,
    this.displayId,
    this.backendIdentifier,
    this.status,
    this.staffProfileId,
    this.staffName,
    this.staffNumber,
    this.staffPosition,
    this.shiftId,
    this.shiftType,
    this.rosterId,
    this.payrollRunId,
    this.periodLabel,
    this.startAt,
    this.endAt,
    this.timelineAt,
    this.assignmentCount = 0,
    this.reason,
  });

  final String id;
  final HrQueue queue;
  final String? displayId;
  final String? backendIdentifier;
  final String? status;
  final String? staffProfileId;
  final String? staffName;
  final String? staffNumber;
  final String? staffPosition;
  final String? shiftId;
  final String? shiftType;
  final String? rosterId;
  final String? payrollRunId;
  final String? periodLabel;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? timelineAt;
  final int assignmentCount;
  final String? reason;

  String get effectiveId => displayId ?? id;
}

@immutable
final class HrWorkspaceState {
  const HrWorkspaceState({
    required this.overview,
    required this.staffQuery,
    required this.staff,
    required this.workItemsQuery,
    required this.workItems,
    required this.referenceData,
    this.selectedStaff,
    this.lastFailure,
    this.isRefreshing = false,
    this.isRefreshingStaff = false,
    this.isRefreshingDetail = false,
    this.isRefreshingWorkItems = false,
    this.isMutating = false,
  });

  final HrWorkspaceOverview overview;
  final HrStaffQuery staffQuery;
  final AppPage<HrStaffProfile> staff;
  final HrWorkItemsQuery workItemsQuery;
  final AppPage<HrWorkItem> workItems;
  final HrReferenceData referenceData;
  final HrStaffDetail? selectedStaff;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingStaff;
  final bool isRefreshingDetail;
  final bool isRefreshingWorkItems;
  final bool isMutating;

  int get workloadCount => overview.summary.workloadCount;

  HrWorkspaceState copyWith({
    HrWorkspaceOverview? overview,
    HrStaffQuery? staffQuery,
    AppPage<HrStaffProfile>? staff,
    HrWorkItemsQuery? workItemsQuery,
    AppPage<HrWorkItem>? workItems,
    HrReferenceData? referenceData,
    HrStaffDetail? selectedStaff,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isRefreshingStaff,
    bool? isRefreshingDetail,
    bool? isRefreshingWorkItems,
    bool? isMutating,
    bool clearSelectedStaff = false,
    bool clearLastFailure = false,
  }) {
    return HrWorkspaceState(
      overview: overview ?? this.overview,
      staffQuery: staffQuery ?? this.staffQuery,
      staff: staff ?? this.staff,
      workItemsQuery: workItemsQuery ?? this.workItemsQuery,
      workItems: workItems ?? this.workItems,
      referenceData: referenceData ?? this.referenceData,
      selectedStaff: clearSelectedStaff
          ? null
          : selectedStaff ?? this.selectedStaff,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingStaff: isRefreshingStaff ?? this.isRefreshingStaff,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isRefreshingWorkItems:
          isRefreshingWorkItems ?? this.isRefreshingWorkItems,
      isMutating: isMutating ?? this.isMutating,
    );
  }
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

String _joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}
