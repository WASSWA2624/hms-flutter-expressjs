#!/usr/bin/env node
/**
 * Read-only survey of duplicated catalog master data.
 *
 * Every tenant currently carries its own copy of the same clinical catalog.
 * Before any of that can be collapsed onto shared platform presets, we need to
 * know how much of it is genuinely the same row repeated, how much differs in
 * ways a merge would destroy, and what operational history points at each copy.
 *
 * Only `count`, `findMany` and `groupBy` run here, so it is safe against any
 * database including production.
 *
 * Usage:
 *   node scripts/analyze-catalog-duplication.js
 *   node scripts/analyze-catalog-duplication.js --domain=lab_test
 *   node scripts/analyze-catalog-duplication.js --json
 *   node scripts/analyze-catalog-duplication.js --show-conflicts
 *
 * @module scripts/analyze-catalog-duplication
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
  console.error('Failed to register analysis script aliases:', error);
  process.exit(1);
}

const { registerAllModuleAliases } = require('@lib/aliases');

registerAllModuleAliases();

const prisma = require('@prisma/client');
const { PRESET_DOMAINS } = require('@lib/catalog/preset-ownership');
const { classifyReferrers, buildDedupeKey } = require('@lib/catalog/preset-references');

/** The naming column each domain identifies a row by. */
const NAME_FIELD = Object.freeze({
  clinical_term_catalog: 'description',
});

/**
 * Fields that must agree before two rows can be called the same preset.
 *
 * Deliberately narrow: these are the clinical identity of the entry. Price and
 * local wording are expected to differ - that is what the adoption row is for -
 * so they are not compared.
 */
const IDENTITY_FIELDS = Object.freeze({
  lab_test: ['category', 'specimen_type', 'result_kind'],
  lab_panel: ['category'],
  radiology_procedure: ['modality', 'body_region'],
  drug: ['form', 'strength', 'generic_name'],
  clinical_term_catalog: ['term_type', 'category'],
});

const parseArgs = (argv) => {
  const args = { domain: null, json: false, showConflicts: false };
  for (const raw of argv.slice(2)) {
    if (raw === '--json') args.json = true;
    else if (raw === '--show-conflicts') args.showConflicts = true;
    else if (raw.startsWith('--domain=')) args.domain = raw.slice('--domain='.length).trim();
  }
  return args;
};

const normalizeValue = (value) =>
  value == null ? '' : String(value).trim().toLowerCase();

/** Do these rows agree on everything that defines the preset clinically? */
const identityMatches = (rows, fields) => {
  if (rows.length < 2) return true;
  return fields.every((field) => {
    const first = normalizeValue(rows[0][field]);
    return rows.every((row) => normalizeValue(row[field]) === first);
  });
};

/** Count operational rows pointing at a set of definition ids. */
const countReferences = async (referrers, ids) => {
  const counts = {};
  for (const referrer of referrers) {
    const delegate = prisma[referrer.model];
    if (!delegate?.count) continue;
    const total = await delegate.count({ where: { [referrer.field]: { in: ids } } });
    if (total > 0) counts[`${referrer.model}.${referrer.field}`] = total;
  }
  return counts;
};

