/**
 * Phase 12 supplemental seed pack
 *
 * Adds canonical commercial/compliance/offline scenarios required by P012.
 */

const crypto = require('crypto');
const prisma = require('@prisma/client');
const {
  HMS_SEED_MODEL_ORDER,
  SEED_CANONICAL_PLAN_DEFINITIONS,
  SEED_ADD_ON_CATALOG,
  SEED_FREE_CORE_MODULE_CATALOG
} = require('@config/constants');

const PLAN_TIER_ORDER = ['FREE', 'BASIC', 'PRO', 'ADVANCED', 'CUSTOM'];
const DETERMINISTIC_BASE_TIMESTAMP = Date.UTC(2026, 0, 1, 8, 0, 0);

const defaultMissingTableCheck = (error) => error?.code === 'P2021';

const normalizeTierCode = (tierCode) => {
  const normalized = String(tierCode || '').trim().toUpperCase();
  return PLAN_TIER_ORDER.includes(normalized) ? normalized : null;
};

const tierMeetsMinimum = (tierCode, minimumTier) => {
  const currentIndex = PLAN_TIER_ORDER.indexOf(normalizeTierCode(tierCode));
  const minimumIndex = PLAN_TIER_ORDER.indexOf(normalizeTierCode(minimumTier));
  if (currentIndex === -1 || minimumIndex === -1) {
    return false;
  }
  return currentIndex >= minimumIndex;
};

const deterministicHashHex = (value) =>
  crypto.createHash('sha256').update(String(value || '')).digest('hex');

const deterministicUuid = (value, randomSeed) => {
  const hex = deterministicHashHex(`${randomSeed}:${value}`);
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    `4${hex.slice(13, 16)}`,
    `a${hex.slice(17, 20)}`,
    hex.slice(20, 32)
  ].join('-');
};

const getDeterministicDate = (randomSeed, sequence = 0, minuteOffset = 0) => {
  const seedOffsetMs = (Math.abs(Number(randomSeed) || 20260217) % 100000) * 1000;
  const sequenceOffsetMs = (Number(sequence) + Number(minuteOffset)) * 60 * 1000;
  return new Date(DETERMINISTIC_BASE_TIMESTAMP + seedOffsetMs + sequenceOffsetMs);
};

const resolveSeedExecutionOrder = (orderedModels, preferredModels = HMS_SEED_MODEL_ORDER) => {
  const orderedSet = new Set(orderedModels);
  const preferred = (preferredModels || []).filter((modelName) => orderedSet.has(modelName));
  const seen = new Set(preferred);
  const remainder = orderedModels.filter((modelName) => !seen.has(modelName));
  return [...preferred, ...remainder];
};

const safeModelCall = async (modelName, method, args, isMissingTableError) => {
  const delegate = prisma[modelName];
  if (!delegate || typeof delegate[method] !== 'function') {
    return null;
  }

  try {
    return await delegate[method](args);
  } catch (error) {
    if ((isMissingTableError || defaultMissingTableCheck)(error)) {
      return null;
    }
    throw error;
  }
};

const ensureScenarioPatient = async ({ tenantId, facilityId, randomSeed, isMissingTableError }) => {
  const existingPatient = await safeModelCall(
    'patient',
    'findFirst',
    {
      where: { tenant_id: tenantId, deleted_at: null },
      orderBy: { created_at: 'asc' }
    },
    isMissingTableError
  );

  if (existingPatient) {
    return existingPatient;
  }

  return safeModelCall(
    'patient',
    'create',
    {
      data: {
        id: deterministicUuid(`seed:patient:${tenantId}`, randomSeed),
        tenant_id: tenantId,
        facility_id: facilityId || null,
        first_name: 'Seed',
        last_name: 'Patient',
        gender: 'OTHER',
        is_active: true
      }
    },
    isMissingTableError
  );
};

const getSeedReferences = async ({ randomSeed, isMissingTableError }) => {
  const tenant = await safeModelCall(
    'tenant',
    'findFirst',
    {
      where: { deleted_at: null },
      orderBy: { created_at: 'asc' }
    },
    isMissingTableError
  );

  if (!tenant) {
    return null;
  }

  const facility = await safeModelCall(
    'facility',
    'findFirst',
    {
      where: { tenant_id: tenant.id, deleted_at: null },
      orderBy: { created_at: 'asc' }
    },
    isMissingTableError
  );

  const user = await safeModelCall(
    'user',
    'findFirst',
    {
      where: { tenant_id: tenant.id, deleted_at: null },
      orderBy: { created_at: 'asc' }
    },
    isMissingTableError
  );

  const patient = await ensureScenarioPatient({
    tenantId: tenant.id,
    facilityId: facility?.id || null,
    randomSeed,
    isMissingTableError
  });

  return { tenant, facility, user, patient };
};

const buildAddOnEligibilityByTier = (tierCode) =>
  SEED_ADD_ON_CATALOG.reduce((acc, addOn) => {
    acc[addOn.code] = {
      minimum_tier: addOn.minimum_plan_tier_code,
      eligible: tierMeetsMinimum(tierCode, addOn.minimum_plan_tier_code)
    };
    return acc;
  }, {});

