import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum HousekeepingResource {
  tasks('housekeeping-tasks', 'tasks'),
  schedules('housekeeping-schedules', 'tasks'),
  maintenanceRequests('maintenance-requests', 'requests');

  const HousekeepingResource(this.serverValue, this.panel);

  final String serverValue;
  final String panel;

  static HousekeepingResource fromServer(String? value) {
    final String normalized = (value ?? '').trim();
    for (final HousekeepingResource resource in values) {
      if (resource.serverValue == normalized) {
        return resource;
      }
    }
    return HousekeepingResource.tasks;
  }
}

enum HousekeepingQueue {
  all(''),
  today('TODAY'),
  overdueTasks('OVERDUE_TASKS'),
  openRequests('OPEN_REQUESTS'),
  overdueRequests('OVERDUE_REQUESTS');

  const HousekeepingQueue(this.serverValue);

  final String serverValue;

  bool get isTaskQueue {
    return this == today || this == overdueTasks;
  }

  bool get isRequestQueue {
    return this == openRequests || this == overdueRequests;
  }

  static HousekeepingQueue fromServer(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return HousekeepingQueue.all;
    }
    for (final HousekeepingQueue queue in values) {
      if (queue.serverValue == normalized) {
        return queue;
      }
    }
    return HousekeepingQueue.all;
  }
}

enum HousekeepingDatePreset {
  all(null),
  today('today'),
  nextSevenDays('next_7_days'),
  overdue('overdue'),
  thisMonth('this_month');

  const HousekeepingDatePreset(this.serverValue);

  final String? serverValue;

  static HousekeepingDatePreset fromServer(String? value) {
    final String normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return HousekeepingDatePreset.all;
    }
    for (final HousekeepingDatePreset preset in values) {
      if (preset.serverValue == normalized) {
        return preset;
      }
    }
    return HousekeepingDatePreset.all;
  }
}

