import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum LabQueueScope {
  all,
  collection,
  processing,
  results,
  critical,
  completed,
  cancelled,
}

enum LabWorkbenchView { patients, orders }

@immutable
final class LabWorkbenchQuery {
  const LabWorkbenchQuery({
    this.search = '',
    this.scope = LabQueueScope.all,
    this.view = LabWorkbenchView.patients,
    this.pageRequest = const AppPageRequest(pageSize: 25),
  });

  final String search;
  final LabQueueScope scope;
  final LabWorkbenchView view;
  final AppPageRequest pageRequest;

  LabWorkbenchQuery copyWith({
    String? search,
    LabQueueScope? scope,
    LabWorkbenchView? view,
    AppPageRequest? pageRequest,
  }) {
    return LabWorkbenchQuery(
      search: search ?? this.search,
      scope: scope ?? this.scope,
      view: view ?? this.view,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class LabWorkbenchSummary {
  const LabWorkbenchSummary({
    this.totalOrders = 0,
    this.collectionQueue = 0,
    this.processingQueue = 0,
    this.resultsQueue = 0,
    this.criticalResults = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.rejectedSamples = 0,
    this.totalPatients = 0,
    this.actionablePatients = 0,
    this.collectionPatients = 0,
    this.processingPatients = 0,
    this.resultsPatients = 0,
    this.criticalPatients = 0,
    this.completedPatients = 0,
    this.cancelledPatients = 0,
    this.rejectedSamplePatients = 0,
  });

  const LabWorkbenchSummary.empty() : this();

  final int totalOrders;
  final int collectionQueue;
  final int processingQueue;
  final int resultsQueue;
  final int criticalResults;
  final int completedOrders;
  final int cancelledOrders;
  final int rejectedSamples;
  final int totalPatients;
  final int actionablePatients;
  final int collectionPatients;
  final int processingPatients;
  final int resultsPatients;
  final int criticalPatients;
  final int completedPatients;
  final int cancelledPatients;
  final int rejectedSamplePatients;

  int totalForView(LabWorkbenchView view) {
    return view == LabWorkbenchView.patients ? totalPatients : totalOrders;
  }

  int collectionForView(LabWorkbenchView view) {
    return view == LabWorkbenchView.patients
        ? collectionPatients
        : collectionQueue;
  }

  int processingForView(LabWorkbenchView view) {
    return view == LabWorkbenchView.patients
        ? processingPatients
        : processingQueue;
  }

  int resultsForView(LabWorkbenchView view) {
    return view == LabWorkbenchView.patients ? resultsPatients : resultsQueue;
  }

  int criticalForView(LabWorkbenchView view) {
    return view == LabWorkbenchView.patients
        ? criticalPatients
        : criticalResults;
  }

  int completedForView(LabWorkbenchView view) {
    return view == LabWorkbenchView.patients
        ? completedPatients
        : completedOrders;
  }
}

@immutable
final class LabOrderPatientContext {
  const LabOrderPatientContext({
    required this.id,
    this.displayId,
    this.displayName,
    this.identifier,
    this.primaryPhone,
  });

  final String id;
  final String? displayId;
  final String? displayName;
  final String? identifier;
  final String? primaryPhone;

  String get displayTitle {
    return _firstNonEmpty(<String?>[displayName, displayId, id]) ?? id;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[displayId, identifier, primaryPhone]);
  }

  String get searchText {
    return _joinDisplay(<String?>[
          id,
          displayId,
          displayName,
          identifier,
          primaryPhone,
        ]) ??
        displayTitle;
  }
}

@immutable
final class LabOrderEncounterContext {
  const LabOrderEncounterContext({
    required this.id,
    this.displayId,
    this.title,
    this.status,
    this.type,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String? displayId;
  final String? title;
  final String? status;
  final String? type;
  final DateTime? startedAt;
  final DateTime? endedAt;

  String get displayTitle {
    return _firstNonEmpty(<String?>[title, displayId, id]) ?? id;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[type, status, displayId]);
  }

  String get searchText {
    return _joinDisplay(<String?>[id, displayId, title, status, type]) ??
        displayTitle;
  }
}

@immutable
final class LabOrderPatientContextDetail {
  const LabOrderPatientContextDetail({
    required this.patient,
    this.encounters = const <LabOrderEncounterContext>[],
  });

  final LabOrderPatientContext patient;
  final List<LabOrderEncounterContext> encounters;
}

enum LabCatalogItemType { test, panel }

@immutable
final class LabCatalogItem {
  const LabCatalogItem({
    required this.id,
    required this.type,
    this.displayId,
    this.name,
    this.code,
    this.category,
    this.specimenType,
    this.resultKind,
    this.unit,
    this.description,
    this.referenceRange,
    this.referenceRanges = const <LabReferenceRange>[],
    this.referenceRangeCount = 0,
    this.unitOptions = const <LabUnitOption>[],
    this.resultOptions = const <LabResultOption>[],
    this.panelItems = const <LabPanelItem>[],
    this.testCount = 0,
    this.unitPrice,
    this.currency,
    this.updatedAt,
    this.isOfferedAtFacility = false,
    this.facilityOfferingId,
    this.usesPlatformDefaults = true,
  });

  final String id;
  final LabCatalogItemType type;
  final String? displayId;
  final String? name;
  final String? code;
  final String? category;
  final String? specimenType;
  final String? resultKind;
  final String? unit;
  final String? description;
  final String? referenceRange;
  final List<LabReferenceRange> referenceRanges;
  final int referenceRangeCount;
  final List<LabUnitOption> unitOptions;
  final List<LabResultOption> resultOptions;
  final List<LabPanelItem> panelItems;
  final int testCount;
  final num? unitPrice;
  final String? currency;
  final DateTime? updatedAt;
  final bool isOfferedAtFacility;
  final String? facilityOfferingId;
  final bool usesPlatformDefaults;

  LabCatalogItem copyWith({
    String? id,
    LabCatalogItemType? type,
    String? displayId,
    String? name,
    String? code,
    String? category,
    String? specimenType,
    String? resultKind,
    String? unit,
    String? description,
    String? referenceRange,
    List<LabReferenceRange>? referenceRanges,
    int? referenceRangeCount,
    List<LabUnitOption>? unitOptions,
    List<LabResultOption>? resultOptions,
    List<LabPanelItem>? panelItems,
    int? testCount,
    num? unitPrice,
    String? currency,
    DateTime? updatedAt,
    bool? isOfferedAtFacility,
    String? facilityOfferingId,
    bool? usesPlatformDefaults,
  }) {
    return LabCatalogItem(
      id: id ?? this.id,
      type: type ?? this.type,
      displayId: displayId ?? this.displayId,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      specimenType: specimenType ?? this.specimenType,
      resultKind: resultKind ?? this.resultKind,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      referenceRange: referenceRange ?? this.referenceRange,
      referenceRanges: referenceRanges ?? this.referenceRanges,
      referenceRangeCount: referenceRangeCount ?? this.referenceRangeCount,
      unitOptions: unitOptions ?? this.unitOptions,
      resultOptions: resultOptions ?? this.resultOptions,
      panelItems: panelItems ?? this.panelItems,
      testCount: testCount ?? this.testCount,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      updatedAt: updatedAt ?? this.updatedAt,
      isOfferedAtFacility: isOfferedAtFacility ?? this.isOfferedAtFacility,
      facilityOfferingId: facilityOfferingId ?? this.facilityOfferingId,
      usesPlatformDefaults: usesPlatformDefaults ?? this.usesPlatformDefaults,
    );
  }

  String get apiId => displayId ?? id;
  bool get isPanel => type == LabCatalogItemType.panel;

  String get displayTitle {
    return _joinDisplay(<String?>[name, code]) ?? apiId;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[
      category,
      specimenType,
      resultKind,
      unit,
      referenceRange,
      referenceRanges.isEmpty ? null : '${referenceRanges.length} ranges',
    ]);
  }

  String get searchText {
    return _joinDisplay(<String?>[
          id,
          displayId,
          name,
          code,
          category,
          specimenType,
          resultKind,
          unit,
          description,
          referenceRange,
          for (final LabReferenceRange range in referenceRanges)
            range.displayLabel,
        ]) ??
        displayTitle;
  }

  bool matchesSearch(String query) {
    return _containsAny(query, <String?>[searchText]);
  }
}

@immutable
final class LabPanelItem {
  const LabPanelItem({
    required this.id,
    this.labTestId,
    this.testDisplayName,
    this.testCode,
    this.unit,
    this.instructions,
    this.isRequired = true,
    this.sortOrder = 0,
  });

  final String id;
  final String? labTestId;
  final String? testDisplayName;
  final String? testCode;
  final String? unit;
  final String? instructions;
  final bool isRequired;
  final int sortOrder;

  String get displayTitle {
    return _joinDisplay(<String?>[testDisplayName, testCode]) ??
        labTestId ??
        id;
  }
}

@immutable
final class LabReferenceRange {
  const LabReferenceRange({
    required this.id,
    this.label,
    this.unit,
    this.gender,
    this.ageMinValue,
    this.ageMinUnit,
    this.ageMaxValue,
    this.ageMaxUnit,
    this.normalMinValue,
    this.normalMaxValue,
    this.criticalMinValue,
    this.criticalMaxValue,
    this.referenceText,
    this.notes,
    this.sortOrder = 0,
    this.summary,
  });

  final String id;
  final String? label;
  final String? unit;
  final String? gender;
  final num? ageMinValue;
  final String? ageMinUnit;
  final num? ageMaxValue;
  final String? ageMaxUnit;
  final String? normalMinValue;
  final String? normalMaxValue;
  final String? criticalMinValue;
  final String? criticalMaxValue;
  final String? referenceText;
  final String? notes;
  final int sortOrder;
  final String? summary;

  String get displayLabel =>
      _joinDisplay(<String?>[label, summary, referenceText, unit]) ?? id;
}

@immutable
final class LabUnitOption {
  const LabUnitOption({
    required this.id,
    this.label,
    this.unit,
    this.ucumCode,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  final String id;
  final String? label;
  final String? unit;
  final String? ucumCode;
  final bool isDefault;
  final int sortOrder;

  String get displayLabel => _joinDisplay(<String?>[label, unit]) ?? id;
}

@immutable
final class LabResultOption {
  const LabResultOption({
    required this.id,
    this.value,
    this.label,
    this.status,
    this.resultFlag,
    this.isPositive = false,
    this.sortOrder = 0,
  });

  final String id;
  final String? value;
  final String? label;
  final String? status;
  final String? resultFlag;
  final bool isPositive;
  final int sortOrder;

  String get displayLabel => _joinDisplay(<String?>[label, value]) ?? id;
}

@immutable
final class LabOrderSummary {
  const LabOrderSummary({
    required this.id,
    this.displayId,
    this.status,
    this.statusRank = 0,
    this.encounterId,
    this.encounterType,
    this.encounterSource,
    this.isInpatient = false,
    this.wardName,
    this.bedLabel,
    this.locationLabel,
    this.patientId,
    this.patientDisplayName,
    this.orderedAt,
    this.createdAt,
    this.updatedAt,
    this.itemCount = 0,
    this.pendingItemCount = 0,
    this.inProcessItemCount = 0,
    this.completedItemCount = 0,
    this.rejectedItemCount = 0,
    this.sampleCount = 0,
    this.isPatientGroup = false,
    this.activeOrderCount = 0,
    this.orderCount = 1,
    this.orderIds = const <String>[],
    this.orderDisplayIds = const <String>[],
    this.testsSummary,
    this.items = const <LabOrderItem>[],
    this.samples = const <LabSample>[],
  });

  final String id;
  final String? displayId;
  final String? status;
  final int statusRank;
  final String? encounterId;
  final String? encounterType;
  final String? encounterSource;
  final bool isInpatient;
  final String? wardName;
  final String? bedLabel;
  final String? locationLabel;
  final String? patientId;
  final String? patientDisplayName;
  final DateTime? orderedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int itemCount;
  final int pendingItemCount;
  final int inProcessItemCount;
  final int completedItemCount;
  final int rejectedItemCount;
  final int sampleCount;
  final bool isPatientGroup;
  final int activeOrderCount;
  final int orderCount;
  final List<String> orderIds;
  final List<String> orderDisplayIds;
  final String? testsSummary;
  final List<LabOrderItem> items;
  final List<LabSample> samples;

  String get apiId => displayId ?? id;

  String get displayTitle {
    return _firstNonEmpty(<String?>[
          patientDisplayName,
          patientId,
          displayId,
          id,
        ]) ??
        id;
  }

  String? get displaySubtitle {
    if (isPatientGroup) {
      return _joinDisplay(<String?>[patientId, encounterId]);
    }
    return _joinDisplay(<String?>[patientId, encounterId, displayId ?? id]);
  }

  String? get encounterSourceLabel {
    final String? source = encounterSource ?? encounterType;
    if (source == null || source.trim().isEmpty) {
      return null;
    }
    return source.trim().toUpperCase();
  }

  String? get encounterLocationLabel {
    if (locationLabel != null && locationLabel!.trim().isNotEmpty) {
      return locationLabel;
    }
    final List<String> parts = <String>[
      if (wardName != null && wardName!.trim().isNotEmpty) wardName!.trim(),
      if (bedLabel != null && bedLabel!.trim().isNotEmpty) bedLabel!.trim(),
    ];
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' · ');
  }

  String? get testsLabel {
    if (testsSummary != null && testsSummary!.trim().isNotEmpty) {
      return testsSummary;
    }
    final List<String> names = items
        .map((LabOrderItem item) => item.displayTitle)
        .where((String value) => value.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
    if (names.isEmpty) {
      return null;
    }
    final int remaining = items.length - names.length;
    if (remaining <= 0) {
      return names.join(', ');
    }
    return '${names.join(', ')} +$remaining';
  }

  bool get hasCriticalResult {
    return items.any((LabOrderItem item) {
      return item.effectiveResultStatus == 'CRITICAL';
    });
  }

  bool get hasRejectedSample {
    return samples.any((LabSample sample) {
      return _normalize(sample.status) == 'REJECTED';
    });
  }

  bool get hasRejectedItem {
    return rejectedItemCount > 0 ||
        items.any((LabOrderItem item) => item.isRejected);
  }

  int get verifiableItemCount {
    return items.where((LabOrderItem item) => item.canVerify).length;
  }

  bool get hasReceivableSample {
    return samples.any((LabSample sample) {
      return sample.canReceive;
    });
  }

  bool get hasRejectableSample {
    return samples.any((LabSample sample) {
      return sample.canReject;
    });
  }

  bool get isTerminal => _isTerminal(status);

  bool matchesSearch(String query) {
    return _containsAny(query, <String?>[
      id,
      displayId,
      status,
      encounterId,
      patientId,
      patientDisplayName,
      testsLabel,
      orderCount.toString(),
      activeOrderCount.toString(),
      ...orderDisplayIds,
      for (final LabOrderItem item in items) item.displayTitle,
      for (final LabSample sample in samples) sample.displayId ?? sample.id,
    ]);
  }
}

@immutable
final class LabOrderItem {
  const LabOrderItem({
    required this.id,
    this.displayId,
    this.status,
    this.resultStatus,
    this.labOrderId,
    this.labTestId,
    this.panelId,
    this.panelDisplayName,
    this.panelCode,
    this.panelSortOrder,
    this.panelItemSortOrder,
    this.testDisplayName,
    this.testCode,
    this.category,
    this.specimenType,
    this.resultKind,
    this.unit,
    this.unitOptions = const <LabUnitOption>[],
    this.resultOptions = const <LabResultOption>[],
    this.referenceRange,
    this.referenceRanges = const <LabReferenceRange>[],
    this.resultId,
    this.resultValue,
    this.resultUnit,
    this.resultText,
    this.resultFlag,
    this.isPositive = false,
    this.referenceRangeLabel,
    this.referenceRangeSummary,
    this.interpretationOverride = false,
    this.referenceRangeOverride,
    this.resultFlagOverride,
    this.reportedAt,
    this.rejectionReason,
    this.rejectionNotes,
    this.rejectedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? status;
  final String? resultStatus;
  final String? labOrderId;
  final String? labTestId;
  final String? panelId;
  final String? panelDisplayName;
  final String? panelCode;
  final int? panelSortOrder;
  final int? panelItemSortOrder;
  final String? testDisplayName;
  final String? testCode;
  final String? category;
  final String? specimenType;
  final String? resultKind;
  final String? unit;
  final List<LabUnitOption> unitOptions;
  final List<LabResultOption> resultOptions;
  final String? referenceRange;
  final List<LabReferenceRange> referenceRanges;
  final String? resultId;
  final String? resultValue;
  final String? resultUnit;
  final String? resultText;
  final String? resultFlag;
  final bool isPositive;
  final String? referenceRangeLabel;
  final String? referenceRangeSummary;
  final bool interpretationOverride;
  final String? referenceRangeOverride;
  final String? resultFlagOverride;
  final DateTime? reportedAt;
  final String? rejectionReason;
  final String? rejectionNotes;
  final DateTime? rejectedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get apiId => displayId ?? id;

  String get displayTitle {
    return _joinDisplay(<String?>[testDisplayName, testCode]) ??
        labTestId ??
        apiId;
  }

  String? get panelKey =>
      _firstNonEmpty(<String?>[panelId, panelCode, panelDisplayName]);

  String? get panelTitle =>
      _joinDisplay(<String?>[panelDisplayName, panelCode]) ?? panelKey;

  bool get hasPanel => panelKey != null;

  String? get displaySubtitle {
    return _joinDisplay(<String?>[
      resultKind,
      unit,
      displayReferenceRange,
      status,
      effectiveResultStatus,
    ]);
  }

  String? get effectiveResultStatus {
    return _firstNonEmpty(<String?>[
      resultStatus,
      resultFlag,
      status,
    ])?.toUpperCase();
  }

  String? get displayResultValue {
    return _joinDisplay(<String?>[resultValue, resultUnit]) ?? resultText;
  }

  String? get displayReferenceRange {
    if (interpretationOverride &&
        _firstNonEmpty(<String?>[referenceRangeOverride]) != null) {
      return referenceRangeOverride;
    }
    return _firstNonEmpty(<String?>[
      referenceRangeSummary,
      referenceRange,
      if (referenceRanges.isNotEmpty) referenceRanges.first.displayLabel,
    ]);
  }

  bool get isNumeric => _normalize(resultKind) == 'NUMERIC';
  bool get isQualitative => _normalize(resultKind) == 'QUALITATIVE';
  bool get isText => _normalize(resultKind) == 'TEXT';
  bool get hasResult =>
      _firstNonEmpty(<String?>[resultValue, resultText, resultId]) != null;
  bool get isRejected =>
      _normalize(status) == 'CANCELLED' &&
      _firstNonEmpty(<String?>[rejectionReason, rejectionNotes]) != null;

  bool get canVerify {
    return switch (_normalize(status)) {
      'ORDERED' || 'COLLECTED' || 'IN_PROCESS' => true,
      _ => false,
    };
  }

  bool get canReopenResult {
    if (isRejected || !isCompleted || !hasResult) {
      return false;
    }
    return switch (_normalize(resultStatus)) {
      'NORMAL' || 'ABNORMAL' || 'CRITICAL' => true,
      _ => false,
    };
  }

  bool get canEnterResult {
    if (isRejected) {
      return false;
    }
    if (canVerify) {
      return true;
    }
    return hasResult && _normalize(effectiveResultStatus) == 'PENDING';
  }

  bool get isCompleted => _normalize(status) == 'COMPLETED';

  bool get canReject => canVerify;
  bool get canRelease => canVerify;
}

@immutable
final class LabSample {
  const LabSample({
    required this.id,
    this.displayId,
    this.status,
    this.labOrderId,
    this.patientId,
    this.patientDisplayName,
    this.collectedAt,
    this.receivedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? status;
  final String? labOrderId;
  final String? patientId;
  final String? patientDisplayName;
  final DateTime? collectedAt;
  final DateTime? receivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get apiId => displayId ?? id;

  bool get canReceive {
    return switch (_normalize(status)) {
      'PENDING' || 'COLLECTED' => true,
      _ => false,
    };
  }

  bool get canReject {
    return switch (_normalize(status)) {
      'PENDING' || 'COLLECTED' || 'RECEIVED' => true,
      _ => false,
    };
  }
}

@immutable
final class LabResult {
  const LabResult({
    required this.id,
    this.displayId,
    this.status,
    this.resultValue,
    this.resultUnit,
    this.resultFlag,
    this.isPositive = false,
    this.referenceRangeLabel,
    this.referenceRangeSummary,
    this.resultText,
    this.reportedAt,
    this.labOrderItemId,
    this.labOrderId,
    this.labTestId,
    this.patientId,
    this.patientDisplayName,
    this.testDisplayName,
    this.testCode,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? status;
  final String? resultValue;
  final String? resultUnit;
  final String? resultFlag;
  final bool isPositive;
  final String? referenceRangeLabel;
  final String? referenceRangeSummary;
  final String? resultText;
  final DateTime? reportedAt;
  final String? labOrderItemId;
  final String? labOrderId;
  final String? labTestId;
  final String? patientId;
  final String? patientDisplayName;
  final String? testDisplayName;
  final String? testCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get apiId => displayId ?? id;

  String get displayTitle {
    return _joinDisplay(<String?>[testDisplayName, testCode]) ??
        labTestId ??
        apiId;
  }

  String? get displayValue {
    return _joinDisplay(<String?>[resultValue, resultUnit]) ?? resultText;
  }
}

@immutable
final class LabQcLog {
  const LabQcLog({
    required this.id,
    this.displayId,
    this.status,
    this.notes,
    this.labTestId,
    this.testDisplayName,
    this.testCode,
    this.loggedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? status;
  final String? notes;
  final String? labTestId;
  final String? testDisplayName;
  final String? testCode;
  final DateTime? loggedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get apiId => displayId ?? id;
  String get displayTitle {
    return _joinDisplay(<String?>[testDisplayName, testCode]) ??
        labTestId ??
        apiId;
  }
}

@immutable
final class LabWorkflowTimelineItem {
  const LabWorkflowTimelineItem({
    required this.id,
    this.type,
    this.label,
    this.occurredAt,
  });

  final String id;
  final String? type;
  final String? label;
  final DateTime? occurredAt;
}

@immutable
final class LabWorkflowNextActions {
  const LabWorkflowNextActions({
    this.canCollect = false,
    this.canReceiveSample = false,
    this.canReleaseResult = false,
    this.canVerifyResult = false,
    this.canVerifyAll = false,
    this.canRejectOrderItem = false,
    this.canReverseWorkflow = false,
  });

  final bool canCollect;
  final bool canReceiveSample;
  final bool canReleaseResult;
  final bool canVerifyResult;
  final bool canVerifyAll;
  final bool canRejectOrderItem;
  final bool canReverseWorkflow;
}

@immutable
final class LabOrderWorkflow {
  const LabOrderWorkflow({
    required this.order,
    this.results = const <LabResult>[],
    this.timeline = const <LabWorkflowTimelineItem>[],
    this.nextActions = const LabWorkflowNextActions(),
  });

  final LabOrderSummary order;
  final List<LabResult> results;
  final List<LabWorkflowTimelineItem> timeline;
  final LabWorkflowNextActions nextActions;

  LabOrderItem? get firstVerifiableItem {
    for (final LabOrderItem item in order.items) {
      if (item.canVerify) {
        return item;
      }
    }
    return null;
  }

  LabOrderItem? get firstReleasableItem => firstVerifiableItem;

  List<LabOrderItem> get verifiableItems => order.items
      .where((LabOrderItem item) => item.canVerify)
      .toList(growable: false);

  LabSample? get firstReceivableSample {
    for (final LabSample sample in order.samples) {
      if (sample.canReceive) {
        return sample;
      }
    }
    return null;
  }

  LabSample? get firstRejectableSample {
    for (final LabSample sample in order.samples) {
      if (sample.canReject) {
        return sample;
      }
    }
    return null;
  }
}

@immutable
final class LabWorkspaceState {
  const LabWorkspaceState({
    required this.query,
    required this.summary,
    required this.worklist,
    this.catalogTests = const <LabCatalogItem>[],
    this.catalogPanels = const <LabCatalogItem>[],
    this.qcLogs = const <LabQcLog>[],
    this.selectedWorkflow,
    this.selectedWorkflows = const <LabOrderWorkflow>[],
    this.lastFailure,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isSaving = false,
  });

  final LabWorkbenchQuery query;
  final LabWorkbenchSummary summary;
  final AppPage<LabOrderSummary> worklist;
  final List<LabCatalogItem> catalogTests;
  final List<LabCatalogItem> catalogPanels;
  final List<LabQcLog> qcLogs;
  final LabOrderWorkflow? selectedWorkflow;
  final List<LabOrderWorkflow> selectedWorkflows;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get workloadCount {
    if (query.view == LabWorkbenchView.patients) {
      return summary.actionablePatients;
    }
    return summary.collectionQueue +
        summary.processingQueue +
        summary.resultsQueue +
        summary.criticalResults;
  }

  int get catalogCount => catalogTests.length + catalogPanels.length;

  LabWorkspaceState copyWith({
    LabWorkbenchQuery? query,
    LabWorkbenchSummary? summary,
    AppPage<LabOrderSummary>? worklist,
    List<LabCatalogItem>? catalogTests,
    List<LabCatalogItem>? catalogPanels,
    List<LabQcLog>? qcLogs,
    LabOrderWorkflow? selectedWorkflow,
    List<LabOrderWorkflow>? selectedWorkflows,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isSaving,
    bool clearSelectedWorkflow = false,
    bool clearLastFailure = false,
  }) {
    return LabWorkspaceState(
      query: query ?? this.query,
      summary: summary ?? this.summary,
      worklist: worklist ?? this.worklist,
      catalogTests: catalogTests ?? this.catalogTests,
      catalogPanels: catalogPanels ?? this.catalogPanels,
      qcLogs: qcLogs ?? this.qcLogs,
      selectedWorkflow: clearSelectedWorkflow
          ? null
          : selectedWorkflow ?? this.selectedWorkflow,
      selectedWorkflows: clearSelectedWorkflow
          ? const <LabOrderWorkflow>[]
          : selectedWorkflows ?? this.selectedWorkflows,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

bool labOrderMatchesScope(LabOrderSummary order, LabQueueScope scope) {
  final String status = _normalize(order.status);
  return switch (scope) {
    LabQueueScope.all => true,
    LabQueueScope.collection => status == 'ORDERED' || status == 'COLLECTED',
    LabQueueScope.processing => status == 'IN_PROCESS',
    LabQueueScope.results => order.items.any(
      (LabOrderItem item) => item.canVerify,
    ),
    LabQueueScope.critical => order.hasCriticalResult,
    LabQueueScope.completed => status == 'COMPLETED',
    LabQueueScope.cancelled => status == 'CANCELLED',
  };
}

bool _containsAny(String query, Iterable<String?> values) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  return values.whereType<String>().any(
    (String value) => value.toLowerCase().contains(needle),
  );
}

bool _isTerminal(String? status) {
  return switch (_normalize(status)) {
    'COMPLETED' || 'CANCELLED' => true,
    _ => false,
  };
}

String _normalize(String? value) {
  return (value ?? '').trim().toUpperCase();
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
