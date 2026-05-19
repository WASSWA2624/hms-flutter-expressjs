import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum NursingQueueScope {
  assignedWard,
  urgent,
  medicationDue,
  handoverPending,
  transferPending,
  dischargePending,
  all,
}

@immutable
final class NursingWorklistQuery {
  const NursingWorklistQuery({
    this.search = '',
    this.scope = NursingQueueScope.assignedWard,
    this.patient = '',
    this.ward = '',
    this.unit = '',
    this.shift = '',
    this.careTask = '',
    this.priority = '',
    this.admissionStatus = '',
    this.dischargeReadiness = '',
    this.dateFrom,
    this.dateTo,
    this.pageRequest = const AppPageRequest(pageSize: 25),
  });

  final String search;
  final NursingQueueScope scope;
  final String patient;
  final String ward;
  final String unit;
  final String shift;
  final String careTask;
  final String priority;
  final String admissionStatus;
  final String dischargeReadiness;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final AppPageRequest pageRequest;

  bool get hasAdvancedFilters {
    return patient.trim().isNotEmpty ||
        ward.trim().isNotEmpty ||
        unit.trim().isNotEmpty ||
        shift.trim().isNotEmpty ||
        careTask.trim().isNotEmpty ||
        priority.trim().isNotEmpty ||
        admissionStatus.trim().isNotEmpty ||
        dischargeReadiness.trim().isNotEmpty ||
        dateFrom != null ||
        dateTo != null;
  }

