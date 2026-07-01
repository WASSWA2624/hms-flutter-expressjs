/**
 * Resolve active module entitlements for a tenant subscription.
 *
 * @module lib/subscriptions/tenant-entitlements
 */

const prisma = require('@prisma/client');

const serializeEntitlement = (record = {}) => {
  const module = record.module || {};
  const subscription = record.subscription || {};

  return {
    code: module.code || module.slug || null,
    module_code: module.code || null,
    module_slug: module.slug || null,
    module_id: module.id || record.module_id || null,
    is_active: Boolean(record.is_active) && !record.entitlement_denied,
    entitlement_denied: Boolean(record.entitlement_denied),
    subscription_status: subscription.status || null,
    license_status: subscription.status || null,
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
      subscription: true,
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
