import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/data/data.dart';

const String mortuaryPanelOverview = 'overview';
const String mortuaryPanelIntake = 'intake';
const String mortuaryPanelStorage = 'storage';
const String mortuaryPanelCustody = 'custody';
const String mortuaryPanelRelease = 'release';
const String mortuaryPanelReporting = 'reporting';

const String mortuaryResourceCases = 'mortuary-cases';
const String mortuaryResourceStorageUnits = 'mortuary-storage-units';
const String mortuaryResourceStorageSlots = 'mortuary-storage-slots';
const String mortuaryResourceStorageAssignments =
    'mortuary-storage-assignments';
const String mortuaryResourceCustodyEvents = 'mortuary-custody-events';
const String mortuaryResourceViewings = 'mortuary-viewings';
const String mortuaryResourcePostMortemRequests =
    'mortuary-post-mortem-requests';
const String mortuaryResourceReleaseAuthorisations =
    'mortuary-release-authorisations';
const String mortuaryResourceBillableEvents = 'mortuary-billable-events';

const String mortuaryQueueIdentificationPending = 'IDENTIFICATION_PENDING';
const String mortuaryQueueStorageExceptions = 'STORAGE_EXCEPTIONS';
const String mortuaryQueueReleaseReady = 'RELEASE_READY';
const String mortuaryQueueUnsettledBilling = 'UNSETTLED_BILLING';
const String mortuaryQueuePostMortemPending = 'POST_MORTEM_PENDING';

const List<String> mortuaryPanels = <String>[
  mortuaryPanelOverview,
  mortuaryPanelIntake,
  mortuaryPanelStorage,
  mortuaryPanelCustody,
  mortuaryPanelRelease,
  mortuaryPanelReporting,
];

const Map<String, String> mortuaryDefaultResourceByPanel = <String, String>{
  mortuaryPanelOverview: mortuaryResourceCases,
  mortuaryPanelIntake: mortuaryResourceCases,
  mortuaryPanelStorage: mortuaryResourceStorageAssignments,
  mortuaryPanelCustody: mortuaryResourceCustodyEvents,
  mortuaryPanelRelease: mortuaryResourceReleaseAuthorisations,
  mortuaryPanelReporting: mortuaryResourcePostMortemRequests,
};

const List<String> mortuaryResources = <String>[
  mortuaryResourceCases,
  mortuaryResourceStorageUnits,
  mortuaryResourceStorageSlots,
  mortuaryResourceStorageAssignments,
  mortuaryResourceCustodyEvents,
  mortuaryResourceViewings,
  mortuaryResourcePostMortemRequests,
  mortuaryResourceReleaseAuthorisations,
  mortuaryResourceBillableEvents,
];

const List<String> mortuaryQueues = <String>[
  mortuaryQueueIdentificationPending,
  mortuaryQueueStorageExceptions,
  mortuaryQueueReleaseReady,
  mortuaryQueueUnsettledBilling,
  mortuaryQueuePostMortemPending,
];

const List<String> mortuaryCaseStatuses = <String>[
  'RECEIVED',
  'IDENTIFICATION_PENDING',
  'IN_STORAGE',
  'POST_MORTEM_PENDING',
  'READY_FOR_RELEASE',
  'RELEASED',
  'CLOSED',
  'CANCELLED',
];

const List<String> mortuaryIdentificationStatuses = <String>[
  'UNVERIFIED',
  'PARTIAL',
  'VERIFIED',
];

const List<String> mortuaryDatePresets = <String>[
  'today',
  'next_7_days',
  'overdue',
  'this_month',
];

@immutable
final class MortuaryWorkspaceQuery {
  const MortuaryWorkspaceQuery({
    this.panel = mortuaryPanelOverview,
    this.resource = mortuaryResourceCases,
    this.queue,
    this.search = '',
    this.status,
    this.identificationStatus,
    this.facilityId,
    this.storageUnitId,
    this.storageSlotId,
    this.datePreset,
    this.id,
    this.action,
    this.pageRequest = const AppPageRequest(),
  });

  final String panel;
  final String resource;
  final String? queue;
  final String search;
  final String? status;
  final String? identificationStatus;
  final String? facilityId;
  final String? storageUnitId;
  final String? storageSlotId;
  final String? datePreset;
  final String? id;
  final String? action;
  final AppPageRequest pageRequest;

