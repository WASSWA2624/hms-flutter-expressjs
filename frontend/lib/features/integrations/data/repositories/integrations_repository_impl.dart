import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/integrations/data/dtos/integration_dtos.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';
import 'package:hosspi_hms/features/integrations/domain/repositories/integrations_repository.dart';

final integrationsRepositoryProvider = Provider<IntegrationsRepository>((ref) {
  return IntegrationsRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class IntegrationsRepositoryImpl implements IntegrationsRepository {
  const IntegrationsRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const int _workspaceListLimit = 100;

  final ApiClient _apiClient;

  @override
  Future<Result<List<IntegrationRecord>>> listIntegrations() {
    return _apiClient.get<List<IntegrationRecord>>(
      ApiEndpoints.collection(HmsApiResource.integrations),
      queryParameters: _listQuery(sortBy: 'updated_at'),
      decoder: decodeIntegrationList,
    );
  }

  @override
  Future<Result<IntegrationRecord>> createIntegration(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<IntegrationRecord>(
      ApiEndpoints.collection(HmsApiResource.integrations),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => IntegrationDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<IntegrationRecord>> updateIntegration(
    String integrationId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<IntegrationRecord>(
      ApiEndpoints.byId(HmsApiResource.integrations, integrationId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => IntegrationDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<void>> deleteIntegration(String integrationId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.integrations, integrationId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<IntegrationActionResult>> testConnection(
    String integrationId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<IntegrationActionResult>(
      ApiEndpoints.nested(HmsApiResource.integrations, integrationId, <String>[
        'test-connection',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return IntegrationActionResultDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<IntegrationActionResult>> syncNow(
    String integrationId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<IntegrationActionResult>(
      ApiEndpoints.nested(HmsApiResource.integrations, integrationId, <String>[
        'sync-now',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return IntegrationActionResultDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<List<ApiKeyRecord>>> listApiKeys() {
    return _apiClient.get<List<ApiKeyRecord>>(
      ApiEndpoints.collection(HmsApiResource.apiKeys),
      queryParameters: _listQuery(sortBy: 'created_at'),
      decoder: decodeApiKeyList,
    );
  }

  @override
  Future<Result<ApiKeyRecord>> createApiKey(Map<String, Object?> payload) {
    return _apiClient.post<ApiKeyRecord>(
      ApiEndpoints.collection(HmsApiResource.apiKeys),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => ApiKeyDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<ApiKeyRecord>> updateApiKey(
    String apiKeyId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<ApiKeyRecord>(
      ApiEndpoints.byId(HmsApiResource.apiKeys, apiKeyId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) => ApiKeyDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<void>> deleteApiKey(String apiKeyId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.apiKeys, apiKeyId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<List<ApiKeyPermissionRecord>>> listApiKeyPermissions() {
    return _apiClient.get<List<ApiKeyPermissionRecord>>(
      ApiEndpoints.collection(HmsApiResource.apiKeyPermissions),
      queryParameters: _listQuery(sortBy: 'created_at'),
      decoder: decodeApiKeyPermissionList,
    );
  }

  @override
  Future<Result<ApiKeyPermissionRecord>> createApiKeyPermission(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<ApiKeyPermissionRecord>(
      ApiEndpoints.collection(HmsApiResource.apiKeyPermissions),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return ApiKeyPermissionDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<void>> deleteApiKeyPermission(String permissionGrantId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.apiKeyPermissions, permissionGrantId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<List<IntegrationPermissionOption>>> listPermissionOptions() {
    return _apiClient.get<List<IntegrationPermissionOption>>(
      ApiEndpoints.collection(HmsApiResource.permissions),
      queryParameters: _listQuery(sortBy: 'name', order: 'asc'),
      decoder: decodePermissionOptions,
    );
  }

  @override
  Future<Result<List<WebhookSubscriptionRecord>>> listWebhooks() {
    return _apiClient.get<List<WebhookSubscriptionRecord>>(
      ApiEndpoints.collection(HmsApiResource.webhookSubscriptions),
      queryParameters: _listQuery(sortBy: 'updated_at'),
      decoder: decodeWebhookList,
    );
  }

  @override
  Future<Result<WebhookSubscriptionRecord>> createWebhook(
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<WebhookSubscriptionRecord>(
      ApiEndpoints.collection(HmsApiResource.webhookSubscriptions),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return WebhookSubscriptionDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<WebhookSubscriptionRecord>> updateWebhook(
    String webhookId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.put<WebhookSubscriptionRecord>(
      ApiEndpoints.byId(HmsApiResource.webhookSubscriptions, webhookId),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return WebhookSubscriptionDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<void>> deleteWebhook(String webhookId) {
    return _apiClient.delete<void>(
      ApiEndpoints.byId(HmsApiResource.webhookSubscriptions, webhookId),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<IntegrationActionResult>> replayWebhook(
    String webhookId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<IntegrationActionResult>(
      ApiEndpoints.nested(
        HmsApiResource.webhookSubscriptions,
        webhookId,
        <String>['replay'],
      ),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return IntegrationActionResultDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  Future<Result<List<IntegrationLogRecord>>> listLogs() {
    return _apiClient.get<List<IntegrationLogRecord>>(
      ApiEndpoints.collection(HmsApiResource.integrationLogs),
      queryParameters: _listQuery(sortBy: 'logged_at'),
      decoder: decodeIntegrationLogList,
    );
  }

  @override
  Future<Result<IntegrationLogRecord>> getLog(String logId) {
    return _apiClient.get<IntegrationLogRecord>(
      ApiEndpoints.byId(HmsApiResource.integrationLogs, logId),
      decoder: (Object? data) =>
          IntegrationLogDto.fromResponse(data).toEntity(),
    );
  }

  @override
  Future<Result<IntegrationActionResult>> replayLog(
    String logId,
    Map<String, Object?> payload,
  ) {
    return _apiClient.post<IntegrationActionResult>(
      ApiEndpoints.nested(HmsApiResource.integrationLogs, logId, <String>[
        'replay',
      ]),
      data: _withoutEmpty(payload),
      decoder: (Object? data) {
        return IntegrationActionResultDto.fromResponse(data).toEntity();
      },
    );
  }

  @override
  List<InteropCapabilityStatus> interopCapabilities() {
    return const <InteropCapabilityStatus>[
      InteropCapabilityStatus(
        id: 'fhir',
        title: 'FHIR_EXCHANGE',
        scope: 'FHIR_EXPORT_IMPORT',
        status: 'READY',
        nextAction: 'RUN_FROM_ACTION_ENDPOINT',
      ),
      InteropCapabilityStatus(
        id: 'hl7',
        title: 'HL7_MESSAGES',
        scope: 'HL7_SUBMIT',
        status: 'READY',
        nextAction: 'RUN_FROM_ACTION_ENDPOINT',
      ),
      InteropCapabilityStatus(
        id: 'dicom',
        title: 'DICOM_LINK',
        scope: 'DICOM_STUDY_LINK',
        status: 'READY',
        nextAction: 'RUN_FROM_ACTION_ENDPOINT',
      ),
      InteropCapabilityStatus(
        id: 'migration',
        title: 'MIGRATION_EXCHANGE',
        scope: 'MIGRATION_EXPORT_IMPORT',
        status: 'READY',
        nextAction: 'RUN_FROM_ACTION_ENDPOINT',
      ),
      InteropCapabilityStatus(
        id: 'readiness',
        title: 'EXTERNAL_READINESS_STATUS',
        scope: 'INTEROP_STATUS',
        status: 'BACKEND_GAP',
        nextAction: 'USE_INTEGRATION_STATUS_AND_LOGS',
        backendGap: 'NO_DEDICATED_INTEROP_READINESS_ENDPOINT',
      ),
    ];
  }

  Map<String, Object?> _listQuery({
    required String sortBy,
    String order = 'desc',
  }) {
    return <String, Object?>{
      'page': 1,
      'limit': _workspaceListLimit,
      'sort_by': sortBy,
      'order': order,
    };
  }
}

Map<String, Object?> _withoutEmpty(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_isEmptyPayloadValue(entry.value)) entry.key: entry.value,
  };
}

bool _isEmptyPayloadValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable) {
    return value.isEmpty;
  }
  if (value is Map) {
    return value.isEmpty;
  }
  return false;
}
