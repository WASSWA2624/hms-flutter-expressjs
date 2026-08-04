import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum IpdQueueScope {
  admissionQueue,
  activePatients,
  transferPending,
  dischargePlanned,
  awaitingClearance,
  discharged,
  all,
}

enum IpdWorkspaceSection {
  admissionQueue,
  activePatients,
  transferPending,
  dischargePlanned,
  bedBoard,
  followUps,
}

extension IpdWorkspaceSectionX on IpdWorkspaceSection {
  IpdQueueScope? get queueScope => switch (this) {
    IpdWorkspaceSection.admissionQueue => IpdQueueScope.admissionQueue,
    IpdWorkspaceSection.activePatients => IpdQueueScope.activePatients,
    IpdWorkspaceSection.transferPending => IpdQueueScope.transferPending,
    IpdWorkspaceSection.dischargePlanned => IpdQueueScope.dischargePlanned,
    IpdWorkspaceSection.bedBoard || IpdWorkspaceSection.followUps => null,
  };

  bool get isBedBoard => this == IpdWorkspaceSection.bedBoard;

  bool get isFollowUps => this == IpdWorkspaceSection.followUps;

  static IpdWorkspaceSection fromQueryParam(String? value) {
    return switch ((value ?? '').trim().toLowerCase()) {
      'admission-queue' ||
      'admission_queue' ||
      'admissionqueue' ||
      'queue' => IpdWorkspaceSection.admissionQueue,
      'active' ||
      'active-patients' ||
      'active_patients' ||
      'activepatients' => IpdWorkspaceSection.activePatients,
      'transfers' ||
      'transfer-pending' ||
      'transfer_pending' ||
      'transferpending' => IpdWorkspaceSection.transferPending,
      'discharge' ||
      'discharge-planned' ||
      'discharge_planned' ||
      'dischargeplanned' => IpdWorkspaceSection.dischargePlanned,
      'bed-board' ||
      'bed_board' ||
      'bedboard' ||
      'beds' => IpdWorkspaceSection.bedBoard,
      'follow-ups' ||
      'follow_ups' ||
      'followups' => IpdWorkspaceSection.followUps,
      _ => IpdWorkspaceSection.admissionQueue,
    };
  }
}

@immutable
final class IpdAdmissionQuery {
  const IpdAdmissionQuery({
    this.search = '',
    this.searchField,
    this.scope = IpdQueueScope.admissionQueue,
    this.wardId,
    this.transferStatus,
    this.hasActiveBed,
    this.hasCriticalAlert,
    this.criticalSeverity,
    this.icuQueueScope,
    this.icuStatus,
    this.patientId,
    this.admittedFrom,
    this.admittedTo,
    this.pageRequest = const AppPageRequest(),
    this.focusAdmissionId,
    this.focusPanel,
    this.focusAction,
    this.section = IpdWorkspaceSection.admissionQueue,
  });

  final String search;
  final String? searchField;
  final IpdQueueScope scope;
  final String? wardId;
  final String? transferStatus;
  final bool? hasActiveBed;
  final bool? hasCriticalAlert;
  final String? criticalSeverity;
  final String? icuQueueScope;
  final String? icuStatus;
  final String? patientId;
  final DateTime? admittedFrom;
  final DateTime? admittedTo;
  final AppPageRequest pageRequest;

  /// Deep-link target: pre-select this admission (display id or uuid).
  final String? focusAdmissionId;

  /// Deep-link target: open this mutation surface (no empty detail shell).
  final IpdDetailPanel? focusPanel;

  /// Deep-link target: focused write (`approve`, `start`, `complete`, …).
  final String? focusAction;

  final IpdWorkspaceSection section;