  MortuaryWorkspaceQuery copyWith({
    String? panel,
    String? resource,
    String? queue,
    String? search,
    String? status,
    String? identificationStatus,
    String? facilityId,
    String? storageUnitId,
    String? storageSlotId,
    String? datePreset,
    String? id,
    String? action,
    AppPageRequest? pageRequest,
    bool clearQueue = false,
    bool clearStatus = false,
    bool clearIdentificationStatus = false,
    bool clearFacilityId = false,
    bool clearStorageUnitId = false,
    bool clearStorageSlotId = false,
    bool clearDatePreset = false,
    bool clearId = false,
    bool clearAction = false,
  }) {
    final String nextPanel = panel ?? this.panel;
    return MortuaryWorkspaceQuery(
      panel: nextPanel,
      resource:
          resource ??
          this.resource.ifNotEmpty ??
          mortuaryDefaultResourceByPanel[nextPanel] ??
          mortuaryResourceCases,
      queue: clearQueue ? null : queue ?? this.queue,
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      identificationStatus: clearIdentificationStatus
          ? null
          : identificationStatus ?? this.identificationStatus,
      facilityId: clearFacilityId ? null : facilityId ?? this.facilityId,
      storageUnitId: clearStorageUnitId
          ? null
          : storageUnitId ?? this.storageUnitId,
      storageSlotId: clearStorageSlotId
          ? null
          : storageSlotId ?? this.storageSlotId,
      datePreset: clearDatePreset ? null : datePreset ?? this.datePreset,
      id: clearId ? null : id ?? this.id,
      action: clearAction ? null : action ?? this.action,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class MortuaryWorkspaceState {
  const MortuaryWorkspaceState({
    required this.items,
    required this.query,
    required this.lookups,
    this.summary = const <MortuarySummaryItem>[],
    this.queues = const <MortuaryQueueSummary>[],
    this.panels = const <MortuaryPanelSummary>[],
    this.spotlight = const <MortuaryQueueSummary>[],
    this.selectedItem,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.lastUpdatedAt,
    this.lastFailure,
  });

  final AppPage<MortuaryWorkspaceItem> items;
  final MortuaryWorkspaceQuery query;
  final MortuaryLookupData lookups;
  final List<MortuarySummaryItem> summary;
  final List<MortuaryQueueSummary> queues;
  final List<MortuaryPanelSummary> panels;
  final List<MortuaryQueueSummary> spotlight;
  final MortuaryWorkspaceItem? selectedItem;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final DateTime? lastUpdatedAt;
  final AppFailure? lastFailure;

  int get workloadCount {
    final int count =
        queueCount(mortuaryQueueIdentificationPending) +
        queueCount(mortuaryQueueStorageExceptions) +
        queueCount(mortuaryQueueReleaseReady) +
        queueCount(mortuaryQueueUnsettledBilling) +
        queueCount(mortuaryQueuePostMortemPending);
    return count > 0 ? count : items.items.length;
  }

  int summaryValue(String id) {
    for (final MortuarySummaryItem item in summary) {
      if (item.id == id) {
        return item.value;
      }
    }
    return 0;
  }

  int queueCount(String queue) {
    for (final MortuaryQueueSummary item in queues) {
      if (item.queue == queue) {
        return item.count;
      }
    }
    return 0;
  }

  MortuaryWorkspaceState copyWith({
    AppPage<MortuaryWorkspaceItem>? items,
    MortuaryWorkspaceQuery? query,
    MortuaryLookupData? lookups,
    List<MortuarySummaryItem>? summary,
    List<MortuaryQueueSummary>? queues,
    List<MortuaryPanelSummary>? panels,
    List<MortuaryQueueSummary>? spotlight,
    MortuaryWorkspaceItem? selectedItem,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    DateTime? lastUpdatedAt,
    AppFailure? lastFailure,
    bool clearSelectedItem = false,
    bool clearLastFailure = false,
  }) {
    return MortuaryWorkspaceState(
      items: items ?? this.items,
      query: query ?? this.query,
      lookups: lookups ?? this.lookups,
      summary: summary ?? this.summary,
      queues: queues ?? this.queues,
      panels: panels ?? this.panels,
      spotlight: spotlight ?? this.spotlight,
      selectedItem: clearSelectedItem
          ? null
          : selectedItem ?? this.selectedItem,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
    );
  }
}

@immutable
final class MortuaryWorkspacePayload {
  const MortuaryWorkspacePayload({
    required this.items,
    required this.lookups,
    this.summary = const <MortuarySummaryItem>[],
    this.queues = const <MortuaryQueueSummary>[],
    this.panels = const <MortuaryPanelSummary>[],
    this.spotlight = const <MortuaryQueueSummary>[],
    this.filters,
    this.lastUpdatedAt,
  });

  final AppPage<MortuaryWorkspaceItem> items;
  final MortuaryLookupData lookups;
  final List<MortuarySummaryItem> summary;
  final List<MortuaryQueueSummary> queues;
  final List<MortuaryPanelSummary> panels;
  final List<MortuaryQueueSummary> spotlight;
  final MortuaryWorkspaceQuery? filters;
  final DateTime? lastUpdatedAt;
}

@immutable
final class MortuaryLookupData {
  const MortuaryLookupData({
    this.facilities = const <MortuaryLookupOption>[],
    this.storageUnits = const <MortuaryLookupOption>[],
    this.storageSlots = const <MortuaryLookupOption>[],
    this.deceasedProfiles = const <MortuaryLookupOption>[],
    this.patients = const <MortuaryLookupOption>[],
    this.sourceWorkflows = const <MortuaryLookupOption>[],
    this.statuses = const <MortuaryLookupOption>[],
    this.identificationStatuses = const <MortuaryLookupOption>[],
    this.storageSlotStatuses = const <MortuaryLookupOption>[],
    this.postMortemStatuses = const <MortuaryLookupOption>[],
    this.releaseStatuses = const <MortuaryLookupOption>[],
    this.queues = const <MortuaryLookupOption>[],
  });

  final List<MortuaryLookupOption> facilities;
  final List<MortuaryLookupOption> storageUnits;
  final List<MortuaryLookupOption> storageSlots;
  final List<MortuaryLookupOption> deceasedProfiles;
  final List<MortuaryLookupOption> patients;
  final List<MortuaryLookupOption> sourceWorkflows;
  final List<MortuaryLookupOption> statuses;
  final List<MortuaryLookupOption> identificationStatuses;
  final List<MortuaryLookupOption> storageSlotStatuses;
  final List<MortuaryLookupOption> postMortemStatuses;
  final List<MortuaryLookupOption> releaseStatuses;
  final List<MortuaryLookupOption> queues;
}

@immutable
final class MortuaryLookupOption {
  const MortuaryLookupOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.meta = const <String, Object?>{},
  });

  final String id;
  final String label;
  final String? subtitle;
  final Map<String, Object?> meta;

  bool get hasValue => id.isNotEmpty && label.isNotEmpty;
}

@immutable
final class MortuarySummaryItem {
  const MortuarySummaryItem({
    required this.id,
    required this.value,
    this.labelKey,
  });

