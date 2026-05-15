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
    this.queueScope = 'ALL',
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  final String search;
  final String? stage;
  final String queueScope;
  final AppPageRequest pageRequest;

  OpdFlowQuery copyWith({
    String? search,
    String? stage,
    String? queueScope,
    AppPageRequest? pageRequest,
    bool clearStage = false,
  }) {
    return OpdFlowQuery(
      search: search ?? this.search,
      stage: clearStage ? null : stage ?? this.stage,
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
    this.endedAt,
    this.stage,
    this.nextStep,
    this.patientDisplayName,
    this.patientIdentifier,
    this.patientPhone,
    this.providerDisplayName,
    this.appointmentId,
    this.visitQueueId,
    this.facilityName,
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
  final DateTime? endedAt;
  final String? stage;
  final String? nextStep;
  final String? patientDisplayName;
  final String? patientIdentifier;
  final String? patientPhone;
  final String? providerDisplayName;
  final String? appointmentId;
  final String? visitQueueId;
  final String? facilityName;

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
    DateTime? endedAt,
    String? stage,
    String? nextStep,
    String? patientDisplayName,
    String? patientIdentifier,
    String? patientPhone,
    String? providerDisplayName,
    String? appointmentId,
    String? visitQueueId,
    String? facilityName,
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
      endedAt: endedAt ?? this.endedAt,
      stage: stage ?? this.stage,
      nextStep: nextStep ?? this.nextStep,
      patientDisplayName: patientDisplayName ?? this.patientDisplayName,
      patientIdentifier: patientIdentifier ?? this.patientIdentifier,
      patientPhone: patientPhone ?? this.patientPhone,
      providerDisplayName: providerDisplayName ?? this.providerDisplayName,
      appointmentId: appointmentId ?? this.appointmentId,
      visitQueueId: visitQueueId ?? this.visitQueueId,
      facilityName: facilityName ?? this.facilityName,
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
    this.consultationPaid = false,
    this.consultationPaymentRequired = false,
    this.timeline = const <OpdTimelineItem>[],
    this.referrals = const <OpdRelatedRecord>[],
    this.followUps = const <OpdRelatedRecord>[],
    this.clinicalAlerts = const <OpdRelatedRecord>[],
    this.vitalSigns = const <OpdRelatedRecord>[],
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
  final bool consultationPaid;
  final bool consultationPaymentRequired;
  final List<OpdTimelineItem> timeline;
  final List<OpdRelatedRecord> referrals;
  final List<OpdRelatedRecord> followUps;
  final List<OpdRelatedRecord> clinicalAlerts;
  final List<OpdRelatedRecord> vitalSigns;
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
final class OpdWorkspaceState {
  const OpdWorkspaceState({
    required this.appointmentQuery,
    required this.queueQuery,
    required this.flowQuery,
    required this.appointments,
    required this.queueEntries,
    required this.flows,
    this.providerSchedules = const <OpdProviderSchedule>[],
    this.availabilitySlots = const <OpdAvailabilitySlot>[],
    this.selectedFlow,
    this.lastFailure,
    this.isRefreshingAppointments = false,
    this.isRefreshingQueue = false,
    this.isRefreshingFlows = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  factory OpdWorkspaceState.empty() {
    return const OpdWorkspaceState(
      appointmentQuery: OpdAppointmentQuery(),
      queueQuery: OpdQueueQuery(),
      flowQuery: OpdFlowQuery(),
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
    );
  }

  final OpdAppointmentQuery appointmentQuery;
  final OpdQueueQuery queueQuery;
  final OpdFlowQuery flowQuery;
  final AppPage<OpdAppointment> appointments;
  final AppPage<OpdQueueEntry> queueEntries;
  final AppPage<OpdFlowSummary> flows;
  final List<OpdProviderSchedule> providerSchedules;
  final List<OpdAvailabilitySlot> availabilitySlots;
  final OpdFlowDetail? selectedFlow;
  final Object? lastFailure;
  final bool isRefreshingAppointments;
  final bool isRefreshingQueue;
  final bool isRefreshingFlows;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get arrivalCount =>
      appointments.totalItemCount ?? appointments.items.length;
  int get queueCount =>
      queueEntries.totalItemCount ?? queueEntries.items.length;
  int get activeFlowCount {
    return flows.items.where((OpdFlowSummary flow) => !flow.isTerminal).length;
  }

  int get completedFlowCount {
    return flows.items.where((OpdFlowSummary flow) => flow.isTerminal).length;
  }

  OpdWorkspaceState copyWith({
    OpdAppointmentQuery? appointmentQuery,
    OpdQueueQuery? queueQuery,
    OpdFlowQuery? flowQuery,
    AppPage<OpdAppointment>? appointments,
    AppPage<OpdQueueEntry>? queueEntries,
    AppPage<OpdFlowSummary>? flows,
    List<OpdProviderSchedule>? providerSchedules,
    List<OpdAvailabilitySlot>? availabilitySlots,
    OpdFlowDetail? selectedFlow,
    Object? lastFailure,
    bool? isRefreshingAppointments,
    bool? isRefreshingQueue,
    bool? isRefreshingFlows,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedFlow = false,
    bool clearLastFailure = false,
  }) {
    return OpdWorkspaceState(
      appointmentQuery: appointmentQuery ?? this.appointmentQuery,
      queueQuery: queueQuery ?? this.queueQuery,
      flowQuery: flowQuery ?? this.flowQuery,
      appointments: appointments ?? this.appointments,
      queueEntries: queueEntries ?? this.queueEntries,
      flows: flows ?? this.flows,
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
