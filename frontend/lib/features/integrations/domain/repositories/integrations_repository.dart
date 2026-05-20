import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';

abstract interface class IntegrationsRepository {
  Future<Result<List<IntegrationRecord>>> listIntegrations();

  Future<Result<IntegrationRecord>> createIntegration(
    Map<String, Object?> payload,
  );

  Future<Result<IntegrationRecord>> updateIntegration(
    String integrationId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteIntegration(String integrationId);

  Future<Result<IntegrationActionResult>> testConnection(
    String integrationId,
    Map<String, Object?> payload,
  );

  Future<Result<IntegrationActionResult>> syncNow(
    String integrationId,
    Map<String, Object?> payload,
  );

  Future<Result<List<ApiKeyRecord>>> listApiKeys();

  Future<Result<ApiKeyRecord>> createApiKey(Map<String, Object?> payload);

  Future<Result<ApiKeyRecord>> updateApiKey(
    String apiKeyId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteApiKey(String apiKeyId);

  Future<Result<List<ApiKeyPermissionRecord>>> listApiKeyPermissions();

  Future<Result<ApiKeyPermissionRecord>> createApiKeyPermission(
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteApiKeyPermission(String permissionGrantId);

  Future<Result<List<IntegrationPermissionOption>>> listPermissionOptions();

  Future<Result<List<WebhookSubscriptionRecord>>> listWebhooks();

  Future<Result<WebhookSubscriptionRecord>> createWebhook(
    Map<String, Object?> payload,
  );

  Future<Result<WebhookSubscriptionRecord>> updateWebhook(
    String webhookId,
    Map<String, Object?> payload,
  );

  Future<Result<void>> deleteWebhook(String webhookId);

  Future<Result<IntegrationActionResult>> replayWebhook(
    String webhookId,
    Map<String, Object?> payload,
  );

  Future<Result<List<IntegrationLogRecord>>> listLogs();

  Future<Result<IntegrationLogRecord>> getLog(String logId);

  Future<Result<IntegrationActionResult>> replayLog(
    String logId,
    Map<String, Object?> payload,
  );

  List<InteropCapabilityStatus> interopCapabilities();
}
