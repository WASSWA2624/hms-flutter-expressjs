const {
  DEMO_ADD_ON_CATALOG,
  DEMO_CORE_MODULE_CATALOG,
  DEMO_PLAN_CATALOG,
  DEMO_TENANT,
} = require('./seed-catalog');

const PLAN_RANK = Object.freeze({
  FREE: 1,
  BASIC: 2,
  PRO: 3,
  ADVANCED: 4,
  CUSTOM: 5,
});

const DEMO_SUBSCRIPTION_PROFILE = Object.freeze({
  status: 'ACTIVE',
  change_status: 'NONE',
  plan_fit_status: 'HEALTHY',
  storage_used_mb: 16800,
});

const buildPlanPolicies = (definition) => ({
  patient_limits: definition.code === 'free' ? { new_patients_per_day: 5 } : { new_patients_per_day: null },
  branding_enabled: definition.code !== 'free',
  exports_enabled: definition.code !== 'free',
});

const buildEligibilityMap = () =>
  DEMO_ADD_ON_CATALOG.reduce((acc, addOn) => {
    acc[addOn.code] = {
      minimum_plan_tier_code: addOn.minimum_plan_tier_code,
      eligible: true,
    };
    return acc;
  }, {});

const isEligibleForTier = (tierCode, minimumTierCode) =>
  (PLAN_RANK[tierCode] || 0) >= (PLAN_RANK[minimumTierCode] || 0);