const upsertCanonicalPlans = async ({ refs, randomSeed, isMissingTableError }) => {
  const plansByCode = {};

  for (const definition of SEED_CANONICAL_PLAN_DEFINITIONS) {
    const tierCode = normalizeTierCode(definition.tier_code);
    const addOnEligibility = buildAddOnEligibilityByTier(tierCode);

    const payload = {
      tenant_id: refs.tenant.id,
      code: definition.code,
      name: definition.name,
      tier_code: definition.tier_code,
      price: definition.price,
      billing_cycle: definition.billing_cycle,
      max_users: definition.max_users,
      max_facilities: definition.max_facilities,
      max_storage_mb: definition.max_storage_mb,
      max_modules: definition.max_modules,
      plan_fit_warning_percent: 80,
      limit_policy_json: {
        warning_percent: 80,
        upgrade_trigger_percent: 100,
        downgrade_review_percent: 50,
        downgrade_review_days: 90,
        daily_patient_cap: definition.code === 'free' ? 5 : null
      },
      add_on_eligibility_json: addOnEligibility,
      extension_json: {
        seed_pack: 'phase_012',
        canonical_tier: definition.code
      }
    };

    const plan = await safeModelCall(
      'subscription_plan',
      'upsert',
      {
        where: {
          tenant_id_code: {
            tenant_id: refs.tenant.id,
            code: definition.code
          }
        },
        update: payload,
        create: {
          id: deterministicUuid(`seed:plan:${refs.tenant.id}:${definition.code}`, randomSeed),
          ...payload
        }
      },
      isMissingTableError
    );

    if (plan) {
      plansByCode[definition.code] = plan;
    }
  }

  return plansByCode;
};

const upsertEntitlementModules = async ({ randomSeed, isMissingTableError }) => {
  const catalog = [
    ...SEED_FREE_CORE_MODULE_CATALOG.map((item) => ({
      ...item,
      minimum_plan_tier_code: 'FREE',
      is_add_on: false,
      add_on_price: null,
      add_on_billing_cycle: null
    })),
    ...SEED_ADD_ON_CATALOG.map((item) => ({
      ...item,
      is_add_on: true
    }))
  ];

  const modulesByCode = {};

  for (const spec of catalog) {
    const moduleRecord = await safeModelCall(
      'module',
      'upsert',
      {
        where: { slug: spec.slug },
        update: {
          name: spec.name,
          slug: spec.slug,
          description: `${spec.name} entitlement scenario seed`,
          module_group: spec.module_group,
          minimum_plan_tier_code: spec.minimum_plan_tier_code || null,
          is_add_on: Boolean(spec.is_add_on),
          add_on_price: spec.add_on_price,
          add_on_billing_cycle: spec.add_on_billing_cycle,
          entitlement_policy_json: {
            seed_pack: 'phase_012',
            add_on_code: spec.code,
            minimum_plan_tier_code: spec.minimum_plan_tier_code || 'FREE'
          }
        },
        create: {
          id: deterministicUuid(`seed:module:${spec.slug}`, randomSeed),
          name: spec.name,
          slug: spec.slug,
          description: `${spec.name} entitlement scenario seed`,
          module_group: spec.module_group,
          minimum_plan_tier_code: spec.minimum_plan_tier_code || null,
          is_add_on: Boolean(spec.is_add_on),
          add_on_price: spec.add_on_price,
          add_on_billing_cycle: spec.add_on_billing_cycle,
          entitlement_policy_json: {
            seed_pack: 'phase_012',
            add_on_code: spec.code,
            minimum_plan_tier_code: spec.minimum_plan_tier_code || 'FREE'
          }
        }
      },
      isMissingTableError
    );

    if (moduleRecord) {
      modulesByCode[spec.code] = moduleRecord;
    }
  }

  return modulesByCode;
};

