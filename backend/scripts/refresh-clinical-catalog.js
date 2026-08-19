/**
 * Production-safe clinical catalog refresh.
 *
 * Brings existing tenants onto the deduplicated catalogs without going near the
 * demo seeders. The seeders under scripts/seed-*-catalog-data.js call
 * seedOrgPack first, which invents demo tenants and facilities, which is why
 * they refuse to run when NODE_ENV=production. This script does not: it only
 * ever reads the tenant list and upserts catalog rows against it.
 *
 * What it touches:
 *   lab_test / lab_panel / lab_panel_item / radiology_procedure
 *   lab_test_reference_range / lab_test_unit_option / lab_test_result_option
 *   clinical_term_catalog (DIAGNOSIS terms only)
 *   facility_lab_panel_offering (deactivation of retired panels only)
 *
 * What it never touches: lab_order, lab_order_item, lab_result, radiology_order,
 * or any other clinical record. Retired panels are soft-deleted, never removed,
 * so historical orders keep resolving their panel.
 *
 * Matching is by natural key (tenant_id + code, or catalog_key for terms) rather
 * than by seeded id, because production rows may predate the seeders or have
 * been edited in the admin UI.
 *
 * Usage:
 *   node scripts/refresh-clinical-catalog.js                 # dry run, prints the plan
 *   node scripts/refresh-clinical-catalog.js --apply         # writes
 *   node scripts/refresh-clinical-catalog.js --apply --tenant <id>
 */

// The shared client carries the MariaDB driver adapter, human_friendly_id
// assignment, and the tenant guard. Never construct a bare PrismaClient here.
const prisma = require('../src/prisma/client');
const { runWithoutTenantGuard } = require('../src/prisma/tenant-guard');
const {
  LAB_PANEL_CATALOG,
  LAB_TEST_CATALOG,
} = require('./seeders/data/uganda-lab-catalog');
const { RADIOLOGY_TEST_CATALOG } = require('./seeders/data/uganda-radiology-catalog');
const { UGANDA_DIAGNOSIS_CATALOG } = require('./seeders/data/uganda-diagnosis-catalog');

/**
 * Panels dropped when the catalog was deduplicated. Retirement is driven by this
 * explicit list rather than "any panel code not in the canonical set", so a
 * tenant's own custom panels are left alone.
 */
const RETIRED_PANEL_CODES = Object.freeze([
  'DMFOLLOW', 'RESPVIR', 'CD4-CD8-PNL', 'ANC1', 'ANCINF', 'ANCANEM', 'ANCHTN',
  'OBSLR', 'PPANEM', 'PREGCONF', 'ECTOPIC', 'MISCA', 'PEDFEV', 'U5MALAN',
  'PEDDIAR', 'PEDNUT', 'PEDRESP', 'MALSCR', 'MALFU', 'TBSCREEN', 'TBHIV', 'TBBL',
  'OISCR', 'CRAGSCR', 'VLFU', 'HBVBL', 'HCVBL', 'JAUND', 'PANC', 'PUD', 'TYPH',
  'BRUCSCR', 'AKI', 'CKD', 'NEPH', 'UTISCR', 'UTICOMP', 'DMDX', 'DMRENAL',
  'HTNBL', 'HFSCR', 'ACS', 'STROKE', 'PREOPMIN', 'PREOPMAJ', 'OBSPREOP', 'BLEED',
  'VTE', 'NUTANEM', 'IRONDEF', 'HEMOL', 'SICKFU', 'INFLAM', 'BACT', 'WOUND',
  'MENING', 'STIEX', 'VAGSCR', 'CRENLYT', 'ICUDAY', 'DEHYD', 'CLD', 'LIPRISK',
  'ENDOBASE', 'ARTHAI', 'PROSCR', 'MICRONUT', 'OCEXP', 'PEP', 'FEVRASH',
  'DENGUE', 'G6PDAM', 'ADMBL',
]);

const CURRENCY = 'UGX';

const LAB_TEST_PRICES = {
  CHEMISTRY: 18000, HEMATOLOGY: 15000, 'CRITICAL CARE': 25000, MICROBIOLOGY: 22000,
  SEROLOGY: 20000, IMMUNOLOGY: 24000, MOLECULAR: 45000, URINALYSIS: 12000,
  COAGULATION: 20000, ENDOCRINOLOGY: 28000, PARASITOLOGY: 18000, HISTOPATHOLOGY: 35000,
};

const LAB_PANEL_PRICES = {
  CHEMISTRY: 55000, HEMATOLOGY: 48000, 'CRITICAL CARE': 75000, MICROBIOLOGY: 65000,
  SEROLOGY: 60000, IMMUNOLOGY: 70000, MOLECULAR: 120000, URINALYSIS: 35000,
  COAGULATION: 60000, ENDOCRINOLOGY: 80000, PARASITOLOGY: 55000, HISTOPATHOLOGY: 95000,
  CARDIOVASCULAR: 70000, RENAL: 65000, EMERGENCY: 75000, CARDIAC: 70000,
};

