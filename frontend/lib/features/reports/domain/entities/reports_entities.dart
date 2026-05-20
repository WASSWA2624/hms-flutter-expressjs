import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum ReportsWorkspacePanel {
  overview('overview'),
  catalog('catalog'),
  delivery('delivery'),
  dashboards('dashboards'),
  monitor('monitor'),
  activity('activity'),
  audit('audit'),
  phi('phi'),
  processing('processing');

  const ReportsWorkspacePanel(this.serverValue);

  final String serverValue;

  bool get isCompliance {
    return switch (this) {
      ReportsWorkspacePanel.audit ||
      ReportsWorkspacePanel.phi ||
      ReportsWorkspacePanel.processing => true,
      _ => false,
    };
  }

  static ReportsWorkspacePanel fromServer(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    for (final ReportsWorkspacePanel panel in values) {
      if (panel.serverValue == normalized) {
        return panel;
      }
    }
    return ReportsWorkspacePanel.overview;
  }
}

enum ReportsWorkspaceResource {
  reportDefinitions('report-definitions'),
  reportRuns('report-runs'),
  dashboardWidgets('dashboard-widgets'),
  kpiSnapshots('kpi-snapshots'),
  analyticsEvents('analytics-events');

  const ReportsWorkspaceResource(this.serverValue);

  final String serverValue;

  static ReportsWorkspaceResource defaultForPanel(ReportsWorkspacePanel panel) {
    return switch (panel) {
      ReportsWorkspacePanel.catalog => reportDefinitions,
      ReportsWorkspacePanel.dashboards => dashboardWidgets,
      ReportsWorkspacePanel.monitor => kpiSnapshots,
      ReportsWorkspacePanel.activity => analyticsEvents,
      _ => reportRuns,
    };
  }

  static ReportsWorkspaceResource fromServer(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    for (final ReportsWorkspaceResource resource in values) {
      if (resource.serverValue == normalized) {
        return resource;
      }
    }
    return ReportsWorkspaceResource.reportRuns;
  }
}

enum ReportItemKind {
  definition,
  run,
  schedule,
  dashboardWidget,
  kpiSnapshot,
  analyticsEvent,
}

enum ComplianceLogKind {
  audit,
  phiAccess,
  dataProcessing;

  ReportsWorkspacePanel get panel {
    return switch (this) {
      ComplianceLogKind.audit => ReportsWorkspacePanel.audit,
      ComplianceLogKind.phiAccess => ReportsWorkspacePanel.phi,
      ComplianceLogKind.dataProcessing => ReportsWorkspacePanel.processing,
    };
  }

  static ComplianceLogKind fromPanel(ReportsWorkspacePanel panel) {
    return switch (panel) {
      ReportsWorkspacePanel.phi => ComplianceLogKind.phiAccess,
      ReportsWorkspacePanel.processing => ComplianceLogKind.dataProcessing,
      _ => ComplianceLogKind.audit,
    };
  }
}

@immutable
final class ReportsWorkspaceQuery {
  const ReportsWorkspaceQuery({
    this.panel = ReportsWorkspacePanel.overview,
    ReportsWorkspaceResource? resource,
    this.search = '',
    this.status,
    this.format,
    this.dataset,
    this.trigger,
    this.datePreset,
    this.from,
    this.to,
    this.pageRequest = const AppPageRequest(pageSize: 12),
  }) : resource = resource ?? ReportsWorkspaceResource.reportRuns;

  final ReportsWorkspacePanel panel;
  final ReportsWorkspaceResource resource;
  final String search;
  final String? status;
  final String? format;
  final String? dataset;
  final String? trigger;
  final String? datePreset;
  final DateTime? from;
  final DateTime? to;
  final AppPageRequest pageRequest;

  ComplianceLogKind get complianceLogKind => ComplianceLogKind.fromPanel(panel);

