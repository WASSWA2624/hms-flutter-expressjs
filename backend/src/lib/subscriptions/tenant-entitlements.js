/**
 * Resolve active module entitlements for a tenant subscription.
 *
 * @module lib/subscriptions/tenant-entitlements
 */

const prisma = require('@prisma/client');
const {
  downgradeExpiredOnboardingTrials,
} = require('@lib/subscriptions/tenant-onboarding');

const serializeEntitlement = (record = {}) => {
  const module = record.module || {};
  const subscription = record.subscription || {};
  const plan = subscription.plan || {};
  const allowedPermissions = Array.isArray(plan.extension_json?.allowed_permissions)
    ? plan.extension_json.allowed_permissions
    : [];

  return {
    code: module.code || module.slug || null,
    module_code: module.code || null,
    module_slug: module.slug || null,
    module_id: module.id || record.module_id || null,
    is_active: Boolean(record.is_active) && !record.entitlement_denied,
    entitlement_denied: Boolean(record.entitlement_denied),
    subscription_status: subscription.status || null,
    license_status: subscription.status || null,
    plan_tier_code: plan.tier_code || null,
    allowed_permissions: allowedPermissions,
  };
};

/**
 * @param {string} tenantId
 * @returns {Promise<Array<Object>>}
 */
const resolveTenantModuleEntitlements = async (tenantId) => {
  if (!tenantId) {
    return [];
  }

  // Lazy expiry: Pro onboarding trials become Free after end_date.
  // Also apply prepaid plan changes that are due.
  await downgradeExpiredOnboardingTrials(tenantId).catch(() => 0);
  const {
    applyDueScheduledPlanChanges,
  } = require('@lib/subscriptions/subscription-payment-request');
  await applyDueScheduledPlanChanges(tenantId).catch(() => 0);

  const now = new Date();
  const records = await prisma.module_subscription.findMany({
    where: {
      deleted_at: null,
      subscription: {
        tenant_id: tenantId,
        deleted_at: null,
        status: { in: ['ACTIVE', 'TRIAL'] },
        OR: [
          { end_date: null },
          { end_date: { gte: now } },
        ],
      },
    },
    include: {
      module: true,
      subscription: {
        include: {
          plan: true,
        },
      },
    },
    orderBy: [{ module: { slug: 'asc' } }],
  });

  return records
    .map(serializeEntitlement)
    .filter((entry) => entry.module_slug || entry.code);
};

module.exports = {
  resolveTenantModuleEntitlements,
  serializeEntitlement,
};
