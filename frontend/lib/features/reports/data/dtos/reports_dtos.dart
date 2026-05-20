import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef ReportsJsonMap = Map<String, Object?>;

final class ReportsWorkspaceOverviewDto {
  const ReportsWorkspaceOverviewDto(this.json, {required this.request});

  final ReportsJsonMap json;
  final AppPageRequest request;

  factory ReportsWorkspaceOverviewDto.fromResponse(
    Object? responseData, {
    required AppPageRequest request,
  }) {
    return ReportsWorkspaceOverviewDto(_dataMap(responseData), request: request);
  }

  ReportsWorkspaceOverview toEntity() {
    final ReportsWorkspaceResource resource =
        ReportsWorkspaceResource.fromServer(
          _string(_map(json['filters'])['resource']),
        );
    return ReportsWorkspaceOverview(
      summary: _list(json['summary'])
          .map(ReportsSummaryCardDto.new)
          .map((ReportsSummaryCardDto dto) => dto.toEntity())
          .where((ReportsSummaryCard item) => item.id.isNotEmpty)
          .toList(growable: false),
      queueSummaries: _list(json['queue_summaries'])
          .map(ReportsQueueSummaryDto.new)
          .map((ReportsQueueSummaryDto dto) => dto.toEntity())
          .where((ReportsQueueSummary item) => item.id.isNotEmpty)
          .toList(growable: false),
      lookups: ReportsLookupsDto(_map(json['lookups'])).toEntity(),
      items: AppPage<ReportsWorkspaceItem>(
        items: _list(json['items'])
            .map((ReportsJsonMap item) {
              return ReportsWorkspaceItemDto(
                item,
                resource: resource,
              ).toEntity();
            })
            .where((ReportsWorkspaceItem item) => item.id.isNotEmpty)
            .toList(growable: false),
        request: request,
        totalItemCount: _int(_map(json['pagination'])['total']),
      ),
      timeline: _list(json['timeline'])
          .map(ReportsTimelineItemDto.new)
          .map((ReportsTimelineItemDto dto) => dto.toEntity())
          .where((ReportsTimelineItem item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

final class ReportsLookupsDto {
  const ReportsLookupsDto(this.json);

  final ReportsJsonMap json;

  ReportsLookups toEntity() {
    return ReportsLookups(
      facilities: _options(json['facilities']),
      branches: _options(json['branches']),
      owners: _options(json['owners']),
      datasets: _options(json['datasets']),
      statuses: _options(json['statuses']),
      formats: _options(json['formats']),
      triggers: _options(json['triggers']),
      frequencies: _options(json['frequencies']),
    );
  }
}

final class ReportsSummaryCardDto {
  const ReportsSummaryCardDto(this.json);

  final ReportsJsonMap json;

  ReportsSummaryCard toEntity() {
    return ReportsSummaryCard(
      id: _firstString(<Object?>[json['id'], json['label']]),
      label: _string(json['label']) ?? '',
      value: _int(json['value']) ?? 0,
    );
  }
}

final class ReportsQueueSummaryDto {
  const ReportsQueueSummaryDto(this.json);

  final ReportsJsonMap json;

  ReportsQueueSummary toEntity() {
    return ReportsQueueSummary(
      id: _firstString(<Object?>[json['id'], json['label']]),
      label: _string(json['label']) ?? '',
      count: _int(json['count']) ?? 0,
      panel: ReportsWorkspacePanel.fromServer(_string(json['panel'])),
      resource: ReportsWorkspaceResource.fromServer(_string(json['resource'])),
    );
  }
}

final class ReportsTimelineItemDto {
  const ReportsTimelineItemDto(this.json);

  final ReportsJsonMap json;

  ReportsTimelineItem toEntity() {
    return ReportsTimelineItem(
      id: _firstString(<Object?>[json['id'], json['target_id']]),
      title: _firstString(<Object?>[json['title'], json['type']]),
      subtitle: _string(json['subtitle']),
      status: _string(json['status']),
      resource: _string(json['resource']) == null
          ? null
          : ReportsWorkspaceResource.fromServer(_string(json['resource'])),
      targetId: _string(json['target_id']),
      occurredAt: _date(json['occurred_at']),
    );
  }
}

final class ReportsWorkspaceItemPageDto {
  const ReportsWorkspaceItemPageDto({required this.page});

  final AppPage<ReportsWorkspaceItem> page;

  factory ReportsWorkspaceItemPageDto.fromPaginatedResponse(
    Object? responseData, {
    required AppPageRequest request,
    required ReportsWorkspaceResource resource,
  }) {
    final ReportsJsonMap response = _map(responseData);
    return ReportsWorkspaceItemPageDto(
      page: AppPage<ReportsWorkspaceItem>(
        items: _list(response['data'])
            .map((ReportsJsonMap item) {
              return ReportsWorkspaceItemDto(
                item,
                resource: resource,
              ).toEntity();
            })
            .where((ReportsWorkspaceItem item) => item.id.isNotEmpty)
            .toList(growable: false),
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }

  factory ReportsWorkspaceItemPageDto.schedulesFromPaginatedResponse(
    Object? responseData, {
    required AppPageRequest request,
  }) {
    final ReportsJsonMap response = _map(responseData);
    return ReportsWorkspaceItemPageDto(
      page: AppPage<ReportsWorkspaceItem>(
        items: _list(response['data'])
            .map((ReportsJsonMap item) {
              return ReportsWorkspaceItemDto(
                item,
                resource: ReportsWorkspaceResource.reportRuns,
              ).schedule();
            })
            .where((ReportsWorkspaceItem item) => item.id.isNotEmpty)
            .toList(growable: false),
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class ReportsWorkspaceItemDto {
  const ReportsWorkspaceItemDto(this.json, {required this.resource});

  final ReportsJsonMap json;
  final ReportsWorkspaceResource resource;

  ReportsWorkspaceItem toEntity() {
    return switch (resource) {
      ReportsWorkspaceResource.reportDefinitions => _definition(),
      ReportsWorkspaceResource.reportRuns => _run(),
      ReportsWorkspaceResource.dashboardWidgets => _dashboardWidget(),
      ReportsWorkspaceResource.kpiSnapshots => _kpiSnapshot(),
      ReportsWorkspaceResource.analyticsEvents => _analyticsEvent(),
    };
  }

  ReportsWorkspaceItem schedule() {
    return ReportsWorkspaceItem(
      id: _id(),
      kind: ReportItemKind.schedule,
      title: _firstString(<Object?>[json['name'], json['display_id']]),
      subtitle: _joinDisplay(<String?>[
        _string(json['report_definition_label']),
        _string(json['frequency']),
        _string(json['time_of_day']),
      ]),
      status: _string(json['status']),
      format: _string(json['format']),
      facilityLabel: _string(json['facility_label']),
      ownerLabel: _string(json['created_by_label']),
      reference: _string(json['display_id']),
      occurredAt: _date(json['next_run_at']) ?? _date(json['updated_at']),
      count: _int(json['pending_runs']),
      rawDetails: json,
    );
  }

  ReportsWorkspaceItem _definition() {
    return ReportsWorkspaceItem(
      id: _id(),
      kind: ReportItemKind.definition,
      title: _firstString(<Object?>[json['name'], json['display_id']]),
      subtitle: _string(json['description']) ?? _string(json['dataset_key']),
      description: _string(json['description']),
      status: _string(json['status']),
      format: _string(json['default_format']),
      category: _string(json['category']),
      datasetKey: _string(json['dataset_key']),
      facilityLabel: _string(json['facility_label']),
      ownerLabel: _string(json['created_by_label']),
      reference: _string(json['display_id']),
      occurredAt: _date(json['updated_at']) ?? _date(json['created_at']),
      count: _int(json['schedule_count']),
      rawDetails: json,
    );
  }

  ReportsWorkspaceItem _run() {
    return ReportsWorkspaceItem(
      id: _id(),
      kind: ReportItemKind.run,
      title: _firstString(<Object?>[
        json['report_definition_label'],
        json['display_id'],
      ]),
      subtitle: _joinDisplay(<String?>[
        _string(json['format']),
        _string(json['trigger_type']),
        _string(json['output_file_name']),
      ]),
      status: _string(json['status']),
      format: _string(json['format']),
      facilityLabel: _string(json['facility_label']),
      ownerLabel: _string(json['requested_by_label']),
      reference: _string(json['display_id']),
      occurredAt:
          _date(json['completed_at']) ??
          _date(json['started_at']) ??
          _date(json['queued_at']) ??
          _date(json['created_at']),
      value: _num(json['output_size_bytes']),
      downloadAvailable: _bool(json['download_available']),
      errorMessage: _string(json['error_message']),
      rawDetails: json,
    );
  }

  ReportsWorkspaceItem _dashboardWidget() {
    return ReportsWorkspaceItem(
      id: _id(),
      kind: ReportItemKind.dashboardWidget,
      title: _firstString(<Object?>[json['name'], json['display_id']]),
      subtitle: _joinDisplay(<String?>[
        _string(json['widget_type']),
        _string(json['placement']),
      ]),
      status: _bool(json['is_pinned']) ? 'PINNED' : null,
      category: _string(json['placement']),
      reference: _string(json['display_id']),
      occurredAt: _date(json['updated_at']) ?? _date(json['created_at']),
      isPinned: _bool(json['is_pinned']),
      rawDetails: json,
    );
  }

  ReportsWorkspaceItem _kpiSnapshot() {
    return ReportsWorkspaceItem(
      id: _id(),
      kind: ReportItemKind.kpiSnapshot,
      title: _firstString(<Object?>[json['name'], json['metric_key']]),
      subtitle: _joinDisplay(<String?>[
        _string(json['metric_group']),
        _string(json['threshold_state']),
      ]),
      status: _string(json['threshold_state']),
      category: _string(json['metric_group']),
      facilityLabel: _string(json['facility_label']),
      reference: _string(json['display_id']),
      occurredAt: _date(json['recorded_at']) ?? _date(json['created_at']),
      value: _num(json['value']),
      rawDetails: json,
    );
  }

  ReportsWorkspaceItem _analyticsEvent() {
    return ReportsWorkspaceItem(
      id: _id(),
      kind: ReportItemKind.analyticsEvent,
      title: _firstString(<Object?>[json['event_name'], json['display_id']]),
      subtitle: _joinDisplay(<String?>[
        _string(json['event_category']),
        _string(json['entity_type']),
        _string(json['entity_public_id']),
      ]),
      status: _string(json['severity']),
      category: _string(json['event_category']),
      facilityLabel: _string(json['facility_label']),
      ownerLabel: _string(json['user_label']),
      reference: _string(json['display_id']),
      occurredAt: _date(json['occurred_at']) ?? _date(json['created_at']),
      rawDetails: json,
    );
  }

  String _id() {
    return _firstString(<Object?>[
      json['id'],
      json['display_id'],
      json['human_friendly_id'],
    ]);
  }
}

final class ComplianceLogItemPageDto {
  const ComplianceLogItemPageDto({required this.page});

  final AppPage<ComplianceLogItem> page;

  factory ComplianceLogItemPageDto.fromPaginatedResponse(
    Object? responseData, {
    required AppPageRequest request,
    required ComplianceLogKind kind,
  }) {
    final ReportsJsonMap response = _map(responseData);
    return ComplianceLogItemPageDto(
      page: AppPage<ComplianceLogItem>(
        items: _list(response['data'])
            .map((ReportsJsonMap item) {
              return ComplianceLogItemDto(item, kind: kind).toEntity();
            })
            .where((ComplianceLogItem item) => item.id.isNotEmpty)
            .toList(growable: false),
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class ComplianceLogItemDto {
  const ComplianceLogItemDto(this.json, {required this.kind});

  final ReportsJsonMap json;
  final ComplianceLogKind kind;

  ComplianceLogItem toEntity() {
    return switch (kind) {
      ComplianceLogKind.audit => _audit(),
      ComplianceLogKind.phiAccess => _phi(),
      ComplianceLogKind.dataProcessing => _processing(),
    };
  }

  ComplianceLogItem _audit() {
    return ComplianceLogItem(
      id: _id(),
      kind: kind,
      title: _joinDisplay(<String?>[
            _string(json['action']),
            _string(json['entity']),
          ]) ??
          _id(),
      subtitle: _joinDisplay(<String?>[
        _string(json['user_label']),
        _string(json['entity_reference']) ?? _string(json['entity_id']),
      ]),
      userLabel: _string(json['user_label']),
      action: _string(json['action']),
      entity: _string(json['entity']),
      recordReference: _string(json['entity_reference']) ??
          _string(json['entity_id']) ??
          _string(json['display_id']),
      ipAddress: _string(json['ip_address']),
      occurredAt: _date(json['created_at']),
      rawDetails: json,
    );
  }

  ComplianceLogItem _phi() {
    return ComplianceLogItem(
      id: _id(),
      kind: kind,
      title: _firstString(<Object?>[
        json['patient_label'],
        json['patient_id'],
        json['display_id'],
      ]),
      subtitle: _joinDisplay(<String?>[
        _string(json['user_label']),
        _string(json['access_scope']),
      ]),
      userLabel: _string(json['user_label']),
      patientLabel: _string(json['patient_label']),
      scope: _string(json['access_scope']),
      recordReference: _string(json['patient_id']),
      occurredAt: _date(json['accessed_at']) ?? _date(json['created_at']),
      details: _string(json['reason']),
      rawDetails: json,
    );
  }

  ComplianceLogItem _processing() {
    return ComplianceLogItem(
      id: _id(),
      kind: kind,
      title: _firstString(<Object?>[json['purpose'], json['display_id']]),
      subtitle: _joinDisplay(<String?>[
        _string(json['legal_basis']),
        _string(json['user_label']),
      ]),
      userLabel: _string(json['user_label']),
      purpose: _string(json['purpose']),
      legalBasis: _string(json['legal_basis']),
      occurredAt: _date(json['processed_at']) ?? _date(json['created_at']),
      details: _string(json['details']),
      rawDetails: json,
    );
  }

  String _id() {
    return _firstString(<Object?>[
      json['id'],
      json['display_id'],
      json['human_friendly_id'],
    ]);
  }
}

ReportsWorkspaceItem decodeReportRun(Object? responseData) {
  return ReportsWorkspaceItemDto(
    _dataMap(responseData),
    resource: ReportsWorkspaceResource.reportRuns,
  ).toEntity();
}

ReportsWorkspaceItem decodeReportSchedule(Object? responseData) {
  return ReportsWorkspaceItemDto(
    _dataMap(responseData),
    resource: ReportsWorkspaceResource.reportRuns,
  ).schedule();
}

List<ReportsLookupOption> _options(Object? value) {
  return _list(value)
      .map((ReportsJsonMap item) {
        return ReportsLookupOption(
          id: _firstString(<Object?>[item['id'], item['key']]),
          label: _firstString(<Object?>[item['label'], item['name'], item['id']]),
          subtitle: _string(item['subtitle']),
          meta: _map(item['meta']),
        );
      })
      .where((ReportsLookupOption item) => item.id.isNotEmpty)
      .toList(growable: false);
}

ReportsJsonMap _dataMap(Object? responseData) {
  final ReportsJsonMap response = _map(responseData);
  final ReportsJsonMap data = _map(response['data']);
  return data.isNotEmpty ? data : response;
}

ReportsJsonMap _map(Object? value) {
  if (value is Map) {
    return value.map<String, Object?>((Object? key, Object? value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });
  }
  return <String, Object?>{};
}

List<ReportsJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <ReportsJsonMap>[];
  }
  return value
      .map(_map)
      .where((ReportsJsonMap item) => item.isNotEmpty)
      .toList(growable: false);
}

String _firstString(Iterable<Object?> values) {
  for (final Object? value in values) {
    final String? normalized = _string(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return '';
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value.replaceAll(',', '').trim());
  }
  return null;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value.trim().toLowerCase() == 'true';
  }
  return false;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }
  return DateTime.tryParse(normalized);
}
