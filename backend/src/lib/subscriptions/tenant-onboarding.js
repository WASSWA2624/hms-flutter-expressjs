/**
 * Provision trial subscriptions for newly activated tenants.
 *
 * @module lib/subscriptions/tenant-onboarding
 */

const prisma = require('@prisma/client');
const env = require('@config/env');
const { HttpError } = require('@lib/errors');
const {
  createSubscriptionPublicId,
  PUBLIC_ID_PREFIXES,
} = require('@lib/subscriptions/constants');

const DEFAULT_TRIAL_DAYS = 90;
const TRIAL_PLAN_TIER_ORDER = ['ADVANCED', 'PRO', 'CUSTOM', 'BASIC'];

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

  return toPositiveInteger(env.TRIAL_DURATION_DAYS, DEFAULT_TRIAL_DAYS);
};

const addDays = (baseDate, days) => {
  const date = new Date(baseDate);
  date.setDate(date.getDate() + days);
  return date;
};

const findTrialPlan = async () => {
  for (const tierCode of TRIAL_PLAN_TIER_ORDER) {
    const plan = await prisma.subscription_plan.findFirst({
      where: {
        deleted_at: null,
        tenant_id: null,
        tier_code: tierCode,
      },
      orderBy: { created_at: 'asc' },
    });
    if (plan) {
      return plan;
    }
  }

  return prisma.subscription_plan.findFirst({
    where: {
      deleted_at: null,
      tenant_id: null,
    },
    orderBy: { created_at: 'asc' },
  });
};

/**
 * @param {string} tenantId
 * @returns {Promise<Object>}
 */
const provisionTrialSubscription = async (tenantId) => {
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

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
          plan_tier_code: plan.tier_code || null,
        },
        extension_json: {
          onboarding_trial: true,
          trial_duration_days: trialDays,
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
};
