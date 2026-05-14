const { DEMO_TENANT } = require('./seed-catalog');

const seedBiomedicalPack = async (ctx, orgPack, accessPack, operationsPack) => {
  const result = {
    registries: {},
    workOrders: {},
  };

  const scenario = DEMO_TENANT;
  const facility = orgPack.facilities[`${scenario.key}:${scenario.facilities[0].key}`];
  const biomedUser = accessPack.users[`${scenario.key}:biomed`] || accessPack.users[`${scenario.key}:operations`];
  const nurseUser = accessPack.users[`${scenario.key}:nurse`];

  const category = await ctx.upsert(
    'equipment_category',
    `${scenario.key}:equipment-category:critical-care`,
    {
      tenant_id: facility.tenant_id,
      name: 'Critical Care Devices',
      code: `${scenario.tenant_code}-CCD`,
      risk_class: 'HIGH',
      description: 'Critical equipment tracked for PM, recall, and safety testing.',
      is_active: true,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'EQC',
    }
  );

  const registry = await ctx.upsert(
    'equipment_registry',
    `${scenario.key}:equipment-registry:ventilator`,
    {
      tenant_id: facility.tenant_id,
      equipment_category_id: category.id,
      facility_id: facility.id,
      name: 'Critical care ventilator',
      equipment_name: 'Puritan Bennett Ventilator',
      equipment_code: `${scenario.tenant_code}-VENT-01`,
      serial_number: `SER-${ctx.hash(`${scenario.key}:ventilator`).slice(0, 10).toUpperCase()}`,
      manufacturer: 'Medtronic',
      model_number: 'PB-980',
      qr_code: `QR-${scenario.tenant_code}-VENT-01`,
      barcode: `BC-${scenario.tenant_code}-VENT-01`,
      status: 'UNDER_REPAIR',
      criticality_level: 'HIGH',
      commissioning_date: ctx.date(-400),
      purchase_date: ctx.date(-500),
      usage_hours: 5400,
      last_service_at: ctx.date(-70),
      next_service_due_at: ctx.date(20),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'EQP',
    }
  );
  result.registries[scenario.key] = registry;

  const maintenancePlan = await ctx.upsert(
    'equipment_maintenance_plan',
    `${scenario.key}:equipment-maintenance-plan:pm`,
    {
      tenant_id: facility.tenant_id,
      equipment_registry_id: registry.id,
      name: 'Preventive Maintenance Plan',
      description: 'Quarterly PM for the critical ventilator fleet.',
      plan_name: 'Quarterly PM',
      maintenance_type: 'PREVENTIVE',
      status: 'ACTIVE',
      is_active: true,
      interval_days: 90,
      interval_usage_hours: 500,
      sla_hours: 8,
      checklist_json: { steps: ['Electrical safety', 'Flow test', 'Alarm verification'] },
      last_run_at: ctx.date(-70),
      next_due_at: ctx.date(20),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'EPM',
    }
  );

  const workOrder = await ctx.upsert(
    'equipment_work_order',
    `${scenario.key}:equipment-work-order:corrective`,
    {
      tenant_id: facility.tenant_id,
      equipment_registry_id: registry.id,
      maintenance_plan_id: maintenancePlan.id,
      maintenance_request_id: null,
      name: 'Corrective ventilator work order',
      description: 'Triggered after low outlet pressure and ventilator alarm escalation.',
      title: 'Ventilator alarm fault investigation',
      priority: 'HIGH',
      status: 'TESTING',
      issue_source: 'NURSE_REPORT',
      reported_by_user_id: nurseUser?.id || biomedUser?.id || null,
      assigned_engineer_user_id: biomedUser?.id || null,
      opened_at: ctx.date(-2),
      acknowledged_at: ctx.date(-2, 20),
      started_at: ctx.date(-2, 35),
      completed_at: ctx.date(-1, 30),
      closed_at: null,
      resolution_notes: 'Alarm control board replaced and oxygen delivery retested successfully.',
      downtime_started_at: ctx.date(-2, 15),
      downtime_ended_at: ctx.date(-1, 35),
      estimated_cost: 180,
      actual_cost: 165,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'EWO',
    }
  );
  result.workOrders[scenario.key] = workOrder;

  await ctx.upsert(
    'equipment_calibration_log',
    `${scenario.key}:equipment-calibration-log:pass`,
    {
      tenant_id: facility.tenant_id,
      equipment_registry_id: registry.id,
      equipment_work_order_id: workOrder.id,
      name: 'Ventilator calibration',
      description: 'Post-maintenance calibration and performance verification.',
      calibrated_by_user_id: biomedUser?.id || null,
      calibrated_at: ctx.date(-1, 40),
      result: 'PASS',
      certificate_number: `${scenario.tenant_code}-CAL-2026-01`,
      certificate_url: 'https://example.com/demo/calibration-certificate.pdf',
      expires_at: ctx.date(180),
      notes: 'Calibration completed within manufacturer tolerance.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ECL',
    }
  );

  await ctx.upsert(
    'equipment_safety_test_log',
    `${scenario.key}:equipment-safety-test-log:pass`,
    {
      tenant_id: facility.tenant_id,
      equipment_registry_id: registry.id,
      equipment_work_order_id: workOrder.id,
      name: 'Electrical safety test',
      description: 'Leakage current and grounding test after corrective maintenance.',
      tested_by_user_id: biomedUser?.id || null,
      tested_at: ctx.date(-1, 50),
      test_type: 'Electrical Safety',
      result: 'PASS',
      certificate_url: 'https://example.com/demo/safety-test-certificate.pdf',
      expires_at: ctx.date(180),
      notes: 'Device cleared for return to service.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'EST',
    }
  );

  await ctx.upsert(
    'equipment_downtime_log',
    `${scenario.key}:equipment-downtime-log:corrective`,
    {
      tenant_id: facility.tenant_id,
      equipment_registry_id: registry.id,
      equipment_work_order_id: workOrder.id,
      name: 'Ventilator downtime incident',
      description: 'Unavailable while corrective maintenance and recall triage were performed.',
      started_at: ctx.date(-2, 15),
      ended_at: ctx.date(-1, 35),
      reason: 'Alarm failure',
      impact_level: 'HIGH',
      is_clinically_critical: true,
      notes: 'Backup ventilator was deployed to the high dependency bed.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'EDT',
    }
  );

  await ctx.upsert(
    'equipment_spare_part',
    `${scenario.key}:equipment-spare-part:alarm-board`,
    {
      tenant_id: facility.tenant_id,
      equipment_registry_id: registry.id,
      inventory_item_id: operationsPack.inventoryItems[scenario.key]?.id || null,
      supplier_id: operationsPack.suppliers[scenario.key]?.id || null,
      name: 'Alarm control board',
      description: 'Critical ventilator replacement board stored for rapid swap-outs.',
      part_name: 'Alarm Control Board',
      part_number: `${scenario.tenant_code}-ALARM-01`,
      manufacturer: 'Medtronic',
      quantity_on_hand: 2,
      min_stock_level: 1,
      unit_cost: 95,
      expiry_date: null,
      notes: 'Stored in the locked biomedical cabinet.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ESP',
    }
  );

  await ctx.upsert(
    'equipment_utilization_snapshot',
    `${scenario.key}:equipment-utilization-snapshot:monthly`,
    {
      tenant_id: facility.tenant_id,
      equipment_registry_id: registry.id,
      name: 'Monthly utilization snapshot',
      description: 'Captured for the demo biomedical dashboard.',
      captured_at: ctx.date(-1, 120),
      usage_hours: 240,
      procedure_count: 32,
      uptime_minutes: 41200,
      downtime_minutes: 360,
      mttr_minutes: 180,
      mtbf_minutes: 14000,
      availability_percentage: 98.1,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'EUS',
    }
  );

  await ctx.upsert(
    'equipment_incident_report',
    `${scenario.key}:equipment-incident-report:ventilator`,
    {
      tenant_id: facility.tenant_id,
      equipment_registry_id: registry.id,
      equipment_work_order_id: workOrder.id,
      reported_by_user_id: biomedUser?.id || null,
      name: 'Ventilator incident',
      title: 'Unexpected ventilator shutdown during transfer preparation',
      description: 'Clinical engineering initiated CAPA review after an unplanned shutdown alert in high dependency care.',
      severity: 'CRITICAL',
      status: 'INVESTIGATING',
      occurred_at: ctx.date(-6),
      patient_impact: true,
      hazard_level: 'HIGH',
      resolved_at: null,
      root_cause: 'Power board degradation under intermittent surge conditions.',
      immediate_action: 'Device quarantined, backup assigned, incident reported to compliance.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'EIR',
    }
  );

  await ctx.upsert(
    'equipment_recall_notice',
    `${scenario.key}:equipment-recall-notice:ventilator`,
    {
      tenant_id: facility.tenant_id,
      equipment_registry_id: registry.id,
      equipment_service_provider_id: null,
      name: 'Ventilator recall notice',
      title: 'Manufacturer class II recall',
      description: 'Recall issued for affected control boards pending replacement and firmware confirmation.',
      recall_reference: 'RC-2026-VENT-88',
      severity: 'HIGH',
      status: 'OPEN',
      issued_at: ctx.date(-4),
      due_by: ctx.date(10),
      resolved_at: null,
      action_taken: 'Affected serial quarantined and replacement order raised with supplier.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ERC',
    }
  );

  await ctx.upsert(
    'equipment_disposal_transfer',
    `${scenario.key}:equipment-disposal-transfer:retire-backup`,
    {
      tenant_id: facility.tenant_id,
      equipment_registry_id: registry.id,
      name: 'Device retirement decision',
      description: 'Older backup ventilator approved for formal retirement after fleet refresh.',
      action_type: 'DISPOSAL',
      status: 'APPROVED',
      to_facility_id: null,
      to_organization: 'Licensed medical waste contractor',
      reason: 'Lifecycle refresh and replacement with supported hardware.',
      approved_by_user_id: biomedUser?.id || null,
      approved_at: ctx.date(-2),
      disposed_or_transferred_at: ctx.date(3),
      certificate_url: 'https://example.com/demo/disposal-certificate.pdf',
      notes: 'Awaiting collection from the approved disposal vendor.',
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'EDP',
    }
  );

  return result;
};

module.exports = {
  seedBiomedicalPack,
};
