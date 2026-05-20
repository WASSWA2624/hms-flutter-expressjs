import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/domain/repositories/housekeeping_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef HousekeepingJsonMap = Map<String, Object?>;

final class HousekeepingWorkspaceDto {
  const HousekeepingWorkspaceDto(this.json);

  final HousekeepingJsonMap json;

  factory HousekeepingWorkspaceDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    return HousekeepingWorkspaceDto(_dataMap(responseData));
  }

  HousekeepingWorkspaceLoad toEntity(AppPageRequest request) {
    final HousekeepingWorkspaceOverview overview = HousekeepingWorkspaceOverview(
      summaryCards: _list(json['summary'])
          .map(HousekeepingSummaryCardDto.new)
          .map((HousekeepingSummaryCardDto dto) => dto.toEntity())
          .where((HousekeepingSummaryCard card) => card.id.isNotEmpty)
          .toList(growable: false),
      queueSummaries: _list(json['queue_summaries'])
          .map(HousekeepingQueueSummaryDto.new)
          .map((HousekeepingQueueSummaryDto dto) => dto.toEntity())
          .toList(growable: false),
      lookups: HousekeepingLookupsDto(_map(json['lookups'])).toEntity(),
    );
    final List<HousekeepingWorkItem> items = _list(json['items'])
        .map(HousekeepingWorkItemDto.new)
        .map((HousekeepingWorkItemDto dto) => dto.toEntity())
        .where((HousekeepingWorkItem item) => item.id.isNotEmpty)
        .toList(growable: false);
    final HousekeepingJsonMap pagination = _map(json['pagination']);

    return HousekeepingWorkspaceLoad(
      overview: overview,
      items: AppPage<HousekeepingWorkItem>(
        items: items,
        request: request,
        totalItemCount: _int(pagination['total']) ?? items.length,
      ),
    );
  }
}

final class HousekeepingSummaryCardDto {
  const HousekeepingSummaryCardDto(this.json);

  final HousekeepingJsonMap json;

  HousekeepingSummaryCard toEntity() {
    return HousekeepingSummaryCard(
      id: _string(json['id']) ?? '',
      labelKey: _string(json['label_key']) ?? '',
      value: _int(json['value']) ?? 0,
    );
  }
}

final class HousekeepingQueueSummaryDto {
  const HousekeepingQueueSummaryDto(this.json);

  final HousekeepingJsonMap json;

  HousekeepingQueueSummary toEntity() {
    final HousekeepingResource resource = HousekeepingResource.fromServer(
      _string(json['resource']),
    );
    return HousekeepingQueueSummary(
      queue: HousekeepingQueue.fromServer(_string(json['queue'])),
      labelKey: _string(json['label_key']) ?? '',
      count: _int(json['count']) ?? 0,
      resource: resource,
    );
  }
}

final class HousekeepingLookupsDto {
  const HousekeepingLookupsDto(this.json);

  final HousekeepingJsonMap json;

  HousekeepingLookups toEntity() {
    return HousekeepingLookups(
      facilities: _options(json['facilities']),
      rooms: _options(json['rooms']),
      assignees: _options(json['assignees']),
      assets: _options(json['assets']),
      statuses: _options(json['statuses']),
    );
  }

  List<HousekeepingLookupOption> _options(Object? value) {
    return _list(value)
        .map(HousekeepingLookupOptionDto.new)
        .map((HousekeepingLookupOptionDto dto) => dto.toEntity())
        .where((HousekeepingLookupOption option) => option.id.isNotEmpty)
        .toList(growable: false);
  }
}

final class HousekeepingLookupOptionDto {
  const HousekeepingLookupOptionDto(this.json);

  final HousekeepingJsonMap json;

  HousekeepingLookupOption toEntity() {
    final String id = _firstString(<Object?>[
      json['id'],
      json['value'],
      json['human_friendly_id'],
    ]);
    return HousekeepingLookupOption(
      id: id,
      label: _string(json['label']) ?? id,
      subtitle: _string(json['subtitle']),
    );
  }
}

final class HousekeepingWorkItemDto {
  const HousekeepingWorkItemDto(this.json);

  final HousekeepingJsonMap json;

  HousekeepingWorkItem toEntity() {
    final HousekeepingResource resource = HousekeepingResource.fromServer(
      _string(json['resource']),
    );
    final String id = _firstString(<Object?>[
      json['id'],
      json['human_friendly_id'],
      json['display_id'],
    ]);

    return HousekeepingWorkItem(
      id: id,
      displayId: _string(json['display_id']) ?? _string(json['human_friendly_id']),
      resource: resource,
      title: _firstString(<Object?>[
        json['title'],
        json['room_label'],
        json['asset_label'],
        json['facility_label'],
        id,
      ]),
      subtitle: _string(json['subtitle']),
      status: _string(json['status']),
      priority: _string(json['priority']),
      facilityId: _string(json['facility_id']),
      facilityLabel: _string(json['facility_label']),
      roomId: _string(json['room_id']),
      roomLabel: _string(json['room_label']),
      assigneeId:
          _string(json['assignee_id']) ?? _string(json['assigned_to_staff_id']),
      assigneeLabel:
          _string(json['assignee_label']) ??
          _string(json['assigned_to_staff_label']),
      assetId: _string(json['asset_id']),
      assetLabel: _string(json['asset_label']),
      scheduledAt: _date(json['scheduled_at']),
      completedAt: _date(json['completed_at']),
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      reportedAt: _date(json['reported_at']),
      resolvedAt: _date(json['resolved_at']),
      servicedAt: _date(json['serviced_at']),
      timelineAt: _date(json['timeline_at']) ?? _date(json['updated_at']),
      targetPath: _string(json['target_path']),
    );
  }
}

HousekeepingJsonMap _dataMap(Object? responseData) {
  final HousekeepingJsonMap response = _map(responseData);
  final HousekeepingJsonMap data = _map(response['data']);
  return data.isNotEmpty ? data : response;
}

HousekeepingJsonMap _map(Object? value) {
  if (value is Map) {
    return value.map<String, Object?>((Object? key, Object? value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });
  }
  return <String, Object?>{};
}

List<HousekeepingJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <HousekeepingJsonMap>[];
  }
  return value
      .map(_map)
      .where((HousekeepingJsonMap item) => item.isNotEmpty)
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

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
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

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }
  return DateTime.tryParse(normalized);
}
