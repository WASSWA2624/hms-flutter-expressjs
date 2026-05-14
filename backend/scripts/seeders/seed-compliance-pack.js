const { DEMO_TENANT } = require('./seed-catalog');

const seedCompliancePack = async (ctx, orgPack, accessPack, clinicalPack) => {
  const scenario = DEMO_TENANT;
  const tenant = orgPack.tenants[scenario.key];
  const admin = accessPack.users[`${scenario.key}:tenant_admin`];
  const doctor = accessPack.users[`${scenario.key}:doctor`];
  const operations = accessPack.users[`${scenario.key}:operations`] || admin;
  const patient = clinicalPack.patients[`${scenario.key}:p4`];
  const subscription = ctx.ref(`subscription:${scenario.key}:subscription`);

  await ctx.upsert(
    'audit_log',
    `${scenario.key}:audit-log:subscription-policy`,
    {
      tenant_id: tenant.id,
      user_id: admin.id,
      action: 'UPDATE',
      entity: 'subscription',
      entity_id: subscription?.id || null,
      diff_json: {
        workspace_mode: { from: 'multi_tenant_demo', to: 'single_tenant_demo' },
        facility_scope: { from: 'mixed', to: 'single_facility' },
      },
      ip_address: '10.14.22.8',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'AUD',
    }
  );

  await ctx.upsert(
    'phi_access_log',
    `${scenario.key}:phi-access-log:telemed-review`,
    {
      tenant_id: tenant.id,
      user_id: doctor.id,
      patient_id: patient.id,
      access_scope: 'PATIENT',
      reason: 'Reviewed demo telemedicine follow-up record during recall case conference.',
      accessed_at: ctx.date(-1, 40),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'PHI',
    }
  );

  await ctx.upsert(
    'data_processing_log',
    `${scenario.key}:data-processing-log:incident-review`,
    {
      tenant_id: tenant.id,
      user_id: admin.id,
      purpose: 'OPERATIONS',
      legal_basis: 'LEGAL_OBLIGATION',
      details: 'Processed biomedical incident evidence package for internal governance review.',
      processed_at: ctx.date(-1, 55),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'DPL',
    }
  );

  await ctx.upsert(
    'breach_notification',
    `${scenario.key}:breach-notification:drill`,
    {
      tenant_id: tenant.id,
      severity: 'HIGH',
      status: 'REPORTED',
      description: 'Annual tabletop drill for sensitive equipment incident communications.',
      reported_at: ctx.date(-2),
      resolved_at: null,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'BRC',
    }
  );

  await ctx.upsert(
    'system_change_log',
    `${scenario.key}:system-change-log:offline-policy`,
    {
      tenant_id: tenant.id,
      user_id: operations.id,
      change_type: 'OFFLINE_SYNC_POLICY_UPDATED',
      details: 'Conflict-resolution policy updated for the single-hospital demo workspace.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'SCL',
    }
  );

  const integration = await ctx.upsert(
    'integration',
    `${scenario.key}:integration:fhir-gateway`,
    {
      tenant_id: tenant.id,
      integration_type: 'FHIR',
      status: 'ACTIVE',
      name: 'DemoCare FHIR Gateway',
      config_json: {
        endpoint: 'https://integration.demo.example/fhir',
        mode: 'cloud_connector',
      },
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'INT',
    }
  );

  await ctx.upsert(
    'integration_log',
    `${scenario.key}:integration-log:fhir-gateway`,
    {
      integration_id: integration.id,
      status: 'ACTIVE',
      message: 'Connector heartbeat healthy after overnight queue reconciliation.',
      logged_at: ctx.date(-1, 100),
    },
    {
      publicIdPrefix: 'INL',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'webhook_subscription',
    `${scenario.key}:webhook-subscription:incident`,
    {
      tenant_id: tenant.id,
      integration_id: integration.id,
      event: 'equipment.incident.reported',
      target_url: 'https://demo.example/hooks/biomedical-incidents',
      is_active: true,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'WHK',
    }
  );

  return {
    integration,
  };
};

module.exports = {
  seedCompliancePack,
};