const upsertScenarioSubscriptions = async ({ refs, plansByCode, randomSeed, isMissingTableError }) => {
  const scenarioDefinitions = [
    { key: 'free_healthy', plan_code: 'free', plan_fit_status: 'HEALTHY', users: 1, facilities: 1, storage: 120, modules: 4, recommendation: 'keep_current_plan', change_status: 'NONE' },
    { key: 'basic_approaching_limit', plan_code: 'basic', plan_fit_status: 'APPROACHING_LIMIT', users: 4, facilities: 1, storage: 4350, modules: 16, recommendation: 'upgrade_recommended', change_status: 'PENDING_UPGRADE' },
    { key: 'basic_exceeded', plan_code: 'basic', plan_fit_status: 'EXCEEDED', users: 7, facilities: 3, storage: 6200, modules: 28, recommendation: 'upgrade_required', change_status: 'PENDING_UPGRADE' },
    { key: 'pro_downgrade_review', plan_code: 'pro', plan_fit_status: 'HEALTHY', users: 3, facilities: 1, storage: 2600, modules: 12, recommendation: 'downgrade_review', change_status: 'PENDING_DOWNGRADE' },
    { key: 'custom_healthy', plan_code: 'custom', plan_fit_status: 'HEALTHY', users: 25, facilities: 6, storage: 68000, modules: 120, recommendation: 'keep_current_plan', change_status: 'NONE' }
  ];

  const subscriptionsByScenario = {};

  for (let index = 0; index < scenarioDefinitions.length; index += 1) {
    const scenario = scenarioDefinitions[index];
    const plan = plansByCode[scenario.plan_code];
    if (!plan) continue;

    const pendingUpgradePlan = plansByCode.pro || plan;
    const pendingDowngradePlan = plansByCode.basic || plan;
    const pendingPlanId = scenario.change_status === 'PENDING_UPGRADE'
      ? pendingUpgradePlan.id
      : scenario.change_status === 'PENDING_DOWNGRADE'
        ? pendingDowngradePlan.id
        : null;

    const record = await safeModelCall(
      'subscription',
      'upsert',
      {
        where: { id: deterministicUuid(`seed:subscription:${refs.tenant.id}:${scenario.key}`, randomSeed) },
        update: {
          tenant_id: refs.tenant.id,
          plan_id: plan.id,
          pending_plan_id: pendingPlanId,
          status: 'ACTIVE',
          change_status: scenario.change_status,
          change_requested_at: scenario.change_status === 'NONE' ? null : getDeterministicDate(randomSeed, 200 + index * 4),
          change_effective_at: scenario.change_status === 'NONE' ? null : getDeterministicDate(randomSeed, 220 + index * 4),
          proration_amount: scenario.change_status === 'NONE' ? null : 25.5,
          proration_currency_code: 'USD',
          users_used: scenario.users,
          facilities_used: scenario.facilities,
          storage_used_mb: scenario.storage,
          modules_used: scenario.modules,
          plan_fit_status: scenario.plan_fit_status,
          plan_fit_evaluated_at: getDeterministicDate(randomSeed, 240 + index * 4),
          entitlement_snapshot_json: {
            seed_pack: 'phase_012',
            scenario: scenario.key,
            recommendation: scenario.recommendation
          },
          extension_json: {
            downgrade_review_candidate: scenario.recommendation === 'downgrade_review',
            low_utilization_window_days: scenario.recommendation === 'downgrade_review' ? 120 : null
          },
          etag: deterministicHashHex(`seed:subscription:etag:${scenario.key}:${randomSeed}`)
        },
        create: {
          id: deterministicUuid(`seed:subscription:${refs.tenant.id}:${scenario.key}`, randomSeed),
          tenant_id: refs.tenant.id,
          plan_id: plan.id,
          pending_plan_id: pendingPlanId,
          status: 'ACTIVE',
          change_status: scenario.change_status,
          start_date: getDeterministicDate(randomSeed, 160 + index * 5),
          end_date: getDeterministicDate(randomSeed, 380 + index * 9),
          change_requested_at: scenario.change_status === 'NONE' ? null : getDeterministicDate(randomSeed, 200 + index * 4),
          change_effective_at: scenario.change_status === 'NONE' ? null : getDeterministicDate(randomSeed, 220 + index * 4),
          proration_amount: scenario.change_status === 'NONE' ? null : 25.5,
          proration_currency_code: 'USD',
          users_used: scenario.users,
          facilities_used: scenario.facilities,
          storage_used_mb: scenario.storage,
          modules_used: scenario.modules,
          plan_fit_status: scenario.plan_fit_status,
          plan_fit_evaluated_at: getDeterministicDate(randomSeed, 240 + index * 4),
          entitlement_snapshot_json: {
            seed_pack: 'phase_012',
            scenario: scenario.key,
            recommendation: scenario.recommendation
          },
          extension_json: {
            downgrade_review_candidate: scenario.recommendation === 'downgrade_review',
            low_utilization_window_days: scenario.recommendation === 'downgrade_review' ? 120 : null
          },
          etag: deterministicHashHex(`seed:subscription:etag:${scenario.key}:${randomSeed}`)
        }
      },
      isMissingTableError
    );

    if (record) {
      subscriptionsByScenario[scenario.key] = {
        ...record,
        seed_plan_tier_code: plan.tier_code
      };
    }
  }

  return subscriptionsByScenario;
};

