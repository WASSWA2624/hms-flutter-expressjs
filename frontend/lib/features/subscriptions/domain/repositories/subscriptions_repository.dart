import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';

abstract interface class SubscriptionsRepository {
  Future<Result<SubscriptionsWorkspaceData>> getWorkspace(
    SubscriptionsWorkspaceQuery query,
  );

  Future<Result<void>> createPlan(SubscriptionPlanDraft draft);

  Future<Result<void>> updatePlan(String planId, SubscriptionPlanDraft draft);

  Future<Result<void>> createSubscription(SubscriptionDraft draft);

  Future<Result<void>> activateSubscription(String subscriptionId);

  Future<Result<void>> cancelSubscription(String subscriptionId);

  Future<Result<void>> renewSubscription(
    String subscriptionId,
    SubscriptionRenewalDraft draft,
  );

  Future<Result<void>> changeSubscriptionPlan(
    String subscriptionId,
    SubscriptionPlanChangeDraft draft,
  );

  Future<Result<void>> createModuleSubscription(
    ModuleSubscriptionDraft draft,
  );

  Future<Result<void>> setModuleSubscriptionActive(
    String moduleSubscriptionId, {
    required bool isActive,
    String? reason,
  });

  Future<Result<void>> createLicense(LicenseDraft draft);

  Future<Result<void>> updateLicense(String licenseId, LicenseDraft draft);

  Future<Result<void>> collectInvoice(
    String subscriptionInvoiceId,
    SubscriptionActionDraft draft,
  );

  Future<Result<void>> retryInvoice(
    String subscriptionInvoiceId,
    SubscriptionActionDraft draft,
  );
}
