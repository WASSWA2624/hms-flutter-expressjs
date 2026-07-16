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

enum HrDeskSection {
  staffDirectory,
  leaveRequests,
  shiftRoster,
  payroll,
  access;

  /// Canonical `?section=` query value for this tab.
  String get routeQueryValue {
    return switch (this) {
      HrDeskSection.staffDirectory => 'staff',
      HrDeskSection.leaveRequests => 'leave-requests',
      HrDeskSection.shiftRoster => 'shift-roster',
      HrDeskSection.payroll => 'payroll',
      HrDeskSection.access => 'access',
    };
  }

  /// Resolves a `?section=` / `?tab=` value to a desk section.
  static HrDeskSection? fromQuery(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'staff':
      case 'staff-directory':
      case 'directory':
        return HrDeskSection.staffDirectory;
      case 'leave':
      case 'leave-requests':
      case 'leaves':
        return HrDeskSection.leaveRequests;
      case 'shift':
      case 'shift-roster':
      case 'roster':
      case 'shifts':
        return HrDeskSection.shiftRoster;
      case 'payroll':
      case 'payroll-drafts':
        return HrDeskSection.payroll;
      case 'access':
      case 'roles':
      case 'permissions':
        return HrDeskSection.access;
      default:
        return null;
    }
  }

  /// Maps a work-queue deep-link onto the matching desk tab.
  static HrDeskSection? fromQueue(HrQueue? queue) {
    if (queue == null) {
      return null;
    }
    return switch (queue) {
      HrQueue.leaveRequests ||
      HrQueue.swapRequests => HrDeskSection.leaveRequests,
      HrQueue.rosterDrafts ||
      HrQueue.unassignedShifts ||
      HrQueue.overdueShifts => HrDeskSection.shiftRoster,
      HrQueue.payrollDrafts => HrDeskSection.payroll,
    };
  }
}

/// Deep-link targeting parsed from the `/hr` route query string.
///
/// Supports pre-selecting a staff profile (`?id=` / `?staff=`), opening a
/// management queue (`?queue=`), seeding directory search (`?search=`), or
/// selecting a desk tab (`?section=` / `?tab=`).
@immutable
final class HrWorkspaceQuery {
  const HrWorkspaceQuery({
    this.focusStaffId,
    this.queue,
    this.search = '',
    this.section = '',
  });

  /// Pre-select this staff profile (display id or uuid).
  final String? focusStaffId;

  /// Open this management queue when no staff target is provided.
  final HrQueue? queue;

  /// Seed the staff directory search when no staff target is provided.
  final String search;

  /// Active tab section parsed from `?section=` or `?tab=` query parameter.
  final String section;

  factory HrWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String? pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    final String? staffId = pick(<String>[
      'id',
      'staff',
      'staffId',
      'staff_id',
      'staff_profile_id',
    ]);
    return HrWorkspaceQuery(
      focusStaffId: staffId,
      queue: HrQueue.fromValue(pick(<String>['queue'])),
      search: staffId ?? pick(<String>['search', 'q']) ?? '',
      section: pick(<String>['section', 'tab']) ?? '',
    );
  }

  bool get hasRouteTargeting {
    return focusStaffId != null ||
        queue != null ||
        search.trim().isNotEmpty ||
        section.trim().isNotEmpty;
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
    this.from,
    this.to,
    this.pageRequest = const AppPageRequest(pageSize: 10),
  });

  final HrQueue queue;
  final String search;
  final String? status;
  final String? departmentId;
  final String? facilityId;
  final DateTime? from;
  final DateTime? to;
  final AppPageRequest pageRequest;

  HrWorkItemsQuery copyWith({
    HrQueue? queue,
    String? search,
    String? status,
    String? departmentId,
    String? facilityId,
    DateTime? from,
    DateTime? to,
    AppPageRequest? pageRequest,
    bool clearStatus = false,
    bool clearDepartmentId = false,
    bool clearFacilityId = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return HrWorkItemsQuery(
      queue: queue ?? this.queue,
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      departmentId: clearDepartmentId
          ? null
          : departmentId ?? this.departmentId,
      facilityId: clearFacilityId ? null : facilityId ?? this.facilityId,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
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
    this.labelKey,
    this.extra = const <String, Object?>{},
  });

  final String value;
  final String label;
  final String? displayId;
  final String? labelKey;
  final Map<String, Object?> extra;
}

