/**
 * Resolve tenant subscription summary for shell header CTA state.
 *
 * @module lib/subscriptions/tenant-subscription-summary
 */

const prisma = require('@prisma/client');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const env = require('@config/env');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

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
    return {
      subscription_id: null,
      status: null,
      plan_id: null,
      plan_label: null,
      tier_code: null,
      end_date: null,
      days_until_expiry: null,
      expiring_soon_days: expiringSoonDays,
      header_state: 'expired',
    };
  }

  const daysUntilExpiry = resolveDaysUntil(subscription.end_date);

  return {
    subscription_id: safePublicId(subscription.human_friendly_id, subscription.id),
    status: subscription.status,
    plan_id: safePublicId(subscription.plan?.human_friendly_id, subscription.plan_id),
    plan_label: subscription.plan?.name || null,
    tier_code: subscription.plan?.tier_code || null,
    end_date: subscription.end_date || null,
    days_until_expiry: daysUntilExpiry,
    expiring_soon_days: expiringSoonDays,
    header_state: resolveHeaderState({
      status: subscription.status,
      daysUntilExpiry,
      expiringSoonDays,
    }),
  };
};

const resolvePlatformAdminContact = () => ({
  email: String(env.PLATFORM_ADMIN_EMAIL || '').trim() || null,
  phone: String(env.PLATFORM_ADMIN_PHONE || '').trim() || null,
});

module.exports = {
  resolveDaysUntil,
  resolveHeaderState,
  resolvePlatformAdminContact,
  resolveTenantSubscriptionSummary,
};
