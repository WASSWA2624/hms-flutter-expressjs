/**
 * Keep module_subscription rows aligned with a subscription's plan tier.
 *
 * @module lib/subscriptions/sync-subscription-module-entitlements
 */

const prisma = require('@prisma/client');
const {
  COMMERCIAL_MODULE_MATRIX,
  PLATFORM_INFRASTRUCTURE_MODULES,
  isEligibleForTier,
} = require('@lib/subscriptions/plan-module-matrix');
const {
  createSubscriptionPublicId,
  PUBLIC_ID_PREFIXES,
} = require('@lib/subscriptions/constants');

const ALL_MODULE_DEFINITIONS = [
  ...PLATFORM_INFRASTRUCTURE_MODULES,
  ...COMMERCIAL_MODULE_MATRIX,
];

/**
 * Activate/create eligible module entitlements for one subscription.
 *
 * @param {string} subscriptionId
 * @param {{ tierCode?: string|null, includeAllModules?: boolean }=} options
 * @returns {Promise<{ activated: number, created: number, deactivated: number }>}
 */
const syncSubscriptionModuleEntitlements = async (
  subscriptionId,
  options = {}
) => {
  if (!subscriptionId) {
    return { activated: 0, created: 0, deactivated: 0 };
  }

  const subscription = await prisma.subscription.findFirst({
    where: { id: subscriptionId, deleted_at: null },
    include: { plan: true },
  });

  if (!subscription) {
    return { activated: 0, created: 0, deactivated: 0 };
  }

  const tierCode =
    options.tierCode || subscription.plan?.tier_code || 'FREE';
  const includeAll =
    options.includeAllModules === true ||
    Boolean(subscription.plan?.extension_json?.includes_all_modules);

  const modules = await prisma.module.findMany({
    where: { deleted_at: null },
    select: {
      id: true,
      slug: true,
      extension_json: true,
      minimum_plan_tier_code: true,
    },
  });

  const bySlug = new Map(
    modules
      .filter((entry) => entry.slug)
      .map((entry) => [String(entry.slug).trim().toLowerCase(), entry])
  );

  const eligibleSlugs = new Set();
  for (const definition of ALL_MODULE_DEFINITIONS) {
    if (definition.extension_json?.deprecated) {
      continue;
    }
    const isPlatform = Boolean(
      definition.extension_json?.is_platform_infrastructure
    );
    if (
      !includeAll &&
      !isPlatform &&
      !isEligibleForTier(tierCode, definition.minimum_plan_tier_code)
    ) {
      continue;
    }
    eligibleSlugs.add(String(definition.slug).trim().toLowerCase());
  }

  let activated = 0;
  let created = 0;
  let deactivated = 0;
  const now = new Date();

  for (const slug of eligibleSlugs) {
    const moduleRecord = bySlug.get(slug);
    if (!moduleRecord) {
      continue;
    }

    const existing = await prisma.module_subscription.findFirst({
      where: {
        subscription_id: subscription.id,
        module_id: moduleRecord.id,
        deleted_at: null,
      },
    });

    if (existing) {
      if (existing.is_active && !existing.entitlement_denied) {
        continue;
      }
      await prisma.module_subscription.update({
        where: { id: existing.id },
        data: {
          is_active: true,
          entitlement_denied: false,
          entitlement_denial_reason: null,
          deactivated_at: null,
          activated_at: existing.activated_at || now,
        },
      });
      activated += 1;
      continue;
    }

    await prisma.module_subscription.create({
      data: {
        subscription_id: subscription.id,
        module_id: moduleRecord.id,
        is_active: true,
        entitlement_denied: false,
        activated_at: now,
        human_friendly_id: createSubscriptionPublicId(
          PUBLIC_ID_PREFIXES.module_subscription
        ),
      },
    });
    created += 1;
  }

  // Soft-disable modules that are no longer eligible for this plan tier.
  const existingRows = await prisma.module_subscription.findMany({
    where: {
      subscription_id: subscription.id,
      deleted_at: null,
      is_active: true,
    },
    include: {
      module: {
        select: { slug: true },
      },
    },
  });

  for (const row of existingRows) {
    const slug = String(row.module?.slug || '')
      .trim()
      .toLowerCase();
    if (!slug || eligibleSlugs.has(slug)) {
      continue;
    }
    await prisma.module_subscription.update({
      where: { id: row.id },
      data: {
        is_active: false,
        entitlement_denied: true,
        entitlement_denial_reason: 'plan_tier_not_eligible',
        deactivated_at: now,
      },
    });
    deactivated += 1;
  }

  return { activated, created, deactivated };
};

module.exports = {
  syncSubscriptionModuleEntitlements,
};