@immutable
final class HrReferenceData {
  const HrReferenceData({
    this.facilities = const <HrOption>[],
    this.departments = const <HrOption>[],
    this.units = const <HrOption>[],
    this.rooms = const <HrOption>[],
    this.staffProfiles = const <HrOption>[],
    this.staffPositions = const <HrOption>[],
    this.rosters = const <HrOption>[],
    this.payrollRuns = const <HrOption>[],
    this.shiftTemplates = const <HrOption>[],
    this.shifts = const <HrOption>[],
    this.roles = const <HrOption>[],
    this.users = const <HrOption>[],
    this.shiftTypes = const <HrOption>[],
    this.leaveTypes = const <HrOption>[],
    this.leaveHalfDayPeriods = const <HrOption>[],
    this.practitionerTypes = const <HrOption>[],
    this.compensationPayTypes = const <HrOption>[],
    this.resourceStatuses = const <String, List<HrOption>>{},
  });

  final List<HrOption> facilities;
  final List<HrOption> departments;
  final List<HrOption> units;
  final List<HrOption> rooms;
  final List<HrOption> staffProfiles;
  final List<HrOption> staffPositions;
  final List<HrOption> rosters;
  final List<HrOption> payrollRuns;
  final List<HrOption> shiftTemplates;
  final List<HrOption> shifts;
  final List<HrOption> roles;
  final List<HrOption> users;
  final List<HrOption> shiftTypes;
  final List<HrOption> leaveTypes;
  final List<HrOption> leaveHalfDayPeriods;
  final List<HrOption> practitionerTypes;
  final List<HrOption> compensationPayTypes;
  final Map<String, List<HrOption>> resourceStatuses;
}

@immutable
final class HrStaffProfile {
  const HrStaffProfile({
    required this.id,
    this.displayId,
    this.tenantId,
    this.tenantDisplayId,
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
    this.compensations = const <HrStaffCompensation>[],
    this.hireDate,
    this.status,
    this.updatedAt,
    this.separationType,
    this.separationDate,
    this.separationNotes,
  });

  final String id;
  final String? displayId;
  final String? tenantId;
  final String? tenantDisplayId;
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
  final List<HrStaffCompensation> compensations;
  final DateTime? hireDate;
  final String? status;
  final DateTime? updatedAt;
  final String? separationType;
  final DateTime? separationDate;
  final String? separationNotes;

  bool get isSeparated =>
      (status ?? '').trim().toUpperCase() == 'SEPARATED' ||
      separationDate != null;

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
    String? tenantDisplayId,
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
    List<HrStaffCompensation>? compensations,
    DateTime? hireDate,
    String? status,
    DateTime? updatedAt,
    String? separationType,
    DateTime? separationDate,
    String? separationNotes,
  }) {
    return HrStaffProfile(
      id: id,
      displayId: displayId ?? this.displayId,
      tenantId: tenantId ?? this.tenantId,
      tenantDisplayId: tenantDisplayId ?? this.tenantDisplayId,
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
      compensations: compensations ?? this.compensations,
      hireDate: hireDate ?? this.hireDate,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      separationType: separationType ?? this.separationType,
      separationDate: separationDate ?? this.separationDate,
      separationNotes: separationNotes ?? this.separationNotes,
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
    this.compensations = const <HrStaffCompensation>[],
    this.shiftAssignments = const <HrShiftAssignment>[],
    this.accessSummary,
  });

  final HrStaffProfile profile;
  final List<HrStaffAssignment> assignments;
  final List<HrStaffLeave> leaves;
  final List<HrStaffAvailability> availabilities;
  final List<HrStaffCompensation> compensations;
  final List<HrShiftAssignment> shiftAssignments;
  final HrStaffAccessSummary? accessSummary;

  HrStaffDetail copyWith({
    HrStaffProfile? profile,
    List<HrStaffAssignment>? assignments,
    List<HrStaffLeave>? leaves,
    List<HrStaffAvailability>? availabilities,
    List<HrStaffCompensation>? compensations,
    List<HrShiftAssignment>? shiftAssignments,
    HrStaffAccessSummary? accessSummary,
    bool clearAccessSummary = false,
  }) {
    return HrStaffDetail(
      profile: profile ?? this.profile,
      assignments: assignments ?? this.assignments,
      leaves: leaves ?? this.leaves,
      availabilities: availabilities ?? this.availabilities,
      compensations: compensations ?? this.compensations,
      shiftAssignments: shiftAssignments ?? this.shiftAssignments,
      accessSummary: clearAccessSummary
          ? null
          : accessSummary ?? this.accessSummary,
    );
  }
}

