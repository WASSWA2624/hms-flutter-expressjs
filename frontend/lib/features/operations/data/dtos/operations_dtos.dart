import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef OperationsJsonMap = Map<String, Object?>;

final class OperationsWorkItemPageDto {
  const OperationsWorkItemPageDto({required this.page});

  final AppPage<OperationsWorkItem> page;

  factory OperationsWorkItemPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request, {
    String? priority,
    DateTime? reportedFrom,
    DateTime? reportedTo,
  }) {
    final OperationsJsonMap response = _expectMap(responseData);
    final String? normalizedPriority = _normalized(priority);
    final List<OperationsWorkItem> sourceItems = _list(response['data'])
        .map(OperationsWorkItemDto.new)
        .map((OperationsWorkItemDto dto) => dto.toEntity())
        .where((OperationsWorkItem item) => item.id.isNotEmpty)
        .toList(growable: false);
    final List<OperationsWorkItem> items = sourceItems.where((
      OperationsWorkItem item,
    ) {
      if (normalizedPriority != null &&
          item.normalizedPriority != normalizedPriority) {
        return false;
      }
      if (reportedFrom != null &&
          item.reportedAt != null &&
          item.reportedAt!.isBefore(_startOfDay(reportedFrom))) {
        return false;
      }
      if (reportedTo != null &&
          item.reportedAt != null &&
          !item.reportedAt!.isBefore(_startOfDay(reportedTo).add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList(growable: false);
    final bool clientFiltered =
        normalizedPriority != null || reportedFrom != null || reportedTo != null;

    return OperationsWorkItemPageDto(
      page: AppPage<OperationsWorkItem>(
        items: items,
        request: request,
        totalItemCount: clientFiltered
            ? items.length
            : _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class OperationsWorkItemDto {
  const OperationsWorkItemDto(this.json);

  final OperationsJsonMap json;

  factory OperationsWorkItemDto.fromResponse(Object? responseData) {
    final OperationsJsonMap response = _expectMap(responseData);
    return OperationsWorkItemDto(_map(response['data']));
  }

  OperationsWorkItem toEntity() {
    final String id =
        _string(json['id']) ??
        _string(json['display_id']) ??
        _string(json['human_friendly_id']) ??
        '';
    final String? description = _string(json['description']);

    return OperationsWorkItem(
      id: id,
      displayId: _string(json['display_id']) ?? _string(json['human_friendly_id']),
      status: _string(json['status']),
      description: description,
      reportedAt: _date(json['reported_at']),
      resolvedAt: _date(json['resolved_at']),
      facilityId: _string(json['facility_id']),
      facilityLabel: _string(json['facility_label']),
      assetId: _string(json['asset_id']),
      assetLabel: _string(json['asset_label']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      metadata: OperationsRequestMetadataDto(description).toEntity(),
    );
  }
}

final class OperationsAssetPageDto {
  const OperationsAssetPageDto({required this.page});

  final AppPage<OperationsAsset> page;

  factory OperationsAssetPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final OperationsJsonMap response = _expectMap(responseData);
    final List<OperationsAsset> items = _list(response['data'])
        .map(OperationsAssetDto.new)
        .map((OperationsAssetDto dto) => dto.toEntity())
        .where((OperationsAsset asset) => asset.id.isNotEmpty)
        .toList(growable: false);

    return OperationsAssetPageDto(
      page: AppPage<OperationsAsset>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class OperationsAssetDto {
  const OperationsAssetDto(this.json);

  final OperationsJsonMap json;

  OperationsAsset toEntity() {
    final String id =
        _string(json['id']) ??
        _string(json['display_id']) ??
        _string(json['human_friendly_id']) ??
        '';

    return OperationsAsset(
      id: id,
      displayId: _string(json['display_id']) ?? _string(json['human_friendly_id']),
      name: _string(json['name']),
      assetTag: _string(json['asset_tag']),
      status: _string(json['status']),
      facilityId: _string(json['facility_id']),
      facilityLabel: _string(json['facility_label']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class OperationsServiceLogPageDto {
  const OperationsServiceLogPageDto({required this.page});

  final AppPage<OperationsServiceLog> page;

  factory OperationsServiceLogPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final OperationsJsonMap response = _expectMap(responseData);
    final List<OperationsServiceLog> items = _list(response['data'])
        .map(OperationsServiceLogDto.new)
        .map((OperationsServiceLogDto dto) => dto.toEntity())
        .where((OperationsServiceLog log) => log.id.isNotEmpty)
        .toList(growable: false);

    return OperationsServiceLogPageDto(
      page: AppPage<OperationsServiceLog>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class OperationsServiceLogDto {
  const OperationsServiceLogDto(this.json);

  final OperationsJsonMap json;

  factory OperationsServiceLogDto.fromResponse(Object? responseData) {
    final OperationsJsonMap response = _expectMap(responseData);
    return OperationsServiceLogDto(_map(response['data']));
  }

  OperationsServiceLog toEntity() {
    final String id =
        _string(json['id']) ??
        _string(json['display_id']) ??
        _string(json['human_friendly_id']) ??
        '';

    return OperationsServiceLog(
      id: id,
      displayId: _string(json['display_id']) ?? _string(json['human_friendly_id']),
      assetId: _string(json['asset_id']),
      assetLabel: _string(json['asset_label']),
      facilityId: _string(json['facility_id']),
      facilityLabel: _string(json['facility_label']),
      servicedAt: _date(json['serviced_at']),
      notes: _string(json['notes']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class OperationsRequestMetadataDto {
  const OperationsRequestMetadataDto(this.description);

  final String? description;

  OperationsRequestMetadata toEntity() {
    final Map<String, String> fields = <String, String>{};
    final List<String> notes = <String>[];
    String? assignee;
    int? slaHours;
    String? triageSummary;

    for (final String line in (description ?? '').split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final int separator = trimmed.indexOf(':');
      if (separator > 0) {
        final String key = trimmed.substring(0, separator).trim().toLowerCase();
        final String value = trimmed.substring(separator + 1).trim();
        if (value.isNotEmpty) {
          fields[key] = value;
          if (key == 'notes') {
            notes.add(value);
          }
        }
        continue;
      }
      if (trimmed.startsWith('[TRIAGE]')) {
        final Map<String, String> triage = _parseKeyValueSuffix(trimmed);
        assignee = triage['assigned_engineer_id'] ?? triage['assigned_engineer'];
        slaHours = _int(triage['sla_hours']);
        triageSummary = triage['triage_summary'];
        if (triageSummary != null) {
          notes.add(triageSummary);
        }
        continue;
      }
      if (trimmed.startsWith('[')) {
        notes.add(trimmed);
      }
    }

    return OperationsRequestMetadata(
      category: fields['category'],
      priority: fields['priority'],
      issue: fields['issue'],
      location: fields['location'],
      notes: notes.isEmpty ? null : notes.join('\n'),
      assignee: assignee,
      slaHours: slaHours,
      triageSummary: triageSummary,
    );
  }
}

OperationsJsonMap _expectMap(Object? value) {
  if (value is OperationsJsonMap) {
    return value;
  }

  throw const FormatException('Expected operations response object.');
}

OperationsJsonMap _map(Object? value) {
  return value is OperationsJsonMap ? value : <String, Object?>{};
}

List<OperationsJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <OperationsJsonMap>[];
  }

  return value.whereType<OperationsJsonMap>().toList(growable: false);
}

Map<String, String> _parseKeyValueSuffix(String line) {
  final int closeBracket = line.indexOf(']');
  if (closeBracket < 0 || closeBracket >= line.length - 1) {
    return const <String, String>{};
  }

  final String suffix = line.substring(closeBracket + 1).trim();
  final Map<String, String> values = <String, String>{};
  for (final String part in suffix.split(';')) {
    final int separator = part.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    final String key = part.substring(0, separator).trim();
    final String value = part.substring(separator + 1).trim();
    if (key.isNotEmpty && value.isNotEmpty) {
      values[key] = value;
    }
  }
  return values;
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

String? _normalized(String? value) {
  final String? normalized = _string(value)?.toUpperCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }

  return DateTime.tryParse(normalized);
}

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
