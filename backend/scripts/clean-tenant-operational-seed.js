#!/usr/bin/env node
/**
 * Report and, on explicit confirmation, remove seeded operational rows from
 * tenants that received them.
 *
 * Step 04 established that tenant creation writes no operational data, and that
 * the operational rows sitting in real tenants are genuine user activity. So
 * this script is deliberately conservative: by default it removes only rows the
 * demo seeder marked as its own (`extension_json.seed_pack`), never rows a
 * person created. Clearing unmarked rows is possible but has to be asked for,
 * and requires acknowledging that a backup exists.
 *
 * Dry-run is the default. Nothing is deleted without `--yes`.
 * Production is blocked by the shared demo-safety guard.
 *
 * Usage:
 *   node scripts/clean-tenant-operational-seed.js                     # dry-run, every tenant
 *   node scripts/clean-tenant-operational-seed.js --tenant=<id|slug>  # dry-run, one tenant
 *   node scripts/clean-tenant-operational-seed.js --json              # machine-readable report
 *   node scripts/clean-tenant-operational-seed.js --yes               # delete seed-marked rows
 *   node scripts/clean-tenant-operational-seed.js --yes --include-unmarked --i-have-a-backup
 *
 * @module scripts/clean-tenant-operational-seed
 */

require('module-alias/register');

const path = require('path');

const BACKEND_ROOT = path.join(__dirname, '..');

try {
  const moduleAlias = require('module-alias');
  moduleAlias.addAliases({
    '@app': path.join(BACKEND_ROOT, 'src', 'app'),
    '@lib': path.join(BACKEND_ROOT, 'src', 'lib'),
    '@config': path.join(BACKEND_ROOT, 'src', 'config'),
    '@middlewares': path.join(BACKEND_ROOT, 'src', 'middlewares'),
    '@logs': path.join(BACKEND_ROOT, 'logs'),
    '@websockets': path.join(BACKEND_ROOT, 'src', 'websockets'),
    '@modules': path.join(BACKEND_ROOT, 'src', 'modules'),
    '@prisma/client': path.join(BACKEND_ROOT, 'src', 'prisma', 'client.js'),
  });
  moduleAlias.addAlias(
    '@prisma/client/runtime',
    path.join(BACKEND_ROOT, 'node_modules', '@prisma', 'client', 'runtime')
  );
} catch (error) {
  console.error('Failed to register cleanup script aliases:', error);
  process.exit(1);
}

const prisma = require('@prisma/client');
const { assertDemoTaskAllowed } = require('./demo-safety');
const { HMS_SEED_MODEL_ORDER } = require('@config/constants');
const { DEMO_SEED_PACK } = require('./seeders/seed-runtime');
const { DEMO_TENANTS } = require('./seeders/seed-catalog');
const {
  listForbiddenTables,
  findTenantOperationalRows,
} = require('@lib/tenant/tenant-initialization-policy');

const { Prisma } = require('.prisma/client');

const parseArgs = (argv) => {
  const args = {
    tenant: null,
    confirm: false,
    includeUnmarked: false,
    backupAcknowledged: false,
    json: false,
  };

  for (const raw of argv.slice(2)) {
    if (raw === '--yes') args.confirm = true;
    else if (raw === '--dry-run') args.confirm = false;
    else if (raw === '--include-unmarked') args.includeUnmarked = true;
    else if (raw === '--i-have-a-backup') args.backupAcknowledged = true;
    else if (raw === '--json') args.json = true;
    else if (raw.startsWith('--tenant=')) args.tenant = raw.slice('--tenant='.length).trim();
  }

  return args;
};

const modelsByName = new Map(Prisma.dmmf.datamodel.models.map((model) => [model.name, model]));

const hasField = (table, field) =>
  Boolean(modelsByName.get(table)?.fields.some((entry) => entry.name === field));

/**
 * Delete-safe ordering: children before parents.
 *
 * `HMS_SEED_MODEL_ORDER` lists models parents-first for seeding, so reversing it
 * gives an order that respects foreign keys on the way out. Anything the list
 * does not mention is deleted first, since unlisted models are leaves.
 */
const deletionOrder = (tables) => {
  const seedOrder = new Map(HMS_SEED_MODEL_ORDER.map((name, index) => [name, index]));
  return [...tables].sort((a, b) => {
    const rankA = seedOrder.has(a) ? seedOrder.get(a) : -1;
    const rankB = seedOrder.has(b) ? seedOrder.get(b) : -1;
    return rankB - rankA;
  });
};

