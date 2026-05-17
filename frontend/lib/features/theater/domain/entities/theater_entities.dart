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
    return cases.items
        .where((TheaterCase item) => item.isActive)
        .length;
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
      selectedCase: clearSelectedCase ? null : selectedCase ?? this.selectedCase,
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