  NursingWorklistQuery copyWith({
    String? search,
    NursingQueueScope? scope,
    String? patient,
    String? ward,
    String? unit,
    String? shift,
    String? careTask,
    String? priority,
    String? admissionStatus,
    String? dischargeReadiness,
    DateTime? dateFrom,
    DateTime? dateTo,
    AppPageRequest? pageRequest,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return NursingWorklistQuery(
      search: search ?? this.search,
      scope: scope ?? this.scope,
      patient: patient ?? this.patient,
      ward: ward ?? this.ward,
      unit: unit ?? this.unit,
      shift: shift ?? this.shift,
      careTask: careTask ?? this.careTask,
      priority: priority ?? this.priority,
      admissionStatus: admissionStatus ?? this.admissionStatus,
      dischargeReadiness: dischargeReadiness ?? this.dischargeReadiness,
      dateFrom: clearDateFrom ? null : dateFrom ?? this.dateFrom,
      dateTo: clearDateTo ? null : dateTo ?? this.dateTo,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

typedef NursingWorkItem = NursingPatientSummary;

@immutable
final class NursingPatientSummary {
  const NursingPatientSummary({
    required this.id,
    required this.admissionId,
    this.displayId,
    this.patientId,
    this.patientDisplayId,
    this.patientDisplayName,
    this.encounterDisplayId,
    this.stage,
    this.nextStep,
    this.admissionStatus,
    this.transferStatus,
    this.wardDisplayName,
    this.bedId,
    this.bedDisplayLabel,
    this.openTransferRequestId,
    this.admittedAt,
    this.dischargedAt,
    this.dischargeStatus,
    this.icuStatus,
    this.hasCriticalAlert = false,
    this.criticalSeverity,
    this.activeIcuStayId,
    this.hasActiveBed = false,
    this.medicationDueCount = 0,
    this.pendingHandoverCount = 0,
    this.lastObservation,
    this.lastObservationAt,
  });

  final String id;
  final String admissionId;
  final String? displayId;
  final String? patientId;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final String? encounterDisplayId;
  final String? stage;
  final String? nextStep;
  final String? admissionStatus;
  final String? transferStatus;
  final String? wardDisplayName;
  final String? bedId;
  final String? bedDisplayLabel;
  final String? openTransferRequestId;
  final DateTime? admittedAt;
  final DateTime? dischargedAt;
  final String? dischargeStatus;
  final String? icuStatus;
  final bool hasCriticalAlert;
  final String? criticalSeverity;
  final String? activeIcuStayId;
  final bool hasActiveBed;
  final int medicationDueCount;
  final int pendingHandoverCount;
  final String? lastObservation;
  final DateTime? lastObservationAt;

  String get apiAdmissionId => admissionId;

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          patientDisplayName,
          patientDisplayId,
          patientId,
          displayId,
          admissionId,
        ]) ??
        admissionId;
  }

  String? get locationLabel {
    return _joinDisplay(<String?>[wardDisplayName, bedDisplayLabel]);
  }

  bool get isUrgent {
    final String values = <String?>[
      stage,
      nextStep,
      transferStatus,
      icuStatus,
      criticalSeverity,
    ].whereType<String>().join(' ').toUpperCase();
    return hasCriticalAlert ||
        values.contains('CRITICAL') ||
        values.contains('URGENT') ||
        values.contains('TRANSFER_REQUESTED') ||
        values.contains('TRANSFER_IN_PROGRESS');
  }

  bool get hasPendingTransfer {
    return switch ((transferStatus ?? '').toUpperCase()) {
      'REQUESTED' || 'APPROVED' || 'IN_PROGRESS' => true,
      _ => false,
    };
  }

  bool get isDischargePending {
    final String status = (dischargeStatus ?? stage ?? '').toUpperCase();
    return status == 'PLANNED' || status == 'DISCHARGE_PLANNED';
  }

  bool get hasMedicationDue => medicationDueCount > 0;

  String get priorityCode {
    if (isUrgent) {
      return 'HIGH';
    }
    if (hasMedicationDue || hasPendingTransfer || isDischargePending) {
      return 'MEDIUM';
    }
    return 'ROUTINE';
  }

  String get taskTypeCode {
    if (hasMedicationDue) {
      return 'MEDICATION_DUE';
    }
    if (pendingHandoverCount > 0) {
      return 'HANDOVER_PENDING';
    }
    if (hasPendingTransfer) {
      return 'TRANSFER_PENDING';
    }
    if (isDischargePending) {
      return 'DISCHARGE_PENDING';
    }
    return _firstNonEmpty(<String?>[nextStep, stage, admissionStatus]) ??
        'WARD_REVIEW';
  }

  DateTime? get dueReferenceAt => lastObservationAt ?? admittedAt;

  bool matchesSearch(String search) {
    final String needle = search.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    return <String?>[
      id,
      admissionId,
      displayId,
      patientId,
      patientDisplayId,
      patientDisplayName,
      encounterDisplayId,
      stage,
      nextStep,
      admissionStatus,
      transferStatus,
      wardDisplayName,
      bedDisplayLabel,
      dischargeStatus,
      icuStatus,
      criticalSeverity,
      activeIcuStayId,
      priorityCode,
      taskTypeCode,
      lastObservation,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  bool matchesWard(String ward) {
    final String needle = ward.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return <String?>[wardDisplayName, bedDisplayLabel].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  bool matchesPatient(String patient) {
    final String needle = patient.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return <String?>[
      patientId,
      patientDisplayId,
      patientDisplayName,
      displayId,
      admissionId,
      encounterDisplayId,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  bool matchesUnit(String unit) {
    final String needle = unit.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return <String?>[wardDisplayName, icuStatus, stage].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  bool matchesCareTask(String careTask) {
    final String needle = careTask.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return <String?>[
      taskTypeCode,
      nextStep,
      stage,
      transferStatus,
      dischargeStatus,
      lastObservation,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  bool matchesPriority(String priority) {
    final String needle = priority.trim().toUpperCase();
    if (needle.isEmpty) {
      return true;
    }
    return priorityCode == needle;
  }

  bool matchesAdmissionStatus(String admissionStatusFilter) {
    final String needle = admissionStatusFilter.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return <String?>[admissionStatus, stage].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  bool matchesDischargeReadiness(String dischargeReadiness) {
    final String needle = dischargeReadiness.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return <String?>[dischargeStatus, stage, nextStep].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  bool matchesShift(String shift) {
    final String needle = shift.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    return <String?>[stage, nextStep, wardDisplayName].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  bool matchesDateRange(DateTime? from, DateTime? to) {
    final DateTime? date = dueReferenceAt ?? admittedAt;
    if (from == null && to == null) {
      return true;
    }
    if (date == null) {
      return false;
    }
    final DateTime localDate = DateTime(date.year, date.month, date.day);
    if (from != null) {
      final DateTime fromDate = DateTime(from.year, from.month, from.day);
      if (localDate.isBefore(fromDate)) {
        return false;
      }
    }
    if (to != null) {
      final DateTime toDate = DateTime(to.year, to.month, to.day);
      if (localDate.isAfter(toDate)) {
        return false;
      }
    }
    return true;
  }

  bool matchesWorklistQuery(NursingWorklistQuery query) {
    return matchesSearch(query.search) &&
        matchesScope(query.scope) &&
        matchesPatient(query.patient) &&
        matchesWard(query.ward) &&
        matchesUnit(query.unit) &&
        matchesShift(query.shift) &&
        matchesCareTask(query.careTask) &&
        matchesPriority(query.priority) &&
        matchesAdmissionStatus(query.admissionStatus) &&
        matchesDischargeReadiness(query.dischargeReadiness) &&
        matchesDateRange(query.dateFrom, query.dateTo);
  }

  bool matchesScope(NursingQueueScope scope) {
    return switch (scope) {
      NursingQueueScope.assignedWard => true,
      NursingQueueScope.urgent => isUrgent,
      NursingQueueScope.medicationDue => hasMedicationDue,
      NursingQueueScope.handoverPending => pendingHandoverCount > 0,
      NursingQueueScope.transferPending => hasPendingTransfer,
      NursingQueueScope.dischargePending => isDischargePending,
      NursingQueueScope.all => true,
    };
  }

  NursingPatientSummary copyWith({
    String? stage,
    String? nextStep,
    String? transferStatus,
    String? dischargeStatus,
    int? medicationDueCount,
    int? pendingHandoverCount,
    String? lastObservation,
    DateTime? lastObservationAt,
  }) {
    return NursingPatientSummary(
      id: id,
      admissionId: admissionId,
      displayId: displayId,
      patientId: patientId,
      patientDisplayId: patientDisplayId,
      patientDisplayName: patientDisplayName,
      encounterDisplayId: encounterDisplayId,
      stage: stage ?? this.stage,
      nextStep: nextStep ?? this.nextStep,
      admissionStatus: admissionStatus,
      transferStatus: transferStatus ?? this.transferStatus,
      wardDisplayName: wardDisplayName,
      bedId: bedId,
      bedDisplayLabel: bedDisplayLabel,
      openTransferRequestId: openTransferRequestId,
      admittedAt: admittedAt,
      dischargedAt: dischargedAt,
      dischargeStatus: dischargeStatus ?? this.dischargeStatus,
      icuStatus: icuStatus,
      hasCriticalAlert: hasCriticalAlert,
      criticalSeverity: criticalSeverity,
      activeIcuStayId: activeIcuStayId,
      hasActiveBed: hasActiveBed,
      medicationDueCount: medicationDueCount ?? this.medicationDueCount,
      pendingHandoverCount: pendingHandoverCount ?? this.pendingHandoverCount,
      lastObservation: lastObservation ?? this.lastObservation,
      lastObservationAt: lastObservationAt ?? this.lastObservationAt,
    );
  }
}

@immutable
final class NursingPatientDetail {
  const NursingPatientDetail({
    required this.summary,
    this.patientGender,
    this.patientDateOfBirth,
    this.facilityName,
    this.encounterType,
    this.encounterStatus,
    this.activeTransfer,
    this.latestDischarge,
    this.nursingNotes = const <NursingNoteRecord>[],
    this.medicationAdministrations = const <MedicationAdministrationRecord>[],
    this.medicationSuggestions = const <MedicationSuggestion>[],
    this.medicationReminders = const <MedicationReminder>[],
    this.vitalSigns = const <NursingVitalSign>[],
    this.carePlans = const <NursingCarePlan>[],
    this.handovers = const <NursingHandover>[],
    this.timeline = const <NursingTimelineItem>[],
    this.icuObservations = const <NursingTimelineItem>[],
    this.criticalAlerts = const <NursingCriticalAlert>[],
  });

  final NursingPatientSummary summary;
  final String? patientGender;
  final DateTime? patientDateOfBirth;
  final String? facilityName;
  final String? encounterType;
  final String? encounterStatus;
  final NursingTransferRequest? activeTransfer;
  final NursingDischargeSummary? latestDischarge;
  final List<NursingNoteRecord> nursingNotes;
  final List<MedicationAdministrationRecord> medicationAdministrations;
  final List<MedicationSuggestion> medicationSuggestions;
  final List<MedicationReminder> medicationReminders;
  final List<NursingVitalSign> vitalSigns;
  final List<NursingCarePlan> carePlans;
  final List<NursingHandover> handovers;
  final List<NursingTimelineItem> timeline;
  final List<NursingTimelineItem> icuObservations;
  final List<NursingCriticalAlert> criticalAlerts;

  bool get hasMedicationDue {
    return medicationReminders.any(
          (MedicationReminder item) => !item.isTerminal,
        ) ||
        medicationSuggestions.isNotEmpty;
  }

  int get medicationDueCount {
    final int reminders = medicationReminders
        .where((MedicationReminder item) => !item.isTerminal)
        .length;
    return reminders + medicationSuggestions.length;
  }

  int get pendingHandoverCount {
    return handovers.where((NursingHandover item) => item.isPending).length;
  }

  NursingPatientSummary get enrichedSummary {
    return summary.copyWith(
      medicationDueCount: medicationDueCount,
      pendingHandoverCount: pendingHandoverCount,
      lastObservation: _lastTimelineItem?.label ?? summary.lastObservation,
      lastObservationAt:
          _lastTimelineItem?.occurredAt ?? summary.lastObservationAt,
    );
  }

  NursingPatientDetail copyWith({
    NursingPatientSummary? summary,
    List<NursingNoteRecord>? nursingNotes,
    List<MedicationAdministrationRecord>? medicationAdministrations,
    List<NursingVitalSign>? vitalSigns,
    List<NursingCarePlan>? carePlans,
    List<NursingHandover>? handovers,
  }) {
    return NursingPatientDetail(
      summary: summary ?? this.summary,
      patientGender: patientGender,
      patientDateOfBirth: patientDateOfBirth,
      facilityName: facilityName,
      encounterType: encounterType,
      encounterStatus: encounterStatus,
      activeTransfer: activeTransfer,
      latestDischarge: latestDischarge,
      nursingNotes: nursingNotes ?? this.nursingNotes,
      medicationAdministrations:
          medicationAdministrations ?? this.medicationAdministrations,
      medicationSuggestions: medicationSuggestions,
      medicationReminders: medicationReminders,
      vitalSigns: vitalSigns ?? this.vitalSigns,
      carePlans: carePlans ?? this.carePlans,
      handovers: handovers ?? this.handovers,
      timeline: timeline,
      icuObservations: icuObservations,
      criticalAlerts: criticalAlerts,
    );
  }

  NursingTimelineItem? get _lastTimelineItem {
    final List<NursingTimelineItem> items = <NursingTimelineItem>[
      ...timeline,
      ...icuObservations,
    ].where((NursingTimelineItem item) => item.occurredAt != null).toList();
    if (items.isEmpty) {
      return null;
    }
    items.sort((NursingTimelineItem left, NursingTimelineItem right) {
      return right.occurredAt!.compareTo(left.occurredAt!);
    });
    return items.first;
  }
}

@immutable
final class NursingNoteRecord {
  const NursingNoteRecord({
    required this.id,
    this.nurseUserId,
    this.nurseName,
    this.note,
    this.createdAt,
  });

  final String id;
  final String? nurseUserId;
  final String? nurseName;
  final String? note;
  final DateTime? createdAt;
}

@immutable
final class MedicationAdministrationRecord {
  const MedicationAdministrationRecord({
    required this.id,
    this.prescriptionId,
    this.administeredAt,
    this.dose,
    this.unit,
    this.route,
    this.createdAt,
  });

  final String id;
  final String? prescriptionId;
  final DateTime? administeredAt;
  final String? dose;
  final String? unit;
  final String? route;
  final DateTime? createdAt;
}

@immutable
final class MedicationSuggestion {
  const MedicationSuggestion({
    required this.id,
    this.medicationLabel,
    this.drugName,
    this.dose,
    this.unit,
    this.route,
    this.frequency,
    this.orderStatus,
    this.itemStatus,
    this.orderedAt,
  });

  final String id;
  final String? medicationLabel;
  final String? drugName;
  final String? dose;
  final String? unit;
  final String? route;
  final String? frequency;
  final String? orderStatus;
  final String? itemStatus;
  final DateTime? orderedAt;

  String get displayTitle {
    return _firstNonEmpty(<String?>[medicationLabel, drugName, id]) ?? id;
  }
}

@immutable
final class MedicationReminder {
  const MedicationReminder({
    required this.id,
    this.scheduledAt,
    this.status,
    this.medicationLabel,
    this.dose,
    this.unit,
    this.route,
    this.frequency,
    this.prescriptionId,
  });

  final String id;
  final DateTime? scheduledAt;
  final String? status;
  final String? medicationLabel;
  final String? dose;
  final String? unit;
  final String? route;
  final String? frequency;
  final String? prescriptionId;

  bool get isTerminal {
    return switch ((status ?? '').toUpperCase()) {
      'COMPLETED' || 'CANCELLED' || 'DONE' => true,
      _ => false,
    };
  }

  String get displayTitle {
    return _firstNonEmpty(<String?>[medicationLabel, dose, id]) ?? id;
  }
}

@immutable
final class NursingVitalSign {
  const NursingVitalSign({
    required this.id,
    required this.vitalType,
    this.value,
    this.unit,
    this.systolicValue,
    this.diastolicValue,
    this.mapValue,
    this.recordedAt,
  });

  final String id;
  final String vitalType;
  final String? value;
  final String? unit;
  final num? systolicValue;
  final num? diastolicValue;
  final num? mapValue;
  final DateTime? recordedAt;

  String get displayValue {
    if (vitalType == 'BLOOD_PRESSURE' &&
        systolicValue != null &&
        diastolicValue != null) {
      return '${_numLabel(systolicValue!)} / ${_numLabel(diastolicValue!)}';
    }
    return _joinDisplay(<String?>[value, unit]) ?? '';
  }
}

@immutable
final class NursingCarePlan {
  const NursingCarePlan({
    required this.id,
    this.plan,
    this.status,
    this.startDate,
    this.endDate,
    this.createdAt,
  });

  final String id;
  final String? plan;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
}

@immutable
final class NursingHandover {
  const NursingHandover({
    required this.id,
    this.status,
    this.admissionId,
    this.fromUserId,
    this.toUserId,
    this.signoffNotes,
    this.acceptedNotes,
    this.createdAt,
    this.acceptedAt,
  });

  final String id;
  final String? status;
  final String? admissionId;
  final String? fromUserId;
  final String? toUserId;
  final String? signoffNotes;
  final String? acceptedNotes;
  final DateTime? createdAt;
  final DateTime? acceptedAt;

  bool get isPending => (status ?? '').toUpperCase() == 'PENDING';
}

@immutable
final class NursingTransferRequest {
  const NursingTransferRequest({
    required this.id,
    this.status,
    this.requestedAt,
    this.fromWardName,
    this.toWardName,
  });

  final String id;
  final String? status;
  final DateTime? requestedAt;
  final String? fromWardName;
  final String? toWardName;
}

@immutable
final class NursingDischargeSummary {
  const NursingDischargeSummary({
    required this.id,
    this.status,
    this.summary,
    this.dischargedAt,
  });

  final String id;
  final String? status;
  final String? summary;
  final DateTime? dischargedAt;
}

@immutable
final class NursingTimelineItem {
  const NursingTimelineItem({
    required this.type,
    required this.label,
    this.occurredAt,
  });

  final String type;
  final String label;
  final DateTime? occurredAt;
}

@immutable
final class NursingCriticalAlert {
  const NursingCriticalAlert({
    required this.id,
    this.severity,
    this.message,
    this.createdAt,
  });

  final String id;
  final String? severity;
  final String? message;
  final DateTime? createdAt;
}

@immutable
final class NursingRosterAssignment {
  const NursingRosterAssignment({
    required this.id,
    this.status,
    this.periodStart,
    this.periodEnd,
    this.facilityId,
    this.departmentId,
  });

  final String id;
  final String? status;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? facilityId;
  final String? departmentId;
}

@immutable
final class NursingWorkspaceState {
  const NursingWorkspaceState({
    required this.query,
    required this.worklist,
    this.pendingHandovers = const <NursingHandover>[],
    this.rosters = const <NursingRosterAssignment>[],
    this.selectedDetail,
    this.lastFailure,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  final NursingWorklistQuery query;
  final AppPage<NursingPatientSummary> worklist;
  final List<NursingHandover> pendingHandovers;
  final List<NursingRosterAssignment> rosters;
  final NursingPatientDetail? selectedDetail;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get assignedWardCount => _filtered(NursingQueueScope.assignedWard).length;
  int get urgentCount => _filtered(NursingQueueScope.urgent).length;
  int get medicationDueCount =>
      _filtered(NursingQueueScope.medicationDue).length;
  int get handoverPendingCount {
    return pendingHandovers
        .where((NursingHandover item) => item.isPending)
        .length;
  }

  int get transferPendingCount =>
      _filtered(NursingQueueScope.transferPending).length;
  int get dischargePendingCount =>
      _filtered(NursingQueueScope.dischargePending).length;
  int get workloadCount =>
      assignedWardCount + urgentCount + handoverPendingCount;

  List<NursingPatientSummary> _filtered(NursingQueueScope scope) {
    return worklist.items
        .where((NursingPatientSummary item) => item.matchesScope(scope))
        .toList(growable: false);
  }

  NursingWorkspaceState copyWith({
    NursingWorklistQuery? query,
    AppPage<NursingPatientSummary>? worklist,
    List<NursingHandover>? pendingHandovers,
    List<NursingRosterAssignment>? rosters,
    NursingPatientDetail? selectedDetail,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedDetail = false,
    bool clearLastFailure = false,
  }) {
    return NursingWorkspaceState(
      query: query ?? this.query,
      worklist: worklist ?? this.worklist,
      pendingHandovers: pendingHandovers ?? this.pendingHandovers,
      rosters: rosters ?? this.rosters,
      selectedDetail: clearSelectedDetail
          ? null
          : selectedDetail ?? this.selectedDetail,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isSaving: isSaving ?? this.isSaving,
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

String _numLabel(num value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
