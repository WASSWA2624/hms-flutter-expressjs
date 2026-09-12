#!/usr/bin/env node
/**
 * Seed the platform preset catalog.
 *
 * These are the centrally owned definitions every tenant can adopt: the curated
 * Uganda lab, radiology and diagnosis catalogs, written at `tenant_id: null`.
 *
 * This is NOT demo data and is deliberately not behind `demo-safety.js`. The
 * platform catalog is reference data that production needs in order for the
 * preset model to mean anything - a tenant cannot adopt a preset that does not
 * exist. The rows carry no patient or tenant information.
 *
 * Idempotent. Rows are keyed on `(tenant_id IS NULL, code)` and updated in
 * place, so re-running refreshes wording and never duplicates. Nothing is
 * deleted, and no tenant-owned row is touched.
 *
 * Usage:
 *   node scripts/seed-platform-presets.js --dry-run
 *   node scripts/seed-platform-presets.js
 *   node scripts/seed-platform-presets.js --domain=lab_test
 *   node scripts/seed-platform-presets.js --json
 *
 * @module scripts/seed-platform-presets
 */

require('module-alias/register');

const crypto = require('crypto');
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
  console.error('Failed to register platform preset seeder aliases:', error);
  process.exit(1);
}

const prisma = require('@prisma/client');
const {
  LAB_PANEL_CATALOG,
  LAB_TEST_CATALOG,
} = require('./seeders/data/uganda-lab-catalog');
const { RADIOLOGY_TEST_CATALOG } = require('./seeders/data/uganda-radiology-catalog');
const { DRUG_CATALOG } = require('./seeders/seed-clinical-catalog-pack');
const {
  CURRENCY_CATALOG,
  CONSULTATION_TYPE_CATALOG,
} = require('./seeders/data/platform-billing-catalog');
const { UGANDA_DIAGNOSIS_CATALOG } = require('./seeders/data/uganda-diagnosis-catalog');

/** Stable ids so a re-run updates the same rows rather than inserting new ones. */
const presetId = (domain, key) => {
  const hex = crypto
    .createHash('sha256')
    .update(`platform-preset:${domain}:${key}`)
    .digest('hex');
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    `4${hex.slice(13, 16)}`,
    `a${hex.slice(17, 20)}`,
    hex.slice(20, 32),
  ].join('-');
};

const friendlyId = (prefix, domain, key) =>
  `${prefix}-${crypto
    .createHash('sha256')
    .update(`platform-preset:${domain}:${key}`)
    .digest('hex')
    .slice(0, 10)
    .toUpperCase()}`;

const text = (value, max = 255) => {
  const normalized = String(value ?? '').trim();
  if (!normalized) return null;
  return normalized.length > max ? normalized.slice(0, max) : normalized;
};

const parseArgs = (argv) => {
  const args = { dryRun: false, json: false, domain: null };
  for (const raw of argv.slice(2)) {
    if (raw === '--dry-run') args.dryRun = true;
    else if (raw === '--json') args.json = true;
    else if (raw.startsWith('--domain=')) args.domain = raw.slice('--domain='.length).trim();
  }
  return args;
};

/**
 * Upsert one platform row by its deterministic id.
 *
 * Scoped to `tenant_id: null` on every write so this can never reach into a
 * tenant's own catalog, even if an id were to collide.
 */
const upsertPreset = async (model, id, data, { dryRun }) => {
  const existing = await prisma[model].findFirst({
    where: { id, tenant_id: null },
    select: { id: true },
  });

  if (dryRun) return existing ? 'update' : 'create';

  if (existing) {
    await prisma[model].update({
      where: { id },
      data: { ...data, tenant_id: null, deleted_at: null },
    });
    return 'update';
  }

  await prisma[model].create({ data: { ...data, id, tenant_id: null } });
  return 'create';
};

const tally = () => ({ created: 0, updated: 0 });
const record = (counts, outcome) => {
  if (outcome === 'create') counts.created += 1;
  else counts.updated += 1;
};

