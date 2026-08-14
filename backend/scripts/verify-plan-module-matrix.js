/**
 * Quick verification of plan → module matrix backfill state.
 * Usage: node scripts/verify-plan-module-matrix.js
 */
require('module-alias/register');
const path = require('path');

try {
  const moduleAlias = require('module-alias');
  moduleAlias.addAliases({
    '@config': path.join(__dirname, '..', 'src', 'config'),
    '@lib': path.join(__dirname, '..', 'src', 'lib'),
    '@prisma/client': path.join(__dirname, '..', 'src', 'prisma', 'client.js'),
  });
  moduleAlias.addAlias(
    '@prisma/client/runtime',
    path.join(__dirname, '..', 'node_modules', '@prisma', 'client', 'runtime')
  );
} catch (error) {
  console.error(error);
  process.exit(1);
}

// Loads the environment-specific file (.env.development / .env.production / .env.test)
// via the centralized resolver in @config/env, instead of a bare dotenv.config() that
// only ever reads a plain .env - matters if this check is ever run in production.
require('@config/env');
const prisma = require('@prisma/client');
const {
  modulesForPlanTier,
} = require('../src/lib/subscriptions/plan-module-matrix');

async function main() {
  const plans = await prisma.subscription_plan.findMany({
    where: { deleted_at: null },
    select: { code: true, tier_code: true, extension_json: true },
    orderBy: { code: 'asc' },
  });

  for (const plan of plans) {
    const included = plan.extension_json?.allowed_modules?.included || [];
    const expected = modulesForPlanTier(plan.tier_code, {
      includeLegacyAliases: false,
    }).length;
    console.log(
      `${plan.code}\t${plan.tier_code}\tincluded=${included.length}\tmatrix_commercial=${expected}`
    );
  }

  const keySlugs = [
    'billing-payments',
    'insurance-claims',
    'developer-tools',
    'subscription-controls',
    'lab-workflows',
    'inventory-procurement-lite',
    'platform-identity',
  ];
  const mods = await prisma.module.findMany({
    where: { deleted_at: null, slug: { in: keySlugs } },
    select: {
      slug: true,
      minimum_plan_tier_code: true,
      extension_json: true,
    },
    orderBy: { slug: 'asc' },
  });
  console.log('--- modules ---');
  for (const mod of mods) {
    console.log(
      `${mod.slug}\t${mod.minimum_plan_tier_code}\tplatform=${Boolean(
        mod.extension_json?.is_platform_infrastructure
      )}`
    );
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (typeof prisma.$disconnect === 'function') {
      await prisma.$disconnect();
    }
  });
