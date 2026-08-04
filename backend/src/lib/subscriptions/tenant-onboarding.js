/**
 * Provision trial subscriptions for newly activated tenants.
 *
 * On activation, tenants receive a Pro trial for 90 days (3 months). When that
 * window ends, the subscription is downgraded to the Free plan.
 *
 * @module lib/subscriptions/tenant-onboarding
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { logger } = require('@lib/logging');
const {
  createSubscriptionPublicId,
  PUBLIC_ID_PREFIXES,
} = require('@lib/subscriptions/constants');

/** Fixed Pro onboarding window (3 months). */
const DEFAULT_TRIAL_DAYS = 90;
/** Prefer Pro for new facility activations; fall back if Pro is unavailable. */
const TRIAL_PLAN_TIER_ORDER = ['PRO', 'ADVANCED', 'BASIC'];

const toPositiveInteger = (value, fallback) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.trunc(parsed);
};

/**
 * @param {Object|null} plan
 * @returns {number}
 */
const resolveTrialDurationDays = (plan = null) => {
  const fromPlan = plan?.extension_json?.trial_duration_days;
  if (fromPlan !== undefined && fromPlan !== null) {
    return toPositiveInteger(fromPlan, DEFAULT_TRIAL_DAYS);
  }

  return DEFAULT_TRIAL_DAYS;
};

const addDays = (baseDate, days) => {
  const date = new Date(baseDate);
  date.setDate(date.getDate() + days);
  return date;
};

const findPlanByTier = async (tierCode) => {
  return prisma.subscription_plan.findFirst({
    where: {
      deleted_at: null,
      tenant_id: null,
      tier_code: tierCode,
    },
    orderBy: { created_at: 'asc' },
  });
};

const findTrialPlan = async () => {
  for (const tierCode of TRIAL_PLAN_TIER_ORDER) {
    const plan = await findPlanByTier(tierCode);
    if (plan) {
      return plan;
    }
  }

  return prisma.subscription_plan.findFirst({
    where: {
      deleted_at: null,
      tenant_id: null,
      tier_code: { not: 'FREE' },
    },
    orderBy: { created_at: 'asc' },
  });
};

const findFreePlan = async () => findPlanByTier('FREE');

const isOnboardingTrialSubscription = (subscription = {}) => {
  if (subscription?.extension_json?.onboarding_trial === true) {
    return true;
  }
  return subscription?.entitlement_snapshot_json?.source === 'tenant_onboarding';
};

/**
 * Downgrade expired onboarding Pro trials to Free for one tenant (or all).
 *
 * @param {string|null} [tenantId]
 * @returns {Promise<number>} Number of subscriptions downgraded
 */
const downgradeExpiredOnboardingTrials = async (tenantId = null) => {
  const now = new Date();
  const where = {
    deleted_at: null,
    status: 'TRIAL',
    end_date: { lt: now },
    ...(tenantId ? { tenant_id: tenantId } : {}),
  };

  const expired = await prisma.subscription.findMany({
    where,
    include: { plan: true },
  });

  const candidates = expired.filter(isOnboardingTrialSubscription);
  if (candidates.length === 0) {
    return 0;
  }

  const freePlan = await findFreePlan();
  if (!freePlan) {
    logger.warn('Free plan missing; cannot downgrade expired onboarding trials.');
    return 0;
  }

  let downgraded = 0;
  for (const subscription of candidates) {
    try {
      await prisma.$transaction(async (tx) => {
        await tx.subscription.update({
          where: { id: subscription.id },
          data: {
            plan_id: freePlan.id,
            status: 'ACTIVE',
            end_date: null,
            change_status: 'NONE',
            change_requested_at: null,
            change_effective_at: null,
            pending_plan_id: null,
            entitlement_snapshot_json: {
              source: 'onboarding_trial_expiry',
              plan_tier_code: freePlan.tier_code || 'FREE',
              previous_plan_tier_code: subscription.plan?.tier_code || 'PRO',
              downgraded_at: now.toISOString(),
            },
            extension_json: {
              ...(subscription.extension_json &&
              typeof subscription.extension_json === 'object'
                ? subscription.extension_json
                : {}),
              onboarding_trial: false,
              downgraded_from_trial_at: now.toISOString(),
              previous_plan_id: subscription.plan_id,
              previous_plan_tier_code: subscription.plan?.tier_code || 'PRO',
            },
          },
        });
      });
      downgraded += 1;
    } catch (error) {
      logger.error('Failed to downgrade expired onboarding trial.', {
        subscription_id: subscription.id,
        tenant_id: subscription.tenant_id,
        error: error?.message || 'unknown_error',
      });
    }
  }

  return downgraded;
};

/**
 * @param {string} tenantId
 * @returns {Promise<Object>}
 */
const provisionTrialSubscription = async (tenantId) => {
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

  // Apply any due Free downgrades before provisioning a fresh Pro trial.
  await downgradeExpiredOnboardingTrials(tenantId);

  const existing = await prisma.subscription.findFirst({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      status: { in: ['ACTIVE', 'TRIAL'] },
      OR: [
        { end_date: null },
        { end_date: { gte: new Date() } },
      ],
    },
    include: {
      plan: true,
      module_subscriptions: {
        where: { deleted_at: null },
        include: { module: true },
      },
    },
  });

  if (existing) {
    return existing;
  }

  const plan = await findTrialPlan();
  if (!plan) {
    throw new HttpError('errors.subscription.plan_not_found', 404);
  }

  const trialDays = resolveTrialDurationDays(plan);
  const startDate = new Date();
  const endDate = addDays(startDate, trialDays);
  const modules = await prisma.module.findMany({
    where: { deleted_at: null },
    orderBy: { slug: 'asc' },
  });

  return prisma.$transaction(async (tx) => {
    const subscription = await tx.subscription.create({
      data: {
        tenant_id: tenantId,
        plan_id: plan.id,
        status: 'TRIAL',
        start_date: startDate,
        end_date: endDate,
        human_friendly_id: createSubscriptionPublicId(PUBLIC_ID_PREFIXES.subscription),
        entitlement_snapshot_json: {
          source: 'tenant_onboarding',
          trial_duration_days: trialDays,
          plan_tier_code: plan.tier_code || 'PRO',
          downgrade_to_tier_code: 'FREE',
        },
        extension_json: {
          onboarding_trial: true,
          trial_duration_days: trialDays,
          downgrade_to_tier_code: 'FREE',
        },
      },
      include: {
        plan: true,
      },
    });

    if (modules.length > 0) {
      await tx.module_subscription.createMany({
        data: modules.map((module) => ({
          module_id: module.id,
          subscription_id: subscription.id,
          is_active: true,
          entitlement_denied: false,
          activated_at: startDate,
          human_friendly_id: createSubscriptionPublicId(PUBLIC_ID_PREFIXES.module_subscription),
        })),
        skipDuplicates: true,
      });
    }

    return tx.subscription.findFirst({
      where: { id: subscription.id },
      include: {
        plan: true,
        module_subscriptions: {
          where: { deleted_at: null },
          include: { module: true },
        },
      },
    });
  });
};

module.exports = {
  DEFAULT_TRIAL_DAYS,
  resolveTrialDurationDays,
  provisionTrialSubscription,
  downgradeExpiredOnboardingTrials,
};
