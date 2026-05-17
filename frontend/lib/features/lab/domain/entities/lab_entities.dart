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

@immutable
final class LabWorkbenchQuery {
  const LabWorkbenchQuery({
    this.search = '',
    this.scope = LabQueueScope.all,
    this.pageRequest = const AppPageRequest(pageSize: 25),
  });

  final String search;
  final LabQueueScope scope;
  final AppPageRequest pageRequest;

  LabWorkbenchQuery copyWith({
    String? search,
    LabQueueScope? scope,
    AppPageRequest? pageRequest,
  }) {
    return LabWorkbenchQuery(
      search: search ?? this.search,
      scope: scope ?? this.scope,
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
  });

  const LabWorkbenchSummary.empty();

  final int totalOrders;
  final int collectionQueue;
  final int processingQueue;
  final int resultsQueue;
  final int criticalResults;
  final int completedOrders;
  final int cancelledOrders;
  final int rejectedSamples;
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
    this.referenceRangeCount = 0,
    this.unitOptions = const <LabUnitOption>[],
    this.resultOptions = const <LabResultOption>[],
    this.panelItems = const <LabPanelItem>[],
    this.testCount = 0,
    this.updatedAt,
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
  final int referenceRangeCount;
  final List<LabUnitOption> unitOptions;
  final List<LabResultOption> resultOptions;
  final List<LabPanelItem> panelItems;
  final int testCount;
  final DateTime? updatedAt;

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
    ]);
  }

  bool matchesSearch(String query) {
    return _containsAny(query, <String?>[
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
    ]);
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
    this.patientId,
    this.patientDisplayName,
    this.orderedAt,
    this.createdAt,
    this.updatedAt,
    this.itemCount = 0,
    this.pendingItemCount = 0,
    this.inProcessItemCount = 0,
    this.completedItemCount = 0,
    this.sampleCount = 0,
    this.items = const <LabOrderItem>[],
    this.samples = const <LabSample>[],
  });

  final String id;
  final String? displayId;
  final String? status;
  final int statusRank;
  final String? encounterId;
  final String? patientId;
  final String? patientDisplayName;
  final DateTime? orderedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int itemCount;
  final int pendingItemCount;
  final int inProcessItemCount;
  final int completedItemCount;
  final int sampleCount;
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
    return _joinDisplay(<String?>[patientId, encounterId, displayId ?? id]);
  }

  String? get testsLabel {
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
    this.testDisplayName,
    this.testCode,
    this.unit,
    this.unitOptions = const <LabUnitOption>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? status;
  final String? resultStatus;
  final String? labOrderId;
  final String? labTestId;
  final String? testDisplayName;
  final String? testCode;
  final String? unit;
  final List<LabUnitOption> unitOptions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get apiId => displayId ?? id;

  String get displayTitle {
    return _joinDisplay(<String?>[testDisplayName, testCode]) ??
        labTestId ??
        apiId;
  }

  String? get displaySubtitle {
    return _joinDisplay(<String?>[status, resultStatus, unit]);
  }

  String? get effectiveResultStatus {
    return _firstNonEmpty(<String?>[resultStatus, status])?.toUpperCase();
  }

  bool get canRelease {
    return switch (_normalize(status)) {
      'ORDERED' || 'COLLECTED' || 'IN_PROCESS' => true,
      _ => false,
    };
  }
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
    this.canReverseWorkflow = false,
  });

  final bool canCollect;
  final bool canReceiveSample;
  final bool canReleaseResult;
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

  LabOrderItem? get firstReleasableItem {
    for (final LabOrderItem item in order.items) {
      if (item.canRelease) {
        return item;
      }
    }
    return null;
  }

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
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isSaving;

  int get workloadCount {
    return summary.collectionQueue +
        summary.processingQueue +
        summary.resultsQueue +
        summary.criticalResults +
        summary.rejectedSamples;
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
    LabQueueScope.results => order.items.any((LabOrderItem item) {
      final String itemStatus = _normalize(item.status);
      return itemStatus == 'COLLECTED' ||
          itemStatus == 'IN_PROCESS' ||
          _normalize(item.resultStatus) == 'PENDING';
    }),
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