const seedLabTests = async ({ dryRun }) => {
  const counts = tally();
  const idByKey = new Map();
  const childCounts = { unit_options: 0, result_options: 0, reference_ranges: 0 };

  for (const spec of LAB_TEST_CATALOG) {
    const id = presetId('lab_test', spec.key);
    idByKey.set(spec.key, id);

    record(counts, await upsertPreset('lab_test', id, {
      human_friendly_id: friendlyId('LTST', 'lab_test', spec.key),
      name: text(spec.name),
      code: text(spec.code, 80),
      category: text(spec.category, 80),
      specimen_type: text(spec.specimen_type, 80),
      result_kind: spec.result_kind || 'NUMERIC',
      unit: text(spec.unit, 40),
      description: text(spec.description),
      reference_range: text(spec.reference_range),
      // Price is a tenant concern and lives on the facility offering, so the
      // platform definition deliberately carries none.
      unit_price: null,
      currency: null,
    }, { dryRun }));

    // Unit options, reference ranges and result options are clinical standards,
    // not commercial terms, so the platform definition owns them. A facility
    // that needs a local variation gets one through the facility-level
    // equivalents on its offering.
    //
    // Written as nested replaces on the lab test: none of these three models
    // carries `human_friendly_id`, and a direct create would trip the extension
    // that assumes every model does.
    const unitOptions = (spec.unit_options || []).map((option, index) => ({
      label: text(option.label, 80),
      unit: text(option.unit, 40),
      ucum_code: text(option.ucum_code, 40),
      is_default: Boolean(option.is_default),
      sort_order: index,
    })).filter((option) => option.unit);

    const resultOptions = (spec.result_options || []).map((option, index) => ({
      value: text(option.value, 80),
      label: text(option.label, 120),
      aliases_json: Array.isArray(option.aliases) && option.aliases.length > 0
        ? option.aliases
        : undefined,
      status: option.status || 'ABNORMAL',
      result_flag: text(option.result_flag, 40),
      is_positive: Boolean(option.is_positive),
      sort_order: index,
    })).filter((option) => option.value);

    const referenceRanges = (spec.reference_ranges || []).map((range, index) => ({
      label: text(range.label, 120),
      unit: text(range.unit, 40),
      method: text(range.method, 120),
      gender: range.gender || null,
      age_min_value: range.age_min_value ?? null,
      age_min_unit: range.age_min_unit || null,
      age_max_value: range.age_max_value ?? null,
      age_max_unit: range.age_max_unit || null,
      normal_min_value: range.normal_min_value ?? null,
      normal_max_value: range.normal_max_value ?? null,
      critical_min_value: range.critical_min_value ?? null,
      critical_max_value: range.critical_max_value ?? null,
      reference_text: text(range.reference_text),
      notes: text(range.notes),
      sort_order: index,
    }));

    childCounts.unit_options += unitOptions.length;
    childCounts.result_options += resultOptions.length;
    childCounts.reference_ranges += referenceRanges.length;

    if (!dryRun) {
      await prisma.lab_test.update({
        where: { id },
        data: {
          unit_options: { deleteMany: {}, create: unitOptions },
          result_options: { deleteMany: {}, create: resultOptions },
          reference_ranges: { deleteMany: {}, create: referenceRanges },
        },
      });
    }
  }

  return { counts, idByKey, childCounts };
};