  final String id;
  final int value;
  final String? labelKey;
}

@immutable
final class MortuaryQueueSummary {
  const MortuaryQueueSummary({
    required this.queue,
    required this.count,
    this.labelKey,
    this.panel,
    this.resource,
    this.targetPath,
  });

  final String queue;
  final int count;
  final String? labelKey;
  final String? panel;
  final String? resource;
  final String? targetPath;
}

@immutable
final class MortuaryPanelSummary {
  const MortuaryPanelSummary({
    required this.id,
    required this.count,
    this.labelKey,
    this.defaultResource,
    this.targetPath,
  });

  final String id;
  final int count;
  final String? labelKey;
  final String? defaultResource;
  final String? targetPath;
}

@immutable
final class MortuaryWorkspaceItem {
  const MortuaryWorkspaceItem({
    required this.id,
    this.displayId,
    this.resource = mortuaryResourceCases,
    this.title,
    this.subtitle,
    this.status,
    this.identificationStatus,
    this.billingStatus,
    this.billingReferenceId,
    this.releaseStatus,
    this.facilityId,
    this.facilityLabel,
    this.patientId,
    this.patientLabel,
    this.deceasedProfileId,
    this.deceasedProfileLabel,
    this.sourceWorkflow,
    this.sourceDepartment,
    this.sourceReferenceId,
    this.receivedFrom,
    this.receivedAt,
    this.releaseReadyAt,
    this.releasedAt,
    this.closedAt,
    this.storageUnitId,
    this.storageUnitLabel,
    this.storageSlotId,
    this.storageSlotLabel,
    this.storageSlotStatus,
    this.storageAssignment,
    this.mortuaryCase,
    this.unitType,
    this.capacity,
    this.slotCount,
    this.assignmentCount,
    this.slotCode,
    this.temperatureZone,
    this.isActive,
    this.eventType,
    this.eventAt,
    this.actorName,
    this.actorRole,
    this.locationLabel,
    this.reason,
    this.notes,
    this.scheduledAt,
    this.authorisedByName,
    this.attendeeSummary,
    this.completedAt,
    this.requestedByName,
    this.requestReason,
    this.diagnosticsReferenceId,
    this.reportReceivedAt,
    this.recipientName,
    this.recipientRelationship,
    this.verificationReference,
    this.funeralServiceName,
    this.releaseMethod,
    this.approvedByName,
    this.approvedAt,
    this.description,
    this.amountText,
    this.currency,
    this.chargedAt,
    this.settledAt,
    this.custodyEvents = const <MortuaryTimelineEvent>[],
    this.viewings = const <MortuaryViewing>[],
    this.postMortemRequests = const <MortuaryPostMortemRequest>[],
    this.releaseAuthorisations = const <MortuaryReleaseAuthorisation>[],
    this.billableEvents = const <MortuaryBillableEvent>[],
    this.targetPath,
    this.timelineAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String resource;
  final String? title;
  final String? subtitle;
  final String? status;
  final String? identificationStatus;
  final String? billingStatus;
  final String? billingReferenceId;
  final String? releaseStatus;
  final String? facilityId;
  final String? facilityLabel;
  final String? patientId;
  final String? patientLabel;
  final String? deceasedProfileId;
  final String? deceasedProfileLabel;
  final String? sourceWorkflow;
  final String? sourceDepartment;
  final String? sourceReferenceId;
  final String? receivedFrom;
  final DateTime? receivedAt;
  final DateTime? releaseReadyAt;
  final DateTime? releasedAt;
  final DateTime? closedAt;
  final String? storageUnitId;
  final String? storageUnitLabel;
  final String? storageSlotId;
  final String? storageSlotLabel;
  final String? storageSlotStatus;
  final MortuaryStorageAssignment? storageAssignment;
  final MortuaryCaseSummary? mortuaryCase;
  final String? unitType;
  final int? capacity;
  final int? slotCount;
  final int? assignmentCount;
  final String? slotCode;
  final String? temperatureZone;
  final bool? isActive;
  final String? eventType;
  final DateTime? eventAt;
  final String? actorName;
  final String? actorRole;
  final String? locationLabel;
  final String? reason;
  final String? notes;
  final DateTime? scheduledAt;
  final String? authorisedByName;
  final String? attendeeSummary;
  final DateTime? completedAt;
  final String? requestedByName;
  final String? requestReason;
  final String? diagnosticsReferenceId;
  final DateTime? reportReceivedAt;
  final String? recipientName;
  final String? recipientRelationship;
  final String? verificationReference;
  final String? funeralServiceName;
  final String? releaseMethod;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? description;
  final String? amountText;
  final String? currency;
  final DateTime? chargedAt;
  final DateTime? settledAt;
  final List<MortuaryTimelineEvent> custodyEvents;
  final List<MortuaryViewing> viewings;
  final List<MortuaryPostMortemRequest> postMortemRequests;
  final List<MortuaryReleaseAuthorisation> releaseAuthorisations;
  final List<MortuaryBillableEvent> billableEvents;
  final String? targetPath;
  final DateTime? timelineAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCase => resource == mortuaryResourceCases;

  String get effectiveDisplayId => displayId.ifNotEmpty ?? id;

  String? get caseId => isCase ? effectiveDisplayId : mortuaryCase?.id;

  String? get caseStatus => isCase ? status : mortuaryCase?.status;

  String? get caseBillingStatus {
    return isCase ? billingStatus : mortuaryCase?.billingStatus;
  }

  String? get caseIdentificationStatus {
    return isCase ? identificationStatus : mortuaryCase?.identificationStatus;
  }

  String? get effectiveDeceasedLabel {
    return deceasedProfileLabel.ifNotEmpty ??
        mortuaryCase?.deceasedProfileLabel.ifNotEmpty ??
        title.ifNotEmpty;
  }

  String? get effectivePersonLabel {
    return patientLabel.ifNotEmpty ?? effectiveDeceasedLabel;
  }

  String? get storageLabel {
    final String? slot = storageSlotLabel.ifNotEmpty;
    final String? unit = storageUnitLabel.ifNotEmpty;
    if (slot != null && unit != null) {
      return '$unit / $slot';
    }
    return slot ?? unit;
  }

  String? get sourceLabel {
    return sourceReferenceId.ifNotEmpty ??
        sourceDepartment.ifNotEmpty ??
        sourceWorkflow.ifNotEmpty ??
        receivedFrom.ifNotEmpty;
  }
}

@immutable
final class MortuaryCaseSummary {
  const MortuaryCaseSummary({
    this.id,
    this.status,
    this.identificationStatus,
    this.receivedAt,
    this.releaseReadyAt,
    this.releasedAt,
    this.billingStatus,
    this.deceasedProfileId,
    this.deceasedProfileLabel,
  });

  final String? id;
  final String? status;
  final String? identificationStatus;
  final DateTime? receivedAt;
  final DateTime? releaseReadyAt;
  final DateTime? releasedAt;
  final String? billingStatus;
  final String? deceasedProfileId;
  final String? deceasedProfileLabel;
}

@immutable
final class MortuaryStorageAssignment {
  const MortuaryStorageAssignment({
    this.id,
    this.status,
    this.assignedAt,
    this.endedAt,
    this.reason,
    this.storageUnitId,
    this.storageUnitLabel,
    this.storageSlotId,
    this.storageSlotLabel,
    this.storageSlotStatus,
  });

  final String? id;
  final String? status;
  final DateTime? assignedAt;
  final DateTime? endedAt;
  final String? reason;
  final String? storageUnitId;
  final String? storageUnitLabel;
  final String? storageSlotId;
  final String? storageSlotLabel;
  final String? storageSlotStatus;
}

@immutable
final class MortuaryTimelineEvent {
  const MortuaryTimelineEvent({
    required this.id,
    this.eventType,
    this.eventAt,
    this.actorName,
    this.actorRole,
    this.locationLabel,
    this.reason,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? eventType;
  final DateTime? eventAt;
  final String? actorName;
  final String? actorRole;
  final String? locationLabel;
  final String? reason;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class MortuaryViewing {
  const MortuaryViewing({
    required this.id,
    this.scheduledAt,
    this.status,
    this.authorisedByName,
    this.attendeeSummary,
    this.completedAt,
  });

  final String id;
  final DateTime? scheduledAt;
  final String? status;
  final String? authorisedByName;
  final String? attendeeSummary;
  final DateTime? completedAt;
}

@immutable
final class MortuaryPostMortemRequest {
  const MortuaryPostMortemRequest({
    required this.id,
    this.requestedByName,
    this.requestReason,
    this.status,
    this.diagnosticsReferenceId,
    this.scheduledAt,
    this.completedAt,
    this.reportReceivedAt,
  });

  final String id;
  final String? requestedByName;
  final String? requestReason;
  final String? status;
  final String? diagnosticsReferenceId;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final DateTime? reportReceivedAt;
}

@immutable
final class MortuaryReleaseAuthorisation {
  const MortuaryReleaseAuthorisation({
    required this.id,
    this.recipientName,
    this.recipientRelationship,
    this.verificationReference,
    this.funeralServiceName,
    this.releaseMethod,
    this.status,
    this.approvedByName,
    this.approvedAt,
    this.releasedAt,
  });

  final String id;
  final String? recipientName;
  final String? recipientRelationship;
  final String? verificationReference;
  final String? funeralServiceName;
  final String? releaseMethod;
  final String? status;
  final String? approvedByName;
  final DateTime? approvedAt;
  final DateTime? releasedAt;
}

@immutable
final class MortuaryBillableEvent {
  const MortuaryBillableEvent({
    required this.id,
    this.eventType,
    this.description,
    this.amountText,
    this.currency,
    this.status,
    this.billingReferenceId,
    this.chargedAt,
    this.settledAt,
  });

  final String id;
  final String? eventType;
  final String? description;
  final String? amountText;
  final String? currency;
  final String? status;
  final String? billingReferenceId;
  final DateTime? chargedAt;
  final DateTime? settledAt;
}

extension _NullableStringX on String? {
  String? get ifNotEmpty {
    final String? normalized = this?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
