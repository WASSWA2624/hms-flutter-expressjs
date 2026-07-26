const { DEMO_TENANTS } = require('./seed-catalog');
const {
  LAB_PANEL_CATALOG,
  LAB_TEST_CATALOG,
} = require('./data/uganda-lab-catalog');

const LAB_CATALOG_CURRENCY = 'UGX';

const resolveLabTestUnitPrice = (testSpec) => {
  const category = String(testSpec.category || '').trim().toUpperCase();
  const priceByCategory = {
    CHEMISTRY: 18000,
    HEMATOLOGY: 15000,
    'CRITICAL CARE': 25000,
    MICROBIOLOGY: 22000,
    SEROLOGY: 20000,
    IMMUNOLOGY: 24000,
    MOLECULAR: 45000,
    URINALYSIS: 12000,
    COAGULATION: 20000,
    ENDOCRINOLOGY: 28000,
    PARASITOLOGY: 18000,
    HISTOPATHOLOGY: 35000,
  };
  return priceByCategory[category] ?? 15000;
};

const resolveLabPanelUnitPrice = (panelSpec) => {
  // Independent panel list price by category — not derived from member tests.
  const category = String(panelSpec.category || '').trim().toUpperCase();
  const priceByCategory = {
    CHEMISTRY: 55000,
    HEMATOLOGY: 48000,
    'CRITICAL CARE': 75000,
    MICROBIOLOGY: 65000,
    SEROLOGY: 60000,
    IMMUNOLOGY: 70000,
    MOLECULAR: 120000,
    URINALYSIS: 35000,
    COAGULATION: 60000,
    ENDOCRINOLOGY: 80000,
    PARASITOLOGY: 55000,
    HISTOPATHOLOGY: 95000,
    CARDIOVASCULAR: 70000,
    RENAL: 65000,
    EMERGENCY: 75000,
    CARDIAC: 70000,
  };
  return priceByCategory[category] ?? 50000;
};

const buildNestedLabTestPayload = (testSpec, includeDeleteMany = false) => ({
  tenant_id: undefined,
  name: testSpec.name,
  code: testSpec.code,
  category: testSpec.category,
  specimen_type: testSpec.specimen_type,
  result_kind: testSpec.result_kind,
  description: testSpec.description,
  unit: testSpec.unit,
  reference_range: testSpec.reference_range,
  unit_price: testSpec.unit_price ?? resolveLabTestUnitPrice(testSpec),
  currency: testSpec.currency ?? LAB_CATALOG_CURRENCY,
  reference_ranges: {
    ...(includeDeleteMany ? { deleteMany: {} } : {}),
    create: testSpec.reference_ranges.map((entry, index) => ({
      ...entry,
      sort_order: index,
    })),
  },
  unit_options: {
    ...(includeDeleteMany ? { deleteMany: {} } : {}),
    create: testSpec.unit_options.map((entry, index) => ({
      ...entry,
      sort_order: index,
    })),
  },
  result_options: {
    ...(includeDeleteMany ? { deleteMany: {} } : {}),
    create: testSpec.result_options.map((entry, index) => ({
      value: entry.value,
      label: entry.label,
      aliases_json: entry.aliases,
      status: entry.status,
      result_flag: entry.result_flag,
      is_positive: entry.is_positive,
      sort_order: index,
    })),
  },
});

const seedLabCatalogForTenant = async (
  ctx,
  {
    seedKey,
    tenantId,
    tenantCode = null,
    scenarioKey = null,
  } = {}
) => {
  if (!tenantId || !seedKey) {
    return {
      tests: {},
      panels: {},
    };
  }

  const result = {
    tests: {},
    panels: {},
  };

  const testsByKey = {};
  for (const testSpec of LAB_TEST_CATALOG) {
    const createPayload = buildNestedLabTestPayload(testSpec, false);
    const updatePayload = buildNestedLabTestPayload(testSpec, true);
    createPayload.tenant_id = tenantId;
    updatePayload.tenant_id = tenantId;

    const record = await ctx.upsert(
      'lab_test',
      `${seedKey}:lab-catalog:${testSpec.key}`,
      createPayload,
      {
        createData: createPayload,
        updateData: updatePayload,
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'LBT',
      }
    );
    testsByKey[testSpec.key] = record;
    result.tests[testSpec.key] = record;
  }

  for (const panelSpec of LAB_PANEL_CATALOG) {
    const panelItems = panelSpec.test_keys
      .map((testKey, index) => {
        const testRecord = testsByKey[testKey];
        if (!testRecord?.id) return null;
        return {
          lab_test_id: testRecord.id,
          is_required: true,
          instructions: null,
          sort_order: index,
        };
      })
      .filter(Boolean);

    const record = await ctx.upsert(
      'lab_panel',
      `${seedKey}:lab-panel:${panelSpec.key}`,
      {
        tenant_id: tenantId,
        name: panelSpec.name,
        code: panelSpec.code,
        category: panelSpec.category,
        description: panelSpec.description,
        unit_price:
          panelSpec.unit_price ?? resolveLabPanelUnitPrice(panelSpec),
        currency: panelSpec.currency ?? LAB_CATALOG_CURRENCY,
        panel_items: {
          create: panelItems,
        },
      },
      {
        updateData: {
          tenant_id: tenantId,
          name: panelSpec.name,
          code: panelSpec.code,
          category: panelSpec.category,
          description: panelSpec.description,
          unit_price:
            panelSpec.unit_price ?? resolveLabPanelUnitPrice(panelSpec),
          currency: panelSpec.currency ?? LAB_CATALOG_CURRENCY,
          panel_items: {
            deleteMany: {},
            create: panelItems,
          },
        },
        tenantCode,
        scenarioKey,
        publicIdPrefix: 'LBP',
      }
    );
    result.panels[panelSpec.key] = record;
  }

  return result;
};

const seedLabCatalogPack = async (ctx, orgPack) => {
  const result = {
    tests: {},
    panels: {},
    summary: {
      tenants: 0,
      tests_per_tenant: LAB_TEST_CATALOG.length,
      panels_per_tenant: LAB_PANEL_CATALOG.length,
    },
  };

  for (const scenario of DEMO_TENANTS) {
    const tenant = orgPack.tenants[scenario.key];
    if (!tenant?.id) continue;

    const tenantResult = await seedLabCatalogForTenant(ctx, {
      seedKey: scenario.key,
      tenantId: tenant.id,
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
    });

    result.summary.tenants += 1;
    Object.entries(tenantResult.tests).forEach(([testKey, record]) => {
      result.tests[`${scenario.key}:${testKey}`] = record;
    });
    Object.entries(tenantResult.panels).forEach(([panelKey, record]) => {
      result.panels[`${scenario.key}:${panelKey}`] = record;
    });
  }

  return result;
};

module.exports = {
  LAB_PANEL_CATALOG,
  LAB_TEST_CATALOG,
  seedLabCatalogForTenant,
  seedLabCatalogPack,
};