const seedLabPanels = async ({ dryRun }, labTestIdByKey) => {
  const counts = tally();
  let itemsLinked = 0;

  for (const spec of LAB_PANEL_CATALOG) {
    const id = presetId('lab_panel', spec.key);

    record(counts, await upsertPreset('lab_panel', id, {
      human_friendly_id: friendlyId('LPNL', 'lab_panel', spec.key),
      name: text(spec.name),
      code: text(spec.code, 80),
      category: text(spec.category, 80),
      description: text(spec.description),
      unit_price: null,
      currency: null,
    }, { dryRun }));

    // A platform panel must reference platform tests, never a tenant's copy.
    const items = (spec.test_keys || [])
      .map((testKey, index) => ({ lab_test_id: labTestIdByKey.get(testKey), sort_order: index }))
      .filter((item) => Boolean(item.lab_test_id));
    itemsLinked += items.length;

    // Written as a nested create on the panel, which is how the rest of the
    // codebase writes panel items. A direct `lab_panel_item.create` goes
    // through the human-friendly-id extension, which assumes every model has
    // that column - `lab_panel_item` does not.
    if (!dryRun && items.length > 0) {
      await prisma.lab_panel.update({
        where: { id },
        data: {
          panel_items: {
            deleteMany: {},
            create: items,
          },
        },
      });
    }
  }

  return { counts, itemsLinked };
};

const seedRadiologyProcedures = async ({ dryRun }) => {
  const counts = tally();

  for (const spec of RADIOLOGY_TEST_CATALOG) {
    const id = presetId('radiology_procedure', spec.key);

    record(counts, await upsertPreset('radiology_procedure', id, {
      human_friendly_id: friendlyId('RPRC', 'radiology_procedure', spec.key),
      name: text(spec.name),
      code: text(spec.code, 80),
      modality: spec.modality,
      body_region: text(spec.body_region, 120),
      procedure_type: text(spec.procedure_type, 120),
      unit_price: null,
      currency: null,
    }, { dryRun }));
  }

  return { counts };
};

const seedDrugs = async ({ dryRun }) => {
  const counts = tally();

  for (const spec of DRUG_CATALOG) {
    const id = presetId('drug', spec.key);

    record(counts, await upsertPreset('drug', id, {
      human_friendly_id: friendlyId('DRUG', 'drug', spec.key),
      name: text(spec.name),
      brand_name: text(spec.brand),
      generic_name: text(spec.generic_name || spec.name),
      code: text(spec.code, 80),
      form: text(spec.form, 80),
      strength: text(spec.strength, 80),
      is_controlled: Boolean(spec.is_controlled),
      // Pricing and stock are facility concerns; the platform definition is
      // the product, not the commercial terms.
      unit_price: null,
      buy_unit_price: null,
      currency: null,
      supplier_id: null,
    }, { dryRun }));
  }

  return { counts };
};

const seedCurrencies = async ({ dryRun }) => {
  const counts = tally();

  for (const [index, spec] of CURRENCY_CATALOG.entries()) {
    const id = presetId('currency_preset', spec.key);

    // currency_preset has no tenant_id at all - a currency is never a tenant's
    // to own - so it is upserted directly rather than through upsertPreset.
    const existing = await prisma.currency_preset.findFirst({
      where: { id },
      select: { id: true },
    });
    const data = {
      human_friendly_id: friendlyId('CUR', 'currency_preset', spec.key),
      code: spec.code,
      name: spec.name,
      symbol: spec.symbol,
      decimal_places: spec.decimal_places,
      is_active: true,
      sort_order: index,
    };

    if (dryRun) {
      record(counts, existing ? 'update' : 'create');
      continue;
    }

    if (existing) {
      await prisma.currency_preset.update({
        where: { id },
        data: { ...data, deleted_at: null },
      });
      record(counts, 'update');
    } else {
      await prisma.currency_preset.create({ data: { ...data, id } });
      record(counts, 'create');
    }
  }

  return { counts };
};

const seedConsultationTypes = async ({ dryRun }) => {
  const counts = tally();

  for (const spec of CONSULTATION_TYPE_CATALOG) {
    const id = presetId('consultation_type', spec.key);

    record(counts, await upsertPreset('consultation_type', id, {
      human_friendly_id: friendlyId('CTYP', 'consultation_type', spec.key),
      name: text(spec.name, 160),
      code: text(spec.code, 80),
      category: text(spec.category, 80),
      description: text(spec.description),
      default_duration_minutes: spec.default_duration_minutes ?? null,
    }, { dryRun }));
  }

  return { counts };
};