const upsertScenarioModuleSubscriptions = async ({
  modulesByCode,
  subscriptionsByScenario,
  randomSeed,
  isMissingTableError
}) => {
  const scenarios = [
    { key: 'free_core_allowed', module_code: 'patient_registry_basic', subscription_key: 'free_healthy' },
    { key: 'free_denied_paid_addon', module_code: 'inventory_procurement_lite', subscription_key: 'free_healthy' },
    { key: 'basic_addon_allowed', module_code: 'inventory_procurement_lite', subscription_key: 'basic_approaching_limit' },
    { key: 'basic_denied_pro_addon', module_code: 'biomedical_engineering_suite', subscription_key: 'basic_approaching_limit' },
    { key: 'pro_addon_allowed', module_code: 'biomedical_engineering_suite', subscription_key: 'pro_downgrade_review' },
    { key: 'exceeded_upgrade_required', module_code: 'integrations_webhooks_pack', subscription_key: 'basic_exceeded' },
    { key: 'custom_integrations_allowed', module_code: 'integrations_webhooks_pack', subscription_key: 'custom_healthy' }
  ];

  const moduleSubscriptionIds = {};

  for (let index = 0; index < scenarios.length; index += 1) {
    const scenario = scenarios[index];
    const moduleRecord = modulesByCode[scenario.module_code];
    const subscription = subscriptionsByScenario[scenario.subscription_key];
    if (!moduleRecord || !subscription) continue;

    const planTier = normalizeTierCode(subscription.seed_plan_tier_code || subscription.plan?.tier_code);
    const minimumTier = normalizeTierCode(moduleRecord.minimum_plan_tier_code || 'FREE');
    const eligible = tierMeetsMinimum(planTier || 'FREE', minimumTier || 'FREE');
    const denialReason = eligible ? null : `requires_${minimumTier}`;
    const checkTime = getDeterministicDate(randomSeed, 500 + index * 3);

    const record = await safeModelCall(
      'module_subscription',
      'upsert',
      {
        where: {
          module_id_subscription_id: {
            module_id: moduleRecord.id,
            subscription_id: subscription.id
          }
        },
        update: {
          is_active: eligible,
          entitlement_denied: !eligible,
          entitlement_denial_reason: denialReason,
          evaluated_plan_fit_status: subscription.plan_fit_status,
          eligibility_checked_at: checkTime,
          activation_requested_at: checkTime,
          activated_at: eligible ? checkTime : null,
          deactivated_at: eligible ? null : checkTime,
          extension_json: { seed_pack: 'phase_012', scenario: scenario.key },
          etag: deterministicHashHex(`seed:module-subscription:${scenario.key}:${randomSeed}`)
        },
        create: {
          id: deterministicUuid(`seed:module-subscription:${scenario.key}`, randomSeed),
          module_id: moduleRecord.id,
          subscription_id: subscription.id,
          is_active: eligible,
          entitlement_denied: !eligible,
          entitlement_denial_reason: denialReason,
          evaluated_plan_fit_status: subscription.plan_fit_status,
          eligibility_checked_at: checkTime,
          activation_requested_at: checkTime,
          activated_at: eligible ? checkTime : null,
          deactivated_at: eligible ? null : checkTime,
          extension_json: { seed_pack: 'phase_012', scenario: scenario.key },
          etag: deterministicHashHex(`seed:module-subscription:${scenario.key}:${randomSeed}`)
        }
      },
      isMissingTableError
    );

    if (record) {
      moduleSubscriptionIds[scenario.key] = record.id;
    }
  }

  return moduleSubscriptionIds;
};

const upsertScenarioLicenses = async ({
  refs,
  plansByCode,
  randomSeed,
  isMissingTableError
}) => {
  const typeByTier = {
    FREE: 'PER_USER',
    BASIC: 'PER_USER',
    PRO: 'PER_FACILITY',
    ADVANCED: 'ENTERPRISE',
    CUSTOM: 'ENTERPRISE'
  };

  for (const definition of SEED_CANONICAL_PLAN_DEFINITIONS) {
    const plan = plansByCode[definition.code];
    if (!plan) continue;

    const tierCode = normalizeTierCode(definition.tier_code);
    await safeModelCall(
      'license',
      'upsert',
      {
        where: {
          id: deterministicUuid(`seed:license:${refs.tenant.id}:${definition.code}`, randomSeed)
        },
        update: {
          tenant_id: refs.tenant.id,
          license_type: typeByTier[tierCode] || 'PER_USER',
          status: 'ACTIVE',
          plan_tier_code: tierCode,
          issued_at: getDeterministicDate(randomSeed, 610),
          expires_at: tierCode === 'CUSTOM' ? null : getDeterministicDate(randomSeed, 610, 60 * 24 * 365),
          entitlement_snapshot_json: {
            seed_pack: 'phase_012',
            tier_code: tierCode,
            add_ons: buildAddOnEligibilityByTier(tierCode)
          }
        },
        create: {
          id: deterministicUuid(`seed:license:${refs.tenant.id}:${definition.code}`, randomSeed),
          tenant_id: refs.tenant.id,
          license_type: typeByTier[tierCode] || 'PER_USER',
          status: 'ACTIVE',
          plan_tier_code: tierCode,
          issued_at: getDeterministicDate(randomSeed, 610),
          expires_at: tierCode === 'CUSTOM' ? null : getDeterministicDate(randomSeed, 610, 60 * 24 * 365),
          entitlement_snapshot_json: {
            seed_pack: 'phase_012',
            tier_code: tierCode,
            add_ons: buildAddOnEligibilityByTier(tierCode)
          }
        }
      },
      isMissingTableError
    );
  }
};