/**
 * Where-clause restricting a table to one tenant.
 *
 * Tenant-scoped tables filter on `tenant_id`; facility-only tables filter on
 * that tenant's facility ids. Returns null when neither applies, so the caller
 * skips the table rather than issuing an unscoped query.
 */
const tenantScopeWhere = (table, tenantId, facilityIds) => {
  if (hasField(table, 'tenant_id')) return { tenant_id: tenantId };
  if (hasField(table, 'facility_id')) {
    if (facilityIds.length === 0) return null;
    return { facility_id: { in: facilityIds } };
  }
  return null;
};

/**
 * Rows the demo seeder marked as its own.
 *
 * Only models carrying `extension_json` get a marker, which is roughly a
 * quarter of the operational tables - `admission`, `invoice`, `appointment` and
 * many others have nowhere to put one. The marker is therefore evidence, not a
 * complete filter; `isDemoTenant` is what actually decides bulk removal.
 */
const seedMarkerWhere = (table) => {
  if (!hasField(table, 'extension_json')) return null;
  return {
    extension_json: {
      path: '$.seed_pack',
      equals: DEMO_SEED_PACK,
    },
  };
};

const DEMO_TENANT_SLUGS = new Set(
  DEMO_TENANTS.map((scenario) => String(scenario.slug || '').toLowerCase()).filter(Boolean)
);

/**
 * Is this whole tenant a seeder-owned demo workspace?
 *
 * The demo packs only ever write into the fixed `DEMO_TENANTS` scenarios - they
 * never attach rows to a tenant a person created (established in step 04). So a
 * demo tenant's operational rows are seeded by definition, marker or not, and a
 * non-demo tenant's unmarked rows are real data.
 */
const isDemoTenant = (tenant) =>
  DEMO_TENANT_SLUGS.has(String(tenant.slug || '').toLowerCase());

const resolveTenants = async (identifier) => {
  if (!identifier) {
    return prisma.tenant.findMany({
      orderBy: { created_at: 'asc' },
      select: { id: true, name: true, slug: true, human_friendly_id: true },
    });
  }

  const tenant = await prisma.tenant.findFirst({
    where: {
      OR: [
        { id: identifier },
        { slug: identifier.toLowerCase() },
        { human_friendly_id: identifier },
      ],
    },
    select: { id: true, name: true, slug: true, human_friendly_id: true },
  });

  if (!tenant) throw new Error(`No tenant matched "${identifier}".`);
  return [tenant];
};

/**
 * Build the per-tenant plan: which forbidden tables hold rows, how many are
 * seed-marked, and how many would actually be deleted under the current flags.
 */
const planForTenant = async (tenant, { includeUnmarked }) => {
  const facilityIds = (
    await prisma.facility.findMany({
      where: { tenant_id: tenant.id },
      select: { id: true },
    })
  ).map((facility) => facility.id);

  const demoTenant = isDemoTenant(tenant);
  const present = await findTenantOperationalRows(tenant.id, { client: prisma });
  const presentByTable = new Map(present.map((entry) => [entry.table, entry.rows]));

  const targets = [];

  for (const table of listForbiddenTables()) {
    const total = presentByTable.get(table) || 0;
    if (total === 0) continue;

    const delegate = prisma[table];
    if (!delegate || typeof delegate.count !== 'function') continue;

    const scope = tenantScopeWhere(table, tenant.id, facilityIds);
    if (!scope) continue;

    const marker = seedMarkerWhere(table);
    const seeded = marker
      ? await delegate.count({ where: { ...scope, ...marker } })
      : 0;

    // A demo tenant is seeder-owned end to end, so everything in it is
    // removable. Elsewhere only marked rows are, unless the caller insists.
    const deletable = demoTenant || includeUnmarked ? total : seeded;

    targets.push({
      table,
      total,
      seeded,
      unmarked: total - seeded,
      deletable,
      markerSupported: Boolean(marker),
    });
  }

  return {
    tenant,
    demo_tenant: demoTenant,
    facility_ids: facilityIds,
    targets: targets.sort((a, b) => b.deletable - a.deletable || a.table.localeCompare(b.table)),
  };
};

/**
 * Delete the planned rows for one tenant, children first.
 *
 * Idempotent: a second run finds nothing left to delete and reports zero.
 */
const applyPlan = async (plan, { includeUnmarked }) => {
  const facilityIds = plan.facility_ids;
  const byTable = new Map(plan.targets.map((target) => [target.table, target]));
  const deleted = [];

  for (const table of deletionOrder(byTable.keys())) {
    const target = byTable.get(table);
    if (!target || target.deletable === 0) continue;

    const scope = tenantScopeWhere(table, plan.tenant.id, facilityIds);
    if (!scope) continue;

    const marker = seedMarkerWhere(table);
    const takeEverything = plan.demo_tenant || includeUnmarked;
    const where = takeEverything ? scope : { ...scope, ...marker };

    const result = await prisma[table].deleteMany({ where });
    if (result.count > 0) {
      deleted.push({ table, rows: result.count });
    }
  }

  return deleted;
};

