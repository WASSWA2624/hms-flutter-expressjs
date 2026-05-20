import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef BiomedicalJsonMap = Map<String, Object?>;

final class BiomedicalWorkbenchDto {
  const BiomedicalWorkbenchDto({required this.workbench});

  final BiomedicalWorkbench workbench;

  factory BiomedicalWorkbenchDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final BiomedicalJsonMap response = _expectMap(responseData);
    final BiomedicalJsonMap data = _map(response['data']);
    final List<BiomedicalAsset> assets = _list(data['items'])
        .map((Object? item) => BiomedicalAssetDto(_map(item)).toEntity())
        .where((BiomedicalAsset item) => item.id.isNotEmpty)
        .toList(growable: false);

    return BiomedicalWorkbenchDto(
      workbench: BiomedicalWorkbench(
        summary: BiomedicalSummaryDto.fromList(
          _list(data['summary']),
        ).toEntity(),
        queues: _list(data['queue_summaries'])
            .map((Object? item) => BiomedicalQueueSummaryDto(_map(item)))
            .map((BiomedicalQueueSummaryDto dto) => dto.toEntity())
            .toList(growable: false),
        panels: _list(data['panel_summaries'])
            .map((Object? item) => BiomedicalPanelSummaryDto(_map(item)))
            .map((BiomedicalPanelSummaryDto dto) => dto.toEntity())
            .toList(growable: false),
        lookups: BiomedicalLookupDataDto(_map(data['lookups'])).toEntity(),
        assets: AppPage<BiomedicalAsset>(
          items: assets,
          request: request,
          totalItemCount: _int(_map(data['pagination'])['total']),
        ),
        spotlight: _list(data['spotlight'])
            .map((Object? item) => BiomedicalQueueSummaryDto(_map(item)))
            .map((BiomedicalQueueSummaryDto dto) => dto.toEntity())
            .toList(growable: false),
      ),
    );
  }
}

final class BiomedicalSummaryDto {
  const BiomedicalSummaryDto(this.values);

  final Map<String, int> values;

  factory BiomedicalSummaryDto.fromList(List<Object?> entries) {
    return BiomedicalSummaryDto(<String, int>{
      for (final Object? entry in entries)
        if (_string(_map(entry)['id']) != null)
          _string(_map(entry)['id'])!: _int(_map(entry)['value']) ?? 0,
    });
  }

  BiomedicalSummary toEntity() {
    return BiomedicalSummary(
      totalEquipment: values['total_equipment'] ?? 0,
      overduePm: values['overdue_pm'] ?? 0,
      openWorkOrders: values['open_work_orders'] ?? 0,
      criticalDowntime: values['critical_downtime'] ?? 0,
      activeRecalls: values['active_recalls'] ?? 0,
    );
  }
}

final class BiomedicalQueueSummaryDto {
  const BiomedicalQueueSummaryDto(this.json);

  final BiomedicalJsonMap json;

  BiomedicalQueueSummary toEntity() {
    return BiomedicalQueueSummary(
      queue: _string(json['queue']) ?? _string(json['id']) ?? '',
      count: _int(json['count']) ?? 0,
      labelKey: _string(json['label_key']),
      panel: _string(json['panel']),
      resource: _string(json['resource']),
      targetPath: _string(json['target_path']),
    );
  }
}

final class BiomedicalPanelSummaryDto {
  const BiomedicalPanelSummaryDto(this.json);

  final BiomedicalJsonMap json;

  BiomedicalPanelSummary toEntity() {
    return BiomedicalPanelSummary(
      id: _string(json['id']) ?? '',
      count: _int(json['count']) ?? 0,
      labelKey: _string(json['label_key']),
      defaultResource: _string(json['default_resource']),
      targetPath: _string(json['target_path']),
    );
  }
}

final class BiomedicalLookupDataDto {
  const BiomedicalLookupDataDto(this.json);

  final BiomedicalJsonMap json;

  factory BiomedicalLookupDataDto.fromResponse(Object? responseData) {
    final BiomedicalJsonMap response = _expectMap(responseData);
    return BiomedicalLookupDataDto(_map(response['data']));
  }

  BiomedicalLookupData toEntity() {
    return BiomedicalLookupData(
      facilities: _options(json['facilities']),
      rooms: _options(json['rooms']),
      equipment: _options(json['equipment']),
      categories: _options(json['categories']),
      providers: _options(json['providers']),
      engineers: _options(json['engineers']),
      statuses: _options(json['statuses']),
      priorities: _options(json['priorities']),
      queues: _options(json['queues']),
    );
  }

  List<BiomedicalLookupOption> _options(Object? value) {
    return _list(value)
        .map((Object? item) => BiomedicalLookupOptionDto(_map(item)).toEntity())
        .where((BiomedicalLookupOption item) => item.id.isNotEmpty)
        .toList(growable: false);
  }
}

final class BiomedicalLookupOptionDto {
  const BiomedicalLookupOptionDto(this.json);

