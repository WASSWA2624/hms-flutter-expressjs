import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/data/data.dart';

const List<String> theaterCaseStatuses = <String>[
  'SCHEDULED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
];

const List<String> theaterWorkflowStages = <String>[
  'PRE_OP',
  'SIGN_IN',
  'TIME_OUT',
  'INTRA_OP',
  'SIGN_OUT',
  'POST_OP',
  'PACU_HANDOFF',
  'COMPLETED',
];

const List<String> theaterChecklistPhases = <String>[
  'PRE_OP',
  'SIGN_IN',
  'TIME_OUT',
  'SIGN_OUT',
  'PACU_HANDOFF',
];

const List<String> theaterRecordStatuses = <String>['DRAFT', 'FINAL'];

const List<String> theaterResourceTypes = <String>[
  'ROOM',
  'STAFF',
  'EQUIPMENT',
];

const List<String> theaterStaffRoles = <String>['SURGEON', 'ANESTHETIST'];

const List<String> theaterFinalizeRecordTypes = <String>[
  'ANESTHESIA',
  'POST_OP',
  'ALL',
];

enum TheaterDetailPanel { checklist, anesthesia, postop, resources }

extension TheaterDetailPanelX on TheaterDetailPanel {
  static TheaterDetailPanel? fromValue(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    return switch (normalized) {
      'checklist' => TheaterDetailPanel.checklist,
      'anesthesia' => TheaterDetailPanel.anesthesia,
      'postop' || 'post-op' || 'post_op' => TheaterDetailPanel.postop,
      'resources' => TheaterDetailPanel.resources,
      _ => null,
    };
  }
}

@immutable
final class TheaterBoardQuery {
  const TheaterBoardQuery({
    this.search = '',
    this.status,
    this.stage,
    this.scheduledDate,
    this.roomId,
    this.surgeonUserId,
    this.anesthetistUserId,
    this.queueScope = 'ACTIVE',
    this.pageRequest = const AppPageRequest(),
    this.focusCaseId,
    this.focusPanel,
    this.initialPatientId,
    this.initialEncounterId,
    this.initialEmergencyCaseId,
    this.scheduleAction,
  });

  final String search;
  final String? status;
  final String? stage;
  final DateTime? scheduledDate;
  final String? roomId;
  final String? surgeonUserId;
  final String? anesthetistUserId;
  final String queueScope;
  final AppPageRequest pageRequest;
  final String? focusCaseId;
  final TheaterDetailPanel? focusPanel;
  final String? initialPatientId;
  final String? initialEncounterId;
  final String? initialEmergencyCaseId;
  final String? scheduleAction;

  bool get hasScheduleContext =>
      (initialPatientId ?? '').trim().isNotEmpty ||
      (initialEncounterId ?? '').trim().isNotEmpty ||
      (initialEmergencyCaseId ?? '').trim().isNotEmpty;

  bool get shouldOpenScheduleDialog {
    final String action = (scheduleAction ?? '').trim().toLowerCase();
    return hasScheduleContext &&
        (action == 'schedule' || action == 'schedule_case');
  }

  bool get hasRouteTargeting =>
      (focusCaseId ?? '').trim().isNotEmpty || focusPanel != null;

  TheaterCaseQuery toCaseQuery() {
    return TheaterCaseQuery(
      search: search,
      status: status,
      stage: stage,
      scheduledDate: scheduledDate,
      roomId: roomId,
      surgeonUserId: surgeonUserId,
      anesthetistUserId: anesthetistUserId,
      queueScope: queueScope,
      pageRequest: pageRequest,
    );
  }

  factory TheaterBoardQuery.fromUri(Uri uri) {
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

    final String? focusId = pick(<String>['id', 'case', 'caseId', 'case_id']);
    return TheaterBoardQuery(
      search: focusId ?? pick(<String>['search', 'q']) ?? '',
      focusCaseId: focusId,
      focusPanel: TheaterDetailPanelX.fromValue(params['panel']),
      initialPatientId: pick(<String>['patient_id', 'patientId', 'patient']),
      initialEncounterId: pick(<String>[
        'encounter_id',
        'encounterId',
        'encounter',
      ]),
      initialEmergencyCaseId: pick(<String>[
        'emergency_case_id',
        'emergencyCaseId',
        'emergency_case',
      ]),
      scheduleAction: pick(<String>['action']),
    );
  }

