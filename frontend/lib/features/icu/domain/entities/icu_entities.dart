import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum IcuBoardScope { active, critical, transfer, discharge, ended, all }

@immutable
final class IcuBoardQuery {
  const IcuBoardQuery({
    this.search = '',
    this.scope = IcuBoardScope.active,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final IcuBoardScope scope;
  final AppPageRequest pageRequest;

  IcuBoardQuery copyWith({
    String? search,
    IcuBoardScope? scope,
    AppPageRequest? pageRequest,
  }) {
    return IcuBoardQuery(
      search: search ?? this.search,
      scope: scope ?? this.scope,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class IcuPatientSummary {
  const IcuPatientSummary({
    required this.id,
    required this.admissionId,
    this.displayId,
    this.patientId,
    this.patientDisplayName,
    this.encounterId,
    this.wardName,
    this.bedLabel,
    this.stage,
    this.nextStep,
    this.transferStatus,
    this.admissionStatus,
    this.dischargeStatus,
    this.icuStatus,
    this.activeIcuStayId,
    this.latestIcuStayId,
    this.criticalSeverity,
    this.hasCriticalAlert = false,
    this.hasActiveBed = false,
    this.admittedAt,
    this.dischargedAt,
  });

  final String id;
  final String admissionId;
  final String? displayId;
  final String? patientId;
  final String? patientDisplayName;
  final String? encounterId;
  final String? wardName;
  final String? bedLabel;
  final String? stage;
  final String? nextStep;
  final String? transferStatus;
  final String? admissionStatus;
  final String? dischargeStatus;
  final String? icuStatus;
  final String? activeIcuStayId;
  final String? latestIcuStayId;
  final String? criticalSeverity;
  final bool hasCriticalAlert;
  final bool hasActiveBed;
  final DateTime? admittedAt;
  final DateTime? dischargedAt;

  String get apiAdmissionId => admissionId;

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          patientDisplayName,
          patientId,
          displayId,
          admissionId,
        ]) ??
        admissionId;
  }

  String get locationLabel {
    return _joinDisplay(<String?>[wardName, bedLabel]) ?? 'No bed';
  }

  bool get isActiveIcu {
    return (icuStatus ?? '').toUpperCase() == 'ACTIVE';
  }

  bool get hasOpenTransfer {
    return switch ((transferStatus ?? '').toUpperCase()) {
      'REQUESTED' || 'APPROVED' || 'IN_PROGRESS' => true,
      _ => false,
    };
  }

  bool get isDischargePlanned {
    return (dischargeStatus ?? '').toUpperCase() == 'PLANNED' ||
        (stage ?? '').toUpperCase() == 'DISCHARGE_PLANNED';
  }

  bool get isEndedIcu {
    return (icuStatus ?? '').toUpperCase() == 'ENDED';
  }

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
      patientDisplayName,
      encounterId,
      wardName,
      bedLabel,
      stage,
      nextStep,
      transferStatus,
      admissionStatus,
      dischargeStatus,
      icuStatus,
      criticalSeverity,
      activeIcuStayId,
      latestIcuStayId,
    ].whereType<String>().any(
      (String value) => value.toLowerCase().contains(needle),
    );
  }

  IcuPatientSummary copyWith({
    String? stage,
    String? nextStep,
    String? transferStatus,
    String? admissionStatus,
    String? dischargeStatus,
    String? icuStatus,
    String? activeIcuStayId,
    String? latestIcuStayId,
    String? criticalSeverity,
    bool? hasCriticalAlert,
    bool? hasActiveBed,
    DateTime? dischargedAt,
  }) {
    return IcuPatientSummary(
      id: id,
      admissionId: admissionId,
      displayId: displayId,
      patientId: patientId,
      patientDisplayName: patientDisplayName,
      encounterId: encounterId,
      wardName: wardName,
      bedLabel: bedLabel,
      stage: stage ?? this.stage,
      nextStep: nextStep ?? this.nextStep,
      transferStatus: transferStatus ?? this.transferStatus,
      admissionStatus: admissionStatus ?? this.admissionStatus,
      dischargeStatus: dischargeStatus ?? this.dischargeStatus,
      icuStatus: icuStatus ?? this.icuStatus,
      activeIcuStayId: activeIcuStayId ?? this.activeIcuStayId,
      latestIcuStayId: latestIcuStayId ?? this.latestIcuStayId,
      criticalSeverity: criticalSeverity ?? this.criticalSeverity,
      hasCriticalAlert: hasCriticalAlert ?? this.hasCriticalAlert,
      hasActiveBed: hasActiveBed ?? this.hasActiveBed,
      admittedAt: admittedAt,
      dischargedAt: dischargedAt ?? this.dischargedAt,
    );
  }
}

