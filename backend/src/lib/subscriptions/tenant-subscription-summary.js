/**
 * Resolve tenant subscription summary for shell header CTA state.
 *
 * @module lib/subscriptions/tenant-subscription-summary
 */

const prisma = require('@prisma/client');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const env = require('@config/env');
const { PLAN_TIER_RANK } = require('@lib/subscriptions/plan-module-matrix');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const COMMERCIAL_TIER_LADDER = Object.freeze(
  Object.entries(PLAN_TIER_RANK)
    .filter(([tier]) => tier !== 'DEVELOPER')
    .sort((left, right) => left[1] - right[1])
    .map(([tier]) => tier)
);

const titleCaseTier = (tierCode) => {
  const normalized = String(tierCode || '').trim();
  if (!normalized) {
    return null;
  }
  return normalized.charAt(0).toUpperCase() + normalized.slice(1).toLowerCase();
};

const resolveDaysUntil = (endDate) => {
  if (!endDate) {
    return null;
  }

  const parsed = endDate instanceof Date ? endDate : new Date(endDate);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  const diffMs = parsed.getTime() - Date.now();
  return Math.ceil(diffMs / (24 * 60 * 60 * 1000));
};

const resolveHeaderState = ({ status, daysUntilExpiry, expiringSoonDays }) => {
  const normalizedStatus = String(status || '').trim().toUpperCase();

  if (
    normalizedStatus === 'PAST_DUE' ||
    normalizedStatus === 'CANCELLED' ||
    (daysUntilExpiry !== null && daysUntilExpiry < 0)
  ) {
    return 'expired';
  }

  if (daysUntilExpiry !== null && daysUntilExpiry <= expiringSoonDays) {
    return 'expiring_soon';
  }

  return 'active';
};

const resolveNextTierCode = (tierCode) => {
  const normalized = String(tierCode || 'FREE').trim().toUpperCase() || 'FREE';
  const index = COMMERCIAL_TIER_LADDER.indexOf(normalized);
  if (index < 0 || index >= COMMERCIAL_TIER_LADDER.length - 1) {
    return null;
  }
  return COMMERCIAL_TIER_LADDER[index + 1];
};

const isDeveloperPlanRecord = (plan) => {
  if (!plan) {
    return false;
  }
  if (String(plan.code || '').trim().toLowerCase() === 'developer') {
    return true;
  }
  const extension =
    plan.extension_json && typeof plan.extension_json === 'object'
      ? plan.extension_json
      : {};
  return Boolean(extension.is_developer_plan);
};

/**
 * Next commercial catalog plan above the current tier (if any).
 * @param {string|null|undefined} tierCode
 * @returns {Promise<{plan_id: string|null, plan_label: string|null, tier_code: string}|null>}
 */
const resolveNextUpgradePlan = async (tierCode) => {
  const nextTier = resolveNextTierCode(tierCode);
  if (!nextTier) {
    return null;
  }

  const plans = await prisma.subscription_plan.findMany({
    where: {
      deleted_at: null,
      tenant_id: null,
      tier_code: nextTier,
    },
    orderBy: [{ price: 'asc' }, { name: 'asc' }],
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      tier_code: true,
      code: true,
      extension_json: true,
    },
  });

  const plan = plans.find((entry) => !isDeveloperPlanRecord(entry)) || null;
  if (!plan) {
    return {
      plan_id: null,
      plan_label: titleCaseTier(nextTier),
      tier_code: nextTier,
    };
  }

  return {
    plan_id: safePublicId(plan.human_friendly_id, plan.id),
    plan_label: plan.name || titleCaseTier(nextTier),
    tier_code: plan.tier_code || nextTier,
  };
};

const withNextPlanFields = (summary, nextPlan) => ({
  ...summary,
  next_plan_id: nextPlan?.plan_id || null,
  next_plan_label: nextPlan?.plan_label || null,
  next_tier_code: nextPlan?.tier_code || null,
});

/**
 * @param {string} tenantId
 * @returns {Promise<Object|null>}
 */
const resolveTenantSubscriptionSummary = async (tenantId) => {
  if (!tenantId) {
    return null;
  }

  const expiringSoonDays = Number(env.SUBSCRIPTION_EXPIRING_SOON_DAYS) || 14;

  const subscription = await prisma.subscription.findFirst({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
    },
    orderBy: [{ updated_at: 'desc' }],
    include: {
      plan: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          code: true,
          tier_code: true,
        },
      },
    },
  });

  if (!subscription) {
    const nextPlan = await resolveNextUpgradePlan('FREE');
    return withNextPlanFields(
      {
        subscription_id: null,
        status: null,
        plan_id: null,
        plan_label: 'Free',
        tier_code: 'FREE',
        end_date: null,
        days_until_expiry: null,
        expiring_soon_days: expiringSoonDays,
        header_state: 'expired',
      },
      nextPlan
    );
  }

  const daysUntilExpiry = resolveDaysUntil(subscription.end_date);
  const tierCode = subscription.plan?.tier_code || null;
  const nextPlan = await resolveNextUpgradePlan(tierCode || 'FREE');

  return withNextPlanFields(
    {
      subscription_id: safePublicId(subscription.human_friendly_id, subscription.id),
      status: subscription.status,
      plan_id: safePublicId(subscription.plan?.human_friendly_id, subscription.plan_id),
      plan_label: subscription.plan?.name || null,
      tier_code: tierCode,
      end_date: subscription.end_date || null,
      days_until_expiry: daysUntilExpiry,
      expiring_soon_days: expiringSoonDays,
      header_state: resolveHeaderState({
        status: subscription.status,
        daysUntilExpiry,
        expiringSoonDays,
      }),
    },
    nextPlan
  );
};

const resolvePlatformAdminContact = () => ({
  email: String(env.PLATFORM_ADMIN_EMAIL || '').trim() || null,
  phone: String(env.PLATFORM_ADMIN_PHONE || '').trim() || null,
});

const resolvePlatformBankTransferDetails = () => {
  const accountName = String(env.PLATFORM_BANK_ACCOUNT_NAME || '').trim() || null;
  const bankName = String(env.PLATFORM_BANK_NAME || '').trim() || null;
  const branch = String(env.PLATFORM_BANK_BRANCH || '').trim() || null;
  const accountNumber = String(env.PLATFORM_BANK_ACCOUNT_NUMBER || '').trim() || null;
  const swiftCode = String(env.PLATFORM_BANK_SWIFT_CODE || '').trim() || null;
  const iban = String(env.PLATFORM_BANK_IBAN || '').trim() || null;

  if (!accountName && !bankName && !accountNumber) {
    return null;
  }

  return {
    account_name: accountName,
    bank_name: bankName,
    branch,
    account_number: accountNumber,
    swift_code: swiftCode,
    iban,
  };
};

module.exports = {
  COMMERCIAL_TIER_LADDER,
  resolveDaysUntil,
  resolveHeaderState,
  resolveNextTierCode,
  resolveNextUpgradePlan,
  resolvePlatformAdminContact,
  resolvePlatformBankTransferDetails,
  resolveTenantSubscriptionSummary,
};