  factory IpdAdmissionQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    final String? admissionId = _nonEmpty(
      params['id'] ??
          params['admission'] ??
          params['admissionId'] ??
          params['admission_id'],
    );
    final IpdWorkspaceSection section = IpdWorkspaceSectionX.fromQueryParam(
      params['section'],
    );
    return IpdAdmissionQuery(
      search: admissionId ?? params['search'] ?? '',
      scope: section.queueScope ?? IpdQueueScope.admissionQueue,
      wardId: _nonEmpty(params['wardId'] ?? params['ward']),
      transferStatus: _nonEmpty(params['transferStatus'] ?? params['transfer_status']),
      patientId: _nonEmpty(params['patientId'] ?? params['patient_id']),
      focusAdmissionId: admissionId,
      focusPanel: IpdDetailPanelX.fromToken(params['panel']),
      focusAction: _nonEmpty(params['action'])?.toLowerCase(),
      section: section,
    );
  }

  bool get hasRouteTargeting {
    return search.trim().isNotEmpty ||
        wardId != null ||
        focusAdmissionId != null ||
        section != IpdWorkspaceSection.admissionQueue;
  }

  bool get hasFocusedMutation {
    return focusAdmissionId != null &&
        (focusPanel != null || (focusAction ?? '').isNotEmpty);
  }

  bool get hasAdvancedFilters {
    return wardId != null ||
        transferStatus != null ||
        hasActiveBed != null ||
        hasCriticalAlert != null ||
        criticalSeverity != null ||
        icuQueueScope != null ||
        icuStatus != null ||
        patientId != null ||
        admittedFrom != null ||
        admittedTo != null ||
        (searchField != null && searchField!.trim().isNotEmpty);
  }

  IpdAdmissionQuery copyWith({
    String? search,
    String? searchField,
    IpdQueueScope? scope,
    String? wardId,
    String? transferStatus,
    bool? hasActiveBed,
    bool? hasCriticalAlert,
    String? criticalSeverity,
    String? icuQueueScope,
    String? icuStatus,
    String? patientId,
    DateTime? admittedFrom,
    DateTime? admittedTo,
    AppPageRequest? pageRequest,
    String? focusAdmissionId,
    IpdDetailPanel? focusPanel,
    String? focusAction,
    IpdWorkspaceSection? section,
    bool clearWard = false,
    bool clearTransferStatus = false,
    bool clearHasActiveBed = false,
    bool clearHasCriticalAlert = false,
    bool clearCriticalSeverity = false,
    bool clearIcuQueueScope = false,
    bool clearIcuStatus = false,
    bool clearPatientId = false,
    bool clearAdmittedFrom = false,
    bool clearAdmittedTo = false,
    bool clearSearchField = false,
    bool clearFocus = false,
  }) {
    return IpdAdmissionQuery(
      search: search ?? this.search,
      searchField: clearSearchField ? null : searchField ?? this.searchField,
      scope: scope ?? this.scope,
      wardId: clearWard ? null : wardId ?? this.wardId,
      transferStatus: clearTransferStatus
          ? null
          : transferStatus ?? this.transferStatus,
      hasActiveBed: clearHasActiveBed ? null : hasActiveBed ?? this.hasActiveBed,
      hasCriticalAlert: clearHasCriticalAlert
          ? null
          : hasCriticalAlert ?? this.hasCriticalAlert,
      criticalSeverity: clearCriticalSeverity
          ? null
          : criticalSeverity ?? this.criticalSeverity,
      icuQueueScope: clearIcuQueueScope
          ? null
          : icuQueueScope ?? this.icuQueueScope,
      icuStatus: clearIcuStatus ? null : icuStatus ?? this.icuStatus,
      patientId: clearPatientId ? null : patientId ?? this.patientId,
      admittedFrom: clearAdmittedFrom ? null : admittedFrom ?? this.admittedFrom,
      admittedTo: clearAdmittedTo ? null : admittedTo ?? this.admittedTo,
      pageRequest: pageRequest ?? this.pageRequest,
      focusAdmissionId: clearFocus
          ? null
          : focusAdmissionId ?? this.focusAdmissionId,
      focusPanel: clearFocus ? null : focusPanel ?? this.focusPanel,
      focusAction: clearFocus ? null : focusAction ?? this.focusAction,
      section: section ?? this.section,
    );
  }
}

enum IpdDetailPanel { beds, nursing, medication, discharge, transfer, rounds }