@immutable
final class HrUserRole {
  const HrUserRole({
    required this.id,
    this.displayId,
    this.backendIdentifier,
    this.roleId,
    this.roleName,
    this.facilityId,
    this.facilityName,
    this.facilityDisplayId,
    this.tenantId,
  });

  final String id;
  final String? displayId;
  final String? backendIdentifier;
  final String? roleId;
  final String? roleName;
  final String? facilityId;
  final String? facilityName;
  final String? facilityDisplayId;
  final String? tenantId;

  String get effectiveId => displayId ?? id;
}

@immutable
final class HrModuleAccess {
  const HrModuleAccess({
    required this.slug,
    this.label,
    this.moduleGroup,
    this.granted = false,
  });

  final String slug;
  final String? label;
  final String? moduleGroup;
  final bool granted;
}

@immutable
final class HrStaffAccessSummary {
  const HrStaffAccessSummary({
    this.staffProfileId,
    this.linkedUserDisplayId,
    this.linkedUserEmail,
    this.linkedUserFullName,
    this.userRoles = const <HrUserRole>[],
    this.moduleAccess = const <HrModuleAccess>[],
    this.effectivePermissions = const <String>[],
  });

  final String? staffProfileId;
  final String? linkedUserDisplayId;
  final String? linkedUserEmail;
  final String? linkedUserFullName;
  final List<HrUserRole> userRoles;
  final List<HrModuleAccess> moduleAccess;
  final List<String> effectivePermissions;

  bool get hasLinkedUser =>
      (linkedUserDisplayId ?? linkedUserEmail ?? '').trim().isNotEmpty;
}

@immutable
final class HrPayrollCalculationComponent {
  const HrPayrollCalculationComponent({
    this.payType,
    this.rate = 0,
    this.currency,
    this.quantity = 0,
    this.unit,
    this.formula,
    this.amount = 0,
  });

  final String? payType;
  final num rate;
  final String? currency;
  final num quantity;
  final String? unit;
  final String? formula;
  final num amount;
}

@immutable
final class HrPayrollPreviewCalculation {
  const HrPayrollPreviewCalculation({
    this.components = const <HrPayrollCalculationComponent>[],
    this.warnings = const <HrPayrollPreviewWarning>[],
    this.eligibleWorkdays,
    this.mixedCurrency = false,
  });

  final List<HrPayrollCalculationComponent> components;
  final List<HrPayrollPreviewWarning> warnings;
  final int? eligibleWorkdays;
  final bool mixedCurrency;
}

@immutable
final class HrPayrollPreviewWarning {
  const HrPayrollPreviewWarning({this.payType, this.warning});

  final String? payType;
  final String? warning;
}

@immutable
final class HrPayrollPreviewItem {
  const HrPayrollPreviewItem({
    this.staffProfileId,
    this.staffProfileDisplayId,
    this.staffNumber,
    this.staffName,
    this.assignmentCount = 0,
    this.totalHours = 0,
    this.amount = 0,
    this.currency,
    this.calculation,
  });

  final String? staffProfileId;
  final String? staffProfileDisplayId;
  final String? staffNumber;
  final String? staffName;
  final int assignmentCount;
  final num totalHours;
  final num amount;
  final String? currency;
  final HrPayrollPreviewCalculation? calculation;
}

@immutable
final class HrPayrollPreview {
  const HrPayrollPreview({
    this.runId,
    this.runDisplayId,
    this.status,
    this.periodStart,
    this.periodEnd,
    this.items = const <HrPayrollPreviewItem>[],
    this.totalAmount = 0,
    this.totalHours = 0,
    this.staffCount = 0,
    this.currency,
  });

  final String? runId;
  final String? runDisplayId;
  final String? status;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final List<HrPayrollPreviewItem> items;
  final num totalAmount;
  final num totalHours;
  final int staffCount;
  final String? currency;
}

