const { DEMO_TENANTS } = require('./seed-catalog');
const {
  LAB_PANEL_CATALOG,
  LAB_TEST_CATALOG,
} = require('./data/uganda-lab-catalog');

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