extension IpdDetailPanelX on IpdDetailPanel {
  static IpdDetailPanel? fromToken(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'beds':
      case 'bed':
        return IpdDetailPanel.beds;
      case 'nursing':
        return IpdDetailPanel.nursing;
      case 'medication':
      case 'mar':
        return IpdDetailPanel.medication;
      case 'discharge':
        return IpdDetailPanel.discharge;
      case 'transfer':
      case 'transfers':
        return IpdDetailPanel.transfer;
      case 'rounds':
      case 'ward_round':
      case 'wardrounds':
        return IpdDetailPanel.rounds;
      default:
        return null;
    }
  }
}

@immutable
final class IpdWardOption {
  const IpdWardOption({
    required this.id,
    this.name,
    this.wardType,
    this.isActive = true,
  });

  final String id;
  final String? name;
  final String? wardType;
  final bool isActive;

  String get displayTitle => _firstNonEmpty(<String?>[name, id]) ?? id;
}

@immutable
final class IpdBedOption {
  const IpdBedOption({
    required this.id,
    this.label,
    this.status,
    this.wardId,
    this.wardName,
    this.roomId,
    this.roomName,
    this.roomFloor,
  });

  final String id;
  final String? label;
  final String? status;
  final String? wardId;
  final String? wardName;
  final String? roomId;
  final String? roomName;
  final String? roomFloor;

  String get displayTitle => _firstNonEmpty(<String?>[label, id]) ?? id;

  String? get displaySubtitle {
    return _joinDisplay(<String?>[wardName, roomName, status]);
  }
}

@immutable
final class IpdBedBoardEntry {
  const IpdBedBoardEntry({
    required this.id,
    this.displayId,
    this.label,
    this.status,
    this.wardId,
    this.wardName,
    this.wardType,
    this.roomName,
    this.floor,
    this.occupantPatientName,
    this.occupantPatientDisplayId,
    this.occupantAdmissionId,
    this.occupantAdmissionDisplayId,
    this.occupantAdmittedAt,
  });

  /// Raw bed UUID (required for status mutations).
  final String id;
  final String? displayId;
  final String? label;
  final String? status;
  final String? wardId;
  final String? wardName;
  final String? wardType;
  final String? roomName;
  final String? floor;
  final String? occupantPatientName;
  final String? occupantPatientDisplayId;
  final String? occupantAdmissionId;
  final String? occupantAdmissionDisplayId;
  final DateTime? occupantAdmittedAt;

  bool get isOccupied {
    return (status ?? '').toUpperCase() == 'OCCUPIED' ||
        occupantAdmissionId != null;
  }

  String get bedLabel => _firstNonEmpty(<String?>[label, displayId, id]) ?? id;

  String? get wardDisplayName => _firstNonEmpty(<String?>[wardName, wardId]);

  String? get roomDisplayName => _joinDisplay(<String?>[roomName, floor]);

  bool matchesSearch(String search) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return <String?>[
      label,
      displayId,
      wardName,
      roomName,
      status,
      occupantPatientName,
      occupantAdmissionDisplayId,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }
}

@immutable
final class IpdBedAssignment {
  const IpdBedAssignment({
    required this.id,
    this.assignedAt,
    this.releasedAt,
    this.bed,
  });

  final String id;
  final DateTime? assignedAt;
  final DateTime? releasedAt;
  final IpdBedOption? bed;
}

@immutable
final class IpdTransferRequest {
  const IpdTransferRequest({
    required this.id,
    this.status,
    this.requestedAt,
    this.fromWard,
    this.toWard,
  });

  final String id;
  final String? status;
  final DateTime? requestedAt;
  final IpdWardOption? fromWard;
  final IpdWardOption? toWard;
}

@immutable
final class IpdDischargeClearance {
  const IpdDischargeClearance({
    this.summaryReady = false,
    this.pendingOrdersReviewed = false,
    this.pharmacyCleared = false,
    this.billingCleared = false,
    this.nursingCleared = false,
    this.documentsReady = false,
    this.patientExited = false,
    this.overrideReason,
  });

