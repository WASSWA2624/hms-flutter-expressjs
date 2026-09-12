#!/usr/bin/env node
/**
 * Read-only tenant initialization audit.
 *
 * Counts every row that exists under one tenant, so a freshly created tenant
 * can be compared against what the creation paths are supposed to write.
 * Supports step 04 of the Fairbanks fixes.
 *
 * Only `count` queries run here - nothing in this file mutates, deletes or
 * seeds, which is what makes it safe to point at the production database.
 *
 * Usage:
 *   node scripts/audit-tenant-initialization.js                  # newest tenant
 *   node scripts/audit-tenant-initialization.js --tenant=<id|slug>
 *   node scripts/audit-tenant-initialization.js --json
 *   node scripts/audit-tenant-initialization.js --all-tables     # include zero counts
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
  console.error('Failed to register audit script aliases:', error);
  process.exit(1);
}

const prisma = require('@prisma/client');

/** Tables a tenant never owns directly; counted through their owning rows. */
const DERIVED_COUNTS = Object.freeze([
  {
    table: 'user_profile',
    via: 'user.tenant_id',
    count: (tenantId) =>
      prisma.user_profile.count({ where: { user: { tenant_id: tenantId } } }),
  },
  {
    table: 'verification_token',
    via: 'user.tenant_id',
    count: (tenantId) =>
      prisma.verification_token.count({ where: { user: { tenant_id: tenantId } } }),
  },
  {
    table: 'module_subscription',
    via: 'subscription.tenant_id',
    count: (tenantId) =>
      prisma.module_subscription.count({
        where: { subscription: { tenant_id: tenantId } },
      }),
  },
]);

const parseArgs = (argv) => {
  const args = { tenant: null, json: false, allTables: false };
  for (const raw of argv.slice(2)) {
    if (raw === '--json') args.json = true;
    else if (raw === '--all-tables') args.allTables = true;
    else if (raw.startsWith('--tenant=')) args.tenant = raw.slice('--tenant='.length).trim();
  }
  return args;
};

const countable = (name) => typeof prisma[name]?.count === 'function';

const hasField = (model, field) => model.fields.some((entry) => entry.name === field);

/** Every Prisma model carrying a `tenant_id` scalar, by delegate name. */
const listTenantScopedModels = () => {
  const { Prisma } = require('.prisma/client');
  return Prisma.dmmf.datamodel.models
    .filter((model) => hasField(model, 'tenant_id'))
    .map((model) => model.name)
    .filter((name) => name !== 'tenant')
    .filter(countable)
    .sort();
};

/**
 * Models reachable only through a facility. A tenant owns no `tenant_id` column
 * on these, so counting them by the tenant's facilities is the only way to prove
 * they are empty for a fresh tenant.
 */
const listFacilityOnlyScopedModels = () => {
  const { Prisma } = require('.prisma/client');
  return Prisma.dmmf.datamodel.models
    .filter((model) => hasField(model, 'facility_id') && !hasField(model, 'tenant_id'))
    .map((model) => model.name)
    .filter((name) => name !== 'facility')
    .filter(countable)
    .sort();
};

const resolveTenant = async (identifier) => {
  if (identifier) {
    const tenant = await prisma.tenant.findFirst({
      where: {
        OR: [
          { id: identifier },
          { slug: identifier.toLowerCase() },
          { human_friendly_id: identifier },
        ],
      },
      select: { id: true, name: true, slug: true, human_friendly_id: true, created_at: true },
    });
    if (!tenant) throw new Error(`No tenant matched "${identifier}".`);
    return tenant;
  }

  const tenant = await prisma.tenant.findFirst({
    where: { deleted_at: null },
    orderBy: { created_at: 'desc' },
    select: { id: true, name: true, slug: true, human_friendly_id: true, created_at: true },
  });
  if (!tenant) throw new Error('No tenants found.');
  return tenant;
};

const main = async () => {
  const args = parseArgs(process.argv);
  const tenant = await resolveTenant(args.tenant);

  const rows = [];

  for (const model of listTenantScopedModels()) {
    const total = await prisma[model].count({ where: { tenant_id: tenant.id } });
    rows.push({ table: model, scope: 'tenant_id', rows: total });
  }

  const facilityIds = (
    await prisma.facility.findMany({
      where: { tenant_id: tenant.id },
      select: { id: true },
    })
  ).map((facility) => facility.id);

  // Tables the derived pass already counts more precisely than facility_id can.
  const derivedTables = new Set(DERIVED_COUNTS.map((entry) => entry.table));

  for (const model of listFacilityOnlyScopedModels()) {
    if (derivedTables.has(model)) continue;
    const total = facilityIds.length
      ? await prisma[model].count({ where: { facility_id: { in: facilityIds } } })
      : 0;
    rows.push({ table: model, scope: 'facility_id', rows: total });
  }

  for (const derived of DERIVED_COUNTS) {
    rows.push({ table: derived.table, scope: derived.via, rows: await derived.count(tenant.id) });
  }

  rows.sort((a, b) => b.rows - a.rows || a.table.localeCompare(b.table));
  const populated = rows.filter((row) => row.rows > 0);

  const report = {
    measured_at: new Date().toISOString(),
    node_env: process.env.NODE_ENV || 'development',
    tenant: {
      id: tenant.id,
      human_friendly_id: tenant.human_friendly_id,
      name: tenant.name,
      slug: tenant.slug,
      created_at: tenant.created_at,
    },
    tables_scanned: rows.length,
    tables_with_rows: populated.length,
    total_rows: rows.reduce((sum, row) => sum + row.rows, 0),
    counts: args.allTables ? rows : populated,
  };

  if (args.json) {
    console.log(JSON.stringify(report, null, 2));
    return;
  }

  console.log(`tenant     : ${tenant.name} (${tenant.human_friendly_id || tenant.id})`);
  console.log(`slug       : ${tenant.slug}`);
  console.log(`created_at : ${tenant.created_at?.toISOString?.() || tenant.created_at}`);
  console.log(`env        : ${report.node_env}`);
  console.log(
    `scanned    : ${report.tables_scanned} tables, ${report.tables_with_rows} with rows, ` +
    `${report.total_rows} rows total`
  );
  console.log('');
  for (const row of report.counts) {
    console.log(`${String(row.rows).padStart(8)}  ${row.table.padEnd(42)} ${row.scope}`);
  }
};

main()
  .catch((error) => {
    console.error(`Audit failed: ${error.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect().catch(() => {});
  });