  TheaterBoardQuery copyWith({
    String? search,
    String? status,
    String? stage,
    DateTime? scheduledDate,
    String? roomId,
    String? surgeonUserId,
    String? anesthetistUserId,
    String? queueScope,
    AppPageRequest? pageRequest,
    String? focusCaseId,
    TheaterDetailPanel? focusPanel,
    String? initialPatientId,
    String? initialEncounterId,
    String? initialEmergencyCaseId,
    String? scheduleAction,
    bool clearStatus = false,
    bool clearStage = false,
    bool clearScheduledDate = false,
    bool clearRoomId = false,
    bool clearSurgeonUserId = false,
    bool clearAnesthetistUserId = false,
    bool clearFocus = false,
    bool clearScheduleContext = false,
  }) {
    return TheaterBoardQuery(
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      stage: clearStage ? null : stage ?? this.stage,
      scheduledDate: clearScheduledDate
          ? null
          : scheduledDate ?? this.scheduledDate,
      roomId: clearRoomId ? null : roomId ?? this.roomId,
      surgeonUserId: clearSurgeonUserId
          ? null
          : surgeonUserId ?? this.surgeonUserId,
      anesthetistUserId: clearAnesthetistUserId
          ? null
          : anesthetistUserId ?? this.anesthetistUserId,
      queueScope: queueScope ?? this.queueScope,
      pageRequest: pageRequest ?? this.pageRequest,
      focusCaseId: clearFocus ? null : focusCaseId ?? this.focusCaseId,
      focusPanel: clearFocus ? null : focusPanel ?? this.focusPanel,
      initialPatientId: clearScheduleContext
          ? null
          : initialPatientId ?? this.initialPatientId,
      initialEncounterId: clearScheduleContext
          ? null
          : initialEncounterId ?? this.initialEncounterId,
      initialEmergencyCaseId: clearScheduleContext
          ? null
          : initialEmergencyCaseId ?? this.initialEmergencyCaseId,
      scheduleAction: clearScheduleContext
          ? null
          : scheduleAction ?? this.scheduleAction,
    );
  }
}

String? deriveTheaterSourceKind(String? encounterType) {
  final String type = (encounterType ?? '').trim().toUpperCase();
  return switch (type) {
    'EMERGENCY' => 'EMERGENCY',
    'OPD' || 'TELEMEDICINE' => 'OPD',
    'IPD' || 'ICU' || 'THEATRE' || 'INPATIENT' => 'IPD',
    _ => null,
  };
}

@immutable
final class TheaterSchedulePatient {
  const TheaterSchedulePatient({
    required this.id,
    this.displayId,
    this.displayName,
    this.identifier,
    this.primaryPhone,
  });

  final String id;
  final String? displayId;
  final String? displayName;
  final String? identifier;
  final String? primaryPhone;

  String get displayTitle {
    return _firstNonEmpty(<String?>[displayName, displayId, id]) ?? id;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[displayId, identifier, primaryPhone]);
  }

  String get searchText {
    return _joinDisplay(<String?>[
          id,
          displayId,
          displayName,
          identifier,
          primaryPhone,
        ]) ??
        displayTitle;
  }
}

@immutable
final class TheaterScheduleEncounter {
  const TheaterScheduleEncounter({
    required this.id,
    this.displayId,
    this.title,
    this.status,
    this.type,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String? displayId;
  final String? title;
  final String? status;
  final String? type;
  final DateTime? startedAt;
  final DateTime? endedAt;

  String? get sourceKind => deriveTheaterSourceKind(type);

  String get displayTitle {
    final String? kindLabel = _theaterEncounterKindLabel(type);
    final String? dateLabel = startedAt == null
        ? null
        : '${startedAt!.year.toString().padLeft(4, '0')}-'
              '${startedAt!.month.toString().padLeft(2, '0')}-'
              '${startedAt!.day.toString().padLeft(2, '0')}';
    return _joinDisplay(<String?>[kindLabel, dateLabel, displayId, title]) ??
        id;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[type, status, displayId]);
  }

  String get searchText {
    return _joinDisplay(<String?>[id, displayId, title, status, type]) ??
        displayTitle;
  }
}

@immutable
final class TheaterSchedulePatientDetail {
  const TheaterSchedulePatientDetail({
    required this.patient,
    this.encounters = const <TheaterScheduleEncounter>[],
    this.emergencyCases = const <TheaterScheduleEmergencyCase>[],
  });