const priceFor = (table, category, fallback) =>
  table[String(category || '').trim().toUpperCase()] ?? fallback;

const parseArgs = (argv) => {
  const apply = argv.includes('--apply');
  const tenantIndex = argv.indexOf('--tenant');
  return {
    apply,
    tenantId: tenantIndex >= 0 ? argv[tenantIndex + 1] || null : null,
  };
};

const summary = {
  tenants: 0,
  lab_tests_created: 0,
  lab_tests_updated: 0,
  lab_panels_created: 0,
  lab_panels_updated: 0,
  lab_panels_retired: 0,
  panel_offerings_deactivated: 0,
  radiology_created: 0,
  radiology_updated: 0,
  diagnoses_created: 0,
  diagnoses_updated: 0,
};

const refreshLabTests = async (tx, tenantId, apply) => {
  const byCode = new Map();
  for (const spec of LAB_TEST_CATALOG) {
    const existing = await tx.lab_test.findFirst({
      where: { tenant_id: tenantId, code: spec.code, deleted_at: null },
      select: { id: true },
    });

    const scalars = {
      name: spec.name,
      code: spec.code,
      category: spec.category,
      specimen_type: spec.specimen_type,
      result_kind: spec.result_kind,
      description: spec.description,
      unit: spec.unit,
      reference_range: spec.reference_range,
    };

    const children = {
      reference_ranges: {
        create: spec.reference_ranges.map((entry, index) => ({ ...entry, sort_order: index })),
      },
      unit_options: {
        create: spec.unit_options.map((entry, index) => ({ ...entry, sort_order: index })),
      },
      result_options: {
        create: spec.result_options.map((entry, index) => ({
          value: entry.value,
          label: entry.label,
          aliases_json: entry.aliases,
          status: entry.status,
          result_flag: entry.result_flag,
          is_positive: entry.is_positive,
          sort_order: index,
        })),
      },
    };

    if (existing) {
      summary.lab_tests_updated += 1;
      if (apply) {
        // Reference data is fully owned by the catalog, so replace the child
        // rows outright rather than trying to reconcile them one by one.
        await tx.lab_test.update({
          where: { id: existing.id },
          data: {
            ...scalars,
            reference_ranges: { deleteMany: {}, ...children.reference_ranges },
            unit_options: { deleteMany: {}, ...children.unit_options },
            result_options: { deleteMany: {}, ...children.result_options },
          },
        });
      }
      byCode.set(spec.key, existing.id);
      continue;
    }

    summary.lab_tests_created += 1;
    if (apply) {
      const created = await tx.lab_test.create({
        data: {
          tenant_id: tenantId,
          ...scalars,
          unit_price: priceFor(LAB_TEST_PRICES, spec.category, 15000),
          currency: CURRENCY,
          ...children,
        },
        select: { id: true },
      });
      byCode.set(spec.key, created.id);
    } else {
      byCode.set(spec.key, `dry-run:${spec.key}`);
    }
  }
  return byCode;
};

const refreshLabPanels = async (tx, tenantId, testIdsByKey, apply) => {
  for (const spec of LAB_PANEL_CATALOG) {
    const existing = await tx.lab_panel.findFirst({
      where: { tenant_id: tenantId, code: spec.code, deleted_at: null },
      select: { id: true },
    });

    const items = spec.test_keys
      .map((testKey, index) => {
        const labTestId = testIdsByKey.get(testKey);
        if (!labTestId) return null;
        return { lab_test_id: labTestId, is_required: true, instructions: null, sort_order: index };
      })
      .filter(Boolean);

    const scalars = {
      name: spec.name,
      code: spec.code,
      category: spec.category,
      description: spec.description,
    };

    if (existing) {
      summary.lab_panels_updated += 1;
      if (apply) {
        await tx.lab_panel.update({
          where: { id: existing.id },
          data: { ...scalars, panel_items: { deleteMany: {}, create: items } },
        });
      }
      continue;
    }

    summary.lab_panels_created += 1;
    if (apply) {
      await tx.lab_panel.create({
        data: {
          tenant_id: tenantId,
          ...scalars,
          unit_price: priceFor(LAB_PANEL_PRICES, spec.category, 50000),
          currency: CURRENCY,
          panel_items: { create: items },
        },
      });
    }
  }
};