@immutable
final class IcuStaySummary {
  const IcuStaySummary({
    required this.id,
    this.displayId,
    this.startedAt,
    this.endedAt,
    this.createdAt,
  });

  final String id;
  final String? displayId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;

  bool get isActive => endedAt == null;
}

@immutable
final class IcuObservation {
  const IcuObservation({
    required this.id,
    this.displayId,
    this.icuStayId,
    this.observedAt,
    this.observation,
    this.createdAt,
  });

  final String id;
  final String? displayId;
  final String? icuStayId;
  final DateTime? observedAt;
  final String? observation;
  final DateTime? createdAt;
}

@immutable
final class IcuCriticalAlert {
  const IcuCriticalAlert({
    required this.id,
    this.displayId,
    this.icuStayId,
    this.severity,
    this.message,
    this.createdAt,
  });

  final String id;
  final String? displayId;
  final String? icuStayId;
  final String? severity;
  final String? message;
  final DateTime? createdAt;
}

@immutable
final class IcuCriticalAlertSummary {
  const IcuCriticalAlertSummary({
    this.total = 0,
    this.highestSeverity,
    this.low = 0,
    this.medium = 0,
    this.high = 0,
    this.critical = 0,
    this.recent = const <IcuCriticalAlert>[],
  });

  final int total;
  final String? highestSeverity;
  final int low;
  final int medium;
  final int high;
  final int critical;
  final List<IcuCriticalAlert> recent;
}

@immutable
final class IcuWardOption {
  const IcuWardOption({required this.id, this.name, this.wardType});

  final String id;
  final String? name;
  final String? wardType;

  String get displayTitle {
    return _joinDisplay(<String?>[name, id]) ?? id;
  }
}

@immutable
final class IcuReferenceData {
  const IcuReferenceData({this.wards = const <IcuWardOption>[]});

  final List<IcuWardOption> wards;
}