  final TheaterSchedulePatient patient;
  final List<TheaterScheduleEncounter> encounters;
  final List<TheaterScheduleEmergencyCase> emergencyCases;
}

@immutable
final class TheaterScheduleEmergencyCase {
  const TheaterScheduleEmergencyCase({
    required this.id,
    this.displayId,
    this.severity,
    this.status,
    this.createdAt,
  });

  final String id;
  final String? displayId;
  final String? severity;
  final String? status;
  final DateTime? createdAt;

  bool get isOpen {
    return switch ((status ?? '').toUpperCase()) {
      'OPEN' || 'PENDING' || 'IN_PROGRESS' => true,
      _ => false,
    };
  }

  String get displayTitle {
    return _firstNonEmpty(<String?>[displayId, id]) ?? id;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[severity, status]);
  }

  String get searchText {
    return _joinDisplay(<String?>[id, displayId, severity, status]) ??
        displayTitle;
  }
}

int compareTheaterScheduleEncounters(
  TheaterScheduleEncounter left,
  TheaterScheduleEncounter right,
) {
  int priority(String? type) {
    return switch ((type ?? '').trim().toUpperCase()) {
      'EMERGENCY' => 0,
      'THEATRE' => 1,
      'IPD' || 'ICU' || 'INPATIENT' => 2,
      'OPD' || 'TELEMEDICINE' => 3,
      _ => 4,
    };
  }

  final int byPriority = priority(left.type).compareTo(priority(right.type));
  if (byPriority != 0) {
    return byPriority;
  }
  final DateTime leftAt = left.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final DateTime rightAt =
      right.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return rightAt.compareTo(leftAt);
}

@immutable
final class TheaterRoomOption {
  const TheaterRoomOption({
    required this.id,
    required this.name,
    this.wardName,
    this.floor,
  });

  final String id;
  final String name;
  final String? wardName;
  final String? floor;

  String get displayTitle => name;

  String? get displaySubtitle {
    return _joinDisplay(<String?>[wardName, floor]);
  }

  String get searchText {
    return _joinDisplay(<String?>[id, name, wardName, floor]) ?? name;
  }

  bool get isLikelyTheatreRoom {
    final String haystack =
        '${name.toLowerCase()} ${(wardName ?? '').toLowerCase()}';
    return haystack.contains('ot') ||
        haystack.contains('theatre') ||
        haystack.contains('theater') ||
        haystack.contains('operating');
  }
}

@immutable
final class TheaterStaffOption {
  const TheaterStaffOption({
    required this.id,
    required this.displayLabel,
    this.email,
    this.phone,
    this.positionTitle,
  });

  final String id;
  final String displayLabel;
  final String? email;
  final String? phone;
  final String? positionTitle;

  String get searchableLabel {
    return _joinDisplay(<String?>[
          displayLabel,
          email,
          phone,
          positionTitle,
          id,
        ]) ??
        id;
  }

  bool matchesRole(String? role) {
    if (role == null || role.trim().isEmpty) {
      return true;
    }
    final String haystack = '${positionTitle ?? ''} $displayLabel'
        .toLowerCase();
    return switch (role.trim().toUpperCase()) {
      'SURGEON' => haystack.contains('surgeon') || haystack.contains('surgery'),
      'ANESTHETIST' =>
        haystack.contains('anesth') || haystack.contains('anaesth'),
      _ => true,
    };
  }
}

