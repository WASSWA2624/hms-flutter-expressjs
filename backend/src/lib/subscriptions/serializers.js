const { resolvePublicIdentifier } = require('@lib/billing/identifiers');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const safeNumber = (value, fallback = null) => {
  if (value === null || value === undefined || value === '') return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const safeString = (value) => {
  const normalized = String(value || '').trim();
  return normalized || null;
};

const mapTenant = (record) => ({
  tenant_id: safePublicId(record?.tenant?.human_friendly_id, record?.tenant_id),
  tenant_label: safeString(record?.tenant?.name),
});

const mapPlan = (record) => ({
  plan_id: safePublicId(record?.plan?.human_friendly_id, record?.plan_id),
  plan_label: safeString(record?.plan?.name),
  plan_code: safeString(record?.plan?.code),
  tier_code: safeString(record?.plan?.tier_code || record?.tier_code),
  billing_cycle: safeString(record?.plan?.billing_cycle || record?.billing_cycle),
});

const mapPendingPlan = (record) => ({
  pending_plan_id: safePublicId(record?.pending_plan?.human_friendly_id, record?.pending_plan_id),
  pending_plan_label: safeString(record?.pending_plan?.name),
});

const serializeSubscriptionPlan = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    ...mapTenant(record),
    code: safeString(record.code),
    name: safeString(record.name),
    tier_code: safeString(record.tier_code),
    price: safeNumber(record.price, 0),
    billing_cycle: safeString(record.billing_cycle),
    max_users: safeNumber(record.max_users),
    max_facilities: safeNumber(record.max_facilities),
    max_storage_mb: safeNumber(record.max_storage_mb),
    max_modules: safeNumber(record.max_modules),
    plan_fit_warning_percent: safeNumber(record.plan_fit_warning_percent, 80),
    limit_policy_json: record.limit_policy_json || null,
    add_on_eligibility_json: record.add_on_eligibility_json || null,
    extension_json: record.extension_json || null,
    subscription_count: safeNumber(record?._count?.subscriptions, 0),
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    version: safeNumber(record.version, 1),
  };
};

const serializeModule = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    name: safeString(record.name),
    slug: safeString(record.slug),
    description: safeString(record.description),
    module_group: safeNumber(record.module_group),
    minimum_plan_tier_code: safeString(record.minimum_plan_tier_code),
    is_add_on: Boolean(record.is_add_on),
    add_on_price: safeNumber(record.add_on_price),
    add_on_billing_cycle: safeString(record.add_on_billing_cycle),
    entitlement_policy_json: record.entitlement_policy_json || null,
    extension_json: record.extension_json || null,
    subscription_count: safeNumber(record?._count?.subscriptions, 0),
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    version: safeNumber(record.version, 1),
  };
};

const serializeSubscription = (record) => {
  if (!record) return null;

  const activeModuleCount = Array.isArray(record?.module_subscriptions)
    ? record.module_subscriptions.filter((entry) => entry?.deleted_at == null && entry?.is_active).length
    : safeNumber(record?._count?.module_subscriptions, 0);

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    ...mapTenant(record),
    ...mapPlan(record),
    ...mapPendingPlan(record),
    status: safeString(record.status),
    change_status: safeString(record.change_status),
    start_date: record.start_date || null,
    end_date: record.end_date || null,
    change_requested_at: record.change_requested_at || null,
    change_effective_at: record.change_effective_at || null,
    proration_amount: safeNumber(record.proration_amount),
    proration_currency_code: safeString(record.proration_currency_code),
    users_used: safeNumber(record.users_used),
    facilities_used: safeNumber(record.facilities_used),
    storage_used_mb: safeNumber(record.storage_used_mb),
    modules_used: safeNumber(record.modules_used),
    active_module_count: activeModuleCount,
    plan_fit_status: safeString(record.plan_fit_status),
    plan_fit_evaluated_at: record.plan_fit_evaluated_at || null,
    entitlement_snapshot_json: record.entitlement_snapshot_json || null,
    extension_json: record.extension_json || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    version: safeNumber(record.version, 1),
  };
};

const serializeModuleSubscription = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    subscription_id: safePublicId(
      record?.subscription?.human_friendly_id,
      record?.subscription_id
    ),
    subscription_label: safePublicId(
      record?.subscription?.human_friendly_id,
      record?.subscription_id
    ),
    module_id: safePublicId(record?.module?.human_friendly_id, record?.module_id),
    module_label: safeString(record?.module?.name),
    module_slug: safeString(record?.module?.slug),
    ...mapTenant(record?.subscription || {}),
    ...mapPlan(record?.subscription || {}),
    is_active: Boolean(record.is_active),
    entitlement_denied: Boolean(record.entitlement_denied),
    entitlement_denial_reason: safeString(record.entitlement_denial_reason),
    evaluated_plan_fit_status: safeString(record.evaluated_plan_fit_status),
    eligibility_checked_at: record.eligibility_checked_at || null,
    activation_requested_at: record.activation_requested_at || null,
    activated_at: record.activated_at || null,
    deactivated_at: record.deactivated_at || null,
    extension_json: record.extension_json || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    version: safeNumber(record.version, 1),
  };
};