const printPlan = (plan, { includeUnmarked }) => {
  const { tenant, targets } = plan;
  const kind = plan.demo_tenant ? 'demo tenant - seeder owned' : 'real tenant';
  const label = `${tenant.name} (${tenant.human_friendly_id || tenant.id}) [${kind}]`;

  if (targets.length === 0) {
    console.log(`\n${label}\n    clean - no operational rows`);
    return;
  }

  const totals = targets.reduce(
    (acc, target) => ({
      total: acc.total + target.total,
      seeded: acc.seeded + target.seeded,
      deletable: acc.deletable + target.deletable,
    }),
    { total: 0, seeded: 0, deletable: 0 }
  );

  console.log(`\n${label}`);
  console.log(
    `    ${targets.length} tables | ${totals.total} operational rows | `
    + `${totals.seeded} seed-marked | ${totals.deletable} would be removed`
  );
  console.log(`    ${'table'.padEnd(38)} ${'total'.padStart(7)} ${'seeded'.padStart(7)} ${'remove'.padStart(7)}`);

  for (const target of targets) {
    console.log(
      `    ${target.table.padEnd(38)} ${String(target.total).padStart(7)} `
      + `${String(target.seeded).padStart(7)} ${String(target.deletable).padStart(7)}`
    );
  }

  if (plan.demo_tenant) {
    console.log(
      '    note: this is a seeder-owned demo tenant, so every operational row in it is '
      + 'demo data and is removable.'
    );
  } else if (!includeUnmarked && totals.total > totals.seeded) {
    console.log(
      `    note: ${totals.total - totals.seeded} unmarked rows are left alone. They were not `
      + 'written by the seeder and are treated as real data.'
    );
  }
};

const main = async () => {
  const args = parseArgs(process.argv);

  const safety = assertDemoTaskAllowed('tenant operational seed cleanup');
  if (!safety.allowed) {
    console.error(
      'Refusing to run the operational seed cleanup against a production database.\n'
      + 'Step 04 established that production operational rows are real user activity; '
      + 'clean development instead and document production exceptions in '
      + 'backend/docs/tenant-initialization-audit.md.'
    );
    process.exitCode = 1;
    return;
  }

  if (args.confirm && args.includeUnmarked && !args.backupAcknowledged) {
    console.error(
      'Refusing to delete unmarked rows without --i-have-a-backup.\n'
      + 'Unmarked rows were not written by the seeder. Take a verified backup, review the '
      + 'dry-run report, then re-run with --yes --include-unmarked --i-have-a-backup.'
    );
    process.exitCode = 1;
    return;
  }

  const tenants = await resolveTenants(args.tenant);
  const report = {
    measured_at: new Date().toISOString(),
    node_env: process.env.NODE_ENV || 'development',
    mode: args.confirm ? 'apply' : 'dry-run',
    include_unmarked: args.includeUnmarked,
    seed_pack: DEMO_SEED_PACK,
    tenants: [],
  };

  if (!args.json) {
    console.log(
      `Tenant operational seed cleanup - ${report.mode}`
      + `${args.includeUnmarked ? ' (including unmarked rows)' : ''}`
    );
    console.log(`Scanning ${tenants.length} tenant(s) across ${listForbiddenTables().length} forbidden tables.`);
  }

  for (const tenant of tenants) {
    const plan = await planForTenant(tenant, { includeUnmarked: args.includeUnmarked });

    if (!args.json) printPlan(plan, { includeUnmarked: args.includeUnmarked });

    const entry = {
      tenant: plan.tenant,
      targets: plan.targets,
      deleted: [],
    };

    if (args.confirm) {
      entry.deleted = await applyPlan(plan, { includeUnmarked: args.includeUnmarked });
      if (!args.json && entry.deleted.length > 0) {
        const removed = entry.deleted.reduce((sum, row) => sum + row.rows, 0);
        console.log(`    removed ${removed} rows across ${entry.deleted.length} tables`);
      }
    }

    report.tenants.push(entry);
  }

  if (args.json) {
    console.log(JSON.stringify(report, null, 2));
    return;
  }

  if (!args.confirm) {
    console.log('\nDry run only. Nothing was deleted. Re-run with --yes to apply.');
  }
};

main()
  .catch((error) => {
    console.error(`Cleanup failed: ${error.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect().catch(() => {});
  });
