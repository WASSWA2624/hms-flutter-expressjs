import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';

typedef HomeJsonMap = Map<String, Object?>;

final class HomeDashboardDto {
  const HomeDashboardDto(this.json);

  final HomeJsonMap json;

  factory HomeDashboardDto.fromResponse(Object? responseData) {
    return HomeDashboardDto(_dataMap(responseData));
  }

  HomeDashboard toEntity() {
    final String state = _string(json['state']) ?? 'ready';
    if (state == 'tenant_context_required') {
      final String? roleValue = _contextRoleValue(json['context']);
      final profile = homeProfileForRole(appRoleFromValue(roleValue));

      return HomeDashboard(
        state: HomeDashboardLoadState.tenantContextRequired,
        profile: profile,
        context: HomeDashboardContext(roleValue: roleValue),
        statusCards: profile.fallbackStatusCards(),
        quickActionIds: profile.quickActionIds,
        shortcutIds: profile.shortcutIds,
        queuePreview: const <HomeQueueItem>[],
        alerts: const <HomeAlertItem>[],
        activity: const <HomeActivityItem>[],
        tenantOptions: _list(json['tenant_options'])
            .map(HomeTenantOptionDto.new)
            .map((HomeTenantOptionDto dto) => dto.toEntity())
            .where((HomeTenantOption option) => option.id.isNotEmpty)
            .toList(growable: false),
        generatedAt: _date(json['generated_at']),
      );
    }

    final HomeJsonMap context = _map(json['context']);
    final HomeJsonMap roleProfile = _map(context['role']);
    final HomeJsonMap overview = _map(json['overview']);
    final HomeJsonMap hero = _map(overview['hero']);
    final String? profileId =
        _string(roleProfile['id']) ?? _string(hero['role_profile_id']);
    final String? roleValue =
        _string(roleProfile['role']) ?? _string(hero['role']);
    final profile = _profile(profileId: profileId, roleValue: roleValue);
    final List<HomeStatusCard> statusCards = _list(json['status_strip'])
        .map(HomeStatusCardDto.new)
        .map(
          (HomeStatusCardDto dto) => dto.toEntity(
            fallbackLabel: _fallbackStatusLabel(profile, dto.id),
          ),
        )
        .where((HomeStatusCard card) => card.id.isNotEmpty)
        .toList(growable: false);
    final List<HomeQueueItem> queuePreview = _list(overview['queue_preview'])
        .map(HomeQueueItemDto.new)
        .map((HomeQueueItemDto dto) => dto.toEntity())
        .where((HomeQueueItem item) => item.id.isNotEmpty)
        .toList(growable: false);
    final List<HomeAlertItem> alerts = _list(overview['alerts'])
        .map(HomeAlertItemDto.new)
        .map((HomeAlertItemDto dto) => dto.toEntity())
        .where((HomeAlertItem item) => item.id.isNotEmpty)
        .toList(growable: false);
    final List<HomeActivityItem> activity = _list(overview['activity_preview'])
        .map(HomeActivityItemDto.new)
        .map((HomeActivityItemDto dto) => dto.toEntity())
        .where((HomeActivityItem item) => item.id.isNotEmpty)
        .toList(growable: false);

    return HomeDashboard(
      state: HomeDashboardLoadState.ready,
      profile: profile,
      context: HomeDashboardContext(
        roleValue: roleValue,
        tenantId: _string(context['tenant_id']),
        facilityId: _string(context['facility_id']),
        facilityName:
            _string(context['facility_name']) ?? _string(hero['facility_name']),
        facilityType:
            _string(context['facility_type']) ?? _string(hero['facility_type']),
        branchId: _string(context['branch_id']),
      ),
      statusCards: statusCards.isEmpty
          ? profile.fallbackStatusCards()
          : statusCards,
      quickActionIds: _strings(json['quick_action_ids']),
      shortcutIds: profile.shortcutIds,
      queuePreview: queuePreview,
      alerts: alerts,
      activity: activity,
      tenantOptions: const <HomeTenantOption>[],
      generatedAt: _date(json['generated_at']),
    );
  }
}

final class HomeTenantOptionDto {
  const HomeTenantOptionDto(this.json);

  final HomeJsonMap json;

  HomeTenantOption toEntity() {
    return HomeTenantOption(
      id: _string(json['id']) ?? '',
      label: _string(json['label']) ?? _string(json['name']) ?? '',
    );
  }
}

final class HomeStatusCardDto {
  const HomeStatusCardDto(this.json);

  final HomeJsonMap json;

  String get id => _string(json['id']) ?? '';

  HomeStatusCard toEntity({String? fallbackLabel}) {
    return HomeStatusCard(
      id: id,
      label: _string(json['label']) ?? fallbackLabel ?? _fallbackLabel(id),
      value: _num(json['value']) ?? 0,
      format: _string(json['format']) ?? 'number',
    );
  }
}