const serializeSubscriptionInvoice = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    subscription_id: safePublicId(
      record?.subscription?.human_friendly_id,
      record?.subscription_id
    ),
    subscription_label: safePublicId(
      record?.subscription?.human_friendly_id,
      record?.subscription_id
    ),
    ...mapTenant(record?.subscription || {}),
    ...mapPlan(record?.subscription || {}),
    invoice_id: safePublicId(record?.invoice?.human_friendly_id, record?.invoice_id),
    invoice_display_id: safePublicId(record?.invoice?.human_friendly_id, record?.invoice_id),
    invoice_status: safeString(record?.invoice?.status),
    billing_status: safeString(record?.invoice?.billing_status),
    total_amount: safeNumber(record?.invoice?.total_amount, 0),
    currency: safeString(record?.invoice?.currency),
    issued_at: record?.invoice?.issued_at || null,
    paid_at: record?.invoice?.paid_at || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    version: safeNumber(record.version, 1),
  };
};

const serializeLicense = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    ...mapTenant(record),
    license_type: safeString(record.license_type),
    status: safeString(record.status),
    plan_tier_code: safeString(record.plan_tier_code),
    entitlement_snapshot_json: record.entitlement_snapshot_json || null,
    extension_json: record.extension_json || null,
    issued_at: record.issued_at || null,
    expires_at: record.expires_at || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    version: safeNumber(record.version, 1),
  };
};

const serializePlanEntitlements = (record) => {
  if (!record) return null;
  return {
    ...record,
    subscription_plan_id: safePublicId(
      record.subscription_plan_human_friendly_id,
      record.subscription_plan_id
    ),
  };
};

const serializePlanAddOnEligibility = (record) => {
  if (!record) return null;
  return {
    ...record,
    subscription_plan_id: safePublicId(
      record.subscription_plan_human_friendly_id,
      record.subscription_plan_id
    ),
  };
};

const serializeSubscriptionUsageSummary = (record) => {
  if (!record) return null;
  return {
    ...record,
    subscription_id: safePublicId(record.subscription_human_friendly_id, record.subscription_id),
    plan_id: safePublicId(record.plan_human_friendly_id, record.plan_id),
    pending_plan_id: safePublicId(
      record.pending_plan_human_friendly_id,
      record.pending_plan_id
    ),
  };
};

const serializeSubscriptionFitCheck = (record) => {
  if (!record) return null;
  return {
    ...record,
    subscription_id: safePublicId(record.subscription_human_friendly_id, record.subscription_id),
    plan_id: safePublicId(record.plan_human_friendly_id, record.plan_id),
  };
};

const serializeSubscriptionUpgradeRecommendation = (record) => {
  if (!record) return null;
  return {
    ...record,
    subscription_id: safePublicId(record.subscription_human_friendly_id, record.subscription_id),
    current_plan_id: safePublicId(record.current_plan_human_friendly_id, record.current_plan_id),
    recommended_plan_id: safePublicId(
      record.recommended_plan_human_friendly_id,
      record.recommended_plan_id
    ),
  };
};

const serializeSubscriptionProrationPreview = (record) => {
  if (!record) return null;
  return {
    ...record,
    subscription_id: safePublicId(record.subscription_human_friendly_id, record.subscription_id),
    current_plan_id: safePublicId(record.current_plan_human_friendly_id, record.current_plan_id),
    target_plan_id: safePublicId(record.target_plan_human_friendly_id, record.target_plan_id),
  };
};

const serializeModuleSubscriptionEligibility = (record) => {
  if (!record) return null;
  return {
    ...record,
    module_subscription_id: safePublicId(
      record.module_subscription_human_friendly_id,
      record.module_subscription_id
    ),
  };
};

const serializeSubscriptionInvoiceCollection = (record) => {
  if (!record) return null;
  return {
    ...record,
    subscription_invoice_id: safePublicId(
      record.subscription_invoice_human_friendly_id,
      record.subscription_invoice_id
    ),
  };
};

module.exports = {
  safeNumber,
  safePublicId,
  serializeLicense,
  serializeModule,
  serializeModuleSubscription,
  serializeModuleSubscriptionEligibility,
  serializePlanAddOnEligibility,
  serializePlanEntitlements,
  serializeSubscription,
  serializeSubscriptionFitCheck,
  serializeSubscriptionInvoice,
  serializeSubscriptionInvoiceCollection,
  serializeSubscriptionPlan,
  serializeSubscriptionProrationPreview,
  serializeSubscriptionUpgradeRecommendation,
  serializeSubscriptionUsageSummary,
};
