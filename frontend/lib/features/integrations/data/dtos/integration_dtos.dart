import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';

typedef IntegrationsJsonMap = Map<String, Object?>;

final class IntegrationDto {
  const IntegrationDto(this.json);

  final IntegrationsJsonMap json;

  factory IntegrationDto.fromResponse(Object? responseData) {
    return IntegrationDto(_dataMap(responseData));
  }

  IntegrationRecord toEntity() {
    return IntegrationRecord(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['human_friendly_id'],
      ]),
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      tenantLabel: _string(json['tenant_label']),
      integrationType: _string(json['integration_type']),
      status: _string(json['status']),
      name: _string(json['name']),
      configSummary: _map(json['config_json']),
      hasConfig: _bool(json['has_config']),
      logCount: _int(json['log_count']) ?? 0,
      webhookSubscriptionCount: _int(json['webhook_subscription_count']) ?? 0,
      requiresAttention: _bool(json['requires_attention']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class ApiKeyDto {
  const ApiKeyDto(this.json);

  final IntegrationsJsonMap json;

  factory ApiKeyDto.fromResponse(Object? responseData) {
    return ApiKeyDto(_dataMap(responseData));
  }

  ApiKeyRecord toEntity() {
    return ApiKeyRecord(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['human_friendly_id'],
      ]),
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      humanFriendlyId: _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      userId: _string(json['user_id']),
      name: _string(json['name']),
      isActive: _bool(json['is_active']),
      expiresAt: _date(json['expires_at']),
      lastUsedAt: _date(json['last_used_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      oneTimeSecret: _string(json['api_key']),
    );
  }
}

final class ApiKeyPermissionDto {
  const ApiKeyPermissionDto(this.json);

  final IntegrationsJsonMap json;

  factory ApiKeyPermissionDto.fromResponse(Object? responseData) {
    return ApiKeyPermissionDto(_dataMap(responseData));
  }

  ApiKeyPermissionRecord toEntity() {
    return ApiKeyPermissionRecord(
      id: _firstString(<Object?>[json['id'], json['display_id']]),
      apiKeyId: _string(json['api_key_id']) ?? '',
      permissionId: _string(json['permission_id']) ?? '',
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class IntegrationPermissionOptionDto {
  const IntegrationPermissionOptionDto(this.json);

  final IntegrationsJsonMap json;

  IntegrationPermissionOption toEntity() {
    return IntegrationPermissionOption(
      id: _firstString(<Object?>[json['id'], json['display_id']]),
      name: _string(json['name']) ?? '',
      description: _string(json['description']),
    );
  }
}

final class WebhookSubscriptionDto {
  const WebhookSubscriptionDto(this.json);

  final IntegrationsJsonMap json;

  factory WebhookSubscriptionDto.fromResponse(Object? responseData) {
    return WebhookSubscriptionDto(_dataMap(responseData));
  }

  WebhookSubscriptionRecord toEntity() {
    return WebhookSubscriptionRecord(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['human_friendly_id'],
      ]),
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      tenantLabel: _string(json['tenant_label']),
      integrationId: _string(json['integration_id']),
      integrationDisplayId: _string(json['integration_display_id']),
      integrationLabel: _string(json['integration_label']),
      integrationType: _string(json['integration_type']),
      integrationStatus: _string(json['integration_status']),
      event: _string(json['event']),
      targetUrl: _string(json['target_url']),
      targetHost: _string(json['target_host']),
      isActive: _bool(json['is_active']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class IntegrationLogDto {
  const IntegrationLogDto(this.json);

  final IntegrationsJsonMap json;

  factory IntegrationLogDto.fromResponse(Object? responseData) {
    return IntegrationLogDto(_dataMap(responseData));
  }

  IntegrationLogRecord toEntity() {
    return IntegrationLogRecord(
      id: _firstString(<Object?>[
        json['id'],
        json['display_id'],
        json['human_friendly_id'],
      ]),
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      integrationId: _string(json['integration_id']),
      integrationDisplayId: _string(json['integration_display_id']),
      integrationLabel: _string(json['integration_label']),
      integrationType: _string(json['integration_type']),
      integrationStatus: _string(json['integration_status']),
      tenantId: _string(json['tenant_id']),
      tenantLabel: _string(json['tenant_label']),
      status: _string(json['status']),
      message: _string(json['message']),
      loggedAt: _date(json['logged_at']),
      timelineAt: _date(json['timeline_at']),
      requiresAttention: _bool(json['requires_attention']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

final class IntegrationActionResultDto {
  const IntegrationActionResultDto(this.json);

  final IntegrationsJsonMap json;

  factory IntegrationActionResultDto.fromResponse(Object? responseData) {
    return IntegrationActionResultDto(_dataMap(responseData));
  }

  IntegrationActionResult toEntity() {
    final bool connected = _bool(json['connected']);
    final bool queued = _bool(json['queued']);
    final String status =
        _string(json['status']) ??
        (connected
            ? 'CONNECTED'
            : queued
            ? 'QUEUED'
            : 'COMPLETED');

    return IntegrationActionResult(
      title: _firstString(<Object?>[
        json['integration_label'],
        json['integration_display_id'],
        json['webhook_subscription_display_id'],
        json['delivery_id'],
        json['id'],
      ]),
      status: status,
      message:
          _string(json['message']) ??
          _string(json['error']) ??
          _string(json['scope']),
      timelineAt:
          _date(json['tested_at']) ??
          _date(json['queued_at']) ??
          _date(json['delivered_at']) ??
          _date(json['timeline_at']) ??
          _date(json['created_at']),
    );
  }
}

List<IntegrationRecord> decodeIntegrationList(Object? responseData) {
  return _dataList(responseData)
      .map(IntegrationDto.new)
      .map((IntegrationDto dto) => dto.toEntity())
      .where((IntegrationRecord record) => record.id.isNotEmpty)
      .toList(growable: false);
}

List<ApiKeyRecord> decodeApiKeyList(Object? responseData) {
  return _dataList(responseData)
      .map(ApiKeyDto.new)
      .map((ApiKeyDto dto) => dto.toEntity())
      .where((ApiKeyRecord record) => record.id.isNotEmpty)
      .toList(growable: false);
}

List<ApiKeyPermissionRecord> decodeApiKeyPermissionList(
  Object? responseData,
) {
  return _dataList(responseData)
      .map(ApiKeyPermissionDto.new)
      .map((ApiKeyPermissionDto dto) => dto.toEntity())
      .where((ApiKeyPermissionRecord record) {
        return record.id.isNotEmpty &&
            record.apiKeyId.isNotEmpty &&
            record.permissionId.isNotEmpty;
      })
      .toList(growable: false);
}

List<IntegrationPermissionOption> decodePermissionOptions(
  Object? responseData,
) {
  return _dataList(responseData)
      .map(IntegrationPermissionOptionDto.new)
      .map((IntegrationPermissionOptionDto dto) => dto.toEntity())
      .where((IntegrationPermissionOption option) {
        return option.id.isNotEmpty && option.name.isNotEmpty;
      })
      .toList(growable: false);
}

List<WebhookSubscriptionRecord> decodeWebhookList(Object? responseData) {
  return _dataList(responseData)
      .map(WebhookSubscriptionDto.new)
      .map((WebhookSubscriptionDto dto) => dto.toEntity())
      .where((WebhookSubscriptionRecord record) => record.id.isNotEmpty)
      .toList(growable: false);
}

List<IntegrationLogRecord> decodeIntegrationLogList(Object? responseData) {
  return _dataList(responseData)
      .map(IntegrationLogDto.new)
      .map((IntegrationLogDto dto) => dto.toEntity())
      .where((IntegrationLogRecord record) => record.id.isNotEmpty)
      .toList(growable: false);
}

IntegrationsJsonMap _dataMap(Object? responseData) {
  final IntegrationsJsonMap response = _map(responseData);
  final IntegrationsJsonMap data = _map(response['data']);
  return data.isNotEmpty ? data : response;
}

List<IntegrationsJsonMap> _dataList(Object? responseData) {
  final IntegrationsJsonMap response = _map(responseData);
  final Object? data = response['data'];
  if (data is List) {
    return data.map(_map).where(_isNotEmpty).toList(growable: false);
  }
  return _list(data);
}

IntegrationsJsonMap _map(Object? value) {
  if (value is Map) {
    return value.map<String, Object?>((Object? key, Object? value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });
  }
  return <String, Object?>{};
}

List<IntegrationsJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <IntegrationsJsonMap>[];
  }
  return value.map(_map).where(_isNotEmpty).toList(growable: false);
}

bool _isNotEmpty(IntegrationsJsonMap item) => item.isNotEmpty;

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

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (<String>['true', '1', 'yes', 'on', 'active'].contains(normalized)) {
      return true;
    }
    if (<String>[
      'false',
      '0',
      'no',
      'off',
      'inactive',
      'disabled',
    ].contains(normalized)) {
      return false;
    }
  }
  return fallback;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }
  return DateTime.tryParse(normalized);
}
