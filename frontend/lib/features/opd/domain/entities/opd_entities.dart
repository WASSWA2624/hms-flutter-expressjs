import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

@immutable
final class OpdAppointmentQuery {
  const OpdAppointmentQuery({
    this.search = '',
    this.status,
    this.pageRequest = const AppPageRequest(pageSize: 8),
  });

  final String search;
  final String? status;
  final AppPageRequest pageRequest;

  OpdAppointmentQuery copyWith({
    String? search,
    String? status,
    AppPageRequest? pageRequest,
    bool clearStatus = false,
  }) {
    return OpdAppointmentQuery(
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class OpdQueueQuery {
  const OpdQueueQuery({
    this.search = '',
    this.status,
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  final String search;
  final String? status;
  final AppPageRequest pageRequest;

  OpdQueueQuery copyWith({
    String? search,
    String? status,
    AppPageRequest? pageRequest,
    bool clearStatus = false,
  }) {
    return OpdQueueQuery(
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class OpdFlowQuery {
  const OpdFlowQuery({
    this.search = '',
    this.stage,
    this.encounterType = 'OPD',
    this.queueScope = 'ALL',
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  final String search;
  final String? stage;
  final String encounterType;
  final String queueScope;
  final AppPageRequest pageRequest;

  OpdFlowQuery copyWith({
    String? search,
    String? stage,
    String? encounterType,
    String? queueScope,
    AppPageRequest? pageRequest,
    bool clearStage = false,
  }) {
    return OpdFlowQuery(
      search: search ?? this.search,
      stage: clearStage ? null : stage ?? this.stage,
      encounterType: encounterType ?? this.encounterType,
      queueScope: queueScope ?? this.queueScope,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

/// Parsed deep-link parameters for the OPD workspace route (`/opd?id=&panel=`).
///
/// `flowId` deep-links to a specific OPD encounter (opens its action dialog).
/// `panel` pre-selects a worklist filter (e.g. `vitals`, `doctor`, `lab`).
/// `search` pre-fills the worklist search box.
@immutable
final class OpdWorkspaceQuery {
  const OpdWorkspaceQuery({
    this.flowId = '',
    this.panel = '',
    this.search = '',
  });

  factory OpdWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    return OpdWorkspaceQuery(
      flowId: pick(<String>[
        'id',
        'flow',
        'flowId',
        'encounter',
        'encounterId',
      ]),
      panel: pick(<String>['panel', 'stage', 'filter', 'queue']),
      search: pick(<String>['search', 'q', 'patient']),
    );
  }

  final String flowId;
  final String panel;
  final String search;

  bool get hasRouteTargeting =>
      flowId.isNotEmpty || panel.isNotEmpty || search.isNotEmpty;

  String get signature => '$flowId|$panel|$search';
}

@immutable
final class OpdTriageQueueQuery {
  const OpdTriageQueueQuery({
    this.search = '',
    this.stage,
    this.triageLevel,
    this.encounterType,
    this.queueScope = 'ALL',
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  final String search;
  final String? stage;
  final String? triageLevel;
  final String? encounterType;
  final String queueScope;
  final AppPageRequest pageRequest;

  OpdTriageQueueQuery copyWith({
    String? search,
    String? stage,
    String? triageLevel,
    String? encounterType,
    String? queueScope,
    AppPageRequest? pageRequest,
    bool clearStage = false,
    bool clearTriageLevel = false,
    bool clearEncounterType = false,
  }) {
    return OpdTriageQueueQuery(
      search: search ?? this.search,
      stage: clearStage ? null : stage ?? this.stage,
      triageLevel: clearTriageLevel ? null : triageLevel ?? this.triageLevel,
      encounterType: clearEncounterType
          ? null
          : encounterType ?? this.encounterType,
      queueScope: queueScope ?? this.queueScope,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class OpdAppointment {
  const OpdAppointment({
    required this.id,
    this.publicId,
    this.tenantId,
    this.facilityId,
    this.patientId,
    this.providerUserId,
    this.status,
    this.scheduledStart,
    this.scheduledEnd,
    this.reason,
    this.patientDisplayName,
    this.patientIdentifier,
    this.patientPhone,
    this.providerDisplayName,
    this.facilityName,
    this.updatedAt,
  });

  final String id;
  final String? publicId;
  final String? tenantId;
  final String? facilityId;
  final String? patientId;
  final String? providerUserId;
  final String? status;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String? reason;
  final String? patientDisplayName;
  final String? patientIdentifier;
  final String? patientPhone;
  final String? providerDisplayName;
  final String? facilityName;
  final DateTime? updatedAt;

  String get apiId => publicId ?? id;

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          patientDisplayName,
          patientIdentifier,
          id,
        ]) ??
        id;
  }

  OpdAppointment copyWith({
    String? id,
    String? publicId,
    String? tenantId,
    String? facilityId,
    String? patientId,
    String? providerUserId,
    String? status,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? reason,
    String? patientDisplayName,
    String? patientIdentifier,
    String? patientPhone,
    String? providerDisplayName,
    String? facilityName,
    DateTime? updatedAt,
  }) {
    return OpdAppointment(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      tenantId: tenantId ?? this.tenantId,
      facilityId: facilityId ?? this.facilityId,
      patientId: patientId ?? this.patientId,
      providerUserId: providerUserId ?? this.providerUserId,
      status: status ?? this.status,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      reason: reason ?? this.reason,
      patientDisplayName: patientDisplayName ?? this.patientDisplayName,
      patientIdentifier: patientIdentifier ?? this.patientIdentifier,
      patientPhone: patientPhone ?? this.patientPhone,
      providerDisplayName: providerDisplayName ?? this.providerDisplayName,
      facilityName: facilityName ?? this.facilityName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
final class OpdQueueEntry {
  const OpdQueueEntry({
    required this.id,
    this.publicId,
    this.tenantId,
    this.facilityId,
    this.patientId,
    this.appointmentId,
    this.providerUserId,
    this.status,
    this.queuedAt,
    this.patientDisplayName,
    this.patientIdentifier,
    this.patientPhone,
    this.appointmentReason,
    this.providerDisplayName,
    this.paymentStatus,
    this.amountToPay,
    this.amountPaid,
    this.currency,
  });

  final String id;
  final String? publicId;
  final String? tenantId;
  final String? facilityId;
  final String? patientId;
  final String? appointmentId;
  final String? providerUserId;
  final String? status;
  final DateTime? queuedAt;
  final String? patientDisplayName;
  final String? patientIdentifier;
  final String? patientPhone;
  final String? appointmentReason;
  final String? providerDisplayName;
  final String? paymentStatus;
  final num? amountToPay;
  final num? amountPaid;
  final String? currency;

  String get apiId => publicId ?? id;

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          patientDisplayName,
          patientIdentifier,
          id,
        ]) ??
        id;
  }

  OpdQueueEntry copyWith({
    String? id,
    String? publicId,
    String? tenantId,
    String? facilityId,
    String? patientId,
    String? appointmentId,
    String? providerUserId,
    String? status,
    DateTime? queuedAt,
    String? patientDisplayName,
    String? patientIdentifier,
    String? patientPhone,
    String? appointmentReason,
    String? providerDisplayName,
    String? paymentStatus,
    num? amountToPay,
    num? amountPaid,
    String? currency,
  }) {
    return OpdQueueEntry(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      tenantId: tenantId ?? this.tenantId,
      facilityId: facilityId ?? this.facilityId,
      patientId: patientId ?? this.patientId,
      appointmentId: appointmentId ?? this.appointmentId,
      providerUserId: providerUserId ?? this.providerUserId,
      status: status ?? this.status,
      queuedAt: queuedAt ?? this.queuedAt,
      patientDisplayName: patientDisplayName ?? this.patientDisplayName,
      patientIdentifier: patientIdentifier ?? this.patientIdentifier,
      patientPhone: patientPhone ?? this.patientPhone,
      appointmentReason: appointmentReason ?? this.appointmentReason,
      providerDisplayName: providerDisplayName ?? this.providerDisplayName,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountToPay: amountToPay ?? this.amountToPay,
      amountPaid: amountPaid ?? this.amountPaid,
      currency: currency ?? this.currency,
    );
  }
}

@immutable
final class OpdFlowSummary {
  const OpdFlowSummary({
    required this.id,
    this.publicId,
    this.tenantId,
    this.facilityId,
    this.patientId,
    this.providerUserId,
    this.encounterType,
    this.status,
    this.startedAt,
    this.queuedAt,
    this.endedAt,
    this.arrivalMode,
    this.stage,
    this.nextStep,
    this.displayCode,
    this.displayStatus,
    this.displayNextStep,
    this.patientDisplayName,
    this.patientIdentifier,
    this.patientPhone,
    this.providerDisplayName,
    this.assignedStaffDisplayName,
    this.assignedStaffRole,
    this.assignedStaffType,
    this.assignedStaffLabel,
    this.appointmentId,
    this.visitQueueId,
    this.triageLevel,
    this.triagePriorityRank,
    this.triageNotes,
    this.chiefComplaint,
    this.emergencyIndicator = false,
    this.lastRouteTo,
    this.facilityName,
    this.consultationPaid = false,
    this.consultationPaymentRequired = false,
    this.consultationFee,
    this.consultationPaidAmount,
    this.consultationCurrency,
    this.consultationInvoiceId,
    this.consultationPaymentId,
    this.consultationPaymentStatus,
  });

  final String id;
  final String? publicId;
  final String? tenantId;
  final String? facilityId;
  final String? patientId;
  final String? providerUserId;
  final String? encounterType;
  final String? status;
  final DateTime? startedAt;
  final DateTime? queuedAt;
  final DateTime? endedAt;
  final String? arrivalMode;
  final String? stage;
  final String? nextStep;
  final String? displayCode;
  final String? displayStatus;
  final String? displayNextStep;
  final String? patientDisplayName;
  final String? patientIdentifier;
  final String? patientPhone;
  final String? providerDisplayName;
  final String? assignedStaffDisplayName;
  final String? assignedStaffRole;
  final String? assignedStaffType;
  final String? assignedStaffLabel;
  final String? appointmentId;
  final String? visitQueueId;
  final String? triageLevel;
  final int? triagePriorityRank;
  final String? triageNotes;
  final String? chiefComplaint;
  final bool emergencyIndicator;
  final String? lastRouteTo;
  final String? facilityName;
  final bool consultationPaid;
  final bool consultationPaymentRequired;
  final num? consultationFee;
  final num? consultationPaidAmount;
  final String? consultationCurrency;
  final String? consultationInvoiceId;
  final String? consultationPaymentId;
  final String? consultationPaymentStatus;

  String get apiId => publicId ?? id;

  bool get isTerminal {
    return stage == 'ADMITTED' || stage == 'DISCHARGED' || status == 'CLOSED';
  }

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          patientDisplayName,
          patientIdentifier,
          id,
        ]) ??
        id;
  }

  OpdFlowSummary copyWith({
    String? id,
    String? publicId,
    String? tenantId,
    String? facilityId,
    String? patientId,
    String? providerUserId,
    String? encounterType,
    String? status,
    DateTime? startedAt,
    DateTime? queuedAt,
    DateTime? endedAt,
    String? arrivalMode,
    String? stage,
    String? nextStep,
    String? displayCode,
    String? displayStatus,
    String? displayNextStep,
    String? patientDisplayName,
    String? patientIdentifier,
    String? patientPhone,
    String? providerDisplayName,
    String? assignedStaffDisplayName,
    String? assignedStaffRole,
    String? assignedStaffType,
    String? assignedStaffLabel,
    String? appointmentId,
    String? visitQueueId,
    String? triageLevel,
    int? triagePriorityRank,
    String? triageNotes,
    String? chiefComplaint,
    bool? emergencyIndicator,
    String? lastRouteTo,
    String? facilityName,
    bool? consultationPaid,
    bool? consultationPaymentRequired,
    num? consultationFee,
    num? consultationPaidAmount,
    String? consultationCurrency,
    String? consultationInvoiceId,
    String? consultationPaymentId,
    String? consultationPaymentStatus,
  }) {
    return OpdFlowSummary(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      tenantId: tenantId ?? this.tenantId,
      facilityId: facilityId ?? this.facilityId,
      patientId: patientId ?? this.patientId,
      providerUserId: providerUserId ?? this.providerUserId,
      encounterType: encounterType ?? this.encounterType,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      queuedAt: queuedAt ?? this.queuedAt,
      endedAt: endedAt ?? this.endedAt,
      arrivalMode: arrivalMode ?? this.arrivalMode,
      stage: stage ?? this.stage,
      nextStep: nextStep ?? this.nextStep,
      displayCode: displayCode ?? this.displayCode,
      displayStatus: displayStatus ?? this.displayStatus,
      displayNextStep: displayNextStep ?? this.displayNextStep,
      patientDisplayName: patientDisplayName ?? this.patientDisplayName,
      patientIdentifier: patientIdentifier ?? this.patientIdentifier,
      patientPhone: patientPhone ?? this.patientPhone,
      providerDisplayName: providerDisplayName ?? this.providerDisplayName,
      assignedStaffDisplayName:
          assignedStaffDisplayName ?? this.assignedStaffDisplayName,
      assignedStaffRole: assignedStaffRole ?? this.assignedStaffRole,
      assignedStaffType: assignedStaffType ?? this.assignedStaffType,
      assignedStaffLabel: assignedStaffLabel ?? this.assignedStaffLabel,
      appointmentId: appointmentId ?? this.appointmentId,
      visitQueueId: visitQueueId ?? this.visitQueueId,
      triageLevel: triageLevel ?? this.triageLevel,
      triagePriorityRank: triagePriorityRank ?? this.triagePriorityRank,
      triageNotes: triageNotes ?? this.triageNotes,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      emergencyIndicator: emergencyIndicator ?? this.emergencyIndicator,
      lastRouteTo: lastRouteTo ?? this.lastRouteTo,
      facilityName: facilityName ?? this.facilityName,
      consultationPaid: consultationPaid ?? this.consultationPaid,
      consultationPaymentRequired:
          consultationPaymentRequired ?? this.consultationPaymentRequired,
      consultationFee: consultationFee ?? this.consultationFee,
      consultationPaidAmount:
          consultationPaidAmount ?? this.consultationPaidAmount,
      consultationCurrency: consultationCurrency ?? this.consultationCurrency,
      consultationInvoiceId:
          consultationInvoiceId ?? this.consultationInvoiceId,
      consultationPaymentId:
          consultationPaymentId ?? this.consultationPaymentId,
      consultationPaymentStatus:
          consultationPaymentStatus ?? this.consultationPaymentStatus,
    );
  }
}

@immutable
final class OpdTimelineItem {
  const OpdTimelineItem({
    required this.action,
    this.stage,
    this.notes,
    this.occurredAt,
  });

  final String action;
  final String? stage;
  final String? notes;
  final DateTime? occurredAt;
}

@immutable
final class OpdRelatedRecord {
  const OpdRelatedRecord({
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
final class OpdVitalSign {
  const OpdVitalSign({
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
    final String normalized = value?.trim() ?? '';
    final String normalizedUnit = unit?.trim() ?? '';
    if (normalized.isEmpty) {
      return '';
    }
    if (normalizedUnit.isEmpty) {
      return normalized;
    }
    return '$normalized $normalizedUnit';
  }

  Iterable<OpdVitalComponentValue> get componentValues sync* {
    if (vitalType == 'BLOOD_PRESSURE') {
      if (systolicValue != null) {
        yield OpdVitalComponentValue(
          vitalType: vitalType,
          component: 'SYSTOLIC',
          value: systolicValue!,
        );
      }
      if (diastolicValue != null) {
        yield OpdVitalComponentValue(
          vitalType: vitalType,
          component: 'DIASTOLIC',
          value: diastolicValue!,
        );
      }
      if (mapValue != null) {
        yield OpdVitalComponentValue(
          vitalType: vitalType,
          component: 'MAP',
          value: mapValue!,
        );
      }
      return;
    }

    final num? parsedValue = value == null ? null : num.tryParse(value!.trim());
    if (parsedValue != null) {
      yield OpdVitalComponentValue(
        vitalType: vitalType,
        component: 'VALUE',
        value: parsedValue,
      );
    }
  }
}

@immutable
final class OpdVitalComponentValue {
  const OpdVitalComponentValue({
    required this.vitalType,
    required this.component,
    required this.value,
  });

  final String vitalType;
  final String component;
  final num value;
}

@immutable
final class OpdClinicalAlert {
  const OpdClinicalAlert({
    required this.id,
    this.severity,
    this.status,
    this.message,
    this.source,
    this.vitalSignId,
    this.createdAt,
  });

  final String id;
  final String? severity;
  final String? status;
  final String? message;
  final String? source;
  final String? vitalSignId;
  final DateTime? createdAt;
}

@immutable
final class OpdClinicalAlertThreshold {
  const OpdClinicalAlertThreshold({
    this.id,
    required this.vitalType,
    required this.component,
    required this.ageBand,
    this.normalMin,
    this.normalMax,
    this.criticalLow,
    this.criticalHigh,
    this.isActive = true,
    this.source,
  });

  final String? id;
  final String vitalType;
  final String component;
  final String ageBand;
  final num? normalMin;
  final num? normalMax;
  final num? criticalLow;
  final num? criticalHigh;
  final bool isActive;
  final String? source;
}

@immutable
final class OpdDrugOption {
  const OpdDrugOption({
    required this.id,
    this.publicId,
    this.name,
    this.code,
    this.form,
    this.strength,
    this.availableQuantity,
  });

  final String id;
  final String? publicId;
  final String? name;
  final String? code;
  final String? form;
  final String? strength;
  final int? availableQuantity;

  String get apiId => publicId ?? id;

  String get displayTitle {
    final List<String> parts = <String>[
      if ((name ?? '').trim().isNotEmpty) name!.trim(),
      if ((code ?? '').trim().isNotEmpty) code!.trim(),
    ];
    return parts.isEmpty ? apiId : parts.join(' | ');
  }
}

@immutable
final class OpdFlowDetail {
  const OpdFlowDetail({
    required this.summary,
    this.consultationInvoiceId,
    this.consultationPaymentId,
    this.consultationPaymentStatus,
    this.consultationPaid = false,
    this.consultationPaymentRequired = false,
    this.consultationPaidAmount,
    this.timeline = const <OpdTimelineItem>[],
    this.referrals = const <OpdRelatedRecord>[],
    this.followUps = const <OpdRelatedRecord>[],
    this.clinicalAlerts = const <OpdRelatedRecord>[],
    this.clinicalAlertDetails = const <OpdClinicalAlert>[],
    this.vitalSigns = const <OpdRelatedRecord>[],
    this.vitalMeasurements = const <OpdVitalSign>[],
    this.clinicalNotes = const <OpdRelatedRecord>[],
    this.diagnoses = const <OpdRelatedRecord>[],
    this.procedures = const <OpdRelatedRecord>[],
    this.labOrders = const <OpdRelatedRecord>[],
    this.radiologyOrders = const <OpdRelatedRecord>[],
    this.pharmacyOrders = const <OpdRelatedRecord>[],
    this.admissions = const <OpdRelatedRecord>[],
  });

  final OpdFlowSummary summary;
  final String? consultationInvoiceId;
  final String? consultationPaymentId;
  final String? consultationPaymentStatus;
  final bool consultationPaid;
  final bool consultationPaymentRequired;
  final num? consultationPaidAmount;
  final List<OpdTimelineItem> timeline;
  final List<OpdRelatedRecord> referrals;
  final List<OpdRelatedRecord> followUps;
  final List<OpdRelatedRecord> clinicalAlerts;
  final List<OpdClinicalAlert> clinicalAlertDetails;
  final List<OpdRelatedRecord> vitalSigns;
  final List<OpdVitalSign> vitalMeasurements;
  final List<OpdRelatedRecord> clinicalNotes;
  final List<OpdRelatedRecord> diagnoses;
  final List<OpdRelatedRecord> procedures;
  final List<OpdRelatedRecord> labOrders;
  final List<OpdRelatedRecord> radiologyOrders;
  final List<OpdRelatedRecord> pharmacyOrders;
  final List<OpdRelatedRecord> admissions;
}

@immutable
final class OpdProviderSchedule {
  const OpdProviderSchedule({
    required this.id,
    this.publicId,
    this.providerUserId,
    this.providerPublicId,
    this.providerDisplayName,
    this.facilityName,
    this.scheduleType,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.timezone,
    this.slotCount = 0,
  });

  final String id;
  final String? publicId;
  final String? providerUserId;
  final String? providerPublicId;
  final String? providerDisplayName;
  final String? facilityName;
  final String? scheduleType;
  final int? dayOfWeek;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? timezone;
  final int slotCount;

  String get apiId => publicId ?? id;
  String get providerApiId => providerPublicId ?? providerUserId ?? '';
}

@immutable
final class OpdProviderOption {
  const OpdProviderOption({
    required this.id,
    this.displayName,
    this.email,
    this.phone,
    this.positionTitle,
    this.practitionerType,
    this.facilityId,
    this.staffProfileId,
    this.consultationFee,
    this.consultationCurrency,
  });

  final String id;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? positionTitle;
  final String? practitionerType;
  final String? facilityId;
  final String? staffProfileId;
  final num? consultationFee;
  final String? consultationCurrency;

  String get displayTitle {
    return _firstNonEmpty(<String?>[displayName]) ?? 'Assigned staff unknown';
  }
}

@immutable
final class OpdAvailabilitySlot {
  const OpdAvailabilitySlot({
    required this.id,
    this.publicId,
    this.scheduleId,
    this.providerDisplayName,
    this.startTime,
    this.endTime,
    this.isAvailable = false,
  });

  final String id;
  final String? publicId;
  final String? scheduleId;
  final String? providerDisplayName;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isAvailable;
}

@immutable
final class OpdFlowAggregateCounts {
  const OpdFlowAggregateCounts({
    this.allPatients = 0,
    this.allOpdPatients = 0,
    this.activeOpd = 0,
    this.vitalsNeeded = 0,
    this.doctorNeeded = 0,
    this.withDoctor = 0,
    this.labPending = 0,
    this.imagingPending = 0,
    this.pharmacyPending = 0,
    this.decisionNeeded = 0,
    this.admissionPending = 0,
    this.dischargedToday = 0,
  });

  static const OpdFlowAggregateCounts empty = OpdFlowAggregateCounts();

  final int allPatients;
  final int allOpdPatients;
  final int activeOpd;
  final int vitalsNeeded;
  final int doctorNeeded;
  final int withDoctor;
  final int labPending;
  final int imagingPending;
  final int pharmacyPending;
  final int decisionNeeded;
  final int admissionPending;
  final int dischargedToday;
}

@immutable
final class OpdWorkspaceState {
  const OpdWorkspaceState({
    required this.appointmentQuery,
    required this.queueQuery,
    required this.flowQuery,
    required this.triageQueueQuery,
    required this.appointments,
    required this.queueEntries,
    required this.flows,
    required this.triageQueue,
    this.summaryCounts = OpdFlowAggregateCounts.empty,
    this.clinicalAlertThresholds = const <OpdClinicalAlertThreshold>[],
    this.providerSchedules = const <OpdProviderSchedule>[],
    this.availabilitySlots = const <OpdAvailabilitySlot>[],
    this.selectedFlow,
    this.lastFailure,
    this.isRefreshingAppointments = false,
    this.isRefreshingQueue = false,
    this.isRefreshingFlows = false,
    this.isRefreshingTriageQueue = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  factory OpdWorkspaceState.empty() {
    return const OpdWorkspaceState(
      appointmentQuery: OpdAppointmentQuery(),
      queueQuery: OpdQueueQuery(),
      flowQuery: OpdFlowQuery(),
      triageQueueQuery: OpdTriageQueueQuery(),
      appointments: AppPage<OpdAppointment>(
        items: <OpdAppointment>[],
        request: AppPageRequest(pageSize: 8),
      ),
      queueEntries: AppPage<OpdQueueEntry>(
        items: <OpdQueueEntry>[],
        request: AppPageRequest(pageSize: 12),
      ),
      flows: AppPage<OpdFlowSummary>(
        items: <OpdFlowSummary>[],
        request: AppPageRequest(pageSize: 12),
      ),
      triageQueue: AppPage<OpdFlowSummary>(
        items: <OpdFlowSummary>[],
        request: AppPageRequest(pageSize: 12),
      ),
    );
  }

  final OpdAppointmentQuery appointmentQuery;
  final OpdQueueQuery queueQuery;
  final OpdFlowQuery flowQuery;
  final OpdTriageQueueQuery triageQueueQuery;
  final AppPage<OpdAppointment> appointments;
  final AppPage<OpdQueueEntry> queueEntries;
  final AppPage<OpdFlowSummary> flows;
  final AppPage<OpdFlowSummary> triageQueue;
  final OpdFlowAggregateCounts summaryCounts;
  final List<OpdClinicalAlertThreshold> clinicalAlertThresholds;
  final List<OpdProviderSchedule> providerSchedules;
  final List<OpdAvailabilitySlot> availabilitySlots;
  final OpdFlowDetail? selectedFlow;
  final Object? lastFailure;
  final bool isRefreshingAppointments;
  final bool isRefreshingQueue;
  final bool isRefreshingFlows;
  final bool isRefreshingTriageQueue;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get arrivalCount => appointments.items
      .where((OpdAppointment item) => !isOpdTerminalStatus(item.status))
      .length;
  int get queueCount => queueEntries.items
      .where((OpdQueueEntry item) => !isOpdTerminalStatus(item.status))
      .length;
  int get activeFlowCount {
    return flows.items
        .where(
          (OpdFlowSummary flow) =>
              !flow.isTerminal &&
              !isOpdTerminalStatus(flow.status ?? flow.stage),
        )
        .length;
  }

  int get triageQueueCount {
    return triageQueue.items
        .where(
          (OpdFlowSummary flow) =>
              !flow.isTerminal &&
              !isOpdTerminalStatus(flow.status ?? flow.stage),
        )
        .length;
  }

  int get completedFlowCount {
    return flows.items.where((OpdFlowSummary flow) => flow.isTerminal).length;
  }

  int get workloadCount {
    if (summaryCounts.activeOpd > 0) {
      return summaryCounts.activeOpd;
    }

    final Set<String> activePatientKeys = <String>{};
    for (final OpdFlowSummary flow in flows.items) {
      if (flow.isTerminal || isOpdTerminalStatus(flow.status ?? flow.stage)) {
        continue;
      }
      final String key = (flow.patientId ?? flow.patientDisplayName ?? flow.id)
          .trim();
      if (key.isNotEmpty) {
        activePatientKeys.add(key);
      }
    }
    return activePatientKeys.isNotEmpty
        ? activePatientKeys.length
        : activeFlowCount;
  }

  OpdWorkspaceState copyWith({
    OpdAppointmentQuery? appointmentQuery,
    OpdQueueQuery? queueQuery,
    OpdFlowQuery? flowQuery,
    OpdTriageQueueQuery? triageQueueQuery,
    AppPage<OpdAppointment>? appointments,
    AppPage<OpdQueueEntry>? queueEntries,
    AppPage<OpdFlowSummary>? flows,
    AppPage<OpdFlowSummary>? triageQueue,
    OpdFlowAggregateCounts? summaryCounts,
    List<OpdClinicalAlertThreshold>? clinicalAlertThresholds,
    List<OpdProviderSchedule>? providerSchedules,
    List<OpdAvailabilitySlot>? availabilitySlots,
    OpdFlowDetail? selectedFlow,
    Object? lastFailure,
    bool? isRefreshingAppointments,
    bool? isRefreshingQueue,
    bool? isRefreshingFlows,
    bool? isRefreshingTriageQueue,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedFlow = false,
    bool clearLastFailure = false,
  }) {
    return OpdWorkspaceState(
      appointmentQuery: appointmentQuery ?? this.appointmentQuery,
      queueQuery: queueQuery ?? this.queueQuery,
      flowQuery: flowQuery ?? this.flowQuery,
      triageQueueQuery: triageQueueQuery ?? this.triageQueueQuery,
      appointments: appointments ?? this.appointments,
      queueEntries: queueEntries ?? this.queueEntries,
      flows: flows ?? this.flows,
      triageQueue: triageQueue ?? this.triageQueue,
      summaryCounts: summaryCounts ?? this.summaryCounts,
      clinicalAlertThresholds:
          clinicalAlertThresholds ?? this.clinicalAlertThresholds,
      providerSchedules: providerSchedules ?? this.providerSchedules,
      availabilitySlots: availabilitySlots ?? this.availabilitySlots,
      selectedFlow: clearSelectedFlow
          ? null
          : selectedFlow ?? this.selectedFlow,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshingAppointments:
          isRefreshingAppointments ?? this.isRefreshingAppointments,
      isRefreshingQueue: isRefreshingQueue ?? this.isRefreshingQueue,
      isRefreshingFlows: isRefreshingFlows ?? this.isRefreshingFlows,
      isRefreshingTriageQueue:
          isRefreshingTriageQueue ?? this.isRefreshingTriageQueue,
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

bool isOpdTerminalStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'DISCHARGED' ||
    'ADMITTED' ||
    'CLOSED' => true,
    _ => false,
  };
}