  final bool summaryReady;
  final bool pendingOrdersReviewed;
  final bool pharmacyCleared;
  final bool billingCleared;
  final bool nursingCleared;
  final bool documentsReady;
  final bool patientExited;
  final String? overrideReason;

  bool get isComplete {
    if ((overrideReason ?? '').trim().isNotEmpty) {
      return true;
    }
    return summaryReady &&
        pendingOrdersReviewed &&
        pharmacyCleared &&
        billingCleared &&
        nursingCleared &&
        documentsReady &&
        patientExited;
  }

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'summary_ready': summaryReady,
      'pending_orders_reviewed': pendingOrdersReviewed,
      'pharmacy_cleared': pharmacyCleared,
      'billing_cleared': billingCleared,
      'nursing_cleared': nursingCleared,
      'documents_ready': documentsReady,
      'patient_exited': patientExited,
      if ((overrideReason ?? '').trim().isNotEmpty)
        'override_reason': overrideReason,
    };
  }
}

@immutable
final class IpdPendingOrder {
  const IpdPendingOrder({
    required this.id,
    this.kind,
    this.status,
    this.label,
    this.orderedAt,
  });

  final String id;
  final String? kind;
  final String? status;
  final String? label;
  final DateTime? orderedAt;
}

@immutable
final class IpdSourceContext {
  const IpdSourceContext({
    this.kind,
    this.encounterType,
    this.encounterStatus,
    this.startedAt,
  });

  final String? kind;
  final String? encounterType;
  final String? encounterStatus;
  final DateTime? startedAt;
}

@immutable
final class IpdDischargeSummary {
  const IpdDischargeSummary({
    required this.id,
    this.status,
    this.summary,
    this.dischargedAt,
    this.createdAt,
    this.updatedAt,
    this.clearance = const IpdDischargeClearance(),
    this.clearancePhase,
  });

  final String id;
  final String? status;
  final String? summary;
  final DateTime? dischargedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final IpdDischargeClearance clearance;
  final String? clearancePhase;
}

@immutable
final class IpdClinicalRecord {
  const IpdClinicalRecord({
    required this.id,
    required this.kind,
    this.status,
    this.title,
    this.subtitle,
    this.occurredAt,
  });

  final String id;
  final String kind;
  final String? status;
  final String? title;
  final String? subtitle;
  final DateTime? occurredAt;
}

@immutable
final class IpdMedicationSuggestion {
  const IpdMedicationSuggestion({
    required this.id,
    this.medicationLabel,
    this.dose,
    this.unit,
    this.route,
    this.frequency,
    this.orderStatus,
    this.itemStatus,
  });

  final String id;
  final String? medicationLabel;
  final String? dose;
  final String? unit;
  final String? route;
  final String? frequency;
  final String? orderStatus;
  final String? itemStatus;

  String get displayTitle {
    return _firstNonEmpty(<String?>[medicationLabel, id]) ?? id;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[dose, unit, route, frequency, orderStatus]);
  }
}

@immutable
final class IpdTimelineItem {
  const IpdTimelineItem({required this.type, this.label, this.occurredAt});

  final String type;
  final String? label;
  final DateTime? occurredAt;
}

@immutable
final class IpdIcuOverlay {
  const IpdIcuOverlay({
    this.status,
    this.hasCriticalAlert = false,
    this.criticalSeverity,
    this.activeStayId,
    this.latestStayId,
    this.recentObservations = const <IpdClinicalRecord>[],
    this.recentAlerts = const <IpdClinicalRecord>[],
  });

  final String? status;
  final bool hasCriticalAlert;
  final String? criticalSeverity;
  final String? activeStayId;
  final String? latestStayId;
  final List<IpdClinicalRecord> recentObservations;
  final List<IpdClinicalRecord> recentAlerts;
}

@immutable
final class IpdTheatreHandoverSummary {
  const IpdTheatreHandoverSummary({
    this.caseDisplayId,
    this.workflowStage,
    this.handoverDestination,
    this.stageNotes,
    this.postOpNote,
    this.completedAt,
  });

  final String? caseDisplayId;
  final String? workflowStage;
  final String? handoverDestination;
  final String? stageNotes;
  final String? postOpNote;
  final DateTime? completedAt;
}