const upsertScenarioFinancialEvents = async ({
  refs,
  subscriptionsByScenario,
  randomSeed,
  isMissingTableError
}) => {
  const invoiceScenarios = [
    { key: 'basic_approaching_limit', amount: 39, invoice_status: 'PAID', billing_status: 'PAID' },
    { key: 'basic_exceeded', amount: 89, invoice_status: 'OVERDUE', billing_status: 'PARTIAL' },
    { key: 'pro_downgrade_review', amount: 89, invoice_status: 'PAID', billing_status: 'PAID' }
  ];

  for (let index = 0; index < invoiceScenarios.length; index += 1) {
    const scenario = invoiceScenarios[index];
    const subscription = subscriptionsByScenario[scenario.key];
    if (!subscription) continue;

    const invoiceId = deterministicUuid(`seed:invoice:${scenario.key}`, randomSeed);
    const invoice = await safeModelCall(
      'invoice',
      'upsert',
      {
        where: { id: invoiceId },
        update: {
          tenant_id: refs.tenant.id,
          facility_id: refs.facility?.id || null,
          patient_id: refs.patient?.id || null,
          status: scenario.invoice_status,
          billing_status: scenario.billing_status,
          total_amount: scenario.amount,
          currency: 'USD',
          issued_at: getDeterministicDate(randomSeed, 700 + index * 5)
        },
        create: {
          id: invoiceId,
          tenant_id: refs.tenant.id,
          facility_id: refs.facility?.id || null,
          patient_id: refs.patient?.id || null,
          status: scenario.invoice_status,
          billing_status: scenario.billing_status,
          total_amount: scenario.amount,
          currency: 'USD',
          issued_at: getDeterministicDate(randomSeed, 700 + index * 5)
        }
      },
      isMissingTableError
    );

    if (!invoice) continue;

    await safeModelCall(
      'invoice_item',
      'upsert',
      {
        where: { id: deterministicUuid(`seed:invoice-item:${scenario.key}`, randomSeed) },
        update: {
          invoice_id: invoice.id,
          description: `Subscription charge (${scenario.key})`,
          quantity: 1,
          unit_price: scenario.amount,
          total_price: scenario.amount
        },
        create: {
          id: deterministicUuid(`seed:invoice-item:${scenario.key}`, randomSeed),
          invoice_id: invoice.id,
          description: `Subscription charge (${scenario.key})`,
          quantity: 1,
          unit_price: scenario.amount,
          total_price: scenario.amount
        }
      },
      isMissingTableError
    );

    const paymentStatus = scenario.key === 'basic_exceeded' ? 'PENDING' : 'COMPLETED';
    const payment = await safeModelCall(
      'payment',
      'upsert',
      {
        where: { id: deterministicUuid(`seed:payment:${scenario.key}`, randomSeed) },
        update: {
          tenant_id: refs.tenant.id,
          facility_id: refs.facility?.id || null,
          patient_id: refs.patient?.id || null,
          invoice_id: invoice.id,
          status: paymentStatus,
          method: 'BANK_TRANSFER',
          amount: scenario.amount,
          paid_at: paymentStatus === 'COMPLETED' ? getDeterministicDate(randomSeed, 710 + index * 5) : null,
          transaction_ref: `SEED-${scenario.key.toUpperCase()}`
        },
        create: {
          id: deterministicUuid(`seed:payment:${scenario.key}`, randomSeed),
          tenant_id: refs.tenant.id,
          facility_id: refs.facility?.id || null,
          patient_id: refs.patient?.id || null,
          invoice_id: invoice.id,
          status: paymentStatus,
          method: 'BANK_TRANSFER',
          amount: scenario.amount,
          paid_at: paymentStatus === 'COMPLETED' ? getDeterministicDate(randomSeed, 710 + index * 5) : null,
          transaction_ref: `SEED-${scenario.key.toUpperCase()}`
        }
      },
      isMissingTableError
    );

    if (payment && scenario.key === 'pro_downgrade_review') {
      await safeModelCall(
        'refund',
        'upsert',
        {
          where: { id: deterministicUuid(`seed:refund:${scenario.key}`, randomSeed) },
          update: {
            payment_id: payment.id,
            amount: 10,
            refunded_at: getDeterministicDate(randomSeed, 712 + index * 5),
            reason: 'Plan fit credit adjustment'
          },
          create: {
            id: deterministicUuid(`seed:refund:${scenario.key}`, randomSeed),
            payment_id: payment.id,
            amount: 10,
            refunded_at: getDeterministicDate(randomSeed, 712 + index * 5),
            reason: 'Plan fit credit adjustment'
          }
        },
        isMissingTableError
      );
    }

    await safeModelCall(
      'subscription_invoice',
      'upsert',
      {
        where: {
          subscription_id_invoice_id: {
            subscription_id: subscription.id,
            invoice_id: invoice.id
          }
        },
        update: {
          subscription_id: subscription.id,
          invoice_id: invoice.id
        },
        create: {
          id: deterministicUuid(`seed:subscription-invoice:${scenario.key}`, randomSeed),
          subscription_id: subscription.id,
          invoice_id: invoice.id
        }
      },
      isMissingTableError
    );
  }
};