@immutable
final class HrRosterGenerateResult {
  const HrRosterGenerateResult({
    this.rosterDisplayId,
    this.dryRun = false,
    this.assignmentCount = 0,
    this.coveragePercent,
    this.gapCount = 0,
    this.summary,
  });

  final String? rosterDisplayId;
  final bool dryRun;
  final int assignmentCount;
  final num? coveragePercent;
  final int gapCount;
  final String? summary;
}

@immutable
final class HrStaffAssignment {
  const HrStaffAssignment({
    required this.id,
    this.displayId,
    this.staffProfileId,
    this.departmentId,
    this.departmentName,
    this.departmentDisplayId,
    this.unitId,
    this.unitName,
    this.unitDisplayId,
    this.roomId,
    this.roomName,
    this.roomDisplayId,
    this.startDate,
    this.endDate,
    this.isPrimary = false,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? staffProfileId;
  final String? departmentId;
  final String? departmentName;
  final String? departmentDisplayId;
  final String? unitId;
  final String? unitName;
  final String? unitDisplayId;
  final String? roomId;
  final String? roomName;
  final String? roomDisplayId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isPrimary;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveId => displayId ?? id;
}

@immutable
final class HrStaffLeave {
  const HrStaffLeave({
    required this.id,
    this.displayId,
    this.staffProfileId,
    this.leaveType,
    this.status,
    this.startDate,
    this.endDate,
    this.isHalfDay = false,
    this.halfDayPeriod,
    this.reason,
    this.handoverNotes,
    this.coveringStaffProfileId,
    this.coveringStaffName,
  });

  final String id;
  final String? displayId;
  final String? staffProfileId;
  final String? leaveType;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isHalfDay;
  final String? halfDayPeriod;
  final String? reason;
  final String? handoverNotes;
  final String? coveringStaffProfileId;
  final String? coveringStaffName;

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
    this.timeSlots = const <HrAvailabilitySlot>[],
    this.preference,
    this.status,
    this.effectiveFrom,
    this.effectiveTo,
  });

  final String id;
  final String? displayId;
  final String? staffProfileId;
  final int? dayOfWeek;
  final String? startTime;
  final String? endTime;
  final List<HrAvailabilitySlot> timeSlots;
  final String? preference;
  final String? status;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
}

@immutable
final class HrAvailabilitySlot {
  const HrAvailabilitySlot({required this.startTime, required this.endTime});

  final String startTime;
  final String endTime;
}

@immutable
final class HrStaffCompensation {
  const HrStaffCompensation({
    required this.id,
    this.displayId,
    this.staffProfileId,
    this.payType,
    this.rate,
    this.currency,
    this.effectiveFrom,
    this.effectiveTo,
    this.payFrequency,
  });

  final String id;
  final String? displayId;
  final String? staffProfileId;
  final String? payType;
  final num? rate;
  final String? currency;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final String? payFrequency;

  bool get isActive {
    final DateTime now = DateTime.now();
    if (effectiveTo != null && effectiveTo!.isBefore(now)) {
      return false;
    }
    return true;
  }
}

@immutable
final class HrShiftAssignment {
  const HrShiftAssignment({
    required this.id,
    this.displayId,
    this.shiftId,
    this.shiftName,
    this.shiftType,
    this.shiftStatus,
    this.rosterPeriodLabel,
    this.staffProfileId,
    this.assignedAt,
  });

  final String id;
  final String? displayId;
  final String? shiftId;
  final String? shiftName;
  final String? shiftType;
  final String? shiftStatus;
  final String? rosterPeriodLabel;
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
    this.leaveType,
    this.isHalfDay = false,
    this.halfDayPeriod,
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
  final String? leaveType;
  final bool isHalfDay;
  final String? halfDayPeriod;
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
    this.openStaffDetailAfterOnboarding = false,
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
  final bool openStaffDetailAfterOnboarding;

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
    bool? openStaffDetailAfterOnboarding,
    bool clearSelectedStaff = false,
    bool clearLastFailure = false,
    bool clearOpenStaffDetailAfterOnboarding = false,
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
      openStaffDetailAfterOnboarding: clearOpenStaffDetailAfterOnboarding
          ? false
          : openStaffDetailAfterOnboarding ??
                this.openStaffDetailAfterOnboarding,
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

enum HrAccessPanel {
  users('users'),
  roles('roles'),
  permissions('permissions');