@immutable
final class IpdTheatreOverlay {
  const IpdTheatreOverlay({
    this.status,
    this.activeCaseId,
    this.procedureName,
    this.workflowStage,
    this.handoverSummary,
  });

  final String? status;
  final String? activeCaseId;
  final String? procedureName;
  final String? workflowStage;
  final IpdTheatreHandoverSummary? handoverSummary;

  bool get hasActiveCase => (status ?? '').toUpperCase() == 'ACTIVE';
}

@immutable
final class IpdAdmissionSummary {
  const IpdAdmissionSummary({
    required this.id,
    this.displayId,
    this.patientId,
    this.patientDisplayName,
    this.encounterId,
    this.stage,
    this.nextStep,
    this.transferStatus,
    this.hasActiveBed = false,
    this.wardDisplayName,
    this.bedId,
    this.bedDisplayLabel,
    this.openTransferRequestId,
    this.admittedAt,
    this.dischargedAt,
    this.dischargeStatus,
    this.clearancePhase,
    this.admissionStatus,
    this.icuStatus,
    this.hasCriticalAlert = false,
    this.criticalSeverity,
    this.activeIcuStayId,
    this.theatreStatus,
    this.activeTheatreCaseId,
  });

  final String id;
  final String? displayId;
  final String? patientId;
  final String? patientDisplayName;
  final String? encounterId;
  final String? stage;
  final String? nextStep;
  final String? transferStatus;
  final bool hasActiveBed;
  final String? wardDisplayName;
  final String? bedId;
  final String? bedDisplayLabel;
  final String? openTransferRequestId;
  final DateTime? admittedAt;
  final DateTime? dischargedAt;
  final String? dischargeStatus;
  final String? clearancePhase;
  final String? admissionStatus;
  final String? icuStatus;
  final bool hasCriticalAlert;
  final String? criticalSeverity;
  final String? activeIcuStayId;
  final String? theatreStatus;
  final String? activeTheatreCaseId;

  String get apiId => id;

  String get displayTitle {
    return _firstNonEmpty(<String?>[patientDisplayName, displayId]) ?? '';
  }

  String? get location {
    return _joinDisplay(<String?>[wardDisplayName, bedDisplayLabel]);
  }

  bool get isInProcedureOt => stage == 'IN_PROCEDURE_OT';

  bool get hasActiveTheatreCase =>
      (theatreStatus ?? '').toUpperCase() == 'ACTIVE' ||
      (activeTheatreCaseId ?? '').isNotEmpty;

  bool get isTerminal {
    return switch ((stage ?? admissionStatus ?? '').toUpperCase()) {
      'DISCHARGED' || 'CANCELLED' => true,
      _ => false,
    };
  }

  bool matchesSearch(String search) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return <String?>[
      id,
      displayId,
      patientId,
      patientDisplayName,
      encounterId,
      stage,
      nextStep,
      transferStatus,
      wardDisplayName,
      bedId,
      bedDisplayLabel,
      admissionStatus,
      dischargeStatus,
      icuStatus,
      criticalSeverity,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  IpdAdmissionSummary copyWith({
    String? stage,
    String? nextStep,
    String? transferStatus,
    bool? hasActiveBed,
    String? wardDisplayName,
    String? bedId,
    String? bedDisplayLabel,
    String? dischargeStatus,
    String? clearancePhase,
    String? admissionStatus,
    String? icuStatus,
    bool? hasCriticalAlert,
    String? criticalSeverity,
    String? activeIcuStayId,
  }) {
    return IpdAdmissionSummary(
      id: id,
      displayId: displayId,
      patientId: patientId,
      patientDisplayName: patientDisplayName,
      encounterId: encounterId,
      stage: stage ?? this.stage,
      nextStep: nextStep ?? this.nextStep,
      transferStatus: transferStatus ?? this.transferStatus,
      hasActiveBed: hasActiveBed ?? this.hasActiveBed,
      wardDisplayName: wardDisplayName ?? this.wardDisplayName,
      bedId: bedId ?? this.bedId,
      bedDisplayLabel: bedDisplayLabel ?? this.bedDisplayLabel,
      openTransferRequestId: openTransferRequestId,
      admittedAt: admittedAt,
      dischargedAt: dischargedAt,
      dischargeStatus: dischargeStatus ?? this.dischargeStatus,
      clearancePhase: clearancePhase ?? this.clearancePhase,
      admissionStatus: admissionStatus ?? this.admissionStatus,
      icuStatus: icuStatus ?? this.icuStatus,
      hasCriticalAlert: hasCriticalAlert ?? this.hasCriticalAlert,
      criticalSeverity: criticalSeverity ?? this.criticalSeverity,
      activeIcuStayId: activeIcuStayId ?? this.activeIcuStayId,
    );
  }
}

@immutable
final class IpdPharmacyOrderSummary {
  const IpdPharmacyOrderSummary({
    required this.id,
    this.status,
    this.orderedAt,
    this.itemCount = 0,
  });