const retirePanels = async (tx, tenantId, apply) => {
  const retired = await tx.lab_panel.findMany({
    where: { tenant_id: tenantId, code: { in: [...RETIRED_PANEL_CODES] }, deleted_at: null },
    select: { id: true, code: true },
  });
  if (retired.length === 0) return;

  const retiredIds = retired.map((panel) => panel.id);

  const offerings = await tx.facility_lab_panel_offering.count({
    where: { lab_panel_id: { in: retiredIds }, deleted_at: null, is_active: true },
  });

  summary.lab_panels_retired += retired.length;
  summary.panel_offerings_deactivated += offerings;

  if (!apply) return;

  // Stop the retired panels being orderable first, then soft-delete them. The
  // rows stay so historical lab_order_item joins still resolve a panel name.
  await tx.facility_lab_panel_offering.updateMany({
    where: { lab_panel_id: { in: retiredIds }, deleted_at: null },
    data: { is_active: false, deleted_at: new Date() },
  });
  await tx.lab_panel.updateMany({
    where: { id: { in: retiredIds } },
    data: { deleted_at: new Date() },
  });
};

const refreshRadiology = async (tx, tenantId, apply) => {
  for (const spec of RADIOLOGY_TEST_CATALOG) {
    const existing = await tx.radiology_procedure.findFirst({
      where: { tenant_id: tenantId, code: spec.code, deleted_at: null },
      select: { id: true },
    });

    const scalars = { name: spec.name, code: spec.code, modality: spec.modality };

    if (existing) {
      summary.radiology_updated += 1;
      if (apply) {
        await tx.radiology_procedure.update({ where: { id: existing.id }, data: scalars });
      }
      continue;
    }

    summary.radiology_created += 1;
    if (apply) {
      await tx.radiology_procedure.create({
        data: { tenant_id: tenantId, ...scalars, unit_price: 60000, currency: CURRENCY },
      });
    }
  }
};

const refreshDiagnoses = async (tx, tenantId, apply) => {
  for (const [index, term] of UGANDA_DIAGNOSIS_CATALOG.entries()) {
    const payload = {
      tenant_id: tenantId,
      facility_id: null,
      catalog_key: term.key,
      term_type: 'DIAGNOSIS',
      code: term.code || null,
      description: term.description,
      category: term.category || null,
      source: term.source,
      sort_order: index,
      usage_rank: term.rank,
      is_active: true,
      deleted_at: null,
    };

    const existing = await tx.clinical_term_catalog.findFirst({
      where: { tenant_id: tenantId, term_type: 'DIAGNOSIS', catalog_key: term.key },
      select: { id: true },
    });

    if (existing) {
      summary.diagnoses_updated += 1;
      if (apply) {
        await tx.clinical_term_catalog.update({ where: { id: existing.id }, data: payload });
      }
      continue;
    }

    summary.diagnoses_created += 1;
    if (apply) {
      await tx.clinical_term_catalog.create({ data: payload });
    }
  }
};

const refreshTenant = async (tenant, apply) => {
  console.log(`\n[tenant] ${tenant.name} (${tenant.id})`);
  // This runs as an operator task with no request context, so the tenant guard
  // has no tenant to scope by. Bypass it and pass tenant_id explicitly instead.
  await runWithoutTenantGuard(async () =>
    prisma.$transaction(
      async (tx) => {
        const testIdsByKey = await refreshLabTests(tx, tenant.id, apply);
        await refreshLabPanels(tx, tenant.id, testIdsByKey, apply);
        await retirePanels(tx, tenant.id, apply);
        await refreshRadiology(tx, tenant.id, apply);
        await refreshDiagnoses(tx, tenant.id, apply);
      },
      { timeout: 600000, maxWait: 30000 }
    )
  );
};

const main = async () => {
  const { apply, tenantId } = parseArgs(process.argv.slice(2));

  console.log(apply ? 'MODE: apply (writing changes)' : 'MODE: dry run (no writes) - pass --apply to commit');
  console.log(
    `catalog: ${LAB_TEST_CATALOG.length} lab tests, ${LAB_PANEL_CATALOG.length} panels, ` +
      `${RADIOLOGY_TEST_CATALOG.length} radiology procedures, ${UGANDA_DIAGNOSIS_CATALOG.length} diagnoses`
  );

  const tenants = await runWithoutTenantGuard(async () =>
    prisma.tenant.findMany({
      where: { deleted_at: null, ...(tenantId ? { id: tenantId } : {}) },
      select: { id: true, name: true },
      orderBy: { name: 'asc' },
    })
  );

  if (tenants.length === 0) {
    console.log('No tenants matched. Nothing to do.');
    return;
  }

  for (const tenant of tenants) {
    await refreshTenant(tenant, apply);
    summary.tenants += 1;
  }

  console.log('\n--- summary ---');
  Object.entries(summary).forEach(([key, value]) => {
    console.log(`  ${key.padEnd(30)} ${value}`);
  });
  if (!apply) {
    console.log('\nDry run only. Re-run with --apply to write these changes.');
  }
};

main()
  .catch((error) => {
    console.error('refresh-clinical-catalog failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