final class HomeQueueItemDto {
  const HomeQueueItemDto(this.json);

  final HomeJsonMap json;

  HomeQueueItem toEntity() {
    final String displayId =
        _string(json['human_friendly_id']) ?? _string(json['id']) ?? '';
    final String queue = _string(json['queue']) ?? _string(json['kind']) ?? '';
    final String moduleSlug = _string(json['module_slug']) ?? '';
    return HomeQueueItem(
      id: _string(json['id']) ?? displayId,
      label: displayId.isEmpty
          ? _friendlyToken(queue)
          : '${_friendlyToken(queue)} $displayId',
      moduleSlug: moduleSlug,
      status: _string(json['status']),
      severity: _string(json['severity']),
      occurredAt: _date(json['occurred_at']),
      target: HomeRouteTargetDto(_map(json['target'])).toEntity(),
    );
  }
}

final class HomeAlertItemDto {
  const HomeAlertItemDto(this.json);

  final HomeJsonMap json;

  HomeAlertItem toEntity() {
    final String id = _string(json['id']) ?? _string(json['kind']) ?? '';
    return HomeAlertItem(
      id: id,
      label: _alertLabel(_string(json['kind']) ?? id),
      severity: _string(json['severity']) ?? 'info',
      count: _int(json['count']) ?? 0,
      target: HomeRouteTargetDto(_map(json['target'])).toEntity(),
    );
  }
}

final class HomeActivityItemDto {
  const HomeActivityItemDto(this.json);

  final HomeJsonMap json;

  HomeActivityItem toEntity() {
    final String displayId =
        _string(json['human_friendly_id']) ?? _string(json['id']) ?? '';
    final String eventType = _string(json['event_type']) ?? '';
    return HomeActivityItem(
      id: _string(json['id']) ?? displayId,
      label: displayId.isEmpty
          ? _friendlyToken(eventType)
          : '${_friendlyToken(eventType)} $displayId',
      moduleSlug: _string(json['module_slug']) ?? '',
      status: _string(json['status']),
      occurredAt: _date(json['occurred_at']),
      target: HomeRouteTargetDto(_map(json['target'])).toEntity(),
    );
  }
}

final class HomeRouteTargetDto {
  const HomeRouteTargetDto(this.json);

  final HomeJsonMap json;

  HomeRouteTarget? toEntity() {
    final String? moduleSlug = _string(json['module_slug']);
    if (moduleSlug == null) {
      return null;
    }

    return HomeRouteTarget(
      moduleSlug: moduleSlug,
      resource: _string(json['resource']),
      publicId: _string(json['public_id']),
      action: _string(json['action']),
    );
  }
}

HomeDashboardProfile _profile({String? profileId, String? roleValue}) {
  final HomeDashboardProfile byProfile = homeProfileForProfileId(profileId);
  if (byProfile.role != AppRole.other || profileId == 'other') {
    return byProfile;
  }

  return homeProfileForRole(appRoleFromValue(roleValue));
}

String? _contextRoleValue(Object? value) {
  if (value is String) {
    return _string(value);
  }
  return _string(_map(value)['role']) ?? _string(_map(value)['name']);
}

String? _fallbackStatusLabel(
  HomeDashboardProfile profile,
  String statusCardId,
) {
  for (final HomeStatusCardTemplate template in profile.statusCards) {
    if (template.id == statusCardId) {
      return template.label;
    }
  }
  return null;
}

String _alertLabel(String value) {
  return switch (value) {
    'overdue_invoices' => 'Overdue invoices',
    'critical_labs' => 'Critical lab results',
    'bed_occupancy_pressure' => 'Bed occupancy pressure',
    'plan_limit_pressure' => 'Plan-limit pressure',
    'guide_signal' => 'Getting started',
    _ => _friendlyToken(value),
  };
}

String _friendlyToken(String value) {
  final String normalized = value
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return '';
  }

  return normalized
      .split(' ')
      .where((String word) => word.isNotEmpty)
      .map((String word) {
        final String lower = word.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String _fallbackLabel(String id) {
  final String label = _friendlyToken(id);
  return label.isEmpty ? 'Dashboard item' : label;
}

HomeJsonMap _dataMap(Object? responseData) {
  final HomeJsonMap response = _map(responseData);
  final HomeJsonMap data = _map(response['data']);
  return data.isNotEmpty ? data : response;
}

HomeJsonMap _map(Object? value) {
  if (value is Map) {
    return value.map<String, Object?>((Object? key, Object? value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });
  }
  return <String, Object?>{};
}

List<HomeJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <HomeJsonMap>[];
  }
  return value
      .map(_map)
      .where((HomeJsonMap item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _strings(Object? value) {
  if (value is! Iterable<Object?>) {
    return const <String>[];
  }
  return value.map(_string).whereType<String>().toSet().toList(growable: false);
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

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }
  return DateTime.tryParse(normalized);
}