@immutable
final class HousekeepingWorkspaceQuery {
  const HousekeepingWorkspaceQuery({
    this.search = '',
    this.resource = HousekeepingResource.tasks,
    this.queue = HousekeepingQueue.all,
    this.status,
    this.facilityId,
    this.roomId,
    this.assigneeId,
    this.datePreset = HousekeepingDatePreset.all,
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  final String search;
  final HousekeepingResource resource;
  final HousekeepingQueue queue;
  final String? status;
  final String? facilityId;
  final String? roomId;
  final String? assigneeId;
  final HousekeepingDatePreset datePreset;
  final AppPageRequest pageRequest;

  HousekeepingWorkspaceQuery copyWith({
    String? search,
    HousekeepingResource? resource,
    HousekeepingQueue? queue,
    String? status,
    String? facilityId,
    String? roomId,
    String? assigneeId,
    HousekeepingDatePreset? datePreset,
    AppPageRequest? pageRequest,
    bool clearStatus = false,
    bool clearFacility = false,
    bool clearRoom = false,
    bool clearAssignee = false,
  }) {
    return HousekeepingWorkspaceQuery(
      search: search ?? this.search,
      resource: resource ?? this.resource,
      queue: queue ?? this.queue,
      status: clearStatus ? null : status ?? this.status,
      facilityId: clearFacility ? null : facilityId ?? this.facilityId,
      roomId: clearRoom ? null : roomId ?? this.roomId,
      assigneeId: clearAssignee ? null : assigneeId ?? this.assigneeId,
      datePreset: datePreset ?? this.datePreset,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class HousekeepingSummaryCard {
  const HousekeepingSummaryCard({
    required this.id,
    required this.labelKey,
    required this.value,
  });

  final String id;
  final String labelKey;
  final int value;
}

@immutable
final class HousekeepingQueueSummary {
  const HousekeepingQueueSummary({
    required this.queue,
    required this.labelKey,
    required this.count,
    required this.resource,
  });

  final HousekeepingQueue queue;
  final String labelKey;
  final int count;
  final HousekeepingResource resource;
}

@immutable
final class HousekeepingLookupOption {
  const HousekeepingLookupOption({
    required this.id,
    required this.label,
    this.subtitle,
  });

  final String id;
  final String label;
  final String? subtitle;
}

@immutable
final class HousekeepingLookups {
  const HousekeepingLookups({
    this.facilities = const <HousekeepingLookupOption>[],
    this.rooms = const <HousekeepingLookupOption>[],
    this.assignees = const <HousekeepingLookupOption>[],
    this.assets = const <HousekeepingLookupOption>[],
    this.statuses = const <HousekeepingLookupOption>[],
  });

  final List<HousekeepingLookupOption> facilities;
  final List<HousekeepingLookupOption> rooms;
  final List<HousekeepingLookupOption> assignees;
  final List<HousekeepingLookupOption> assets;
  final List<HousekeepingLookupOption> statuses;
}

@immutable
final class HousekeepingWorkItem {
  const HousekeepingWorkItem({
    required this.id,
    required this.resource,
    required this.title,
    this.displayId,
    this.subtitle,
    this.status,
    this.priority,
    this.facilityId,
    this.facilityLabel,
    this.roomId,
    this.roomLabel,
    this.assigneeId,
    this.assigneeLabel,
    this.assetId,
    this.assetLabel,
    this.scheduledAt,
    this.completedAt,
    this.startDate,
    this.endDate,
    this.reportedAt,
    this.resolvedAt,
    this.servicedAt,
    this.timelineAt,
    this.targetPath,
  });

  final String id;
  final String? displayId;
  final HousekeepingResource resource;
  final String title;
  final String? subtitle;
  final String? status;
  final String? priority;
  final String? facilityId;
  final String? facilityLabel;
  final String? roomId;
  final String? roomLabel;
  final String? assigneeId;
  final String? assigneeLabel;
  final String? assetId;
  final String? assetLabel;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? reportedAt;
  final DateTime? resolvedAt;
  final DateTime? servicedAt;
  final DateTime? timelineAt;
  final String? targetPath;

  bool get isTask => resource == HousekeepingResource.tasks;
  bool get isSchedule => resource == HousekeepingResource.schedules;
  bool get isMaintenanceRequest {
    return resource == HousekeepingResource.maintenanceRequests;
  }

  bool get isTerminal {
    final String normalized = (status ?? '').trim().toUpperCase();
    return normalized == 'COMPLETED' || normalized == 'CANCELLED';
  }

  String get effectiveDisplayId => displayId ?? id;

  String get locationDisplay {
    return _firstNonEmpty(<String?>[roomLabel, facilityLabel, assetLabel]) ?? '';
  }

  String get dueDisplaySource {
    return _firstNonEmpty(<String?>[
          scheduledAt?.toIso8601String(),
          startDate?.toIso8601String(),
          reportedAt?.toIso8601String(),
          timelineAt?.toIso8601String(),
        ]) ??
        '';
  }
}

@immutable
final class HousekeepingWorkspaceOverview {
  const HousekeepingWorkspaceOverview({
    this.summaryCards = const <HousekeepingSummaryCard>[],
    this.queueSummaries = const <HousekeepingQueueSummary>[],
    this.lookups = const HousekeepingLookups(),
  });

  final List<HousekeepingSummaryCard> summaryCards;
  final List<HousekeepingQueueSummary> queueSummaries;
  final HousekeepingLookups lookups;

  int summaryValue(String id) {
    for (final HousekeepingSummaryCard card in summaryCards) {
      if (card.id == id) {
        return card.value;
      }
    }
    return 0;
  }

  int queueCount(HousekeepingQueue queue) {
    for (final HousekeepingQueueSummary summary in queueSummaries) {
      if (summary.queue == queue) {
        return summary.count;
      }
    }
    return 0;
  }

  int get workloadCount {
    return summaryValue('pending_tasks') + summaryValue('open_requests');
  }
}

@immutable
final class HousekeepingBackendGap {
  const HousekeepingBackendGap({required this.title, required this.body});

  final String title;
  final String body;
}

@immutable
final class HousekeepingWorkspaceState {
  const HousekeepingWorkspaceState({
    required this.query,
    required this.overview,
    required this.items,
    this.selectedItem,
    this.lastFailure,
    this.isRefreshing = false,
    this.isSaving = false,
    this.backendGaps = housekeepingBackendGaps,
  });

  final HousekeepingWorkspaceQuery query;
  final HousekeepingWorkspaceOverview overview;
  final AppPage<HousekeepingWorkItem> items;
  final HousekeepingWorkItem? selectedItem;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isSaving;
  final List<HousekeepingBackendGap> backendGaps;

  int get workloadCount => overview.workloadCount;

  HousekeepingWorkspaceState copyWith({
    HousekeepingWorkspaceQuery? query,
    HousekeepingWorkspaceOverview? overview,
    AppPage<HousekeepingWorkItem>? items,
    HousekeepingWorkItem? selectedItem,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isSaving,
    bool clearSelectedItem = false,
    bool clearLastFailure = false,
  }) {
    return HousekeepingWorkspaceState(
      query: query ?? this.query,
      overview: overview ?? this.overview,
      items: items ?? this.items,
      selectedItem: clearSelectedItem
          ? null
          : selectedItem ?? this.selectedItem,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
      backendGaps: backendGaps,
    );
  }
}

@immutable
final class HousekeepingTaskDraft {
  const HousekeepingTaskDraft({
    required this.status,
    this.facilityId,
    this.roomId,
    this.assigneeId,
    this.scheduledAt,
    this.completedAt,
  });

  final String status;
  final String? facilityId;
  final String? roomId;
  final String? assigneeId;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
}

@immutable
final class HousekeepingScheduleDraft {
  const HousekeepingScheduleDraft({
    required this.frequency,
    this.facilityId,
    this.roomId,
    this.startDate,
    this.endDate,
  });

  final String frequency;
  final String? facilityId;
  final String? roomId;
  final DateTime? startDate;
  final DateTime? endDate;
}

@immutable
final class HousekeepingMaintenanceRequestDraft {
  const HousekeepingMaintenanceRequestDraft({
    required this.status,
    this.facilityId,
    this.assetId,
    this.description,
    this.reportedAt,
    this.resolvedAt,
  });

  final String status;
  final String? facilityId;
  final String? assetId;
  final String? description;
  final DateTime? reportedAt;
  final DateTime? resolvedAt;
}

@immutable
final class HousekeepingMaintenanceTriageDraft {
  const HousekeepingMaintenanceTriageDraft({
    required this.status,
    this.summary,
    this.slaHours,
  });

  final String status;
  final String? summary;
  final int? slaHours;
}

const List<String> housekeepingTaskStatusValues = <String>[
  'PENDING',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
];

const List<String> housekeepingMaintenanceStatusValues = <String>[
  'OPEN',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
];

const List<HousekeepingBackendGap> housekeepingBackendGaps =
    <HousekeepingBackendGap>[
      HousekeepingBackendGap(
        title: 'Discharge-to-cleaning automation',
        body:
            'No confirmed atomic endpoint links final discharge, bed release, and housekeeping task creation.',
      ),
      HousekeepingBackendGap(
        title: 'Bed cleaning status',
        body:
            'The beds API currently supports AVAILABLE, OCCUPIED, RESERVED, and OUT_OF_SERVICE only; CLEANING and room-ready transitions are not exposed.',
      ),
      HousekeepingBackendGap(
        title: 'Inspection and rework',
        body:
            'Housekeeping tasks do not expose inspection pending, failed, rework, sanitation checklist, or task note fields.',
      ),
      HousekeepingBackendGap(
        title: 'Generated housekeeping reports',
        body:
            'No dedicated housekeeping report template/run contract is exposed yet for turnaround and readiness reports.',
      ),
    ];

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String? normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}
