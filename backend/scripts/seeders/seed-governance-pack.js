const { DEMO_TENANT } = require('./seed-catalog');

const seedGovernancePack = async (ctx, orgPack, accessPack, clinicalPack, operationsPack = {}) => {
  const scenario = DEMO_TENANT;
  const tenant = orgPack.tenants[scenario.key];
  const facility = orgPack.facilities[`${scenario.key}:${scenario.facilities[0].key}`];
  const complianceDepartment = orgPack.departments[`${scenario.key}:Compliance`] || null;
  const inpatientDepartment = orgPack.departments[`${scenario.key}:Inpatient`] || null;

  const tenantAdmin = accessPack.users[`${scenario.key}:tenant_admin`];
  const doctor = accessPack.users[`${scenario.key}:doctor`];
  const nurse = accessPack.users[`${scenario.key}:nurse`];
  const billing = accessPack.users[`${scenario.key}:billing`];
  const operations = accessPack.users[`${scenario.key}:operations`] || tenantAdmin;
  const patient = clinicalPack.patients[`${scenario.key}:p4`] || clinicalPack.patients[`${scenario.key}:p1`];
  const shift =
    operationsPack.shift
    || ctx.ref(`shift:${scenario.key}:shift:night`);

  if (!shift?.id) {
    throw new Error('Governance seed requires the demo night shift to exist before seeding Last Office records.');
  }

  const officeContext = await ctx.upsert(
    'office_context',
    `${scenario.key}:office-context:night`,
    {
      tenant_id: tenant.id,
      facility_id: facility?.id || null,
      shift_id: shift?.id,
      opened_by_user_id: operations.id,
      current_holder_user_id: operations.id,
      office_date: ctx.date(0),
      status: 'OPEN',
      opened_at: ctx.date(-1, 18 * 60),
      handover_due_at: ctx.date(0, 6 * 60),
      notes: 'Demo night-shift office context for closeout and custody workflows.',
      metadata_json: {
        workflow: 'last_office',
        seed_pack: 'governance',
        shift_label: 'night',
      },
      etag: ctx.hash(`${scenario.key}:office-context:etag`),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'OFC',
    }
  );

  const shiftClose = await ctx.upsert(
    'shift_close',
    `${scenario.key}:shift-close:night`,
    {
      tenant_id: tenant.id,
      facility_id: facility?.id || null,
      office_context_id: officeContext.id,
      shift_id: shift?.id,
      closed_by_user_id: billing?.id || operations.id,
      approved_by_user_id: operations.id,
      status: 'APPROVED',
      totals_json: {
        cash_sales: 540.25,
        mobile_money: 210.00,
        card: 130.75,
      },
      reconciliation_json: {
        drawer_counted_by: billing?.id || operations.id,
        discrepancies: [],
      },
      expected_amount: '881.00',
      actual_amount: '881.00',
      variance_amount: '0.00',
      submitted_at: ctx.date(0, 10),
      approved_at: ctx.date(0, 20),
      notes: 'Night cashier shift reconciled without variance.',
      evidence_json: {
        cash_sheet_attached: true,
        till_number: 'TILL-01',
      },
      etag: ctx.hash(`${scenario.key}:shift-close:etag`),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'SCL',
    }
  );

  const dayClose = await ctx.upsert(
    'day_close',
    `${scenario.key}:day-close:night`,
    {
      tenant_id: tenant.id,
      facility_id: facility?.id || null,
      office_context_id: officeContext.id,
      submitted_by_user_id: operations.id,
      approved_by_user_id: tenantAdmin.id,
      status: 'APPROVED',
      checklist_json: {
        admissions_reconciled: true,
        billing_balanced: true,
        pharmacy_handover_complete: true,
      },
      blockers_json: [],
      unresolved_items_json: [],
      submitted_at: ctx.date(0, 30),
      approved_at: ctx.date(0, 45),
      notes: 'Day close completed for the seeded single-facility workspace.',
      evidence_json: {
        incident_log_checked: true,
      },
      etag: ctx.hash(`${scenario.key}:day-close:etag`),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'DCL',
    }
  );

  const handover = await ctx.upsert(
    'handover',
    `${scenario.key}:handover:night`,
    {
      tenant_id: tenant.id,
      facility_id: facility?.id || null,
      office_context_id: officeContext.id,
      from_user_id: nurse?.id || operations.id,
      to_user_id: operations.id,
      status: 'ACCEPTED',
      items_json: [
        { item: 'ward_keys', count: 1, evidence: 'sealed-envelope' },
        { item: 'incident_register', count: 1, evidence: 'signed' },
      ],
      signoff_notes: 'Nurse team handed over ward keys and overnight incident register.',
      accepted_notes: 'Operations accepted custody of keys and register.',
      submitted_at: ctx.date(0, 35),
      accepted_at: ctx.date(0, 42),
      etag: ctx.hash(`${scenario.key}:handover:etag`),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'HND',
    }
  );

  const custodySnapshot = await ctx.upsert(
    'custody_snapshot',
    `${scenario.key}:custody-snapshot:night`,
    {
      tenant_id: tenant.id,
      facility_id: facility?.id || null,
      office_context_id: officeContext.id,
      captured_by_user_id: operations.id,
      status: 'FINALIZED',
      asset_snapshot_json: [
        { asset: 'drug-cabinet', status: 'sealed' },
        { asset: 'emergency-crash-cart', status: 'complete' },
      ],
      cash_drawer_snapshot_json: {
        till_number: 'TILL-01',
        counted_amount: 881.00,
        currency: 'USD',
      },
      controlled_items_json: [
        { item: 'narcotics-register', status: 'verified' },
      ],
      captured_at: ctx.date(0, 32),
      finalized_at: ctx.date(0, 40),
      notes: 'Custody snapshot finalized after dual count.',
      etag: ctx.hash(`${scenario.key}:custody-snapshot:etag`),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'CUS',
    }
  );

  const closeoutPack = await ctx.upsert(
    'closeout_pack',
    `${scenario.key}:closeout-pack:night`,
    {
      tenant_id: tenant.id,
      facility_id: facility?.id || null,
      office_context_id: officeContext.id,
      shift_close_id: shiftClose.id,
      day_close_id: dayClose.id,
      handover_id: handover.id,
      custody_snapshot_id: custodySnapshot.id,
      generated_by_user_id: operations.id,
      status: 'READY',
      format: 'pdf',
      output_storage_path: `last-office/${tenant.id}/2026/02/${ctx.publicId('closeout_pack', `${scenario.key}:closeout-pack:night`, 'CLP')}.pdf`,
      output_file_name: 'last-office-closeout-night.pdf',
      output_mime_type: 'application/pdf',
      output_size_bytes: 102400,
      checksum: ctx.hash(`${scenario.key}:closeout-pack:checksum`),
      generated_at: ctx.date(0, 50),
      summary_json: {
        shift_close_status: shiftClose.status,
        day_close_status: dayClose.status,
        handover_status: handover.status,
        custody_snapshot_status: custodySnapshot.status,
      },
      parameter_overrides_json: {
        export_reason: 'demo_seed',
      },
      etag: ctx.hash(`${scenario.key}:closeout-pack:etag`),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'CLP',
    }
  );

  const abacAllowPolicy = await ctx.upsert(
    'abac_policy',
    `${scenario.key}:abac-policy:ward-shift-allow`,
    {
      tenant_id: tenant.id,
      facility_id: facility?.id || null,
      department_id: inpatientDepartment?.id || null,
      name: 'Ward shift scope for nursing access',
      description: 'Allows nurses to access assigned inpatient patient records during the current shift.',
      resource_type: 'patient',
      action: 'read',
      effect: 'ALLOW',
      priority: 50,
      subject_conditions_json: {
        role: ['NURSE', 'DOCTOR'],
        department_id: inpatientDepartment?.id || null,
      },
      object_conditions_json: {
        facility_id: facility?.id || null,
      },
      environment_conditions_json: {
        shift_type: 'NIGHT',
      },
      reason_template: 'Clinical staff may access records for the active inpatient shift.',
      is_active: true,
      created_by_user_id: tenantAdmin.id,
      updated_by_user_id: tenantAdmin.id,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ABP',
    }
  );

  const abacDenyPolicy = await ctx.upsert(
    'abac_policy',
    `${scenario.key}:abac-policy:export-deny-without-break-glass`,
    {
      tenant_id: tenant.id,
      facility_id: facility?.id || null,
      department_id: complianceDepartment?.id || null,
      name: 'Deny patient export without emergency override',
      description: 'Blocks sensitive patient export actions unless a break-glass override is active.',
      resource_type: 'patient',
      action: 'export',
      effect: 'DENY',
      priority: 10,
      environment_conditions_json: {
        break_glass_active: false,
      },
      reason_template: 'Break-glass approval is required before exporting sensitive patient data.',
      is_active: true,
      created_by_user_id: tenantAdmin.id,
      updated_by_user_id: tenantAdmin.id,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'ABP',
    }
  );

  const breakGlassRequested = await ctx.upsert(
    'break_glass_access',
    `${scenario.key}:break-glass-access:pending`,
    {
      tenant_id: tenant.id,
      facility_id: facility?.id || null,
      patient_id: patient?.id || null,
      target_resource_type: 'patient',
      target_resource_id: patient?.id || null,
      requested_by_user_id: doctor.id,
      reason: 'Emergency deterioration review during night escalation.',
      justification_json: {
        escalation: 'respiratory_failure',
      },
      requested_scope_json: {
        patient_id: patient?.id || null,
        reason_code: 'EMERGENT_REVIEW',
      },
      status: 'REQUESTED',
      review_status: 'PENDING',
      requested_at: ctx.date(0, 5),
      expires_at: ctx.date(0, 65),
      etag: ctx.hash(`${scenario.key}:break-glass-pending:etag`),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'BGA',
    }
  );

  const breakGlassActive = await ctx.upsert(
    'break_glass_access',
    `${scenario.key}:break-glass-access:approved`,
    {
      tenant_id: tenant.id,
      facility_id: facility?.id || null,
      patient_id: patient?.id || null,
      target_resource_type: 'patient',
      target_resource_id: patient?.id || null,
      requested_by_user_id: doctor.id,
      approved_by_user_id: operations.id,
      reason: 'Approved emergency chart review for active deterioration workflow.',
      justification_json: {
        escalation: 'critical_observation',
      },
      requested_scope_json: {
        patient_id: patient?.id || null,
        duration_minutes: 45,
      },
      status: 'ACTIVE',
      review_status: 'APPROVED',
      requested_at: ctx.date(-1, 22 * 60),
      approved_at: ctx.date(-1, 22 * 60 + 10),
      starts_at: ctx.date(-1, 22 * 60 + 10),
      expires_at: ctx.date(-1, 22 * 60 + 55),
      reviewed_at: ctx.date(-1, 22 * 60 + 10),
      etag: ctx.hash(`${scenario.key}:break-glass-approved:etag`),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'BGA',
    }
  );

  const breakGlassReview = await ctx.upsert(
    'break_glass_review',
    `${scenario.key}:break-glass-review:approved`,
    {
      break_glass_access_id: breakGlassActive.id,
      tenant_id: tenant.id,
      reviewer_user_id: operations.id,
      status: 'APPROVED',
      notes: 'Emergency access approved for short-lived patient review.',
      decided_at: ctx.date(-1, 22 * 60 + 10),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'BGR',
    }
  );

  return {
    abacPolicies: {
      allowWardShift: abacAllowPolicy,
      denyPatientExport: abacDenyPolicy,
    },
    breakGlassAccesses: {
      pending: breakGlassRequested,
      active: breakGlassActive,
    },
    breakGlassReviews: {
      approved: breakGlassReview,
    },
    officeContexts: {
      active: officeContext,
    },
    shiftCloses: {
      approved: shiftClose,
    },
    dayCloses: {
      approved: dayClose,
    },
    handovers: {
      accepted: handover,
    },
    custodySnapshots: {
      finalized: custodySnapshot,
    },
    closeoutPacks: {
      ready: closeoutPack,
    },
  };
};

module.exports = {
  seedGovernancePack,
};
