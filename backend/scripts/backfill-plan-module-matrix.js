/**
 * Backfill commercial plan → module packaging matrix into an existing DB.
 *
 * - Upserts platform + commercial modules from plan-module-matrix
 * - Sets module.minimum_plan_tier_code from the matrix
 * - Rewrites subscription_plan.extension_json.allowed_modules.included by tier
 *   (merges; preserves other extension_json fields)
 * - Activates module_subscription rows for eligible modules on ACTIVE/TRIAL subs
 * - Migrates legacy billing-insurance allowlist entries to billing-payments +
 *   insurance-claims
 *
 * Usage: node scripts/backfill-plan-module-matrix.js
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

try {
  const { registerAllModuleAliases } = require('@lib/aliases');
  registerAllModuleAliases();
} catch (error) {
  console.warn('Failed to register module-scoped aliases:', error.message);
}

require('dotenv').config();

const prisma = require('@prisma/client');
const {
  COMMERCIAL_MODULE_MATRIX,
  PLATFORM_INFRASTRUCTURE_MODULES,
  isEligibleForTier,
  modulesForPlanTier,
} = require('../src/lib/subscriptions/plan-module-matrix');
const {
  PLAN_PERMISSION_CAPS,
} = require('../src/lib/subscriptions/subscription-permission-caps');
const {
  clearModuleEntitlementCaches,
} = require('../src/middlewares/module-entitlement.middleware');

const text = (value) => String(value || '').trim();

const publicId = (record) =>
  text(record?.human_friendly_id) || text(record?.id) || null;

const ALL_MODULE_DEFINITIONS = [
  ...PLATFORM_INFRASTRUCTURE_MODULES.map((entry) => ({
    ...entry,
    is_add_on: false,
  })),
  ...COMMERCIAL_MODULE_MATRIX.map((entry) => ({
    ...entry,
    is_add_on: false,
  })),
];

async function upsertCatalogModules() {
  const bySlug = new Map();
  let upserted = 0;

  for (const definition of ALL_MODULE_DEFINITIONS) {
    // Prefer exact slug; for lite inventory also adopt legacy inventory-procurement row.
    const slugCandidates = [definition.slug];
    if (definition.slug === 'inventory-procurement-lite') {
      slugCandidates.push('inventory-procurement');
    }

    let existing = null;
    for (const slug of slugCandidates) {
      existing = await prisma.module.findFirst({
        where: {
          deleted_at: null,
          slug,
        },
      });
      if (existing) break;
    }

    // Avoid unique name collisions when creating a new slug beside a legacy row.
    if (!existing) {
      existing = await prisma.module.findFirst({
        where: {
          deleted_at: null,
          name: definition.name,
        },
      });
    }

    const payload = {
      name: definition.name,
      slug: definition.slug,
      description:
        definition.description || `${definition.name} catalog module`,
      module_group: definition.module_group,
      minimum_plan_tier_code: definition.minimum_plan_tier_code,
      is_add_on: Boolean(definition.is_add_on),
      add_on_price: definition.add_on_price || null,
      add_on_billing_cycle: definition.add_on_billing_cycle || null,
      entitlement_policy_json: {
        minimum_plan_tier_code: definition.minimum_plan_tier_code,
      },
      extension_json: definition.extension_json || null,
    };

    let record;
    if (existing && existing.slug === definition.slug) {
      record = await prisma.module.update({
        where: { id: existing.id },
        data: {
          ...payload,
          entitlement_policy_json: {
            ...(existing.entitlement_policy_json &&
            typeof existing.entitlement_policy_json === 'object'
              ? existing.entitlement_policy_json
              : {}),
            minimum_plan_tier_code: definition.minimum_plan_tier_code,
          },
          extension_json: definition.extension_json
            ? {
                ...(existing.extension_json &&
                typeof existing.extension_json === 'object'
                  ? existing.extension_json
                  : {}),
                ...definition.extension_json,
              }
            : existing.extension_json,
        },
      });
    } else if (
      existing &&
      definition.slug === 'inventory-procurement-lite' &&
      existing.slug === 'inventory-procurement'
    ) {
      record = await prisma.module.update({
        where: { id: existing.id },
        data: {
          ...payload,
          slug: definition.slug,
          entitlement_policy_json: {
            ...(existing.entitlement_policy_json &&
            typeof existing.entitlement_policy_json === 'object'
              ? existing.entitlement_policy_json
              : {}),
            minimum_plan_tier_code: definition.minimum_plan_tier_code,
          },
          extension_json: definition.extension_json
            ? {
                ...(existing.extension_json &&
                typeof existing.extension_json === 'object'
                  ? existing.extension_json
                  : {}),
                ...definition.extension_json,
              }
            : existing.extension_json,
        },
      });
    } else {
      // Name collision with a different slug (e.g. legacy `insurance`):
      // free the name, then create the canonical catalog row.
      if (existing && existing.slug !== definition.slug) {
        const legacyName = `${existing.name} (Legacy Path)`.slice(0, 120);
        await prisma.module.update({
          where: { id: existing.id },
          data: {
            name: legacyName,
            extension_json: {
              ...(existing.extension_json &&
              typeof existing.extension_json === 'object'
                ? existing.extension_json
                : {}),
              superseded_by_slug: definition.slug,
              deprecated: true,
            },
          },
        });
      }

      const bySlugAgain = await prisma.module.findFirst({
        where: { deleted_at: null, slug: definition.slug },
      });
      if (bySlugAgain) {
        record = await prisma.module.update({
          where: { id: bySlugAgain.id },
          data: payload,
        });
      } else {
        record = await prisma.module.create({
          data: payload,
        });
      }
    }

    bySlug.set(definition.slug, record);
    upserted += 1;
  }

  return { bySlug, upserted };
}

function resolveIncludedPublicIds(tierCode, modulesBySlug, { includeAll = false } = {}) {
  const selected = [];
  const seen = new Set();

  for (const definition of ALL_MODULE_DEFINITIONS) {
    const isPlatform = Boolean(
      definition.extension_json?.is_platform_infrastructure
    );
    const isLegacy = Boolean(definition.extension_json?.deprecated);
    if (isLegacy) {
      continue;
    }
    if (
      !includeAll &&
      !isPlatform &&
      !isEligibleForTier(tierCode, definition.minimum_plan_tier_code)
    ) {
      continue;
    }
    const record = modulesBySlug.get(definition.slug);
    const id = publicId(record);
    if (!id || seen.has(id)) {
      continue;
    }
    seen.add(id);
    selected.push(id);
  }

  return selected;
}

function expandLegacyAllowlistTokens(included, modulesBySlug) {
  const next = [...included];
  const seen = new Set(included.map((entry) => text(entry).toLowerCase()));

  const pushId = (record) => {
    const id = publicId(record);
    if (!id) return;
    const key = id.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    next.push(id);
  };

  const hasLegacyBilling = included.some((entry) => {
    const value = text(entry).toLowerCase();
    return (
      value === 'billing-insurance' ||
      value === 'billing_insurance' ||
      value.includes('billing-insurance')
    );
  });

  if (hasLegacyBilling) {
    pushId(modulesBySlug.get('billing-payments'));
    pushId(modulesBySlug.get('insurance-claims'));
  }

  const hasLegacyInventory = included.some((entry) => {
    const value = text(entry).toLowerCase();
    return (
      value === 'inventory-procurement' ||
      value === 'inventory_procurement'
    );
  });

  if (hasLegacyInventory) {
    pushId(modulesBySlug.get('inventory-procurement-lite'));
  }

  return next;
}

async function rewritePlanAllowlists(modulesBySlug) {
  const plans = await prisma.subscription_plan.findMany({
    where: { deleted_at: null },
  });

  let updated = 0;
  for (const plan of plans) {
    const extension =
      plan.extension_json && typeof plan.extension_json === 'object'
        ? { ...plan.extension_json }
        : {};
    const includeAll = Boolean(extension.includes_all_modules);
    const matrixIds = resolveIncludedPublicIds(plan.tier_code, modulesBySlug, {
      includeAll,
    });

    const allowedModules =
      extension.allowed_modules && typeof extension.allowed_modules === 'object'
        ? { ...extension.allowed_modules }
        : {};

    const previousIncluded = Array.isArray(allowedModules.included)
      ? allowedModules.included.map(text).filter(Boolean)
      : [];

    // Prefer matrix defaults; keep any extra custom IDs already on the plan.
    const merged = new Set([
      ...matrixIds,
      ...expandLegacyAllowlistTokens(previousIncluded, modulesBySlug),
    ]);

    // Drop pure legacy tokens when replacements exist.
    for (const token of [...merged]) {
      const lower = token.toLowerCase();
      if (
        lower === 'billing-insurance' ||
        lower === 'billing_insurance' ||
        lower === 'inventory-procurement' ||
        lower === 'inventory_procurement'
      ) {
        merged.delete(token);
      }
    }

    const included = [...merged];
    const tierCode = String(plan.tier_code || '')
      .trim()
      .toUpperCase();
    // Keep CUSTOM explicit caps when present; refresh shipped tiers from code so
    // new domains (e.g. accounts:*) appear without a full reseed.
    const shippedCaps = PLAN_PERMISSION_CAPS[tierCode];
    const previousCaps = Array.isArray(extension.allowed_permissions)
      ? extension.allowed_permissions
      : [];
    const nextAllowedPermissions =
      tierCode === 'CUSTOM' && previousCaps.length > 0
        ? previousCaps
        : shippedCaps || previousCaps;

    await prisma.subscription_plan.update({
      where: { id: plan.id },
      data: {
        extension_json: {
          ...extension,
          allowed_permissions: nextAllowedPermissions,
          allowed_modules: {
            ...allowedModules,
            included,
          },
        },
      },
    });
    updated += 1;
  }

  return updated;
}

async function activateEligibleModuleSubscriptions(modulesBySlug) {
  const subscriptions = await prisma.subscription.findMany({
    where: {
      deleted_at: null,
      status: { in: ['ACTIVE', 'TRIAL'] },
    },
    include: { plan: true },
  });

  let activated = 0;
  let created = 0;

  for (const subscription of subscriptions) {
    const tierCode = subscription.plan?.tier_code || 'FREE';
    const includeAll = Boolean(
      subscription.plan?.extension_json?.includes_all_modules
    );
    const eligibleDefinitions = ALL_MODULE_DEFINITIONS.filter((definition) => {
      if (definition.extension_json?.deprecated) {
        return false;
      }
      if (definition.extension_json?.is_platform_infrastructure) {
        return true;
      }
      if (includeAll) {
        return true;
      }
      return isEligibleForTier(tierCode, definition.minimum_plan_tier_code);
    });

    for (const definition of eligibleDefinitions) {
      const moduleRecord = modulesBySlug.get(definition.slug);
      if (!moduleRecord) continue;

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
          activated_at: new Date(),
        },
      });
      created += 1;
    }
  }

  return { activated, created };
}

async function main() {
  console.log('[backfill-plan-module-matrix] starting');
  console.log(
    `[backfill-plan-module-matrix] matrix_modules=${ALL_MODULE_DEFINITIONS.length} free_defaults=${
      modulesForPlanTier('FREE', { includeLegacyAliases: false }).length
    }`
  );

  const { bySlug, upserted } = await upsertCatalogModules();
  console.log(`[backfill-plan-module-matrix] modules_upserted=${upserted}`);

  const plansUpdated = await rewritePlanAllowlists(bySlug);
  console.log(`[backfill-plan-module-matrix] plans_updated=${plansUpdated}`);

  const { activated, created } = await activateEligibleModuleSubscriptions(bySlug);
  console.log(
    `[backfill-plan-module-matrix] module_subscriptions activated=${activated} created=${created}`
  );

  clearModuleEntitlementCaches();
  console.log('[backfill-plan-module-matrix] entitlement caches cleared');
}

main()
  .catch((error) => {
    console.error('[backfill-plan-module-matrix] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (typeof prisma.$disconnect === 'function') {
      await prisma.$disconnect();
    }
  });