const seedSubscriptionsPack = async (ctx, orgPack) => {
  const result = {
    plans: {},
    modules: {},
    subscriptions: {},
    licenses: {},
  };

  for (const planDefinition of DEMO_PLAN_CATALOG) {
    const plan = await ctx.upsert(
      'subscription_plan',
      `plan:${planDefinition.code}`,
      {
        tenant_id: null,
        code: planDefinition.code,
        name: planDefinition.name,
        tier_code: planDefinition.tier_code,
        price: planDefinition.price,
        billing_cycle: planDefinition.billing_cycle,
        max_users: planDefinition.max_users,
        max_facilities: planDefinition.max_facilities,
        max_storage_mb: planDefinition.max_storage_mb,
        max_modules: planDefinition.max_modules,
        plan_fit_warning_percent: 80,
        limit_policy_json: buildPlanPolicies(planDefinition),
        add_on_eligibility_json: buildEligibilityMap(),
        extension_json: planDefinition.extension_json,
      },
      {
        tenantCode: 'GLOBAL',
        scenarioKey: 'CATALOG',
        publicIdPrefix: 'SPLAN',
      }
    );
    result.plans[planDefinition.code] = plan;
  }

  const allModuleDefinitions = [
    ...DEMO_CORE_MODULE_CATALOG.map((definition) => ({ ...definition, is_add_on: false })),
    ...DEMO_ADD_ON_CATALOG.map((definition) => ({ ...definition, is_add_on: true })),
  ];

  for (const moduleDefinition of allModuleDefinitions) {
    const module = await ctx.upsert(
      'module',
      `module:${moduleDefinition.code}`,
      {
        name: moduleDefinition.name,
        slug: moduleDefinition.slug,
        description: `${moduleDefinition.name} demo module`,
        module_group: moduleDefinition.module_group,
        minimum_plan_tier_code: moduleDefinition.minimum_plan_tier_code,
        is_add_on: Boolean(moduleDefinition.is_add_on),
        add_on_price: moduleDefinition.add_on_price || null,
        add_on_billing_cycle: moduleDefinition.add_on_billing_cycle || null,
        entitlement_policy_json: {
          minimum_plan_tier_code: moduleDefinition.minimum_plan_tier_code,
        },
        extension_json: moduleDefinition.extension_json || null,
      },
      {
        tenantCode: 'GLOBAL',
        scenarioKey: 'CATALOG',
        publicIdPrefix: 'MOD',
      }
    );
    result.modules[moduleDefinition.code] = module;
  }

  const scenario = DEMO_TENANT;
  const tenant = orgPack.tenants[scenario.key];
  const plan = result.plans[scenario.primary_plan_code];
  const activeModules = allModuleDefinitions.filter((entry) =>
    isEligibleForTier(plan.tier_code, entry.minimum_plan_tier_code)
  );

  const subscription = await ctx.upsert(
    'subscription',
    `${scenario.key}:subscription`,
    {
      tenant_id: tenant.id,
      plan_id: plan.id,
      pending_plan_id: null,
      status: DEMO_SUBSCRIPTION_PROFILE.status,
      change_status: DEMO_SUBSCRIPTION_PROFILE.change_status,
      start_date: ctx.date(-60),
      end_date: ctx.date(305),
      change_requested_at: null,
      change_effective_at: null,
      proration_amount: null,
      proration_currency_code: null,
      users_used: scenario.users.length,
      facilities_used: scenario.facilities.length,
      storage_used_mb: DEMO_SUBSCRIPTION_PROFILE.storage_used_mb,
      modules_used: activeModules.length,
      plan_fit_status: DEMO_SUBSCRIPTION_PROFILE.plan_fit_status,
      plan_fit_evaluated_at: ctx.date(-1),
      entitlement_snapshot_json: {
        tenant_plan_code: scenario.primary_plan_code,
        included_groups: activeModules.map((entry) => entry.module_group),
        single_tenant_demo: true,
      },
      extension_json: {
        workspace_mode: 'single_tenant_demo',
        seeded_roles: scenario.users.flatMap((entry) => [
          entry.role,
          ...((Array.isArray(entry.extra_roles) ? entry.extra_roles : []).filter(Boolean)),
        ]),
      },
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'SUB',
    }
  );
  result.subscriptions[scenario.key] = subscription;

  for (const moduleDefinition of allModuleDefinitions) {
    const moduleRecord = result.modules[moduleDefinition.code];
    const eligible = isEligibleForTier(plan.tier_code, moduleDefinition.minimum_plan_tier_code);

    await ctx.upsert(
      'module_subscription',
      `${scenario.key}:module-subscription:${moduleDefinition.code}`,
      {
        module_id: moduleRecord.id,
        subscription_id: subscription.id,
        is_active: eligible,
        entitlement_denied: !eligible,
        entitlement_denial_reason: eligible ? null : `Requires ${moduleDefinition.minimum_plan_tier_code} plan`,
        evaluated_plan_fit_status: DEMO_SUBSCRIPTION_PROFILE.plan_fit_status,
        eligibility_checked_at: ctx.date(-1, 10),
        activation_requested_at: ctx.date(-20),
        activated_at: eligible ? ctx.date(-18) : null,
        extension_json: moduleDefinition.is_add_on
          ? {
              add_on_code: moduleDefinition.code,
              activation_state: eligible ? 'ALLOWED' : 'DENIED',
            }
          : null,
      },
      {
        tenantCode: scenario.tenant_code,
        scenarioKey: scenario.scenario_key,
        publicIdPrefix: 'MSUB',
      }
    );
  }

  const invoice = await ctx.upsert(
    'invoice',
    `${scenario.key}:subscription-invoice:invoice`,
    {
      tenant_id: tenant.id,
      facility_id: null,
      patient_id: null,
      status: 'PAID',
      billing_status: 'PAID',
      total_amount: Number(plan.price),
      currency: 'USD',
      issued_at: ctx.date(-7),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'INV',
    }
  );

  await ctx.upsert(
    'subscription_invoice',
    `${scenario.key}:subscription-invoice`,
    {
      subscription_id: subscription.id,
      invoice_id: invoice.id,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'SINV',
    }
  );

  await ctx.upsert(
    'invoice_item',
    `${scenario.key}:subscription-invoice:item`,
    {
      invoice_id: invoice.id,
      description: `${plan.name} ${plan.billing_cycle.toLowerCase()} subscription`,
      quantity: 1,
      unit_price: Number(plan.price),
      total_price: Number(plan.price),
    },
    {
      publicIdPrefix: 'IITM',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'payment',
    `${scenario.key}:subscription-payment`,
    {
      tenant_id: tenant.id,
      facility_id: null,
      patient_id: null,
      invoice_id: invoice.id,
      status: 'COMPLETED',
      method: 'BANK_TRANSFER',
      amount: Number(plan.price),
      paid_at: ctx.date(-5),
      transaction_ref: `TX-${ctx.hash(`${scenario.key}:subscription-payment`).slice(0, 10).toUpperCase()}`,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'PAY',
    }
  );

  const license = await ctx.upsert(
    'license',
    `${scenario.key}:license`,
    {
      tenant_id: tenant.id,
      license_type: 'PER_FACILITY',
      status: 'ACTIVE',
      plan_tier_code: plan.tier_code,
      entitlement_snapshot_json: {
        plan_code: plan.code,
        active_modules: activeModules.map((entry) => entry.code),
        facility_scope: 'single_demo_facility',
      },
      issued_at: ctx.date(-45),
      expires_at: ctx.date(365),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'LIC',
    }
  );
  result.licenses[scenario.key] = license;

  await ctx.upsert(
    'configuration_snapshot',
    `${scenario.key}:subscription-snapshot:v1`,
    {
      tenant_id: tenant.id,
      resource_type: 'subscription',
      resource_id: subscription.id,
      configuration_version: 1,
      snapshot_json: {
        plan_code: plan.code,
        status: DEMO_SUBSCRIPTION_PROFILE.status,
        sync_mode: 'normal',
      },
      checksum: ctx.hash(`${scenario.key}:subscription:snapshot:1`),
      is_immutable: true,
      created_by_user_id: null,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'CFG',
    }
  );

  await ctx.upsert(
    'configuration_snapshot',
    `${scenario.key}:subscription-snapshot:v2`,
    {
      tenant_id: tenant.id,
      resource_type: 'subscription',
      resource_id: subscription.id,
      configuration_version: 2,
      snapshot_json: {
        plan_code: plan.code,
        sync_mode: 'normal',
        clinical_data_profile: 'single_hospital_demo',
      },
      checksum: ctx.hash(`${scenario.key}:subscription:snapshot:2`),
      is_immutable: true,
      created_by_user_id: null,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'CFG',
    }
  );

  return result;
};

module.exports = {
  seedSubscriptionsPack,
};