  final BiomedicalJsonMap json;

  BiomedicalLookupOption toEntity() {
    return BiomedicalLookupOption(
      id: _string(json['id']) ?? '',
      label: _string(json['label']) ?? _string(json['name']) ?? '',
      subtitle: _string(json['subtitle']),
      meta: _map(json['meta']),
    );
  }
}

final class BiomedicalAssetDto {
  const BiomedicalAssetDto(this.json, {String? resource})
    : resourceOverride = resource;

  final BiomedicalJsonMap json;
  final String? resourceOverride;

  BiomedicalAsset toEntity() {
    final String resource =
        resourceOverride ??
        _string(json['resource']) ??
        BiomedicalResources.registries;
    final String? id = _firstNonEmpty(<String?>[
      _string(json['id']),
      _string(json['human_friendly_id']),
      _string(json['display_id']),
    ]);
    final String? equipmentId = _firstNonEmpty(<String?>[
      _string(json['equipment_id']),
      _string(json['equipment_registry_id']),
    ]);
    final String? equipmentLabel = _firstNonEmpty(<String?>[
      _string(json['equipment_label']),
      _string(json['equipment_registry_label']),
      _string(json['equipment_name']),
      _string(_map(json['equipment_registry'])['equipment_name']),
      _string(_map(json['equipment_registry'])['equipment_code']),
    ]);

    return BiomedicalAsset(
      id: id ?? '',
      humanFriendlyId: _firstNonEmpty(<String?>[
        _string(json['human_friendly_id']),
        _string(json['display_id']),
      ]),
      resource: resource,
      title: _firstNonEmpty(<String?>[
        _string(json['title']),
        _string(json['equipment_name']),
        _string(json['plan_name']),
        _string(json['name']),
        _string(json['part_name']),
        _string(json['provider_name']),
        _string(json['contract_number']),
        id,
      ]),
      subtitle: _firstNonEmpty(<String?>[
        _string(json['subtitle']),
        _string(json['equipment_code']),
        _string(json['serial_number']),
        _string(json['description']),
      ]),
      status: _string(json['status']) ?? _string(json['result']),
      priority: _firstNonEmpty(<String?>[
        _string(json['priority']),
        _string(json['criticality_level']),
        _string(json['severity']),
        _string(json['impact_level']),
      ]),
      facilityId: _string(json['facility_id']),
      facilityLabel: _string(json['facility_label']),
      equipmentId: equipmentId,
      equipmentLabel: equipmentLabel,
      categoryId: _firstNonEmpty(<String?>[
        _string(json['equipment_category_id']),
        _string(json['category_id']),
      ]),
      categoryLabel: _firstNonEmpty(<String?>[
        _string(json['equipment_category_label']),
        _string(_map(json['category'])['name']),
      ]),
      engineerId:
          _string(json['engineer_id']) ??
          _string(json['assigned_engineer_user_id']),
      engineerLabel: _string(json['engineer_label']),
      nextDueAt: _date(json['next_due_at']),
      timelineAt: _firstDate(<Object?>[
        json['timeline_at'],
        json['updated_at'],
        json['created_at'],
      ]),
      targetPath: _string(json['target_path']),
      raw: json,
    );
  }
}

final class BiomedicalMutationResultDto {
  const BiomedicalMutationResultDto(this.json, {this.resource});

  final BiomedicalJsonMap json;
  final String? resource;

  factory BiomedicalMutationResultDto.fromResourceResponse(
    Object? responseData,
    String resource,
  ) {
    final BiomedicalJsonMap response = _expectMap(responseData);
    return BiomedicalMutationResultDto(
      _map(response['data']).isEmpty ? response : _map(response['data']),
      resource: resource,
    );
  }

  factory BiomedicalMutationResultDto.fromFaultResponse(Object? responseData) {
    final BiomedicalJsonMap response = _expectMap(responseData);
    return BiomedicalMutationResultDto(_map(response['data']));
  }

  BiomedicalMutationResult toEntity() {
    final BiomedicalJsonMap workOrder = _map(json['equipment_work_order']);
    return BiomedicalMutationResult(
      asset: resource == null
          ? null
          : BiomedicalAssetDto(json, resource: resource).toEntity(),
      workOrderId:
          _string(workOrder['id']) ?? _string(workOrder['human_friendly_id']),
      deepLink: _string(json['deep_link']),
      raw: json,
    );
  }
}

BiomedicalJsonMap _expectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return <String, Object?>{};
}

BiomedicalJsonMap _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return <String, Object?>{};
}

List<Object?> _list(Object? value) {
  if (value is List<Object?>) {
    return value;
  }
  if (value is Iterable) {
    return value.cast<Object?>().toList(growable: false);
  }
  return <Object?>[];
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
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }
  return DateTime.tryParse(normalized);
}

DateTime? _firstDate(Iterable<Object?> values) {
  for (final Object? value in values) {
    final DateTime? date = _date(value);
    if (date != null) {
      return date;
    }
  }
  return null;
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
