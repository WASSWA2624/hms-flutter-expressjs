import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';

typedef HomeLookupsJsonMap = Map<String, Object?>;

final class HomeDashboardLookupsDto {
  const HomeDashboardLookupsDto(this.json);

  final HomeLookupsJsonMap json;

  factory HomeDashboardLookupsDto.fromResponse(Object? responseData) {
    return HomeDashboardLookupsDto(_dataMap(responseData));
  }

  HomeDashboardLookups toEntity() {
    return HomeDashboardLookups(
      tenants: _options(json['tenants']),
      facilities: _options(json['facilities'], includeFacilityMeta: true),
      queueTypes: _options(json['queue_types']),
      datePresets: _options(json['date_presets']),
    );
  }

  List<HomeLookupOption> _options(
    Object? value, {
    bool includeFacilityMeta = false,
    bool includeBranchMeta = false,
  }) {
    if (value is! List<Object?>) {
      return const <HomeLookupOption>[];
    }

    return value
        .map(_map)
        .map((HomeLookupsJsonMap item) {
          final String id = _string(item['id']) ?? '';
          if (id.isEmpty) {
            return null;
          }

          final HomeLookupsJsonMap meta = _map(item['meta']);
          return HomeLookupOption(
            id: id,
            label: _string(item['label']) ?? _string(item['name']) ?? id,
            metaTenantId: includeFacilityMeta
                ? _string(meta['tenant_id'])
                : null,
            metaFacilityId: includeBranchMeta
                ? _string(meta['facility_id'])
                : null,
            metaFacilityType: includeFacilityMeta
                ? _string(meta['facility_type'])
                : null,
          );
        })
        .whereType<HomeLookupOption>()
        .toList(growable: false);
  }
}

HomeLookupsJsonMap _dataMap(Object? responseData) {
  final HomeLookupsJsonMap response = _map(responseData);
  final HomeLookupsJsonMap data = _map(response['data']);
  return data.isNotEmpty ? data : response;
}

HomeLookupsJsonMap _map(Object? value) {
  if (value is Map) {
    return value.map<String, Object?>((Object? key, Object? value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });
  }
  return <String, Object?>{};
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}