  final String id;
  final String? status;
  final DateTime? orderedAt;
  final int itemCount;
}

@immutable
final class IpdPharmacyClearance {
  const IpdPharmacyClearance({
    this.hasClearance = true,
    this.openOrderCount = 0,
    this.orders = const <IpdPharmacyOrderSummary>[],
  });

  final bool hasClearance;
  final int openOrderCount;
  final List<IpdPharmacyOrderSummary> orders;
}

@immutable
final class IpdAdmissionDetail {
  const IpdAdmissionDetail({
    required this.summary,
    this.patientFirstName,
    this.patientLastName,
    this.patientGender,
    this.patientDateOfBirth,
    this.facilityName,
    this.activeBedAssignment,
    this.openTransferRequest,
    this.latestDischargeSummary,
    this.transferRequests = const <IpdTransferRequest>[],
    this.dischargeSummaries = const <IpdDischargeSummary>[],
    this.wardRounds = const <IpdClinicalRecord>[],
    this.nursingNotes = const <IpdClinicalRecord>[],
    this.medicationAdministrations = const <IpdClinicalRecord>[],
    this.medicationSuggestions = const <IpdMedicationSuggestion>[],
    this.medicationReminders = const <IpdClinicalRecord>[],
    this.pharmacyClearance = const IpdPharmacyClearance(),
    this.timeline = const <IpdTimelineItem>[],
    this.icu = const IpdIcuOverlay(),
    this.theatre = const IpdTheatreOverlay(),
    this.sourceContext,
    this.pendingDischargeOrders = const <IpdPendingOrder>[],
    this.encounterType,
  });

  final IpdAdmissionSummary summary;
  final String? patientFirstName;
  final String? patientLastName;
  final String? patientGender;
  final DateTime? patientDateOfBirth;
  final String? facilityName;
  final IpdBedAssignment? activeBedAssignment;
  final IpdTransferRequest? openTransferRequest;
  final IpdDischargeSummary? latestDischargeSummary;
  final List<IpdTransferRequest> transferRequests;
  final List<IpdDischargeSummary> dischargeSummaries;
  final List<IpdClinicalRecord> wardRounds;
  final List<IpdClinicalRecord> nursingNotes;
  final List<IpdClinicalRecord> medicationAdministrations;
  final List<IpdMedicationSuggestion> medicationSuggestions;
  final List<IpdClinicalRecord> medicationReminders;
  final IpdPharmacyClearance pharmacyClearance;
  final List<IpdTimelineItem> timeline;
  final IpdIcuOverlay icu;
  final IpdTheatreOverlay theatre;
  final IpdSourceContext? sourceContext;
  final List<IpdPendingOrder> pendingDischargeOrders;
  final String? encounterType;

  String get patientDisplayName {
    return _joinDisplay(<String?>[patientFirstName, patientLastName]) ??
        summary.displayTitle;
  }
}

@immutable
final class IpdReferenceData {
  const IpdReferenceData({
    this.wards = const <IpdWardOption>[],
    this.availableBeds = const <IpdBedOption>[],
  });

  final List<IpdWardOption> wards;
  final List<IpdBedOption> availableBeds;