const seedDiagnoses = async ({ dryRun }) => {
  const counts = tally();

  for (const spec of UGANDA_DIAGNOSIS_CATALOG) {
    const id = presetId('clinical_term_catalog', spec.key);

    record(counts, await upsertPreset('clinical_term_catalog', id, {
      human_friendly_id: friendlyId('CTRM', 'clinical_term_catalog', spec.key),
      facility_id: null,
      catalog_key: text(spec.key, 120),
      term_type: 'DIAGNOSIS',
      code: text(spec.code, 80),
      description: String(spec.description || '').trim(),
      category: text(spec.category, 120),
      source: text(spec.source, 80),
      sort_order: Number(spec.rank ?? 0),
      usage_rank: Number(spec.rank ?? 0),
      is_active: true,
    }, { dryRun }));
  }

  return { counts };
};

const main = async () => {
  const args = parseArgs(process.argv);
  const wanted = (domain) => !args.domain || args.domain === domain;

  if (args.domain
    && ![
      'lab_test', 'lab_panel', 'radiology_procedure', 'drug',
      'currency_preset', 'consultation_type', 'clinical_term_catalog',
    ].includes(args.domain)) {
    throw new Error(`Unknown domain "${args.domain}".`);
  }

  const report = {
    measured_at: new Date().toISOString(),
    node_env: process.env.NODE_ENV || 'development',
    mode: args.dryRun ? 'dry-run' : 'apply',
    domains: {},
  };

  if (!args.json) {
    console.log(`Platform preset catalog - ${report.mode} (${report.node_env})`);
  }

  // Lab tests always load: panels reference them by key, so their ids are
  // needed even when only panels are being seeded.
  const {
    idByKey: labTestIdByKey,
    counts: labTestCounts,
    childCounts: labTestChildCounts,
  } = await seedLabTests({ dryRun: args.dryRun || !wanted('lab_test') });
  if (wanted('lab_test')) {
    report.domains.lab_test = { ...labTestCounts, ...labTestChildCounts };
  }

  if (wanted('lab_panel')) {
    const { counts, itemsLinked } = await seedLabPanels({ dryRun: args.dryRun }, labTestIdByKey);
    report.domains.lab_panel = { ...counts, panel_items_linked: itemsLinked };
  }

  if (wanted('radiology_procedure')) {
    report.domains.radiology_procedure = (await seedRadiologyProcedures({ dryRun: args.dryRun })).counts;
  }

  if (wanted('drug')) {
    report.domains.drug = (await seedDrugs({ dryRun: args.dryRun })).counts;
  }

  if (wanted('currency_preset')) {
    report.domains.currency_preset = (await seedCurrencies({ dryRun: args.dryRun })).counts;
  }

  if (wanted('consultation_type')) {
    report.domains.consultation_type = (await seedConsultationTypes({ dryRun: args.dryRun })).counts;
  }

  if (wanted('clinical_term_catalog')) {
    report.domains.clinical_term_catalog = (await seedDiagnoses({ dryRun: args.dryRun })).counts;
  }

  if (args.json) {
    console.log(JSON.stringify(report, null, 2));
    return;
  }

  for (const [domain, counts] of Object.entries(report.domains)) {
    const detail = [];
    if (counts.panel_items_linked !== undefined) {
      detail.push(`${counts.panel_items_linked} panel items`);
    }
    if (counts.unit_options !== undefined) {
      detail.push(
        `${counts.unit_options} unit options`,
        `${counts.reference_ranges} reference ranges`,
        `${counts.result_options} result options`
      );
    }
    const extra = detail.length > 0 ? `, ${detail.join(', ')}` : '';
    console.log(
      `    ${domain.padEnd(24)} ${String(counts.created).padStart(5)} created, `
      + `${String(counts.updated).padStart(5)} updated${extra}`
    );
  }

  if (args.dryRun) {
    console.log('\nDry run only. Nothing was written.');
  }
};

main()
  .catch((error) => {
    console.error(`Platform preset seed failed: ${error.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect().catch(() => {});
  });
