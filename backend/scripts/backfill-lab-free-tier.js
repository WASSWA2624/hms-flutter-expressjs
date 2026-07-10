/**
 * Ensure Lab Workflows is FREE-tier and included on every catalog plan allowlist.
 *
 * Usage: node scripts/backfill-lab-free-tier.js
 */

require('module-alias/register');
const path = require('path');

try {
  const moduleAlias = require('module-alias');
  const prismaRuntimePath = path.join(
    __dirname,
    '..',
    'node_modules',
    '@prisma',
    'client',
    'runtime'
  );

  moduleAlias.addAliases({
    '@app': path.join(__dirname, '..', 'src', 'app'),
    '@lib': path.join(__dirname, '..', 'src', 'lib'),
    '@config': path.join(__dirname, '..', 'src', 'config'),
    '@middlewares': path.join(__dirname, '..', 'src', 'middlewares'),
    '@logs': path.join(process.cwd(), 'logs'),
    '@websockets': path.join(__dirname, '..', 'src', 'websockets'),
    '@modules': path.join(__dirname, '..', 'src', 'modules'),
    '@prisma/client': path.join(__dirname, '..', 'src', 'prisma', 'client.js'),
  });
  moduleAlias.addAlias('@prisma/client/runtime', prismaRuntimePath);
} catch (error) {
  console.error('Failed to register module aliases:', error);
  process.exit(1);
}

require('dotenv').config();

const prisma = require('@prisma/client');

const PLAN_RANK = Object.freeze({
  FREE: 0,
  BASIC: 1,
  PRO: 2,
  ADVANCED: 3,
  CUSTOM: 4,
});

const text = (value) => String(value || '').trim();

async function main() {
  const lab = await prisma.module.findFirst({
    where: {
      deleted_at: null,
      slug: 'lab-workflows',
    },
  });

  if (!lab) {
    console.log(
      '[backfill-lab-free-tier] lab-workflows module not found; nothing to do'
    );
    return;
  }

  const labPublicId = text(lab.human_friendly_id) || text(lab.id);

  await prisma.module.update({
    where: { id: lab.id },
    data: {
      minimum_plan_tier_code: 'FREE',
      entitlement_policy_json: {
        ...(lab.entitlement_policy_json &&
        typeof lab.entitlement_policy_json === 'object'
          ? lab.entitlement_policy_json
          : {}),
        minimum_plan_tier_code: 'FREE',
      },
    },
  });

  const plans = await prisma.subscription_plan.findMany({
    where: { deleted_at: null },
    select: {
      id: true,
      code: true,
      tier_code: true,
      extension_json: true,
    },
  });

  let updatedPlans = 0;
  for (const plan of plans) {
    const tierRank = PLAN_RANK[String(plan.tier_code || '').toUpperCase()];
    if (!Number.isFinite(tierRank) || tierRank < PLAN_RANK.FREE) {
      continue;
    }

    const extension =
      plan.extension_json && typeof plan.extension_json === 'object'
        ? { ...plan.extension_json }
        : {};
    const allowedModules =
      extension.allowed_modules && typeof extension.allowed_modules === 'object'
        ? { ...extension.allowed_modules }
        : {};
    const included = Array.isArray(allowedModules.included)
      ? [...allowedModules.included]
      : [];

    const alreadyIncluded = included.some(
      (entry) =>
        text(entry) === labPublicId ||
        text(entry) === text(lab.id) ||
        text(entry).toLowerCase() === 'lab-workflows' ||
        text(entry).toLowerCase() === 'lab_workflows'
    );

    if (alreadyIncluded) {
      continue;
    }

    included.push(labPublicId);

    await prisma.subscription_plan.update({
      where: { id: plan.id },
      data: {
        extension_json: {
          ...extension,
          allowed_modules: {
            ...allowedModules,
            included,
          },
        },
      },
    });
    updatedPlans += 1;
  }

  console.log(
    `[backfill-lab-free-tier] lab=${labPublicId} plans_updated=${updatedPlans}`
  );

  const subscriptionUpdate = await prisma.module_subscription.updateMany({
    where: {
      module_id: lab.id,
      deleted_at: null,
      OR: [{ entitlement_denied: true }, { is_active: false }],
    },
    data: {
      is_active: true,
      entitlement_denied: false,
      entitlement_denial_reason: null,
    },
  });
  console.log(
    `[backfill-lab-free-tier] module_subscriptions_activated=${subscriptionUpdate.count}`
  );
}

main()
  .catch((error) => {
    console.error('[backfill-lab-free-tier] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (typeof prisma.$disconnect === 'function') {
      await prisma.$disconnect();
    }
  });