  ReportsWorkspaceQuery copyWith({
    ReportsWorkspacePanel? panel,
    ReportsWorkspaceResource? resource,
    String? search,
    String? status,
    String? format,
    String? dataset,
    String? trigger,
    String? datePreset,
    DateTime? from,
    DateTime? to,
    AppPageRequest? pageRequest,
    bool clearStatus = false,
    bool clearFormat = false,
    bool clearDataset = false,
    bool clearTrigger = false,
    bool clearDatePreset = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    final ReportsWorkspacePanel nextPanel = panel ?? this.panel;
    return ReportsWorkspaceQuery(
      panel: nextPanel,
      resource:
          resource ??
          (panel == null
              ? this.resource
              : ReportsWorkspaceResource.defaultForPanel(nextPanel)),
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      format: clearFormat ? null : format ?? this.format,
      dataset: clearDataset ? null : dataset ?? this.dataset,
      trigger: clearTrigger ? null : trigger ?? this.trigger,
      datePreset: clearDatePreset ? null : datePreset ?? this.datePreset,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}

@immutable
final class ReportsLookupOption {
  const ReportsLookupOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.meta = const <String, Object?>{},
  });

  final String id;
  final String label;
  final String? subtitle;
  final Map<String, Object?> meta;
}

@immutable
final class ReportsLookups {
  const ReportsLookups({
    this.facilities = const <ReportsLookupOption>[],
    this.branches = const <ReportsLookupOption>[],
    this.owners = const <ReportsLookupOption>[],
    this.datasets = const <ReportsLookupOption>[],
    this.statuses = const <ReportsLookupOption>[],
    this.formats = const <ReportsLookupOption>[],
    this.triggers = const <ReportsLookupOption>[],
    this.frequencies = const <ReportsLookupOption>[],
  });