  const HrAccessPanel(this.serverValue);

  final String serverValue;
}

@immutable
final class HrAccessQuery {
  const HrAccessQuery({
    this.panel = HrAccessPanel.users,
    this.search = '',
    this.tenantId,
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  final HrAccessPanel panel;
  final String search;
  final String? tenantId;
  final AppPageRequest pageRequest;

  HrAccessQuery copyWith({
    HrAccessPanel? panel,
    String? search,
    Object? tenantId = _hrAccessUnset,
    AppPageRequest? pageRequest,
  }) {
    return HrAccessQuery(
      panel: panel ?? this.panel,
      search: search ?? this.search,
      tenantId: identical(tenantId, _hrAccessUnset)
          ? this.tenantId
          : tenantId as String?,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }

  static const Object _hrAccessUnset = Object();
}

@immutable
final class HrAccessUser {
  const HrAccessUser({
    required this.id,
    this.displayId,
    this.email,
    this.phone,
    this.positionTitle,
    this.status,
    this.profileName,
    this.roleNames = const <String>[],
    this.roleIds = const <String>[],
    this.directPermissionNames = const <String>[],
    this.staffProfileId,
    this.staffProfileName,
  });

  final String id;
  final String? displayId;
  final String? email;
  final String? phone;
  final String? positionTitle;
  final String? status;
  final String? profileName;
  final List<String> roleNames;
  final List<String> roleIds;
  final List<String> directPermissionNames;
  final String? staffProfileId;
  final String? staffProfileName;

  String get effectiveId => displayId ?? id;

  String get displayLabel => profileName ?? email ?? effectiveId;
}

@immutable
final class HrAccessUserDetail {
  const HrAccessUserDetail({
    required this.id,
    this.displayId,
    this.email,
    this.phone,
    this.positionTitle,
    this.status,
    this.profileName,
    this.staffProfileId,
    this.staffProfileName,
    this.userRoles = const <HrUserRole>[],
    this.directPermissions = const <HrAccessPermission>[],
    this.effectivePermissionLabels = const <String>[],
  });

  final String id;
  final String? displayId;
  final String? email;
  final String? phone;
  final String? positionTitle;
  final String? status;
  final String? profileName;
  final String? staffProfileId;
  final String? staffProfileName;
  final List<HrUserRole> userRoles;
  final List<HrAccessPermission> directPermissions;
  final List<String> effectivePermissionLabels;

  String get effectiveId => displayId ?? id;

  List<String> get roleNames => userRoles
      .map((HrUserRole role) => role.roleName)
      .whereType<String>()
      .toList(growable: false);

  HrAccessUser toSummary() {
    return HrAccessUser(
      id: id,
      displayId: displayId,
      email: email,
      phone: phone,
      positionTitle: positionTitle,
      status: status,
      profileName: profileName,
      roleNames: roleNames,
      roleIds: userRoles
          .map((HrUserRole role) => role.roleId)
          .whereType<String>()
          .toList(growable: false),
      directPermissionNames: directPermissions
          .map((HrAccessPermission permission) => permission.name)
          .whereType<String>()
          .toList(growable: false),
      staffProfileId: staffProfileId,
      staffProfileName: staffProfileName,
    );
  }
}

@immutable
final class HrAccessRole {
  const HrAccessRole({
    required this.id,
    this.displayId,
    this.name,
    this.displayName,
    this.description,
    this.permissionCount = 0,
    this.userCount = 0,
    this.isSystemCritical = false,
  });

  final String id;
  final String? displayId;
  final String? name;
  final String? displayName;
  final String? description;
  final int permissionCount;
  final int userCount;
  final bool isSystemCritical;

  String get effectiveId => displayId ?? id;

  String get effectiveDisplayName =>
      (displayName != null && displayName!.trim().isNotEmpty)
      ? displayName!.trim()
      : (name ?? effectiveId);
}

@immutable
final class HrAccessPermission {
  const HrAccessPermission({
    required this.id,
    this.displayId,
    this.name,
    this.description,
    this.roleCount = 0,
  });

  final String id;
  final String? displayId;
  final String? name;
  final String? description;
  final int roleCount;

  String get effectiveId => displayId ?? id;
}
