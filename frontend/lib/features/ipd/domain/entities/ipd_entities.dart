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

@immutable
final class IpdAdmissionQuery {
  const IpdAdmissionQuery({
    this.search = '',
    this.scope = IpdQueueScope.admissionQueue,
    this.wardId,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final IpdQueueScope scope;
  final String? wardId;
  final AppPageRequest pageRequest;

  IpdAdmissionQuery copyWith({
    String? search,
    IpdQueueScope? scope,
    String? wardId,
    AppPageRequest? pageRequest,
    bool clearWard = false,
  }) {
    return IpdAdmissionQuery(
      search: search ?? this.search,
      scope: scope ?? this.scope,
      wardId: clearWard ? null : wardId ?? this.wardId,
      pageRequest: pageRequest ?? this.pageRequest,
    );
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
final class IpdDischargeSummary {
  const IpdDischargeSummary({
    required this.id,
    this.status,
    this.summary,
    this.dischargedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? status;
  final String? summary;
  final DateTime? dischargedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
    this.admissionStatus,
    this.icuStatus,
    this.hasCriticalAlert = false,
    this.criticalSeverity,
    this.activeIcuStayId,
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
  final String? admissionStatus;
  final String? icuStatus;
  final bool hasCriticalAlert;
  final String? criticalSeverity;
  final String? activeIcuStayId;

  String get apiId => id;

  String get displayTitle {
    return _firstNonEmpty(<String?>[patientDisplayName, patientId, id]) ?? id;
  }

  String? get location {
    return _joinDisplay(<String?>[wardDisplayName, bedDisplayLabel]);
  }

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
      admissionStatus: admissionStatus ?? this.admissionStatus,
      icuStatus: icuStatus ?? this.icuStatus,
      hasCriticalAlert: hasCriticalAlert ?? this.hasCriticalAlert,
      criticalSeverity: criticalSeverity ?? this.criticalSeverity,
      activeIcuStayId: activeIcuStayId ?? this.activeIcuStayId,
    );
  }
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
    this.timeline = const <IpdTimelineItem>[],
    this.icu = const IpdIcuOverlay(),
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
  final List<IpdTimelineItem> timeline;
  final IpdIcuOverlay icu;

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
final class IpdWorkspaceState {
  const IpdWorkspaceState({
    required this.query,
    required this.admissions,
    this.referenceData = const IpdReferenceData(),
    this.selectedAdmission,
    this.lastFailure,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  final IpdAdmissionQuery query;
  final AppPage<IpdAdmissionSummary> admissions;
  final IpdReferenceData referenceData;
  final IpdAdmissionDetail? selectedAdmission;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get admissionQueueCount => admissions.items
      .where((IpdAdmissionSummary item) => item.stage == 'ADMITTED_PENDING_BED')
      .length;

  int get activePatientCount => admissions.items
      .where((IpdAdmissionSummary item) => item.stage == 'ADMITTED_IN_BED')
      .length;

  int get transferPendingCount => admissions.items
      .where(
        (IpdAdmissionSummary item) =>
            item.stage == 'TRANSFER_REQUESTED' ||
            item.stage == 'TRANSFER_IN_PROGRESS',
      )
      .length;

  int get dischargePlannedCount => admissions.items
      .where((IpdAdmissionSummary item) => item.stage == 'DISCHARGE_PLANNED')
      .length;

  int get criticalAlertCount => admissions.items
      .where((IpdAdmissionSummary item) => item.hasCriticalAlert)
      .length;

  int get workloadCount {
    return admissions.items
        .where((IpdAdmissionSummary item) => !item.isTerminal)
        .length;
  }

  IpdWorkspaceState copyWith({
    IpdAdmissionQuery? query,
    AppPage<IpdAdmissionSummary>? admissions,
    IpdReferenceData? referenceData,
    IpdAdmissionDetail? selectedAdmission,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedAdmission = false,
    bool clearLastFailure = false,
  }) {
    return IpdWorkspaceState(
      query: query ?? this.query,
      admissions: admissions ?? this.admissions,
      referenceData: referenceData ?? this.referenceData,
      selectedAdmission: clearSelectedAdmission
          ? null
          : selectedAdmission ?? this.selectedAdmission,
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
