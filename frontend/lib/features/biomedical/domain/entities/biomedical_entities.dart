import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/data/data.dart';

abstract final class BiomedicalPanels {
  static const overview = 'overview';
  static const registry = 'registry';
  static const preventive = 'preventive';
  static const workOrders = 'work-orders';
  static const compliance = 'compliance';
  static const support = 'support';
  static const analytics = 'analytics';

  static const values = <String>[
    overview,
    registry,
    preventive,
    workOrders,
    compliance,
    support,
    analytics,
  ];
}

abstract final class BiomedicalResources {
  static const registries = 'equipment-registries';
  static const categories = 'equipment-categories';
  static const locationHistories = 'equipment-location-histories';
  static const maintenancePlans = 'equipment-maintenance-plans';
  static const workOrders = 'equipment-work-orders';
  static const calibrationLogs = 'equipment-calibration-logs';
  static const safetyTestLogs = 'equipment-safety-test-logs';
  static const downtimeLogs = 'equipment-downtime-logs';
  static const spareParts = 'equipment-spare-parts';
  static const warrantyContracts = 'equipment-warranty-contracts';
  static const serviceProviders = 'equipment-service-providers';
  static const incidentReports = 'equipment-incident-reports';
  static const recallNotices = 'equipment-recall-notices';
  static const utilizationSnapshots = 'equipment-utilization-snapshots';
  static const disposalTransfers = 'equipment-disposal-transfers';

  static const values = <String>[
    registries,
    maintenancePlans,
    workOrders,
    calibrationLogs,
    safetyTestLogs,
    downtimeLogs,
    incidentReports,
    recallNotices,
    serviceProviders,
    warrantyContracts,
    spareParts,
    categories,
    disposalTransfers,
    utilizationSnapshots,
    locationHistories,
  ];
}

abstract final class BiomedicalQueues {
  static const overduePm = 'OVERDUE_PM';
  static const openWorkOrders = 'OPEN_WORK_ORDERS';
  static const criticalDowntime = 'CRITICAL_DOWNTIME';
  static const recallActions = 'RECALL_ACTIONS';
  static const returnToService = 'RETURN_TO_SERVICE';

  static const values = <String>[
    overduePm,
    openWorkOrders,
    criticalDowntime,
    recallActions,
    returnToService,
  ];
}

abstract final class BiomedicalDatePresets {
  static const today = 'today';
  static const next7Days = 'next_7_days';
  static const overdue = 'overdue';
  static const thisMonth = 'this_month';

  static const values = <String>[today, next7Days, overdue, thisMonth];
}

@immutable
final class BiomedicalWorkspaceQuery {
  const BiomedicalWorkspaceQuery({
    this.panel = BiomedicalPanels.registry,
    this.resource = BiomedicalResources.registries,
    this.queue,
    this.search = '',
    this.status,
    this.priority,
    this.facilityId,
    this.equipmentId,
    this.engineerId,
    this.datePreset,
    this.pageRequest = const AppPageRequest(),
  });

  final String panel;
  final String resource;
  final String? queue;
  final String search;
  final String? status;
  final String? priority;
  final String? facilityId;
  final String? equipmentId;
  final String? engineerId;
  final String? datePreset;
  final AppPageRequest pageRequest;

  bool get hasActiveFilters {
    return queue != null ||
        search.trim().isNotEmpty ||
        status != null ||
        priority != null ||
        facilityId != null ||
        equipmentId != null ||
        engineerId != null ||
        datePreset != null ||
        panel != BiomedicalPanels.registry ||
        resource != BiomedicalResources.registries;
  }