String? _theaterEncounterKindLabel(String? encounterType) {
  final String type = (encounterType ?? '').trim().toUpperCase();
  return switch (type) {
    'IPD' || 'INPATIENT' => 'IPD',
    'ICU' => 'IPD',
    'OPD' => 'OPD',
    'EMERGENCY' => 'Emergency',
    'THEATRE' => 'Theatre',
    _ => type.isEmpty ? null : type,
  };
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String? _joinDisplay(Iterable<String?> values) {
  final List<String> parts = <String>[];
  for (final String? value in values) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isNotEmpty && !parts.contains(trimmed)) {
      parts.add(trimmed);
    }
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

@immutable
final class TheaterCaseQuery {
  const TheaterCaseQuery({
    this.search = '',
    this.status,
    this.stage,
    this.scheduledDate,
    this.roomId,
    this.surgeonUserId,
    this.anesthetistUserId,
    this.queueScope = 'ACTIVE',
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final String? status;
  final String? stage;
  final DateTime? scheduledDate;
  final String? roomId;
  final String? surgeonUserId;
  final String? anesthetistUserId;
  final String queueScope;
  final AppPageRequest pageRequest;

  TheaterCaseQuery copyWith({
    String? search,
    String? status,
    String? stage,
    DateTime? scheduledDate,
    String? roomId,
    String? surgeonUserId,
    String? anesthetistUserId,
    String? queueScope,
    AppPageRequest? pageRequest,
    bool clearStatus = false,
    bool clearStage = false,
    bool clearScheduledDate = false,
    bool clearRoomId = false,
    bool clearSurgeonUserId = false,
    bool clearAnesthetistUserId = false,
  }) {
    return TheaterCaseQuery(
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      stage: clearStage ? null : stage ?? this.stage,
      scheduledDate: clearScheduledDate
          ? null
          : scheduledDate ?? this.scheduledDate,
      roomId: clearRoomId ? null : roomId ?? this.roomId,
      surgeonUserId: clearSurgeonUserId
          ? null
          : surgeonUserId ?? this.surgeonUserId,
      anesthetistUserId: clearAnesthetistUserId
          ? null
          : anesthetistUserId ?? this.anesthetistUserId,
      queueScope: queueScope ?? this.queueScope,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class TheaterWorkspaceState {
  const TheaterWorkspaceState({
    required this.cases,
    required this.query,
    this.selectedCase,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isMutating = false,
    this.lastFailure,
  });

  final AppPage<TheaterCase> cases;
  final TheaterCaseQuery query;
  final TheaterCase? selectedCase;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isMutating;
  final AppFailure? lastFailure;

  int get workloadCount {
    return cases.items.where((TheaterCase item) => item.isActive).length;
  }

  int get scheduledCount {
    return cases.items
        .where((TheaterCase item) => item.normalizedStatus == 'SCHEDULED')
        .length;
  }

  int get inTheaterCount {
    return cases.items
        .where((TheaterCase item) => item.normalizedStatus == 'IN_PROGRESS')
        .length;
  }

  int get completedCount {
    return cases.items
        .where((TheaterCase item) => item.normalizedStatus == 'COMPLETED')
        .length;
  }

  int get cancelledCount {
    return cases.items
        .where((TheaterCase item) => item.normalizedStatus == 'CANCELLED')
        .length;
  }

  int get readyCount {
    return cases.items.where((TheaterCase item) => item.isReady).length;
  }

  TheaterWorkspaceState copyWith({
    AppPage<TheaterCase>? cases,
    TheaterCaseQuery? query,
    TheaterCase? selectedCase,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isMutating,
    AppFailure? lastFailure,
    bool clearSelectedCase = false,
    bool clearLastFailure = false,
  }) {
    return TheaterWorkspaceState(
      cases: cases ?? this.cases,
      query: query ?? this.query,
      selectedCase: clearSelectedCase
          ? null
          : selectedCase ?? this.selectedCase,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isMutating: isMutating ?? this.isMutating,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
    );
  }
}

@immutable
final class TheaterCase {
  const TheaterCase({
    required this.id,
    this.displayId,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.status,
    this.workflowStage,
    this.stageNotes,
    this.encounterDisplayId,
    this.patientDisplayId,
    this.patientDisplayName,
    this.roomDisplayId,
    this.roomDisplayLabel,
    this.surgeonUserDisplayId,
    this.surgeonDisplayName,
    this.anesthetistUserDisplayId,
    this.anesthetistDisplayName,
    this.procedureName,
    this.sourceKind,
    this.admissionDisplayId,
    this.emergencyCaseDisplayId,
    this.handoverDestination,
    this.anesthesiaRecordDisplayId,
    this.postOpNoteDisplayId,
    this.anesthesiaStatus,
    this.postOpStatus,
    this.checklistCompleted = 0,
    this.checklistTotal = 0,
    this.createdAt,
    this.updatedAt,
    this.checklistItems = const <TheaterChecklistItem>[],
    this.resourceAllocations = const <TheaterResourceAllocation>[],
    this.anesthesiaObservations = const <TheaterAnesthesiaObservation>[],
    this.anesthesiaRecords = const <TheaterClinicalRecord>[],
    this.postOpNotes = const <TheaterClinicalRecord>[],
    this.timeline = const <TheaterTimelineItem>[],
  });

  final String id;
  final String? displayId;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? status;
  final String? workflowStage;
  final String? stageNotes;
  final String? encounterDisplayId;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final String? roomDisplayId;
  final String? roomDisplayLabel;
  final String? surgeonUserDisplayId;
  final String? surgeonDisplayName;
  final String? anesthetistUserDisplayId;
  final String? anesthetistDisplayName;
  final String? procedureName;
  final String? sourceKind;
  final String? admissionDisplayId;
  final String? emergencyCaseDisplayId;
  final String? handoverDestination;
  final String? anesthesiaRecordDisplayId;
  final String? postOpNoteDisplayId;
  final String? anesthesiaStatus;
  final String? postOpStatus;
  final int checklistCompleted;
  final int checklistTotal;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<TheaterChecklistItem> checklistItems;
  final List<TheaterResourceAllocation> resourceAllocations;
  final List<TheaterAnesthesiaObservation> anesthesiaObservations;
  final List<TheaterClinicalRecord> anesthesiaRecords;
  final List<TheaterClinicalRecord> postOpNotes;
  final List<TheaterTimelineItem> timeline;

  String get normalizedStatus => (status ?? '').trim().toUpperCase();

  String get normalizedStage => (workflowStage ?? '').trim().toUpperCase();

  bool get isActive {
    return normalizedStatus == 'SCHEDULED' || normalizedStatus == 'IN_PROGRESS';
  }

  bool get isReady {
    return checklistTotal > 0 && checklistCompleted >= checklistTotal;
  }

  bool get hasFinalAnesthesia {
    return (anesthesiaStatus ?? '').trim().toUpperCase() == 'FINAL';
  }

  bool get hasFinalPostOp {
    return (postOpStatus ?? '').trim().toUpperCase() == 'FINAL';
  }

  String get effectiveDisplayId => displayId ?? id;

  TheaterClinicalRecord? get latestAnesthesiaRecord {
    return anesthesiaRecords.isEmpty ? null : anesthesiaRecords.first;
  }

  TheaterClinicalRecord? get latestPostOpNote {
    return postOpNotes.isEmpty ? null : postOpNotes.first;
  }

  String get responsibleRoleLabel {
    return switch (normalizedStage) {
      'PRE_OP' => 'NURSE',
      'SIGN_IN' || 'TIME_OUT' || 'SIGN_OUT' => 'TEAM',
      'INTRA_OP' => 'SURGEON',
      'POST_OP' || 'PACU_HANDOFF' => 'ANESTHETIST',
      _ => 'COORDINATOR',
    };
  }
}

@immutable
final class TheaterChecklistItem {
  const TheaterChecklistItem({
    required this.id,
    this.phase,
    this.itemCode,
    this.itemLabel,
    this.isChecked = false,
    this.checkedAt,
    this.notes,
  });

  final String id;
  final String? phase;
  final String? itemCode;
  final String? itemLabel;
  final bool isChecked;
  final DateTime? checkedAt;
  final String? notes;
}

@immutable
final class TheaterResourceAllocation {
  const TheaterResourceAllocation({
    required this.id,
    this.resourceType,
    this.resourceDisplayId,
    this.resourceLabel,
    this.assignedAt,
    this.releasedAt,
    this.notes,
  });

  final String id;
  final String? resourceType;
  final String? resourceDisplayId;
  final String? resourceLabel;
  final DateTime? assignedAt;
  final DateTime? releasedAt;
  final String? notes;

  bool get isActive => releasedAt == null;
}

@immutable
final class TheaterAnesthesiaObservation {
  const TheaterAnesthesiaObservation({
    required this.id,
    this.observedAt,
    this.observationType,
    this.metricKey,
    this.metricValue,
    this.unit,
    this.notes,
  });

  final String id;
  final DateTime? observedAt;
  final String? observationType;
  final String? metricKey;
  final String? metricValue;
  final String? unit;
  final String? notes;
}

@immutable
final class TheaterClinicalRecord {
  const TheaterClinicalRecord({
    required this.id,
    this.recordStatus,
    this.notes,
    this.anesthetistDisplayName,
    this.finalizedAt,
    this.reopenedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? recordStatus;
  final String? notes;
  final String? anesthetistDisplayName;
  final DateTime? finalizedAt;
  final DateTime? reopenedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class TheaterTimelineItem {
  const TheaterTimelineItem({
    required this.type,
    required this.label,
    this.occurredAt,
  });

  final String type;
  final String label;
  final DateTime? occurredAt;
}