const upsertScenarioComplianceAndOfflineRecords = async ({
  refs,
  subscriptionsByScenario,
  moduleSubscriptionIds,
  randomSeed,
  isMissingTableError
}) => {
  const referenceSubscription =
    subscriptionsByScenario.basic_exceeded || subscriptionsByScenario.basic_approaching_limit;
  const referenceSubscriptionId =
    referenceSubscription?.id || deterministicUuid('seed:fallback:subscription', randomSeed);
  const referenceModuleSubscriptionId =
    moduleSubscriptionIds.exceeded_upgrade_required || deterministicUuid('seed:fallback:module-subscription', randomSeed);

  const auditPayloads = [
    {
      suffix: 'subscription',
      action: 'UPDATE',
      entity: 'subscription',
      entity_id: referenceSubscriptionId,
      diff_json: {
        seed_pack: 'phase_012',
        scenario: 'upgrade_required',
        field: 'plan_fit_status',
        to: 'EXCEEDED'
      }
    },
    {
      suffix: 'biomedical',
      action: 'UPDATE',
      entity: 'equipment_work_order',
      entity_id: deterministicUuid('seed:biomed:work-order', randomSeed),
      diff_json: {
        seed_pack: 'phase_012',
        scenario: 'biomedical_action',
        status: 'IN_PROGRESS'
      }
    }
  ];

  for (const payload of auditPayloads) {
    await safeModelCall(
      'audit_log',
      'upsert',
      {
        where: {
          id: deterministicUuid(`seed:audit:${payload.suffix}:${refs.tenant.id}`, randomSeed)
        },
        update: {
          tenant_id: refs.tenant.id,
          user_id: refs.user?.id || null,
          action: payload.action,
          entity: payload.entity,
          entity_id: payload.entity_id,
          diff_json: payload.diff_json,
          ip_address: '10.12.0.10'
        },
        create: {
          id: deterministicUuid(`seed:audit:${payload.suffix}:${refs.tenant.id}`, randomSeed),
          tenant_id: refs.tenant.id,
          user_id: refs.user?.id || null,
          action: payload.action,
          entity: payload.entity,
          entity_id: payload.entity_id,
          diff_json: payload.diff_json,
          ip_address: '10.12.0.10'
        }
      },
      isMissingTableError
    );
  }

  if (refs.user?.id && refs.patient?.id) {
    await safeModelCall(
      'phi_access_log',
      'upsert',
      {
        where: { id: deterministicUuid(`seed:phi:${refs.tenant.id}`, randomSeed) },
        update: {
          tenant_id: refs.tenant.id,
          user_id: refs.user.id,
          patient_id: refs.patient.id,
          access_scope: 'PATIENT',
          reason: 'Compliance regression path',
          accessed_at: getDeterministicDate(randomSeed, 820)
        },
        create: {
          id: deterministicUuid(`seed:phi:${refs.tenant.id}`, randomSeed),
          tenant_id: refs.tenant.id,
          user_id: refs.user.id,
          patient_id: refs.patient.id,
          access_scope: 'PATIENT',
          reason: 'Compliance regression path',
          accessed_at: getDeterministicDate(randomSeed, 820)
        }
      },
      isMissingTableError
    );
  }

  await safeModelCall(
    'data_processing_log',
    'upsert',
    {
      where: { id: deterministicUuid(`seed:data-processing:${refs.tenant.id}`, randomSeed) },
      update: {
        tenant_id: refs.tenant.id,
        user_id: refs.user?.id || null,
        purpose: 'BILLING',
        legal_basis: 'CONTRACT',
        details: 'Seeded billing compliance trail',
        processed_at: getDeterministicDate(randomSeed, 821)
      },
      create: {
        id: deterministicUuid(`seed:data-processing:${refs.tenant.id}`, randomSeed),
        tenant_id: refs.tenant.id,
        user_id: refs.user?.id || null,
        purpose: 'BILLING',
        legal_basis: 'CONTRACT',
        details: 'Seeded billing compliance trail',
        processed_at: getDeterministicDate(randomSeed, 821)
      }
    },
    isMissingTableError
  );

  await safeModelCall(
    'breach_notification',
    'upsert',
    {
      where: { id: deterministicUuid(`seed:breach:${refs.tenant.id}`, randomSeed) },
      update: {
        tenant_id: refs.tenant.id,
        severity: 'HIGH',
        status: 'INVESTIGATING',
        description: 'Seeded breach workflow drill',
        reported_at: getDeterministicDate(randomSeed, 822)
      },
      create: {
        id: deterministicUuid(`seed:breach:${refs.tenant.id}`, randomSeed),
        tenant_id: refs.tenant.id,
        severity: 'HIGH',
        status: 'INVESTIGATING',
        description: 'Seeded breach workflow drill',
        reported_at: getDeterministicDate(randomSeed, 822)
      }
    },
    isMissingTableError
  );

  await safeModelCall(
    'system_change_log',
    'upsert',
    {
      where: { id: deterministicUuid(`seed:system-change:${refs.tenant.id}`, randomSeed) },
      update: {
        tenant_id: refs.tenant.id,
        user_id: refs.user?.id || null,
        change_type: 'module_entitlement_policy_update',
        details: 'Seeded entitlement control baseline'
      },
      create: {
        id: deterministicUuid(`seed:system-change:${refs.tenant.id}`, randomSeed),
        tenant_id: refs.tenant.id,
        user_id: refs.user?.id || null,
        change_type: 'module_entitlement_policy_update',
        details: 'Seeded entitlement control baseline'
      }
    },
    isMissingTableError
  );

  const integration = await safeModelCall(
    'integration',
    'upsert',
    {
      where: { id: deterministicUuid(`seed:integration:${refs.tenant.id}`, randomSeed) },
      update: {
        tenant_id: refs.tenant.id,
        integration_type: 'FHIR',
        status: 'ACTIVE',
        name: 'Seeded FHIR Bridge',
        config_json: {
          seed_pack: 'phase_012',
          replay_supported: true
        }
      },
      create: {
        id: deterministicUuid(`seed:integration:${refs.tenant.id}`, randomSeed),
        tenant_id: refs.tenant.id,
        integration_type: 'FHIR',
        status: 'ACTIVE',
        name: 'Seeded FHIR Bridge',
        config_json: {
          seed_pack: 'phase_012',
          replay_supported: true
        }
      }
    },
    isMissingTableError
  );

  if (integration) {
    await safeModelCall(
      'integration_log',
      'upsert',
      {
        where: { id: deterministicUuid(`seed:integration-log:${refs.tenant.id}`, randomSeed) },
        update: {
          integration_id: integration.id,
          status: 'ACTIVE',
          message: 'Seeded integration replay health check',
          logged_at: getDeterministicDate(randomSeed, 830)
        },
        create: {
          id: deterministicUuid(`seed:integration-log:${refs.tenant.id}`, randomSeed),
          integration_id: integration.id,
          status: 'ACTIVE',
          message: 'Seeded integration replay health check',
          logged_at: getDeterministicDate(randomSeed, 830)
        }
      },
      isMissingTableError
    );

    await safeModelCall(
      'webhook_subscription',
      'upsert',
      {
        where: { id: deterministicUuid(`seed:webhook:${refs.tenant.id}`, randomSeed) },
        update: {
          tenant_id: refs.tenant.id,
          integration_id: integration.id,
          event: 'subscription.plan_fit.changed',
          target_url: 'https://seed.example.com/hooks/plan-fit',
          is_active: true
        },
        create: {
          id: deterministicUuid(`seed:webhook:${refs.tenant.id}`, randomSeed),
          tenant_id: refs.tenant.id,
          integration_id: integration.id,
          event: 'subscription.plan_fit.changed',
          target_url: 'https://seed.example.com/hooks/plan-fit',
          is_active: true
        }
      },
      isMissingTableError
    );
  }

  const snapshotV1Id = deterministicUuid(`seed:configuration-snapshot:${referenceModuleSubscriptionId}:v1`, randomSeed);
  const snapshotV2Id = deterministicUuid(`seed:configuration-snapshot:${referenceModuleSubscriptionId}:v2`, randomSeed);
  const snapshotV3Id = deterministicUuid(`seed:configuration-snapshot:${referenceModuleSubscriptionId}:v3`, randomSeed);

  await safeModelCall(
    'configuration_snapshot',
    'upsert',
    {
      where: {
        resource_type_resource_id_configuration_version: {
          resource_type: 'module_subscription',
          resource_id: referenceModuleSubscriptionId,
          configuration_version: 1
        }
      },
      update: {
        tenant_id: refs.tenant.id,
        snapshot_json: {
          seed_pack: 'phase_012',
          version: 1,
          conflict_state: 'baseline'
        },
        checksum: deterministicHashHex(`seed:snapshot:${referenceModuleSubscriptionId}:v1:${randomSeed}`),
        created_by_user_id: refs.user?.id || null
      },
      create: {
        id: snapshotV1Id,
        tenant_id: refs.tenant.id,
        resource_type: 'module_subscription',
        resource_id: referenceModuleSubscriptionId,
        configuration_version: 1,
        snapshot_json: {
          seed_pack: 'phase_012',
          version: 1,
          conflict_state: 'baseline'
        },
        checksum: deterministicHashHex(`seed:snapshot:${referenceModuleSubscriptionId}:v1:${randomSeed}`),
        created_by_user_id: refs.user?.id || null
      }
    },
    isMissingTableError
  );

  const snapshotV2 = await safeModelCall(
    'configuration_snapshot',
    'upsert',
    {
      where: {
        resource_type_resource_id_configuration_version: {
          resource_type: 'module_subscription',
          resource_id: referenceModuleSubscriptionId,
          configuration_version: 2
        }
      },
      update: {
        tenant_id: refs.tenant.id,
        snapshot_json: {
          seed_pack: 'phase_012',
          version: 2,
          conflict_state: 'server_wins',
          replay_batch_id: 'sync-replay-pack-01'
        },
        checksum: deterministicHashHex(`seed:snapshot:${referenceModuleSubscriptionId}:v2:${randomSeed}`),
        created_by_user_id: refs.user?.id || null
      },
      create: {
        id: snapshotV2Id,
        tenant_id: refs.tenant.id,
        resource_type: 'module_subscription',
        resource_id: referenceModuleSubscriptionId,
        configuration_version: 2,
        snapshot_json: {
          seed_pack: 'phase_012',
          version: 2,
          conflict_state: 'server_wins',
          replay_batch_id: 'sync-replay-pack-01'
        },
        checksum: deterministicHashHex(`seed:snapshot:${referenceModuleSubscriptionId}:v2:${randomSeed}`),
        created_by_user_id: refs.user?.id || null
      }
    },
    isMissingTableError
  );

  if (snapshotV2) {
    await safeModelCall(
      'configuration_snapshot',
      'update',
      {
        where: { id: snapshotV1Id },
        data: { superseded_by_snapshot_id: snapshotV2.id }
      },
      isMissingTableError
    );
  }

  await safeModelCall(
    'configuration_snapshot',
    'upsert',
    {
      where: {
        resource_type_resource_id_configuration_version: {
          resource_type: 'module_subscription',
          resource_id: referenceModuleSubscriptionId,
          configuration_version: 3
        }
      },
      update: {
        tenant_id: refs.tenant.id,
        snapshot_json: {
          seed_pack: 'phase_012',
          version: 3,
          conflict_state: 'resolved',
          replay_batch_id: 'sync-replay-pack-01',
          replay_of_versions: [1, 2]
        },
        checksum: deterministicHashHex(`seed:snapshot:${referenceModuleSubscriptionId}:v3:${randomSeed}`),
        created_by_user_id: refs.user?.id || null
      },
      create: {
        id: snapshotV3Id,
        tenant_id: refs.tenant.id,
        resource_type: 'module_subscription',
        resource_id: referenceModuleSubscriptionId,
        configuration_version: 3,
        snapshot_json: {
          seed_pack: 'phase_012',
          version: 3,
          conflict_state: 'resolved',
          replay_batch_id: 'sync-replay-pack-01',
          replay_of_versions: [1, 2]
        },
        checksum: deterministicHashHex(`seed:snapshot:${referenceModuleSubscriptionId}:v3:${randomSeed}`),
        created_by_user_id: refs.user?.id || null
      }
    },
    isMissingTableError
  );
};