  BiomedicalWorkspaceQuery copyWith({
    String? panel,
    String? resource,
    String? queue,
    String? search,
    String? status,
    String? priority,
    String? facilityId,
    String? equipmentId,
    String? engineerId,
    String? datePreset,
    AppPageRequest? pageRequest,
    bool clearQueue = false,
    bool clearStatus = false,
    bool clearPriority = false,
    bool clearFacility = false,
    bool clearEquipment = false,
    bool clearEngineer = false,
    bool clearDatePreset = false,
  }) {
    final String nextPanel = panel ?? this.panel;
    return BiomedicalWorkspaceQuery(
      panel: nextPanel,
      resource: resource ?? _defaultResourceForPanel(nextPanel),
      queue: clearQueue ? null : queue ?? this.queue,
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      priority: clearPriority ? null : priority ?? this.priority,
      facilityId: clearFacility ? null : facilityId ?? this.facilityId,
      equipmentId: clearEquipment ? null : equipmentId ?? this.equipmentId,
      engineerId: clearEngineer ? null : engineerId ?? this.engineerId,
      datePreset: clearDatePreset ? null : datePreset ?? this.datePreset,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class BiomedicalWorkspaceState {
  const BiomedicalWorkspaceState({
    required this.workbench,
    required this.query,
    this.selectedAsset,
    this.isRefreshing = false,
    this.isMutating = false,
    this.lastFailure,
  });

  final BiomedicalWorkbench workbench;
  final BiomedicalWorkspaceQuery query;
  final BiomedicalAsset? selectedAsset;
  final bool isRefreshing;
  final bool isMutating;
  final AppFailure? lastFailure;

  int get workloadCount {
    return workbench.summary.overduePm +
        workbench.summary.openWorkOrders +
        workbench.summary.criticalDowntime +
        workbench.summary.activeRecalls;
  }

  BiomedicalWorkspaceState copyWith({
    BiomedicalWorkbench? workbench,
    BiomedicalWorkspaceQuery? query,
    BiomedicalAsset? selectedAsset,
    bool? isRefreshing,
    bool? isMutating,
    AppFailure? lastFailure,
    bool clearSelectedAsset = false,
    bool clearLastFailure = false,
  }) {
    return BiomedicalWorkspaceState(
      workbench: workbench ?? this.workbench,
      query: query ?? this.query,
      selectedAsset: clearSelectedAsset
          ? null
          : selectedAsset ?? this.selectedAsset,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isMutating: isMutating ?? this.isMutating,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
    );
  }
}

@immutable
final class BiomedicalWorkbench {
  const BiomedicalWorkbench({
    required this.summary,
    required this.queues,
    required this.panels,
    required this.lookups,
    required this.assets,
    this.spotlight = const <BiomedicalQueueSummary>[],
  });

  final BiomedicalSummary summary;
  final List<BiomedicalQueueSummary> queues;
  final List<BiomedicalPanelSummary> panels;
  final BiomedicalLookupData lookups;
  final AppPage<BiomedicalAsset> assets;
  final List<BiomedicalQueueSummary> spotlight;

  static const empty = BiomedicalWorkbench(
    summary: BiomedicalSummary(),
    queues: <BiomedicalQueueSummary>[],
    panels: <BiomedicalPanelSummary>[],
    lookups: BiomedicalLookupData.empty,
    assets: AppPage<BiomedicalAsset>(
      items: <BiomedicalAsset>[],
      request: AppPageRequest(),
      totalItemCount: 0,
    ),
  );
}

@immutable
final class BiomedicalSummary {
  const BiomedicalSummary({
    this.totalEquipment = 0,
    this.overduePm = 0,
    this.openWorkOrders = 0,
    this.criticalDowntime = 0,
    this.activeRecalls = 0,
  });

  final int totalEquipment;
  final int overduePm;
  final int openWorkOrders;
  final int criticalDowntime;
  final int activeRecalls;
}

@immutable
final class BiomedicalQueueSummary {
  const BiomedicalQueueSummary({
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
final class BiomedicalPanelSummary {
  const BiomedicalPanelSummary({
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
final class BiomedicalLookupData {
  const BiomedicalLookupData({
    this.facilities = const <BiomedicalLookupOption>[],
    this.rooms = const <BiomedicalLookupOption>[],
    this.equipment = const <BiomedicalLookupOption>[],
    this.categories = const <BiomedicalLookupOption>[],
    this.providers = const <BiomedicalLookupOption>[],
    this.engineers = const <BiomedicalLookupOption>[],
    this.statuses = const <BiomedicalLookupOption>[],
    this.priorities = const <BiomedicalLookupOption>[],
    this.queues = const <BiomedicalLookupOption>[],
  });

  final List<BiomedicalLookupOption> facilities;
  final List<BiomedicalLookupOption> rooms;
  final List<BiomedicalLookupOption> equipment;
  final List<BiomedicalLookupOption> categories;
  final List<BiomedicalLookupOption> providers;
  final List<BiomedicalLookupOption> engineers;
  final List<BiomedicalLookupOption> statuses;
  final List<BiomedicalLookupOption> priorities;
  final List<BiomedicalLookupOption> queues;

  static const empty = BiomedicalLookupData();
}

@immutable
final class BiomedicalLookupOption {
  const BiomedicalLookupOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.meta = const <String, Object?>{},
  });

  final String id;
  final String label;
  final String? subtitle;
  final Map<String, Object?> meta;

  String get displayLabel {
    final String normalizedSubtitle = subtitle?.trim() ?? '';
    if (normalizedSubtitle.isEmpty) {
      return label;
    }
    return '$label | $normalizedSubtitle';
  }
}

@immutable
final class BiomedicalAsset {
  const BiomedicalAsset({
    required this.id,
    required this.resource,
    this.humanFriendlyId,
    this.title,
    this.subtitle,
    this.status,
    this.priority,
    this.facilityId,
    this.facilityLabel,
    this.equipmentId,
    this.equipmentLabel,
    this.categoryId,
    this.categoryLabel,
    this.engineerId,
    this.engineerLabel,
    this.nextDueAt,
    this.timelineAt,
    this.targetPath,
    this.raw = const <String, Object?>{},
  });

  final String id;
  final String resource;
  final String? humanFriendlyId;
  final String? title;
  final String? subtitle;
  final String? status;
  final String? priority;
  final String? facilityId;
  final String? facilityLabel;
  final String? equipmentId;
  final String? equipmentLabel;
  final String? categoryId;
  final String? categoryLabel;
  final String? engineerId;
  final String? engineerLabel;
  final DateTime? nextDueAt;
  final DateTime? timelineAt;
  final String? targetPath;
  final Map<String, Object?> raw;

  String get displayId => _firstNonEmpty(<String?>[humanFriendlyId, id]) ?? id;

  String get displayTitle =>
      _firstNonEmpty(<String?>[title, equipmentLabel, subtitle, displayId]) ??
      id;

  String? get displaySubtitle {
    return _firstNonEmpty(<String?>[
      subtitle,
      categoryLabel,
      facilityLabel,
      equipmentLabel,
    ]);
  }

  bool get isRegistryAsset => resource == BiomedicalResources.registries;

  String? get effectiveEquipmentId {
    return isRegistryAsset ? displayId : equipmentId;
  }

  String? get effectiveEquipmentLabel {
    return isRegistryAsset ? displayTitle : equipmentLabel ?? title;
  }
}

@immutable
final class BiomedicalMutationResult {
  const BiomedicalMutationResult({
    this.asset,
    this.workOrderId,
    this.deepLink,
    this.raw = const <String, Object?>{},
  });

  final BiomedicalAsset? asset;
  final String? workOrderId;
  final String? deepLink;
  final Map<String, Object?> raw;
}

String _defaultResourceForPanel(String panel) {
  return switch (panel) {
    BiomedicalPanels.overview => BiomedicalResources.workOrders,
    BiomedicalPanels.registry => BiomedicalResources.registries,
    BiomedicalPanels.preventive => BiomedicalResources.maintenancePlans,
    BiomedicalPanels.workOrders => BiomedicalResources.workOrders,
    BiomedicalPanels.compliance => BiomedicalResources.calibrationLogs,
    BiomedicalPanels.support => BiomedicalResources.serviceProviders,
    BiomedicalPanels.analytics => BiomedicalResources.utilizationSnapshots,
    _ => BiomedicalResources.registries,
  };
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