  IpdReferenceData copyWith({
    List<IpdWardOption>? wards,
    List<IpdBedOption>? availableBeds,
  }) {
    return IpdReferenceData(
      wards: wards ?? this.wards,
      availableBeds: availableBeds ?? this.availableBeds,
    );
  }
}

@immutable
final class IpdFlowAggregateCounts {
  const IpdFlowAggregateCounts({
    this.admissionQueue = 0,
    this.activePatients = 0,
    this.transferPending = 0,
    this.dischargePlanned = 0,
    this.inProcedureOt = 0,
    this.criticalAlerts = 0,
    this.activeTotal = 0,
  });

  static const IpdFlowAggregateCounts empty = IpdFlowAggregateCounts();

  final int admissionQueue;
  final int activePatients;
  final int transferPending;
  final int dischargePlanned;
  final int inProcedureOt;
  final int criticalAlerts;
  final int activeTotal;
}

@immutable
final class IpdWorkspaceState {
  const IpdWorkspaceState({
    required this.query,
    required this.admissions,
    this.referenceData = const IpdReferenceData(),
    this.summaryCounts = IpdFlowAggregateCounts.empty,
    this.selectedAdmission,
    this.lastFailure,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
    this.bedBoard = const <IpdBedBoardEntry>[],
    this.bedBoardWardId,
    this.bedBoardStatus,
    this.isLoadingBedBoard = false,
    this.bedBoardLoaded = false,
  });

  final IpdAdmissionQuery query;
  final AppPage<IpdAdmissionSummary> admissions;
  final IpdReferenceData referenceData;
  final IpdFlowAggregateCounts summaryCounts;
  final IpdAdmissionDetail? selectedAdmission;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isSaving;
  final List<IpdBedBoardEntry> bedBoard;
  final String? bedBoardWardId;
  final String? bedBoardStatus;
  final bool isLoadingBedBoard;
  final bool bedBoardLoaded;

  int get admissionQueueCount => summaryCounts.admissionQueue;

  int get activePatientCount => summaryCounts.activePatients;

  int get transferPendingCount => summaryCounts.transferPending;

  int get dischargePlannedCount => summaryCounts.dischargePlanned;

  int get criticalAlertCount => summaryCounts.criticalAlerts;

  int get workloadCount => summaryCounts.activeTotal > 0
      ? summaryCounts.activeTotal
      : admissions.items
            .where((IpdAdmissionSummary item) => !item.isTerminal)
            .length;

  IpdWorkspaceState copyWith({
    IpdAdmissionQuery? query,
    AppPage<IpdAdmissionSummary>? admissions,
    IpdReferenceData? referenceData,
    IpdFlowAggregateCounts? summaryCounts,
    IpdAdmissionDetail? selectedAdmission,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isSaving,
    List<IpdBedBoardEntry>? bedBoard,
    String? bedBoardWardId,
    String? bedBoardStatus,
    bool? isLoadingBedBoard,
    bool? bedBoardLoaded,
    bool clearSelectedAdmission = false,
    bool clearLastFailure = false,
    bool clearBedBoardWard = false,
    bool clearBedBoardStatus = false,
  }) {
    return IpdWorkspaceState(
      query: query ?? this.query,
      admissions: admissions ?? this.admissions,
      referenceData: referenceData ?? this.referenceData,
      summaryCounts: summaryCounts ?? this.summaryCounts,
      selectedAdmission: clearSelectedAdmission
          ? null
          : selectedAdmission ?? this.selectedAdmission,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isSaving: isSaving ?? this.isSaving,
      bedBoard: bedBoard ?? this.bedBoard,
      bedBoardWardId: clearBedBoardWard
          ? null
          : bedBoardWardId ?? this.bedBoardWardId,
      bedBoardStatus: clearBedBoardStatus
          ? null
          : bedBoardStatus ?? this.bedBoardStatus,
      isLoadingBedBoard: isLoadingBedBoard ?? this.isLoadingBedBoard,
      bedBoardLoaded: bedBoardLoaded ?? this.bedBoardLoaded,
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

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}

String? _nonEmpty(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