const seedPhase12SupplementalScenarios = async ({
  randomSeed = 20260217,
  isMissingTableError = defaultMissingTableCheck
} = {}) => {
  const refs = await getSeedReferences({ randomSeed, isMissingTableError });
  if (!refs) {
    return { skipped: true, reason: 'tenant unavailable' };
  }

  const plansByCode = await upsertCanonicalPlans({ refs, randomSeed, isMissingTableError });
  const modulesByCode = await upsertEntitlementModules({ randomSeed, isMissingTableError });
  const subscriptionsByScenario = await upsertScenarioSubscriptions({
    refs,
    plansByCode,
    randomSeed,
    isMissingTableError
  });
  const moduleSubscriptionIds = await upsertScenarioModuleSubscriptions({
    modulesByCode,
    subscriptionsByScenario,
    randomSeed,
    isMissingTableError
  });

  await upsertScenarioLicenses({
    refs,
    plansByCode,
    randomSeed,
    isMissingTableError
  });

  await upsertScenarioFinancialEvents({
    refs,
    subscriptionsByScenario,
    randomSeed,
    isMissingTableError
  });

  await upsertScenarioComplianceAndOfflineRecords({
    refs,
    subscriptionsByScenario,
    moduleSubscriptionIds,
    randomSeed,
    isMissingTableError
  });

  return {
    skipped: false,
    plansSeeded: Object.keys(plansByCode).length,
    modulesSeeded: Object.keys(modulesByCode).length,
    subscriptionsSeeded: Object.keys(subscriptionsByScenario).length,
    moduleSubscriptionsSeeded: Object.keys(moduleSubscriptionIds).length
  };
};

const verifyRequiredModelCoverage = async ({
  requiredModels = HMS_SEED_MODEL_ORDER,
  isMissingTableError = defaultMissingTableCheck
} = {}) => {
  const missingModels = [];
  const unavailableModels = [];

  for (const modelName of requiredModels) {
    const delegate = prisma[modelName];
    if (!delegate || typeof delegate.count !== 'function') {
      unavailableModels.push(modelName);
      continue;
    }

    try {
      const count = await delegate.count({ where: { deleted_at: null } });
      if (!Number.isFinite(count) || count <= 0) {
        missingModels.push(modelName);
      }
    } catch (error) {
      if (isMissingTableError(error)) {
        unavailableModels.push(modelName);
      } else {
        throw error;
      }
    }
  }

  return {
    missingModels,
    unavailableModels
  };
};

module.exports = {
  resolveSeedExecutionOrder,
  seedPhase12SupplementalScenarios,
  verifyRequiredModelCoverage
};
