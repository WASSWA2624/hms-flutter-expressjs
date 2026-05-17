import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/data/data.dart';

const List<String> radiologyStageFilters = <String>[
  'ALL',
  'ORDERED',
  'PROCESSING',
  'REPORTING',
  'COMPLETED',
  'CANCELLED',
];

const List<String> radiologyOrderStatuses = <String>[
  'ORDERED',
  'IN_PROCESS',
  'COMPLETED',
  'CANCELLED',
];

const List<String> radiologyModalities = <String>[
  'XRAY',
  'CT',
  'MRI',
  'ULTRASOUND',
  'PET',
  'ECG',
  'ECHO',
  'ENDO',
  'GASTRO',
  'OTHER',
];

const List<String> radiologyResultStatuses = <String>[
  'DRAFT',
  'FINAL',
  'AMENDED',
];

@immutable
final class RadiologyWorkspaceQuery {
  const RadiologyWorkspaceQuery({
    this.search = '',
    this.stage = 'ALL',
    this.status,
    this.modality,
    this.from,
    this.to,
    this.patientId,
    this.encounterId,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final String stage;
  final String? status;
  final String? modality;
  final DateTime? from;
  final DateTime? to;
  final String? patientId;
  final String? encounterId;
  final AppPageRequest pageRequest;

  RadiologyWorkspaceQuery copyWith({
    String? search,
    String? stage,
    String? status,
    String? modality,
    DateTime? from,
    DateTime? to,
    String? patientId,
    String? encounterId,
    AppPageRequest? pageRequest,
    bool clearStatus = false,
    bool clearModality = false,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearPatientId = false,
    bool clearEncounterId = false,
  }) {
    return RadiologyWorkspaceQuery(
      search: search ?? this.search,
      stage: stage ?? this.stage,
      status: clearStatus ? null : status ?? this.status,
      modality: clearModality ? null : modality ?? this.modality,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      patientId: clearPatientId ? null : patientId ?? this.patientId,
      encounterId: clearEncounterId ? null : encounterId ?? this.encounterId,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class RadiologyWorkspaceState {
  const RadiologyWorkspaceState({
    required this.orders,
    required this.summary,
    required this.references,
    required this.query,
    this.selectedWorkflow,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isMutating = false,
    this.lastFailure,
  });

  final AppPage<RadiologyOrder> orders;
  final RadiologySummary summary;
  final RadiologyReferenceData references;
  final RadiologyWorkspaceQuery query;
  final RadiologyWorkflow? selectedWorkflow;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isMutating;
  final AppFailure? lastFailure;

  int get workloadCount {
    return summary.orderedQueue +
        summary.processingQueue +
        summary.draftReports;
  }

  int get reportingCount {
    return summary.draftReports;
  }

  int get releasedCount {
    return summary.finalizedReports + summary.amendedReports;
  }

  RadiologyWorkspaceState copyWith({
    AppPage<RadiologyOrder>? orders,
    RadiologySummary? summary,
    RadiologyReferenceData? references,
    RadiologyWorkspaceQuery? query,
    RadiologyWorkflow? selectedWorkflow,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isMutating,
    AppFailure? lastFailure,
    bool clearSelectedWorkflow = false,
    bool clearLastFailure = false,
  }) {
    return RadiologyWorkspaceState(
      orders: orders ?? this.orders,
      summary: summary ?? this.summary,
      references: references ?? this.references,
      query: query ?? this.query,
      selectedWorkflow: clearSelectedWorkflow
          ? null
          : selectedWorkflow ?? this.selectedWorkflow,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isMutating: isMutating ?? this.isMutating,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
    );
  }
}

@immutable
final class RadiologySummary {
  const RadiologySummary({
    this.totalOrders = 0,
    this.orderedQueue = 0,
    this.processingQueue = 0,
    this.draftReports = 0,
    this.finalizedReports = 0,
    this.amendedReports = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.studiesTotal = 0,
    this.unsyncedStudies = 0,
  });

  final int totalOrders;
  final int orderedQueue;
  final int processingQueue;
  final int draftReports;
  final int finalizedReports;
  final int amendedReports;
  final int completedOrders;
  final int cancelledOrders;
  final int studiesTotal;
  final int unsyncedStudies;
}

@immutable
final class RadiologyOrder {
  const RadiologyOrder({
    required this.id,
    this.displayId,
    this.status,
    this.encounterId,
    this.patientId,
    this.patientDisplayName,
    this.radiologyTestId,
    this.testDisplayName,
    this.modality,
    this.clinicalNote,
    this.paymentStatus,
    this.authorizationStatus,
    this.requestDetails = const <String, Object?>{},
    this.requestedTests = const <RadiologyRequestedTest>[],
    this.orderedAt,
    this.createdAt,
    this.updatedAt,
    this.resultCount = 0,
    this.draftResultCount = 0,
    this.finalResultCount = 0,
    this.amendedResultCount = 0,
    this.studyCount = 0,
    this.unsyncedStudyCount = 0,
    this.results = const <RadiologyResult>[],
    this.imagingStudies = const <ImagingStudy>[],
  });

  final String id;
  final String? displayId;
  final String? status;
  final String? encounterId;
  final String? patientId;
  final String? patientDisplayName;
  final String? radiologyTestId;
  final String? testDisplayName;
  final String? modality;
  final String? clinicalNote;
  final String? paymentStatus;
  final String? authorizationStatus;
  final Map<String, Object?> requestDetails;
  final List<RadiologyRequestedTest> requestedTests;
  final DateTime? orderedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int resultCount;
  final int draftResultCount;
  final int finalResultCount;
  final int amendedResultCount;
  final int studyCount;
  final int unsyncedStudyCount;
  final List<RadiologyResult> results;
  final List<ImagingStudy> imagingStudies;

  String get effectiveDisplayId => displayId ?? id;

  String get normalizedStatus => (status ?? '').trim().toUpperCase();

  String get normalizedModality => (modality ?? '').trim().toUpperCase();

  bool get isCancelled => normalizedStatus == 'CANCELLED';

  bool get hasFinalResult {
    return results.any((RadiologyResult result) => result.isReleased);
  }

  bool get hasDraftResult {
    return results.any((RadiologyResult result) => result.isDraft);
  }

  RadiologyResult? get latestResult {
    return results.isEmpty ? null : results.first;
  }

  RadiologyResult? get latestDraftResult {
    for (final RadiologyResult result in results) {
      if (result.isDraft) {
        return result;
      }
    }
    return null;
  }

  RadiologyResult? get latestReleasedResult {
    for (final RadiologyResult result in results) {
      if (result.isReleased) {
        return result;
      }
    }
    return null;
  }

  ImagingStudy? get latestStudy {
    return imagingStudies.isEmpty ? null : imagingStudies.last;
  }

  String? get priority {
    for (final RadiologyRequestedTest test in requestedTests) {
      if (test.priority != null) {
        return test.priority;
      }
    }
    return _stringValue(requestDetails['priority']);
  }

  String? get bodyRegion {
    for (final RadiologyRequestedTest test in requestedTests) {
      if (test.bodyRegion != null) {
        return test.bodyRegion;
      }
    }
    return _stringValue(requestDetails['body_region']);
  }

  String? get laterality {
    for (final RadiologyRequestedTest test in requestedTests) {
      if (test.laterality != null) {
        return test.laterality;
      }
    }
    return _stringValue(requestDetails['laterality']);
  }

  bool get hasBillingGate {
    return paymentStatus != null || authorizationStatus != null;
  }
}

@immutable
final class RadiologyRequestedTest {
  const RadiologyRequestedTest({
    this.radiologyTestId,
    this.testDisplayName,
    this.modality,
    this.bodyRegion,
    this.laterality,
    this.priority,
  });

  final String? radiologyTestId;
  final String? testDisplayName;
  final String? modality;
  final String? bodyRegion;
  final String? laterality;
  final String? priority;
}

@immutable
final class RadiologyResult {
  const RadiologyResult({
    required this.id,
    this.displayId,
    this.radiologyOrderId,
    this.patientId,
    this.patientDisplayName,
    this.radiologyTestId,
    this.testDisplayName,
    this.modality,
    this.status,
    this.reportText,
    this.finalization = const RadiologyResultFinalization(),
    this.attestations = const <RadiologyResultAttestation>[],
    this.reportedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? radiologyOrderId;
  final String? patientId;
  final String? patientDisplayName;
  final String? radiologyTestId;
  final String? testDisplayName;
  final String? modality;
  final String? status;
  final String? reportText;
  final RadiologyResultFinalization finalization;
  final List<RadiologyResultAttestation> attestations;
  final DateTime? reportedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveDisplayId => displayId ?? id;

  String get normalizedStatus => (status ?? '').trim().toUpperCase();

  bool get isDraft => normalizedStatus == 'DRAFT';

  bool get isReleased {
    return normalizedStatus == 'FINAL' || normalizedStatus == 'AMENDED';
  }
}

@immutable
final class RadiologyResultFinalization {
  const RadiologyResultFinalization({
    this.requested = false,
    this.requestedAt,
    this.requestedByRole,
    this.attested = false,
    this.attestedAt,
    this.attestedByRole,
    this.pendingAttestation = false,
  });

  final bool requested;
  final DateTime? requestedAt;
  final String? requestedByRole;
  final bool attested;
  final DateTime? attestedAt;
  final String? attestedByRole;
  final bool pendingAttestation;
}

@immutable
final class RadiologyResultAttestation {
  const RadiologyResultAttestation({
    required this.id,
    this.displayId,
    this.radiologyResultId,
    this.phase,
    this.attestedByUserId,
    this.attestedRole,
    this.statement,
    this.reason,
    this.attestedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? radiologyResultId;
  final String? phase;
  final String? attestedByUserId;
  final String? attestedRole;
  final String? statement;
  final String? reason;
  final DateTime? attestedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class ImagingStudy {
  const ImagingStudy({
    required this.id,
    this.displayId,
    this.radiologyOrderId,
    this.modality,
    this.performedAt,
    this.createdAt,
    this.updatedAt,
    this.assetCount = 0,
    this.pacsLinkCount = 0,
    this.lastPacsUrl,
    this.assets = const <ImagingAsset>[],
    this.pacsLinks = const <PacsLink>[],
  });

  final String id;
  final String? displayId;
  final String? radiologyOrderId;
  final String? modality;
  final DateTime? performedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int assetCount;
  final int pacsLinkCount;
  final String? lastPacsUrl;
  final List<ImagingAsset> assets;
  final List<PacsLink> pacsLinks;

  String get effectiveDisplayId => displayId ?? id;

  bool get hasAssets => assets.isNotEmpty || assetCount > 0;

  bool get hasPacsLinks => pacsLinks.isNotEmpty || pacsLinkCount > 0;
}

@immutable
final class ImagingAsset {
  const ImagingAsset({
    required this.id,
    this.displayId,
    this.imagingStudyId,
    this.storageKey,
    this.fileName,
    this.contentType,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? imagingStudyId;
  final String? storageKey;
  final String? fileName;
  final String? contentType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class PacsLink {
  const PacsLink({
    required this.id,
    this.displayId,
    this.imagingStudyId,
    this.url,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? imagingStudyId;
  final String? url;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
final class RadiologyWorkflow {
  const RadiologyWorkflow({
    required this.order,
    this.results = const <RadiologyResult>[],
    this.studies = const <ImagingStudy>[],
    this.timeline = const <RadiologyTimelineItem>[],
    this.nextActions = const RadiologyNextActions(),
  });

  final RadiologyOrder order;
  final List<RadiologyResult> results;
  final List<ImagingStudy> studies;
  final List<RadiologyTimelineItem> timeline;
  final RadiologyNextActions nextActions;
}

@immutable
final class RadiologyNextActions {
  const RadiologyNextActions({
    this.canAssign = false,
    this.canStart = false,
    this.canComplete = false,
    this.canCancel = false,
    this.canCreateStudy = false,
    this.canCreateDraftResult = false,
    this.canFinalizeResult = false,
    this.canRequestFinalization = false,
    this.canAttestFinalization = false,
    this.canAddAddendum = false,
    this.canPacsSync = false,
  });

  final bool canAssign;
  final bool canStart;
  final bool canComplete;
  final bool canCancel;
  final bool canCreateStudy;
  final bool canCreateDraftResult;
  final bool canFinalizeResult;
  final bool canRequestFinalization;
  final bool canAttestFinalization;
  final bool canAddAddendum;
  final bool canPacsSync;
}

@immutable
final class RadiologyTimelineItem {
  const RadiologyTimelineItem({
    required this.id,
    required this.type,
    required this.label,
    this.occurredAt,
  });

  final String id;
  final String type;
  final String label;
  final DateTime? occurredAt;
}

@immutable
final class RadiologyReferenceData {
  const RadiologyReferenceData({
    this.patients = const <RadiologyReferenceOption>[],
    this.encounters = const <RadiologyReferenceOption>[],
    this.radiologyTests = const <RadiologyReferenceOption>[],
    this.assignees = const <RadiologyReferenceOption>[],
  });

  final List<RadiologyReferenceOption> patients;
  final List<RadiologyReferenceOption> encounters;
  final List<RadiologyReferenceOption> radiologyTests;
  final List<RadiologyReferenceOption> assignees;

  static const empty = RadiologyReferenceData();
}

@immutable
final class RadiologyReferenceOption {
  const RadiologyReferenceOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.patientId,
  });

  final String value;
  final String label;
  final String? subtitle;
  final String? patientId;

  String get displayLabel {
    final String normalizedSubtitle = subtitle?.trim() ?? '';
    return normalizedSubtitle.isEmpty ? label : '$label | $normalizedSubtitle';
  }
}

String? _stringValue(Object? value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}