@immutable
final class IcuTransferRequest {
  const IcuTransferRequest({
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
final class IcuDischargeSummary {
  const IcuDischargeSummary({
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
final class IcuRoundNote {
  const IcuRoundNote({
    required this.id,
    this.roundAt,
    this.notes,
    this.createdAt,
  });

  final String id;
  final DateTime? roundAt;
  final String? notes;
  final DateTime? createdAt;
}

@immutable
final class IcuNursingNote {
  const IcuNursingNote({
    required this.id,
    this.nurseName,
    this.note,
    this.createdAt,
  });

  final String id;
  final String? nurseName;
  final String? note;
  final DateTime? createdAt;
}

@immutable
final class IcuMedicationTask {
  const IcuMedicationTask({
    required this.id,
    this.scheduledAt,
    this.status,
    this.note,
    this.medicationLabel,
    this.dose,
    this.unit,
    this.route,
    this.frequency,
  });

  final String id;
  final DateTime? scheduledAt;
  final String? status;
  final String? note;
  final String? medicationLabel;
  final String? dose;
  final String? unit;
  final String? route;
  final String? frequency;
}

@immutable
final class IcuMedicationAdministration {
  const IcuMedicationAdministration({
    required this.id,
    this.administeredAt,
    this.dose,
    this.unit,
    this.route,
  });

  final String id;
  final DateTime? administeredAt;
  final String? dose;
  final String? unit;
  final String? route;
}

@immutable
final class IcuVitalSign {
  const IcuVitalSign({
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
    if (vitalType == 'BLOOD_PRESSURE') {
      final String systolic = systolicValue?.toString() ?? '';
      final String diastolic = diastolicValue?.toString() ?? '';
      if (systolic.isNotEmpty && diastolic.isNotEmpty) {
        return '$systolic/$diastolic mmHg';
      }
    }

    final String normalizedValue = value?.trim() ?? '';
    final String normalizedUnit = unit?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      return '';
    }
    return normalizedUnit.isEmpty
        ? normalizedValue
        : '$normalizedValue $normalizedUnit';
  }
}

@immutable
final class IcuTimelineItem {
  const IcuTimelineItem({required this.type, required this.label, this.at});

  final String type;
  final String label;
  final DateTime? at;
}

@immutable
final class IcuPatientDetail {
  const IcuPatientDetail({
    required this.summary,
    this.facilityName,
    this.patientGender,
    this.patientDateOfBirth,
    this.activeStay,
    this.latestStay,
    this.recentStays = const <IcuStaySummary>[],
    this.observations = const <IcuObservation>[],
    this.alerts = const <IcuCriticalAlert>[],
    this.alertSummary = const IcuCriticalAlertSummary(),
    this.vitalSigns = const <IcuVitalSign>[],
    this.transferRequests = const <IcuTransferRequest>[],
    this.dischargeSummaries = const <IcuDischargeSummary>[],
    this.roundNotes = const <IcuRoundNote>[],
    this.nursingNotes = const <IcuNursingNote>[],
    this.medicationTasks = const <IcuMedicationTask>[],
    this.medicationAdministrations = const <IcuMedicationAdministration>[],
    this.timeline = const <IcuTimelineItem>[],
  });

  final IcuPatientSummary summary;
  final String? facilityName;
  final String? patientGender;
  final DateTime? patientDateOfBirth;
  final IcuStaySummary? activeStay;
  final IcuStaySummary? latestStay;
  final List<IcuStaySummary> recentStays;
  final List<IcuObservation> observations;
  final List<IcuCriticalAlert> alerts;
  final IcuCriticalAlertSummary alertSummary;
  final List<IcuVitalSign> vitalSigns;
  final List<IcuTransferRequest> transferRequests;
  final List<IcuDischargeSummary> dischargeSummaries;
  final List<IcuRoundNote> roundNotes;
  final List<IcuNursingNote> nursingNotes;
  final List<IcuMedicationTask> medicationTasks;
  final List<IcuMedicationAdministration> medicationAdministrations;
  final List<IcuTimelineItem> timeline;

  IcuCriticalAlert? get latestAlert {
    if (alerts.isNotEmpty) {
      return alerts.first;
    }
    if (alertSummary.recent.isNotEmpty) {
      return alertSummary.recent.first;
    }
    return null;
  }

  bool get canRecordIcuAction => activeStay != null;

  IcuPatientDetail copyWith({
    IcuPatientSummary? summary,
    List<IcuVitalSign>? vitalSigns,
  }) {
    return IcuPatientDetail(
      summary: summary ?? this.summary,
      facilityName: facilityName,
      patientGender: patientGender,
      patientDateOfBirth: patientDateOfBirth,
      activeStay: activeStay,
      latestStay: latestStay,
      recentStays: recentStays,
      observations: observations,
      alerts: alerts,
      alertSummary: alertSummary,
      vitalSigns: vitalSigns ?? this.vitalSigns,
      transferRequests: transferRequests,
      dischargeSummaries: dischargeSummaries,
      roundNotes: roundNotes,
      nursingNotes: nursingNotes,
      medicationTasks: medicationTasks,
      medicationAdministrations: medicationAdministrations,
      timeline: timeline,
    );
  }
}

@immutable
final class IcuVitalsInput {
  const IcuVitalsInput({
    this.temperature,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.recordedAt,
  });

  final String? temperature;
  final String? systolic;
  final String? diastolic;
  final String? heartRate;
  final String? respiratoryRate;
  final String? oxygenSaturation;
  final DateTime? recordedAt;

  bool get hasAnyValue {
    return <String?>[
      temperature,
      systolic,
      diastolic,
      heartRate,
      respiratoryRate,
      oxygenSaturation,
    ].any((String? value) => (value ?? '').trim().isNotEmpty);
  }
}

@immutable
final class IcuWorkspaceState {
  const IcuWorkspaceState({
    required this.query,
    required this.board,
    this.referenceData = const IcuReferenceData(),
    this.selectedDetail,
    this.lastFailure,
    this.isRefreshingBoard = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  final IcuBoardQuery query;
  final AppPage<IcuPatientSummary> board;
  final IcuReferenceData referenceData;
  final IcuPatientDetail? selectedDetail;
  final Object? lastFailure;
  final bool isRefreshingBoard;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get activeCount {
    return board.items
        .where((IcuPatientSummary item) => item.isActiveIcu)
        .length;
  }

  int get criticalCount {
    return board.items
        .where((IcuPatientSummary item) => item.hasCriticalAlert)
        .length;
  }

  int get transferCount {
    return board.items
        .where((IcuPatientSummary item) => item.hasOpenTransfer)
        .length;
  }

  int get dischargeReadyCount {
    return board.items
        .where((IcuPatientSummary item) => item.isDischargePlanned)
        .length;
  }

  IcuWorkspaceState copyWith({
    IcuBoardQuery? query,
    AppPage<IcuPatientSummary>? board,
    IcuReferenceData? referenceData,
    IcuPatientDetail? selectedDetail,
    Object? lastFailure,
    bool? isRefreshingBoard,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedDetail = false,
    bool clearLastFailure = false,
  }) {
    return IcuWorkspaceState(
      query: query ?? this.query,
      board: board ?? this.board,
      referenceData: referenceData ?? this.referenceData,
      selectedDetail: clearSelectedDetail
          ? null
          : selectedDetail ?? this.selectedDetail,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshingBoard: isRefreshingBoard ?? this.isRefreshingBoard,
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
