import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/facility_catalog/facility_catalog_scope.dart';

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
  'FLUOROSCOPY',
  'MAMMOGRAPHY',
  'PET',
  'NUCLEAR_MEDICINE',
  'INTERVENTIONAL_RADIOLOGY',
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

const List<String> radiologyPriorities = <String>[
  'ROUTINE',
  'URGENT',
  'STAT',
];

const List<String> radiologyBillingGateFilters = <String>[
  'AWAITING',
  'CONFIRMED',
];

enum RadiologyWorkbenchView { patients, orders }

@immutable
final class RadiologyWorkspaceQuery {
  const RadiologyWorkspaceQuery({
    this.search = '',
    this.stage = 'ALL',
    this.view = RadiologyWorkbenchView.patients,
    this.status,
    this.modality,
    this.priority,
    this.billingGate,
    this.from,
    this.to,
    this.patientId,
    this.encounterId,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final String stage;
  final RadiologyWorkbenchView view;
  final String? status;
  final String? modality;
  final String? priority;
  final String? billingGate;
  final DateTime? from;
  final DateTime? to;
  final String? patientId;
  final String? encounterId;
  final AppPageRequest pageRequest;

  RadiologyWorkspaceQuery copyWith({
    String? search,
    String? stage,
    RadiologyWorkbenchView? view,
    String? status,
    String? modality,
    String? priority,
    String? billingGate,
    DateTime? from,
    DateTime? to,
    String? patientId,
    String? encounterId,
    AppPageRequest? pageRequest,
    bool clearStatus = false,
    bool clearModality = false,
    bool clearPriority = false,
    bool clearBillingGate = false,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearPatientId = false,
    bool clearEncounterId = false,
  }) {
    return RadiologyWorkspaceQuery(
      search: search ?? this.search,
      stage: stage ?? this.stage,
      view: view ?? this.view,
      status: clearStatus ? null : status ?? this.status,
      modality: clearModality ? null : modality ?? this.modality,
      priority: clearPriority ? null : priority ?? this.priority,
      billingGate: clearBillingGate ? null : billingGate ?? this.billingGate,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      patientId: clearPatientId ? null : patientId ?? this.patientId,
      encounterId: clearEncounterId ? null : encounterId ?? this.encounterId,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

enum RadiologyDetailViewMode { imagingFloor, reporting }

typedef RadiologyCatalogScope = FacilityCatalogScope;

final class RadiologyWorkspaceState {
  const RadiologyWorkspaceState({
    required this.orders,
    required this.summary,
    required this.references,
    required this.query,
    this.catalogScope,
    this.catalogTests = const <RadiologyCatalogTest>[],
    this.equipmentRecords = const <RadiologyEquipmentRecord>[],
    this.selectedWorkflow,
    this.detailViewMode = RadiologyDetailViewMode.imagingFloor,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isMutating = false,
    this.isLoadingCatalog = false,
    this.catalogLoadFailure,
    this.lastFailure,
  });

  final AppPage<RadiologyOrder> orders;
  final RadiologySummary summary;
  final RadiologyReferenceData references;
  final RadiologyWorkspaceQuery query;
  final RadiologyCatalogScope? catalogScope;
  final List<RadiologyCatalogTest> catalogTests;
  final List<RadiologyEquipmentRecord> equipmentRecords;
  final RadiologyWorkflow? selectedWorkflow;
  final RadiologyDetailViewMode detailViewMode;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isMutating;
  final bool isLoadingCatalog;
  final Object? catalogLoadFailure;
  final AppFailure? lastFailure;

  int get workloadCount {
    if (query.view == RadiologyWorkbenchView.patients) {
      return summary.actionablePatients;
    }
    return summary.orderedQueue +
        summary.processingQueue +
        summary.draftReports;
  }

  int get reportingCount {
    return query.view == RadiologyWorkbenchView.patients
        ? summary.reportingPatients
        : summary.draftReports;
  }

  int get releasedCount {
    return query.view == RadiologyWorkbenchView.patients
        ? summary.releasedPatients
        : summary.finalizedReports + summary.amendedReports;
  }

  RadiologyWorkspaceState copyWith({
    AppPage<RadiologyOrder>? orders,
    RadiologySummary? summary,
    RadiologyReferenceData? references,
    RadiologyWorkspaceQuery? query,
    RadiologyCatalogScope? catalogScope,
    List<RadiologyCatalogTest>? catalogTests,
    List<RadiologyEquipmentRecord>? equipmentRecords,
    RadiologyWorkflow? selectedWorkflow,
    RadiologyDetailViewMode? detailViewMode,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isMutating,
    bool? isLoadingCatalog,
    Object? catalogLoadFailure,
    AppFailure? lastFailure,
    bool clearSelectedWorkflow = false,
    bool clearLastFailure = false,
    bool clearCatalogLoadFailure = false,
  }) {
    return RadiologyWorkspaceState(
      orders: orders ?? this.orders,
      summary: summary ?? this.summary,
      references: references ?? this.references,
      query: query ?? this.query,
      catalogScope: catalogScope ?? this.catalogScope,
      catalogTests: catalogTests ?? this.catalogTests,
      equipmentRecords: equipmentRecords ?? this.equipmentRecords,
      selectedWorkflow: clearSelectedWorkflow
          ? null
          : selectedWorkflow ?? this.selectedWorkflow,
      detailViewMode: detailViewMode ?? this.detailViewMode,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isMutating: isMutating ?? this.isMutating,
      isLoadingCatalog: isLoadingCatalog ?? this.isLoadingCatalog,
      catalogLoadFailure: clearCatalogLoadFailure
          ? null
          : catalogLoadFailure ?? this.catalogLoadFailure,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
    );
  }
}

@immutable
final class RadiologyCatalogTest {
  const RadiologyCatalogTest({
    required this.id,
    required this.name,
    this.displayId,
    this.code,
    this.modality,
    this.bodyRegion,
    this.laterality,
    this.procedureType,
    this.equipment,
    this.status,
    this.source,
    this.searchText,
    this.unitPrice,
    this.currency,
    this.isOfferedAtFacility = false,
    this.facilityOfferingId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? displayId;
  final String? code;
  final String? modality;
  final String? bodyRegion;
  final String? laterality;
  final String? procedureType;
  final String? equipment;
  final String? status;
  final String? source;
  final String? searchText;
  final num? unitPrice;
  final String? currency;
  final bool isOfferedAtFacility;
  final String? facilityOfferingId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveId => displayId ?? id;
  String get apiId => id;

  bool get isStandard {
    final String sourceKey = (source ?? status ?? '').trim().toUpperCase();
    return id.startsWith('STD_RAD_TEST_') ||
        effectiveId.startsWith('STD_RAD_TEST_') ||
        sourceKey == 'STANDARD' ||
        sourceKey == 'STANDARD_RADIOLOGY_CATALOG';
  }

  bool matchesSearch(String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    final String haystack = <String?>[
      id,
      displayId,
      name,
      code,
      modality,
      bodyRegion,
      laterality,
      procedureType,
      equipment,
      status,
      source,
      searchText,
    ].whereType<String>().join(' ').toLowerCase();
    return normalized
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .every(haystack.contains);
  }

  RadiologyCatalogTest copyWith({
    String? id,
    String? name,
    String? displayId,
    String? code,
    String? modality,
    String? bodyRegion,
    String? laterality,
    String? procedureType,
    String? equipment,
    String? status,
    String? source,
    String? searchText,
    num? unitPrice,
    String? currency,
    bool? isOfferedAtFacility,
    String? facilityOfferingId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RadiologyCatalogTest(
      id: id ?? this.id,
      name: name ?? this.name,
      displayId: displayId ?? this.displayId,
      code: code ?? this.code,
      modality: modality ?? this.modality,
      bodyRegion: bodyRegion ?? this.bodyRegion,
      laterality: laterality ?? this.laterality,
      procedureType: procedureType ?? this.procedureType,
      equipment: equipment ?? this.equipment,
      status: status ?? this.status,
      source: source ?? this.source,
      searchText: searchText ?? this.searchText,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      isOfferedAtFacility: isOfferedAtFacility ?? this.isOfferedAtFacility,
      facilityOfferingId: facilityOfferingId ?? this.facilityOfferingId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
final class RadiologyEquipmentRecord {
  const RadiologyEquipmentRecord({
    required this.id,
    required this.equipmentName,
    this.displayId,
    this.equipmentCode,
    this.serialNumber,
    this.manufacturer,
    this.modelNumber,
    this.status,
    this.facilityId,
    this.categoryId,
    this.categoryName,
  });

  final String id;
  final String equipmentName;
  final String? displayId;
  final String? equipmentCode;
  final String? serialNumber;
  final String? manufacturer;
  final String? modelNumber;
  final String? status;
  final String? facilityId;
  final String? categoryId;
  final String? categoryName;

  String get effectiveId => displayId ?? id;

  bool matchesSearch(String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    final String haystack = <String?>[
      id,
      displayId,
      equipmentName,
      equipmentCode,
      serialNumber,
      manufacturer,
      modelNumber,
      status,
      facilityId,
      categoryId,
      categoryName,
    ].whereType<String>().join(' ').toLowerCase();
    return normalized
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .every(haystack.contains);
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
    this.totalPatients = 0,
    this.actionablePatients = 0,
    this.orderedPatients = 0,
    this.processingPatients = 0,
    this.reportingPatients = 0,
    this.releasedPatients = 0,
    this.completedPatients = 0,
    this.cancelledPatients = 0,
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
  final int totalPatients;
  final int actionablePatients;
  final int orderedPatients;
  final int processingPatients;
  final int reportingPatients;
  final int releasedPatients;
  final int completedPatients;
  final int cancelledPatients;

  int totalForView(RadiologyWorkbenchView view) {
    return view == RadiologyWorkbenchView.patients
        ? totalPatients
        : totalOrders;
  }

  int orderedForView(RadiologyWorkbenchView view) {
    return view == RadiologyWorkbenchView.patients
        ? orderedPatients
        : orderedQueue;
  }
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
    this.isPatientGroup = false,
    this.activeOrderCount = 0,
    this.orderCount = 1,
    this.orderIds = const <String>[],
    this.orderDisplayIds = const <String>[],
    this.testsSummary,
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
  final bool isPatientGroup;
  final int activeOrderCount;
  final int orderCount;
  final List<String> orderIds;
  final List<String> orderDisplayIds;
  final String? testsSummary;
  final List<RadiologyResult> results;
  final List<ImagingStudy> imagingStudies;

  String get effectiveDisplayId => displayId ?? '';

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
    return effectivePaymentStatus != null || authorizationStatus != null;
  }

  String? get effectivePaymentStatus {
    final String? direct = _trimmedOrNull(paymentStatus);
    if (direct != null) {
      return direct;
    }
    final Object? billing = requestDetails['billing'];
    if (billing is Map) {
      return _trimmedOrNull(billing['payment_status']?.toString());
    }
    return null;
  }

  static String? _trimmedOrNull(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
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

  String get effectiveDisplayId => displayId ?? '';

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

  String get effectiveDisplayId => displayId ?? '';

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

  String get effectiveDisplayId => displayId ?? id;
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
    if (normalizedSubtitle.isEmpty) {
      return label;
    }
    return '$label | $normalizedSubtitle';
  }
}

@immutable
final class StudyAssetUploadRequest {
  const StudyAssetUploadRequest({
    required this.fileName,
    this.contentType,
    this.sizeBytes,
    this.caption,
  });

  final String fileName;
  final String? contentType;
  final int? sizeBytes;
  final String? caption;
}

String? _stringValue(Object? value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}