const analyzeDomain = async (domain, contract, { showConflicts }) => {
  const nameField = NAME_FIELD[domain] || 'name';
  const identityFields = IDENTITY_FIELDS[domain] || [];
  const delegate = prisma[contract.definitionModel];

  if (!delegate?.findMany) {
    return { domain, skipped: 'no prisma delegate' };
  }

  const rows = await delegate.findMany({
    where: { deleted_at: null },
    orderBy: { created_at: 'asc' },
  });

  const platformRows = rows.filter((row) => row.tenant_id == null);
  const tenantRows = rows.filter((row) => row.tenant_id != null);

  const groups = new Map();
  let unkeyed = 0;

  for (const row of rows) {
    const key = buildDedupeKey(row, nameField);
    if (!key) {
      unkeyed += 1;
      continue;
    }
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(row);
  }

  const referrers = classifyReferrers(contract.definitionModel, contract.adoptionModel);
  const operationalReferrers = [...referrers.operational, ...referrers.cascading];

  const collapsible = [];
  const conflicts = [];

  for (const [key, groupRows] of groups) {
    const tenantsInGroup = new Set(
      groupRows.map((row) => row.tenant_id).filter(Boolean)
    );
    // A group is only interesting if the same entry exists more than once.
    if (groupRows.length < 2) continue;

    const entry = {
      key,
      rows: groupRows.length,
      tenants: tenantsInGroup.size,
      has_platform_row: groupRows.some((row) => row.tenant_id == null),
      sample_name: groupRows[0][nameField],
    };

    if (identityMatches(groupRows, identityFields)) {
      collapsible.push(entry);
    } else {
      entry.differing_fields = identityFields.filter((field) => {
        const first = normalizeValue(groupRows[0][field]);
        return groupRows.some((row) => normalizeValue(row[field]) !== first);
      });
      conflicts.push(entry);
    }
  }

  const collapsibleRows = collapsible.reduce((sum, entry) => sum + entry.rows, 0);
  const referenceCounts = await countReferences(
    operationalReferrers,
    tenantRows.map((row) => row.id)
  );

  return {
    domain,
    definition_model: contract.definitionModel,
    adoption_model: contract.adoptionModel,
    total_rows: rows.length,
    platform_rows: platformRows.length,
    tenant_rows: tenantRows.length,
    unkeyed_rows: unkeyed,
    duplicate_groups: collapsible.length + conflicts.length,
    collapsible_groups: collapsible.length,
    collapsible_rows: collapsibleRows,
    rows_retired_if_collapsed: collapsibleRows - collapsible.length,
    conflict_groups: conflicts.length,
    conflicts: showConflicts ? conflicts.slice(0, 25) : conflicts.slice(0, 5),
    referrers: {
      adoption: referrers.adoption.map((r) => `${r.model}.${r.field}`),
      cascading: referrers.cascading.map((r) => `${r.model}.${r.field}`),
      operational: referrers.operational.map((r) => `${r.model}.${r.field}`),
    },
    references_to_tenant_rows: referenceCounts,
  };
};

const printDomain = (report) => {
  if (report.skipped) {
    console.log(`\n### ${report.domain}\n    skipped: ${report.skipped}`);
    return;
  }

  console.log(`\n### ${report.domain}  (${report.definition_model})`);
  console.log(
    `    rows            : ${report.total_rows} total | `
    + `${report.platform_rows} platform | ${report.tenant_rows} tenant-scoped`
  );
  console.log(
    `    duplicate groups: ${report.duplicate_groups} `
    + `(${report.collapsible_groups} collapsible, ${report.conflict_groups} conflicting)`
  );
  console.log(
    `    would retire    : ${report.rows_retired_if_collapsed} rows `
    + `into ${report.collapsible_groups} shared presets`
  );

  if (report.unkeyed_rows > 0) {
    console.log(`    unkeyed         : ${report.unkeyed_rows} rows have no code or name - left alone`);
  }

  const refs = Object.entries(report.references_to_tenant_rows);
  if (refs.length > 0) {
    console.log('    references to tenant rows that must survive:');
    for (const [table, count] of refs.sort((a, b) => b[1] - a[1])) {
      console.log(`        ${String(count).padStart(7)}  ${table}`);
    }
  } else {
    console.log('    references      : none - nothing operational points at these rows');
  }

  if (report.conflicts.length > 0) {
    console.log(`    conflicts (same key, different clinical identity):`);
    for (const conflict of report.conflicts) {
      console.log(
        `        ${conflict.key} - ${conflict.rows} rows across ${conflict.tenants} tenants, `
        + `differ on ${conflict.differing_fields.join(', ')}`
      );
    }
  }
};

const main = async () => {
  const args = parseArgs(process.argv);
  const domains = args.domain
    ? { [args.domain]: PRESET_DOMAINS[args.domain] }
    : PRESET_DOMAINS;

  if (args.domain && !domains[args.domain]) {
    throw new Error(`Unknown domain "${args.domain}".`);
  }

  const reports = [];
  for (const [domain, contract] of Object.entries(domains)) {
    reports.push(await analyzeDomain(domain, contract, { showConflicts: args.showConflicts }));
  }

  const summary = {
    measured_at: new Date().toISOString(),
    node_env: process.env.NODE_ENV || 'development',
    domains: reports,
  };

  if (args.json) {
    console.log(JSON.stringify(summary, null, 2));
    return;
  }

  console.log(`Catalog duplication survey - ${summary.node_env}`);
  reports.forEach(printDomain);

  const retired = reports.reduce((sum, r) => sum + (r.rows_retired_if_collapsed || 0), 0);
  const conflicts = reports.reduce((sum, r) => sum + (r.conflict_groups || 0), 0);
  console.log(
    `\nAcross all domains: ${retired} rows could collapse onto shared presets; `
    + `${conflicts} groups conflict and need a decision.`
  );
};

main()
  .catch((error) => {
    console.error(`Analysis failed: ${error.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect().catch(() => {});
  });