  final List<ReportsLookupOption> facilities;
  final List<ReportsLookupOption> branches;
  final List<ReportsLookupOption> owners;
  final List<ReportsLookupOption> datasets;
  final List<ReportsLookupOption> statuses;
  final List<ReportsLookupOption> formats;
  final List<ReportsLookupOption> triggers;
  final List<ReportsLookupOption> frequencies;
}

@immutable
final class ReportsSummaryCard {
  const ReportsSummaryCard({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final int value;
}

@immutable
final class ReportsQueueSummary {
  const ReportsQueueSummary({
    required this.id,
    required this.label,
    required this.count,
    required this.panel,
    required this.resource,
  });

  final String id;
  final String label;
  final int count;
  final ReportsWorkspacePanel panel;
  final ReportsWorkspaceResource resource;
}

@immutable
final class ReportsTimelineItem {
  const ReportsTimelineItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.status,
    this.resource,
    this.targetId,
    this.occurredAt,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? status;
  final ReportsWorkspaceResource? resource;
  final String? targetId;
  final DateTime? occurredAt;
}

@immutable
final class ReportsWorkspaceItem {
  const ReportsWorkspaceItem({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.description,
    this.status,
    this.format,
    this.category,
    this.datasetKey,
    this.facilityLabel,
    this.ownerLabel,
    this.reference,
    this.occurredAt,
    this.value,
    this.count,
    this.isPinned = false,
    this.downloadAvailable = false,
    this.errorMessage,
    this.rawDetails = const <String, Object?>{},
  });

  final String id;
  final ReportItemKind kind;
  final String title;
  final String? subtitle;
  final String? description;
  final String? status;
  final String? format;
  final String? category;
  final String? datasetKey;
  final String? facilityLabel;
  final String? ownerLabel;
  final String? reference;
  final DateTime? occurredAt;
  final num? value;
  final int? count;
  final bool isPinned;
  final bool downloadAvailable;
  final String? errorMessage;
  final Map<String, Object?> rawDetails;

  bool get canRun => kind == ReportItemKind.definition;

  bool get canSchedule => kind == ReportItemKind.definition;

  bool get canRetry {
    return kind == ReportItemKind.run && _normalizedStatus == 'FAILED';
  }

  bool get canCancel {
    return kind == ReportItemKind.run &&
        <String>{'QUEUED', 'PROCESSING'}.contains(_normalizedStatus);
  }

  bool get isSchedule {
    return kind == ReportItemKind.schedule;
  }

  String get _normalizedStatus {
    return (status ?? '').trim().toUpperCase();
  }
}

@immutable
final class ComplianceLogItem {
  const ComplianceLogItem({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.userLabel,
    this.patientLabel,
    this.action,
    this.entity,
    this.scope,
    this.purpose,
    this.legalBasis,
    this.recordReference,
    this.facilityLabel,
    this.ipAddress,
    this.occurredAt,
    this.details,
    this.rawDetails = const <String, Object?>{},
  });

  final String id;
  final ComplianceLogKind kind;
  final String title;
  final String? subtitle;
  final String? userLabel;
  final String? patientLabel;
  final String? action;
  final String? entity;
  final String? scope;
  final String? purpose;
  final String? legalBasis;
  final String? recordReference;
  final String? facilityLabel;
  final String? ipAddress;
  final DateTime? occurredAt;
  final String? details;
  final Map<String, Object?> rawDetails;
}

@immutable
final class ReportsWorkspaceOverview {
  const ReportsWorkspaceOverview({
    this.summary = const <ReportsSummaryCard>[],
    this.queueSummaries = const <ReportsQueueSummary>[],
    this.lookups = const ReportsLookups(),
    this.items = const AppPage<ReportsWorkspaceItem>(
      items: <ReportsWorkspaceItem>[],
      request: AppPageRequest(pageSize: 12),
    ),
    this.schedules = const AppPage<ReportsWorkspaceItem>(
      items: <ReportsWorkspaceItem>[],
      request: AppPageRequest(pageSize: 12),
    ),
    this.timeline = const <ReportsTimelineItem>[],
  });

  final List<ReportsSummaryCard> summary;
  final List<ReportsQueueSummary> queueSummaries;
  final ReportsLookups lookups;
  final AppPage<ReportsWorkspaceItem> items;
  final AppPage<ReportsWorkspaceItem> schedules;
  final List<ReportsTimelineItem> timeline;

  int get workloadCount {
    return queueSummaries.fold<int>(0, (int total, ReportsQueueSummary item) {
      return total + item.count;
    });
  }

  ReportsWorkspaceOverview copyWith({
    List<ReportsSummaryCard>? summary,
    List<ReportsQueueSummary>? queueSummaries,
    ReportsLookups? lookups,
    AppPage<ReportsWorkspaceItem>? items,
    AppPage<ReportsWorkspaceItem>? schedules,
    List<ReportsTimelineItem>? timeline,
  }) {
    return ReportsWorkspaceOverview(
      summary: summary ?? this.summary,
      queueSummaries: queueSummaries ?? this.queueSummaries,
      lookups: lookups ?? this.lookups,
      items: items ?? this.items,
      schedules: schedules ?? this.schedules,
      timeline: timeline ?? this.timeline,
    );
  }
}

@immutable
final class ReportsWorkspaceState {
  const ReportsWorkspaceState({
    required this.query,
    required this.overview,
    required this.complianceLogs,
    this.selectedItem,
    this.selectedComplianceLog,
    this.lastFailure,
    this.isRefreshing = false,
    this.isSaving = false,
  });

  final ReportsWorkspaceQuery query;
  final ReportsWorkspaceOverview overview;
  final AppPage<ComplianceLogItem> complianceLogs;
  final ReportsWorkspaceItem? selectedItem;
  final ComplianceLogItem? selectedComplianceLog;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isSaving;

  int get workloadCount {
    return overview.workloadCount;
  }

  ReportsWorkspaceState copyWith({
    ReportsWorkspaceQuery? query,
    ReportsWorkspaceOverview? overview,
    AppPage<ComplianceLogItem>? complianceLogs,
    ReportsWorkspaceItem? selectedItem,
    ComplianceLogItem? selectedComplianceLog,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isSaving,
    bool clearSelectedItem = false,
    bool clearSelectedComplianceLog = false,
    bool clearLastFailure = false,
  }) {
    return ReportsWorkspaceState(
      query: query ?? this.query,
      overview: overview ?? this.overview,
      complianceLogs: complianceLogs ?? this.complianceLogs,
      selectedItem: clearSelectedItem
          ? null
          : selectedItem ?? this.selectedItem,
      selectedComplianceLog: clearSelectedComplianceLog
          ? null
          : selectedComplianceLog ?? this.selectedComplianceLog,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

@immutable
final class ReportRunDraft {
  const ReportRunDraft({this.format, this.retentionDays});

  final String? format;
  final int? retentionDays;
}

@immutable
final class ReportScheduleDraft {
  const ReportScheduleDraft({
    required this.reportDefinitionId,
    required this.name,
    required this.frequency,
    this.format,
    this.timeOfDay,
    this.dayOfWeek,
    this.dayOfMonth,
    this.timezone,
    this.retentionDays,
  });

  final String reportDefinitionId;
  final String name;
  final String frequency;
  final String? format;
  final String? timeOfDay;
  final int? dayOfWeek;
  final int? dayOfMonth;
  final String? timezone;
  final int? retentionDays;
}
