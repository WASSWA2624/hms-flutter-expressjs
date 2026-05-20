import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/features/subscriptions/data/dtos/subscription_dtos.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/domain/repositories/subscriptions_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final subscriptionsRepositoryProvider = Provider<SubscriptionsRepository>((
  ref,
) {
  return SubscriptionsRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final class SubscriptionsRepositoryImpl implements SubscriptionsRepository {
  const SubscriptionsRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Result<SubscriptionsWorkspaceData>> getWorkspace(
    SubscriptionsWorkspaceQuery query,
  ) {
    final AppPageRequest request = query.pageRequest;
    return _apiClient.get<SubscriptionsWorkspaceData>(
      ApiEndpoints.nested(
        HmsApiResource.subscriptionsWorkspace,
        'workspace',
        const <String>[],
      ),
      queryParameters: _withoutEmpty(<String, Object?>{
        'page': request.pageIndex + 1,
        'limit': request.pageSize,
        'panel': query.panel.serverValue,
        'resource': query.resource.serverValue,
        'queue': query.queue,
        'search': query.search,
        'tenantId': query.tenantId,
        'status': query.status,
        'tierCode': query.tierCode,
        'billingCycle': query.billingCycle,
        'planId': query.planId,
        'moduleId': query.moduleId,
        'fitStatus': query.fitStatus,
        'changeStatus': query.changeStatus,
        'invoiceStatus': query.invoiceStatus,
        'licenseType': query.licenseType,
        'eligibilityState': query.eligibilityState,
        'datePreset': query.datePreset == SubscriptionDatePreset.none
            ? null
            : query.datePreset.serverValue,
      }),
      decoder: (Object? data) {
        return SubscriptionsWorkspaceDto.fromResponse(data, query).toEntity();
      },
    );
  }

  @override
  Future<Result<void>> createPlan(SubscriptionPlanDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.subscriptionPlans),
      data: _planPayload(draft, includeTenant: true),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> updatePlan(String planId, SubscriptionPlanDraft draft) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.subscriptionPlans, planId),
      data: _planPayload(draft),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createSubscription(SubscriptionDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.subscriptions),
      data: _withoutEmpty(<String, Object?>{
        'tenant_id': draft.tenantId,
        'plan_id': draft.planId,
        'status': draft.status,
        'start_date': _isoDateTimeOrNull(draft.startDate),
        'end_date': _isoDateTimeOrNull(draft.endDate),
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> activateSubscription(String subscriptionId) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.subscriptions, subscriptionId),
      data: const <String, Object?>{'status': 'ACTIVE'},
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> cancelSubscription(String subscriptionId) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.subscriptions, subscriptionId),
      data: const <String, Object?>{'status': 'CANCELLED'},
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> renewSubscription(
    String subscriptionId,
    SubscriptionRenewalDraft draft,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.subscriptions,
        subscriptionId,
        const <String>['renew'],
      ),
      data: _withoutEmpty(<String, Object?>{
        'end_date': _isoDateTimeOrNull(draft.endDate),
        'reason': draft.reason,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> changeSubscriptionPlan(
    String subscriptionId,
    SubscriptionPlanChangeDraft draft,
  ) {
    final String action = draft.changeType.trim().toLowerCase() == 'downgrade'
        ? 'downgrade'
        : 'upgrade';
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.subscriptions,
        subscriptionId,
        <String>[action],
      ),
      data: _withoutEmpty(<String, Object?>{
        'target_plan_id': draft.targetPlanId,
        'effective_at': _isoDateTimeOrNull(draft.effectiveAt),
        'reason': draft.reason,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createModuleSubscription(ModuleSubscriptionDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.moduleSubscriptions),
      data: _withoutEmpty(<String, Object?>{
        'subscription_id': draft.subscriptionId,
        'module_id': draft.moduleId,
        'is_active': draft.isActive,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> setModuleSubscriptionActive(
    String moduleSubscriptionId, {
    required bool isActive,
    String? reason,
  }) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.moduleSubscriptions,
        moduleSubscriptionId,
        <String>[isActive ? 'activate' : 'deactivate'],
      ),
      data: _withoutEmpty(<String, Object?>{'reason': reason}),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> createLicense(LicenseDraft draft) {
    return _apiClient.post<void>(
      ApiEndpoints.collection(HmsApiResource.licenses),
      data: _licensePayload(draft, includeTenant: true),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> updateLicense(String licenseId, LicenseDraft draft) {
    return _apiClient.put<void>(
      ApiEndpoints.byId(HmsApiResource.licenses, licenseId),
      data: _licensePayload(draft, includeTenant: true),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> collectInvoice(
    String subscriptionInvoiceId,
    SubscriptionActionDraft draft,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.subscriptionInvoices,
        subscriptionInvoiceId,
        const <String>['collect'],
      ),
      data: _withoutEmpty(<String, Object?>{
        'payment_method': draft.paymentMethod,
        'notes': draft.notes,
      }),
      decoder: (_) {},
    );
  }

  @override
  Future<Result<void>> retryInvoice(
    String subscriptionInvoiceId,
    SubscriptionActionDraft draft,
  ) {
    return _apiClient.post<void>(
      ApiEndpoints.nested(
        HmsApiResource.subscriptionInvoices,
        subscriptionInvoiceId,
        const <String>['retry'],
      ),
      data: _withoutEmpty(<String, Object?>{'retry_reason': draft.reason}),
      decoder: (_) {},
    );
  }
}

Map<String, Object?> _planPayload(
  SubscriptionPlanDraft draft, {
  bool includeTenant = false,
}) {
  return _withoutEmpty(<String, Object?>{
    if (includeTenant) 'tenant_id': draft.tenantId,
    'name': draft.name.trim(),
    'code': draft.code,
    'tier_code': draft.tierCode,
    'price': _decimal(draft.price),
    'billing_cycle': draft.billingCycle,
    'max_users': _intOrNull(draft.maxUsers),
    'max_facilities': _intOrNull(draft.maxFacilities),
    'max_storage_mb': _intOrNull(draft.maxStorageMb),
    'max_modules': _intOrNull(draft.maxModules),
  });
}

Map<String, Object?> _licensePayload(
  LicenseDraft draft, {
  required bool includeTenant,
}) {
  return _withoutEmpty(<String, Object?>{
    if (includeTenant) 'tenant_id': draft.tenantId,
    'license_type': draft.licenseType,
    'status': draft.status,
    'issued_at': _isoDateTimeOrNull(draft.issuedAt),
    'expires_at': _isoDateTimeOrNull(draft.expiresAt),
  });
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

num _decimal(String value) {
  return num.tryParse(value.replaceAll(',', '').trim()) ?? 0;
}

int? _intOrNull(String? value) {
  final String? normalized = _nonEmpty(value);
  return normalized == null ? null : int.tryParse(normalized);
}

String? _isoDateTimeOrNull(String? value) {
  final String? normalized = _nonEmpty(value);
  if (normalized == null) {
    return null;
  }
  final DateTime? parsed = DateTime.tryParse(normalized);
  return parsed == null ? normalized : parsed.toUtc().toIso8601String();
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
