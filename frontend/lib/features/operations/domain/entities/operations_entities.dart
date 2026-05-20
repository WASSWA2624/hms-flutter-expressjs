import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/data/data.dart';

const List<String> operationsMaintenanceStatuses = <String>[
  'OPEN',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
];

const List<String> operationsRequestPriorities = <String>[
  'URGENT',
  'HIGH',
  'NORMAL',
  'LOW',
];

const List<String> operationsRequestCategories = <String>[
  'ELECTRICAL',
  'PLUMBING',
  'WATER',
  'POWER_BACKUP',
  'HVAC',
  'GENERAL_ASSET',
  'SAFETY',
  'OTHER',
];

@immutable
final class OperationsWorkItemQuery {
  const OperationsWorkItemQuery({
    this.search = '',
    this.status,
    this.priority,
    this.facilityId,
    this.assetId,
    this.reportedFrom,
    this.reportedTo,
    this.pageRequest = const AppPageRequest(),
  });

  final String search;
  final String? status;
  final String? priority;
  final String? facilityId;
  final String? assetId;
  final DateTime? reportedFrom;
  final DateTime? reportedTo;
  final AppPageRequest pageRequest;

  OperationsWorkItemQuery copyWith({
    String? search,
    String? status,
    String? priority,
    String? facilityId,
    String? assetId,
    DateTime? reportedFrom,
    DateTime? reportedTo,
    AppPageRequest? pageRequest,
    bool clearStatus = false,
    bool clearPriority = false,
    bool clearFacilityId = false,
    bool clearAssetId = false,
    bool clearReportedFrom = false,
    bool clearReportedTo = false,
  }) {
    return OperationsWorkItemQuery(
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      priority: clearPriority ? null : priority ?? this.priority,
      facilityId: clearFacilityId ? null : facilityId ?? this.facilityId,
      assetId: clearAssetId ? null : assetId ?? this.assetId,
      reportedFrom: clearReportedFrom
          ? null
          : reportedFrom ?? this.reportedFrom,
      reportedTo: clearReportedTo ? null : reportedTo ?? this.reportedTo,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class OperationsAssetQuery {
  const OperationsAssetQuery({
    this.search = '',
    this.status,
    this.pageRequest = const AppPageRequest(pageSize: 50),
  });

  final String search;
  final String? status;
  final AppPageRequest pageRequest;
}

@immutable
final class OperationsServiceLogQuery {
  const OperationsServiceLogQuery({
    this.assetId,
    this.search = '',
    this.pageRequest = const AppPageRequest(pageSize: 10),
  });

  final String? assetId;
  final String search;
  final AppPageRequest pageRequest;
}

@immutable
final class OperationsWorkspaceState {
  const OperationsWorkspaceState({
    required this.query,
    required this.workItems,
    required this.assets,
    required this.serviceLogs,
    this.selectedItem,
    this.isRefreshing = false,
    this.isRefreshingDetail = false,
    this.isMutating = false,
    this.lastFailure,
  });

  final OperationsWorkItemQuery query;
  final AppPage<OperationsWorkItem> workItems;
  final AppPage<OperationsAsset> assets;
  final AppPage<OperationsServiceLog> serviceLogs;
  final OperationsWorkItem? selectedItem;
  final bool isRefreshing;
  final bool isRefreshingDetail;
  final bool isMutating;
  final AppFailure? lastFailure;

  int get workloadCount {
    return workItems.items.where((OperationsWorkItem item) => item.isActive).length;
  }

  int get openCount {
    return _countStatus('OPEN');
  }

  int get inProgressCount {
    return _countStatus('IN_PROGRESS');
  }

  int get completedCount {
    return _countStatus('COMPLETED');
  }

  int get cancelledCount {
    return _countStatus('CANCELLED');
  }

  int get assetCount {
    return assets.totalItemCount ?? assets.items.length;
  }

  int get activeAssetCount {
    return assets.items.where((OperationsAsset asset) => asset.isActive).length;
  }

  OperationsWorkspaceState copyWith({
    OperationsWorkItemQuery? query,
    AppPage<OperationsWorkItem>? workItems,
    AppPage<OperationsAsset>? assets,
    AppPage<OperationsServiceLog>? serviceLogs,
    OperationsWorkItem? selectedItem,
    bool? isRefreshing,
    bool? isRefreshingDetail,
    bool? isMutating,
    AppFailure? lastFailure,
    bool clearSelectedItem = false,
    bool clearLastFailure = false,
  }) {
    return OperationsWorkspaceState(
      query: query ?? this.query,
      workItems: workItems ?? this.workItems,
      assets: assets ?? this.assets,
      serviceLogs: serviceLogs ?? this.serviceLogs,
      selectedItem: clearSelectedItem
          ? null
          : selectedItem ?? this.selectedItem,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isRefreshingDetail: isRefreshingDetail ?? this.isRefreshingDetail,
      isMutating: isMutating ?? this.isMutating,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
    );
  }

  int _countStatus(String status) {
    return workItems.items
        .where((OperationsWorkItem item) => item.normalizedStatus == status)
        .length;
  }
}

@immutable
final class OperationsWorkItem {
  const OperationsWorkItem({
    required this.id,
    required this.metadata,
    this.displayId,
    this.status,
    this.description,
    this.reportedAt,
    this.resolvedAt,
    this.facilityId,
    this.facilityLabel,
    this.assetId,
    this.assetLabel,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? status;
  final String? description;
  final DateTime? reportedAt;
  final DateTime? resolvedAt;
  final String? facilityId;
  final String? facilityLabel;
  final String? assetId;
  final String? assetLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final OperationsRequestMetadata metadata;

  String get effectiveDisplayId => displayId ?? id;

  String get normalizedStatus => (status ?? '').trim().toUpperCase();

  String get normalizedPriority {
    return (metadata.priority ?? 'NORMAL').trim().toUpperCase();
  }

  bool get isActive {
    return normalizedStatus == 'OPEN' || normalizedStatus == 'IN_PROGRESS';
  }

  bool get isTerminal {
    return normalizedStatus == 'COMPLETED' || normalizedStatus == 'CANCELLED';
  }

  DateTime? get dueAt {
    final int? slaHours = metadata.slaHours;
    final DateTime? base = reportedAt ?? createdAt;
    if (slaHours == null || base == null) {
      return null;
    }
    return base.add(Duration(hours: slaHours));
  }
}

@immutable
final class OperationsRequestMetadata {
  const OperationsRequestMetadata({
    this.category,
    this.priority,
    this.issue,
    this.location,
    this.notes,
    this.assignee,
    this.slaHours,
    this.triageSummary,
  });

  final String? category;
  final String? priority;
  final String? issue;
  final String? location;
  final String? notes;
  final String? assignee;
  final int? slaHours;
  final String? triageSummary;
}

@immutable
final class OperationsAsset {
  const OperationsAsset({
    required this.id,
    this.displayId,
    this.name,
    this.assetTag,
    this.status,
    this.facilityId,
    this.facilityLabel,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? name;
  final String? assetTag;
  final String? status;
  final String? facilityId;
  final String? facilityLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveDisplayId => displayId ?? id;

  String get effectiveLabel {
    final String? normalizedName = _nonEmpty(name);
    final String? normalizedTag = _nonEmpty(assetTag);
    if (normalizedName != null && normalizedTag != null) {
      return '$normalizedName ($normalizedTag)';
    }
    return normalizedName ?? normalizedTag ?? effectiveDisplayId;
  }

  String get normalizedStatus => (status ?? '').trim().toUpperCase();

  bool get isActive {
    return normalizedStatus == 'OPEN' || normalizedStatus == 'IN_PROGRESS';
  }
}

@immutable
final class OperationsServiceLog {
  const OperationsServiceLog({
    required this.id,
    this.displayId,
    this.assetId,
    this.assetLabel,
    this.facilityId,
    this.facilityLabel,
    this.servicedAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayId;
  final String? assetId;
  final String? assetLabel;
  final String? facilityId;
  final String? facilityLabel;
  final DateTime? servicedAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveDisplayId => displayId ?? id;
}

@immutable
final class OperationsRequestDraft {
  const OperationsRequestDraft({
    required this.category,
    required this.priority,
    required this.issue,
    this.facilityId,
    this.assetId,
    this.location,
    this.notes,
  });

  final String category;
  final String priority;
  final String issue;
  final String? facilityId;
  final String? assetId;
  final String? location;
  final String? notes;
}

@immutable
final class OperationsTriageDraft {
  const OperationsTriageDraft({
    this.assignedEngineer,
    this.triageSummary,
    this.slaHours,
  });

  final String? assignedEngineer;
  final String? triageSummary;
  final int? slaHours;
}

@immutable
final class OperationsStatusUpdateDraft {
  const OperationsStatusUpdateDraft({
    required this.status,
    this.notes,
    this.resolvedAt,
  });

  final String status;
  final String? notes;
  final DateTime? resolvedAt;
}

@immutable
final class OperationsServiceLogDraft {
  const OperationsServiceLogDraft({
    required this.assetId,
    required this.notes,
    this.servicedAt,
  });

  final String assetId;
  final String notes;
  final DateTime? servicedAt;
}

@immutable
final class OperationsRequestNoteDraft {
  const OperationsRequestNoteDraft({required this.kind, required this.note});

  final String kind;
  final String note;
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
