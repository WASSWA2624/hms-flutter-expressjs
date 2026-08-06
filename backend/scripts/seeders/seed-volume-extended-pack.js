/**
 * Extended demo volume: clinical charting, billing extras, reports/analytics,
 * reception queues, ED/ambulance children, HR/roster, communications, compliance.
 *
 * Runs after seed-volume-pack and reuses its FK anchors.
 */

const { DEMO_TENANT } = require('./seed-catalog');
const { resolveVolumeTargets } = require('./seed-volume-pack');

const REPORT_DATASET_SEEDS = Object.freeze([
  { key: 'patient_registrations', category: 'patients', label: 'Patient registrations', visualization: 'LINE_CHART' },
  { key: 'appointment_throughput_no_shows', category: 'appointments', label: 'Appointment throughput', visualization: 'BAR_CHART' },
  { key: 'billing_collections_open_balances', category: 'billing', label: 'Billing collections', visualization: 'AREA_CHART' },
  { key: 'insurance_claims_aging', category: 'billing', label: 'Insurance claims aging', visualization: 'TABLE' },
  { key: 'pharmacy_dispenses', category: 'pharmacy', label: 'Pharmacy dispenses', visualization: 'BAR_CHART' },
  { key: 'lab_turnaround', category: 'diagnostics', label: 'Lab turnaround', visualization: 'LINE_CHART' },
  { key: 'inpatient_occupancy', category: 'clinical', label: 'Inpatient occupancy', visualization: 'KPI' },
  { key: 'emergency_throughput', category: 'emergency', label: 'Emergency throughput', visualization: 'BAR_CHART' },
]);
const REPORT_FORMATS = Object.freeze(['PDF', 'CSV', 'JSON', 'XLSX']);

const DIAGNOSIS_TYPES = Object.freeze(['PRIMARY', 'SECONDARY', 'DIFFERENTIAL']);
const DIAGNOSIS_CODES = Object.freeze([
  ['J45.901', 'Asthma, unspecified'],
  ['J18.9', 'Pneumonia, unspecified'],
  ['E11.9', 'Type 2 diabetes mellitus'],
  ['I10', 'Essential hypertension'],
  ['A01.0', 'Typhoid fever'],
  ['B50.9', 'Plasmodium falciparum malaria'],
  ['N39.0', 'Urinary tract infection'],
  ['K35.80', 'Unspecified acute appendicitis'],
]);
const VITAL_TYPES = Object.freeze([
  ['TEMPERATURE', '37.2', 'C'],
  ['BLOOD_PRESSURE', '120/80', 'mmHg'],
  ['HEART_RATE', '78', 'bpm'],
  ['RESPIRATORY_RATE', '18', '/min'],
  ['OXYGEN_SATURATION', '98', '%'],
  ['WEIGHT', '68', 'kg'],
]);
const MED_ROUTES = Object.freeze(['ORAL', 'IV', 'IM', 'SC', 'INHALATION', 'TOPICAL']);
const DISCHARGE_STATUSES = Object.freeze(['PLANNED', 'COMPLETED', 'CANCELLED']);
const CLAIM_STATUSES = Object.freeze([
  'SUBMITTED', 'APPROVED', 'PARTIAL', 'REJECTED', 'PAID', 'CANCELLED',
]);
const AUTH_STATUSES = Object.freeze([
  'PENDING', 'APPROVED', 'PARTIAL', 'DENIED', 'EXPIRED', 'CANCELLED',
]);
const BILLING_ADJ_STATUSES = Object.freeze(['DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED']);
const QUEUE_STATUSES = Object.freeze([
  'SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW',
]);
const TRIAGE_LEVELS = Object.freeze(['LEVEL_1', 'LEVEL_2', 'LEVEL_3', 'LEVEL_4', 'LEVEL_5']);
const AMBULANCE_STATUSES = Object.freeze([
  'AVAILABLE', 'DISPATCHED', 'EN_ROUTE', 'ON_SCENE', 'TRANSPORTING', 'OUT_OF_SERVICE',
]);
const SHIFT_TYPES = Object.freeze(['DAY', 'NIGHT', 'SWING', 'ON_CALL']);
const SHIFT_STATUSES = Object.freeze(['SCHEDULED', 'COMPLETED', 'CANCELLED']);
const PAYROLL_STATUSES = Object.freeze(['DRAFT', 'PROCESSED', 'PAID', 'CANCELLED']);
const AUDIT_ACTIONS = Object.freeze([
  'CREATE', 'UPDATE', 'DELETE', 'ACCESS', 'EXPORT', 'LOGIN', 'LOGOUT',
]);
const ACCESS_SCOPES = Object.freeze(['TENANT', 'FACILITY', 'DEPARTMENT', 'PATIENT']);
const RUN_STATUSES = Object.freeze(['QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED']);
const WIDGET_TYPES = Object.freeze(['KPI', 'LINE_CHART', 'BAR_CHART', 'TABLE', 'DONUT']);
const KPI_STATES = Object.freeze(['NORMAL', 'WARNING', 'CRITICAL']);

const pick = (values, index) => values[index % values.length];
const pad = (value, width = 4) => String(value).padStart(width, '0');

const runInBatches = async (total, batchSize, worker) => {
  for (let start = 1; start <= total; start += batchSize) {
    const end = Math.min(total, start + batchSize - 1);
    const tasks = [];
    for (let index = start; index <= end; index += 1) {
      tasks.push(worker(index));
    }
    await Promise.all(tasks);
  }
};

const at = (list, index) => {
  if (!Array.isArray(list) || list.length === 0) return null;
  return list[(index - 1) % list.length];
};

const seedVolumeExtendedPack = async (
  ctx,
  targetCount,
  {
    orgPack,
    accessPack,
    operationsPack,
    volumeSummary,
    communicationsPack,
  } = {}
) => {
  const targets = resolveVolumeTargets(targetCount);
  if (targets.skipped || volumeSummary?.skipped) {
    return {
      skipped: true,
      reason: volumeSummary?.skipped ? 'volume_pack_skipped' : 'target_count_zero',
      created: {},
    };
  }

  const scenario = DEMO_TENANT;
  const facility =
    volumeSummary.facility
    || orgPack?.facilities?.[`${scenario.key}:${scenario.facilities[0].key}`];
  if (!facility) {
    throw new Error('seedVolumeExtendedPack requires demo facility');
  }

  const doctor = volumeSummary.doctor || accessPack?.users?.[`${scenario.key}:doctor`];
  const nurse = volumeSummary.nurse || accessPack?.users?.[`${scenario.key}:nurse`] || doctor;
  const billing = accessPack?.users?.[`${scenario.key}:billing`] || doctor;
  const receptionist = accessPack?.users?.[`${scenario.key}:reception`] || nurse;
  const staffProfiles = Object.values(accessPack?.staffProfiles || {}).filter(Boolean);
  const staffUsers = Object.values(accessPack?.users || {}).filter(Boolean);

  const patients = (volumeSummary.patient_ids || []).map((id) => ({ id }));
  const encounters = volumeSummary.encounters || [];
  const admissions = volumeSummary.admissions || [];
  const appointments = volumeSummary.appointments || [];
  const invoices = volumeSummary.invoices || [];
  const payments = volumeSummary.payments || [];
  const emergencies = volumeSummary.emergencies || [];

  const seedOpts = {
    tenantCode: scenario.tenant_code,
    scenarioKey: scenario.scenario_key,
  };

  const n = targets.highTraffic;
  const created = {};
  const bump = (key) => {
    created[key] = (created[key] || 0) + 1;
  };

  console.log(`Seeding extended demo volume (target=${n})...`);

  // --- Clinical charting on encounters / admissions ---
  if (encounters.length > 0) {
    await runInBatches(n, 10, async (index) => {
      const encounter = at(encounters, index);
      if (!encounter) return;
      const [code, description] = pick(DIAGNOSIS_CODES, index);
      await ctx.upsert(
        'diagnosis',
        `${scenario.key}:volx:diagnosis:${pad(index)}`,
        {
          encounter_id: encounter.id,
          diagnosis_type: pick(DIAGNOSIS_TYPES, index),
          code,
          description: `${description} (volume #${index})`,
        },
        { publicIdPrefix: 'DIA', seedMeta: false }
      );
      bump('diagnoses');

      const [vitalType, value, unit] = pick(VITAL_TYPES, index);
      const vitalPayload = {
        encounter_id: encounter.id,
        vital_type: vitalType,
        value,
        unit,
        recorded_at: ctx.date(-((index % 90) + 1), 20 + (index % 30)),
      };
      if (vitalType === 'BLOOD_PRESSURE') {
        vitalPayload.systolic_value = 110 + (index % 30);
        vitalPayload.diastolic_value = 70 + (index % 15);
        vitalPayload.map_value = 90 + (index % 10);
      }
      await ctx.upsert(
        'vital_sign',
        `${scenario.key}:volx:vital:${pad(index)}`,
        vitalPayload,
        { publicIdPrefix: 'VTL', seedMeta: false }
      );
      bump('vital_signs');

      await ctx.upsert(
        'procedure',
        `${scenario.key}:volx:procedure:${pad(index)}`,
        {
          encounter_id: encounter.id,
          code: `PROC-${(index % 20) + 1}`,
          description: `Volume clinical procedure #${index}`,
          performed_at: ctx.date(-((index % 80) + 1), 40),
        },
        { publicIdPrefix: 'PRC', seedMeta: false }
      );
      bump('procedures');
    });
  }

  if (admissions.length > 0 && nurse) {
    await runInBatches(n, 10, async (index) => {
      const admission = at(admissions, index);
      if (!admission) return;

      await ctx.upsert(
        'nursing_note',
        `${scenario.key}:volx:nursing-note:${pad(index)}`,
        {
          admission_id: admission.id,
          nurse_user_id: nurse.id,
          note: `Volume nursing note #${index}: patient reviewed; vitals stable.`,
        },
        { publicIdPrefix: 'NNT', seedMeta: false }
      );
      bump('nursing_notes');

      await ctx.upsert(
        'ward_round',
        `${scenario.key}:volx:ward-round:${pad(index)}`,
        {
          admission_id: admission.id,
          round_at: ctx.date(-((index % 50) + 1), 8 + (index % 12)),
          notes: `Volume ward round #${index}`,
        },
        { publicIdPrefix: 'WRD', seedMeta: false }
      );
      bump('ward_rounds');

      await ctx.upsert(
        'medication_administration',
        `${scenario.key}:volx:mar:${pad(index)}`,
        {
          admission_id: admission.id,
          administered_at: ctx.date(-((index % 50) + 1), 9 + (index % 10)),
          dose: `${1 + (index % 2)}`,
          unit: 'tab',
          route: pick(MED_ROUTES, index),
        },
        { publicIdPrefix: 'MAR', seedMeta: false }
      );
      bump('medication_administrations');

      await ctx.upsert(
        'discharge_summary',
        `${scenario.key}:volx:discharge:${pad(index)}`,
        {
          admission_id: admission.id,
          summary: `Volume discharge summary #${index}`,
          status: pick(DISCHARGE_STATUSES, index),
          discharged_at: index % 3 === 0 ? ctx.date(-((index % 40) + 1), 70) : null,
        },
        { publicIdPrefix: 'DSC', seedMeta: false }
      );
      bump('discharge_summaries');
    });
  }

  // --- Reception visit queue ---
  if (patients.length > 0) {
    await runInBatches(n, 10, async (index) => {
      const patientId = at(patients, index)?.id;
      if (!patientId) return;
      const appointment = at(appointments, index);
      await ctx.upsert(
        'visit_queue',
        `${scenario.key}:volx:visit-queue:${pad(index)}`,
        {
          tenant_id: facility.tenant_id,
          facility_id: facility.id,
          patient_id: patientId,
          appointment_id: appointment?.id || null,
          provider_user_id: doctor?.id || null,
          status: pick(QUEUE_STATUSES, index),
          queued_at: ctx.date(-((index % 60) + 1), 5 + (index % 40)),
          is_prioritized: index % 11 === 0,
        },
        { ...seedOpts, publicIdPrefix: 'VQ' }
      );
      bump('visit_queues');
    });
  }

  // --- Billing extras: refunds, adjustments, insurance ---
  const refundablePayments = payments.filter(
    (payment) => payment.status === 'COMPLETED' || payment.status === 'REFUNDED'
  );
  if (refundablePayments.length > 0) {
    await runInBatches(n, 10, async (index) => {
      const payment = at(refundablePayments, index);
      if (!payment) return;
      await ctx.upsert(
        'refund',
        `${scenario.key}:volx:refund:${pad(index)}`,
        {
          payment_id: payment.id,
          amount: Math.max(5, Number(payment.amount || 50) / 4),
          refunded_at: ctx.date(-((index % 80) + 1), 85),
          reason: `Volume refund #${index}`,
        },
        { publicIdPrefix: 'RFD', seedMeta: false }
      );
      bump('refunds');
    });
  }

  if (invoices.length > 0) {
    await runInBatches(n, 10, async (index) => {
      const invoice = at(invoices, index);
      if (!invoice) return;
      await ctx.upsert(
        'billing_adjustment',
        `${scenario.key}:volx:billing-adj:${pad(index)}`,
        {
          invoice_id: invoice.id,
          amount: index % 2 === 0 ? -(10 + (index % 20)) : 10 + (index % 15),
          status: pick(BILLING_ADJ_STATUSES, index),
          reason: `Volume billing adjustment #${index}`,
          adjusted_at: ctx.date(-((index % 70) + 1), 55),
        },
        { publicIdPrefix: 'BADJ', seedMeta: false }
      );
      bump('billing_adjustments');
    });
  }

  const insurers = [];
  for (let i = 1; i <= 8; i += 1) {
    const company = await ctx.upsert(
      'insurance_company',
      `${scenario.key}:volx:insurer:${pad(i)}`,
      {
        tenant_id: facility.tenant_id,
        name: `Demo Insurer ${i}`,
        code: `DINS-${pad(i, 2)}`,
        is_active: true,
        notes: 'Volume seed insurer',
      },
      { ...seedOpts, publicIdPrefix: 'INS' }
    );
    insurers.push(company);
    bump('insurance_companies');
  }

  const plans = [];
  for (let i = 1; i <= 16; i += 1) {
    const company = at(insurers, i);
    const plan = await ctx.upsert(
      'coverage_plan',
      `${scenario.key}:volx:coverage:${pad(i)}`,
      {
        tenant_id: facility.tenant_id,
        insurance_company_id: company?.id || null,
        name: `Demo Coverage Plan ${i}`,
        code: `DCP-${pad(i, 2)}`,
        provider_name: company?.name || 'Demo Payer',
        coverage_percentage: 50 + (i % 5) * 10,
        status: 'ACTIVE',
        effective_from: ctx.date(-365),
        default_copay_type: 'NONE',
      },
      { ...seedOpts, publicIdPrefix: 'CPL' }
    );
    plans.push(plan);
    bump('coverage_plans');
  }

  if (plans.length > 0 && invoices.length > 0) {
    await runInBatches(n, 10, async (index) => {
      const plan = at(plans, index);
      const invoice = at(invoices, index);
      const company = at(insurers, index);
      if (!plan || !invoice) return;
      await ctx.upsert(
        'insurance_claim',
        `${scenario.key}:volx:claim:${pad(index)}`,
        {
          coverage_plan_id: plan.id,
          insurance_company_id: company?.id || null,
          invoice_id: invoice.id,
          status: pick(CLAIM_STATUSES, index),
          submitted_at: ctx.date(-((index % 90) + 1), 60),
          claim_amount: Number(invoice.total_amount || 100),
          settlement_amount: index % 3 === 0 ? Number(invoice.total_amount || 100) * 0.8 : null,
          payer_reference: `CLM-${pad(index, 5)}`,
          notes: `Volume insurance claim #${index}`,
        },
        { publicIdPrefix: 'ICLM', seedMeta: false }
      );
      bump('insurance_claims');

      const patientId = at(patients, index)?.id || invoice.patient_id;
      await ctx.upsert(
        'pre_authorization',
        `${scenario.key}:volx:preauth:${pad(index)}`,
        {
          coverage_plan_id: plan.id,
          patient_id: patientId || null,
          encounter_id: at(encounters, index)?.id || null,
          admission_id: at(admissions, index)?.id || null,
          status: pick(AUTH_STATUSES, index),
          reason: 'Volume elective procedure authorization',
          approved_amount: 100 + (index % 50) * 10,
          consumed_amount: index % 4 === 0 ? 50 : 0,
          requested_at: ctx.date(-((index % 70) + 1), 30),
          approved_at: index % 2 === 0 ? ctx.date(-((index % 60) + 1), 45) : null,
          notes: `Volume pre-authorization #${index}`,
        },
        { publicIdPrefix: 'PAUTH', seedMeta: false }
      );
      bump('pre_authorizations');
    });
  }

  // --- ED triage + ambulance graph ---
  if (emergencies.length > 0) {
    await runInBatches(n, 10, async (index) => {
      const emergency = at(emergencies, index);
      if (!emergency) return;
      await ctx.upsert(
        'triage_assessment',
        `${scenario.key}:volx:triage:${pad(index)}`,
        {
          emergency_case_id: emergency.id,
          triage_level: pick(TRIAGE_LEVELS, index),
          notes: `Volume triage #${index}`,
        },
        { publicIdPrefix: 'TRI', seedMeta: false }
      );
      bump('triage_assessments');
    });

    const ambulances = [];
    for (let i = 1; i <= 12; i += 1) {
      const ambulance = await ctx.upsert(
        'ambulance',
        `${scenario.key}:volx:ambulance:${pad(i)}`,
        {
          tenant_id: facility.tenant_id,
          facility_id: facility.id,
          identifier: `AMB-VOL-${pad(i, 2)}`,
          status: pick(AMBULANCE_STATUSES, i),
        },
        { ...seedOpts, publicIdPrefix: 'AMB' }
      );
      ambulances.push(ambulance);
      bump('ambulances');
    }

    await runInBatches(n, 10, async (index) => {
      const emergency = at(emergencies, index);
      const ambulance = at(ambulances, index);
      if (!emergency || !ambulance) return;
      await ctx.upsert(
        'ambulance_dispatch',
        `${scenario.key}:volx:amb-dispatch:${pad(index)}`,
        {
          ambulance_id: ambulance.id,
          emergency_case_id: emergency.id,
          dispatched_at: ctx.date(-((index % 40) + 1), 10),
          status: pick(AMBULANCE_STATUSES, index),
        },
        { publicIdPrefix: 'ADSP', seedMeta: false }
      );
      bump('ambulance_dispatches');

      await ctx.upsert(
        'ambulance_trip',
        `${scenario.key}:volx:amb-trip:${pad(index)}`,
        {
          ambulance_id: ambulance.id,
          emergency_case_id: emergency.id,
          started_at: ctx.date(-((index % 40) + 1), 15),
          ended_at: index % 3 === 0 ? null : ctx.date(-((index % 40) + 1), 55),
        },
        { publicIdPrefix: 'ATRP', seedMeta: false }
      );
      bump('ambulance_trips');
    });
  }

  // --- HR roster / shifts / payroll ---
  const rosters = [];
  for (let i = 1; i <= 24; i += 1) {
    const roster = await ctx.upsert(
      'nurse_roster',
      `${scenario.key}:volx:roster:${pad(i)}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        department_id: orgPack?.departments?.[`${scenario.key}:Inpatient`]?.id || null,
        period_start: ctx.date(-(i * 7 + 7)),
        period_end: ctx.date(-(i * 7)),
        status: i % 4 === 0 ? 'DRAFT' : 'PUBLISHED',
        published_at: i % 4 === 0 ? null : ctx.date(-(i * 7 + 8)),
      },
      { ...seedOpts, publicIdPrefix: 'NRS' }
    );
    rosters.push(roster);
    bump('nurse_rosters');
  }

  const shifts = [];
  await runInBatches(n, 10, async (index) => {
    const roster = at(rosters, index);
    const dayOffset = -((index % 120) + 1);
    const shift = await ctx.upsert(
      'shift',
      `${scenario.key}:volx:shift:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        nurse_roster_id: roster?.id || null,
        shift_type: pick(SHIFT_TYPES, index),
        status: pick(SHIFT_STATUSES, index),
        start_time: ctx.date(dayOffset, (index % 2 === 0 ? 8 : 18) * 60),
        end_time: ctx.date(dayOffset + (index % 2 === 0 ? 0 : 1), (index % 2 === 0 ? 16 : 6) * 60),
      },
      { ...seedOpts, publicIdPrefix: 'SFT' }
    );
    shifts.push(shift);
    bump('shifts');

    const staffProfile = at(staffProfiles, index);
    if (staffProfile) {
      await ctx.upsert(
        'shift_assignment',
        `${scenario.key}:volx:shift-asg:${pad(index)}`,
        {
          shift_id: shift.id,
          staff_profile_id: staffProfile.id,
          assigned_at: ctx.date(-((index % 100) + 1), 5),
        },
        { publicIdPrefix: 'SASG', seedMeta: false }
      );
      bump('shift_assignments');
    }
  });

  const payrollRuns = [];
  for (let i = 1; i <= 36; i += 1) {
    const run = await ctx.upsert(
      'payroll_run',
      `${scenario.key}:volx:payroll:${pad(i)}`,
      {
        tenant_id: facility.tenant_id,
        period_start: ctx.date(-(i * 30 + 30)),
        period_end: ctx.date(-(i * 30)),
        status: pick(PAYROLL_STATUSES, i),
      },
      { ...seedOpts, publicIdPrefix: 'PAYR' }
    );
    payrollRuns.push(run);
    bump('payroll_runs');
  }

  if (staffProfiles.length > 0 && payrollRuns.length > 0) {
    await runInBatches(n, 10, async (index) => {
      const run = at(payrollRuns, index);
      const staffProfile = at(staffProfiles, index);
      if (!run || !staffProfile) return;
      await ctx.upsert(
        'payroll_item',
        `${scenario.key}:volx:payroll-item:${pad(index)}`,
        {
          payroll_run_id: run.id,
          staff_profile_id: staffProfile.id,
          amount: 800000 + (index % 40) * 25000,
          currency: 'UGX',
        },
        { publicIdPrefix: 'PAYI', seedMeta: false }
      );
      bump('payroll_items');
    });
  }

  // --- Communications volume ---
  await runInBatches(Math.min(n, 500), 10, async (index) => {
    const creator = at(staffUsers, index) || doctor;
    const conversation = await ctx.upsert(
      'conversation',
      `${scenario.key}:volx:conversation:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        subject: `Volume thread #${index}`,
        created_by_user_id: creator?.id || null,
        conversation_type: index % 3 === 0 ? 'GROUP' : 'DIRECT',
        status: index % 7 === 0 ? 'ARCHIVED' : 'OPEN',
        is_sensitive: index % 11 === 0,
        last_message_at: ctx.date(-((index % 40) + 1), 50),
        archived_at: index % 7 === 0 ? ctx.date(-((index % 20) + 1), 70) : null,
      },
      { ...seedOpts, publicIdPrefix: 'CONV' }
    );
    bump('conversations');

    if (creator) {
      await ctx.upsert(
        'conversation_participant',
        `${scenario.key}:volx:conv-part-a:${pad(index)}`,
        {
          conversation_id: conversation.id,
          user_id: creator.id,
          role_snapshot: 'MEMBER',
          joined_at: ctx.date(-((index % 40) + 1), 40),
        },
        { publicIdPrefix: 'CPART', seedMeta: false }
      );
      const peer = at(staffUsers, index + 1);
      if (peer && peer.id !== creator.id) {
        await ctx.upsert(
          'conversation_participant',
          `${scenario.key}:volx:conv-part-b:${pad(index)}`,
          {
            conversation_id: conversation.id,
            user_id: peer.id,
            role_snapshot: 'MEMBER',
            joined_at: ctx.date(-((index % 40) + 1), 41),
          },
          { publicIdPrefix: 'CPART', seedMeta: false }
        );
      }
      bump('conversation_participants');
    }

    await ctx.upsert(
      'message',
      `${scenario.key}:volx:message:${pad(index)}`,
      {
        conversation_id: conversation.id,
        sender_user_id: creator?.id || null,
        content: `Volume message body #${index} for facility operations coordination.`,
        message_type: 'TEXT',
        sent_at: ctx.date(-((index % 40) + 1), 50),
      },
      { publicIdPrefix: 'MSG', seedMeta: false }
    );
    bump('messages');
  });

  // Keep curated hero conversations referenced so they aren't lost conceptually.
  void communicationsPack;

  // --- Compliance / audit volume ---
  await runInBatches(n, 10, async (index) => {
    const user = at(staffUsers, index);
    const patientId = at(patients, index)?.id;
    await ctx.upsert(
      'audit_log',
      `${scenario.key}:volx:audit:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        user_id: user?.id || null,
        action: pick(AUDIT_ACTIONS, index),
        entity: pick(['patient', 'invoice', 'encounter', 'lab_order', 'report_run'], index),
        entity_id: patientId || `00000000-0000-4000-a000-${pad(index, 12)}`,
        diff_json: { volume: true, index },
        ip_address: `10.0.${index % 200}.${(index * 3) % 200}`,
      },
      { ...seedOpts, publicIdPrefix: 'AUD' }
    );
    bump('audit_logs');

    if (user && patientId) {
      await ctx.upsert(
        'phi_access_log',
        `${scenario.key}:volx:phi:${pad(index)}`,
        {
          tenant_id: facility.tenant_id,
          user_id: user.id,
          patient_id: patientId,
          access_scope: pick(ACCESS_SCOPES, index),
          reason: `Volume PHI access #${index}`,
          accessed_at: ctx.date(-((index % 100) + 1), 12),
        },
        { ...seedOpts, publicIdPrefix: 'PHI' }
      );
      bump('phi_access_logs');
    }
  });

  // --- Reporting & analytics ---
  const definitions = [];
  const datasetList = REPORT_DATASET_SEEDS;
  for (let i = 0; i < datasetList.length; i += 1) {
    const dataset = datasetList[i];
    for (let copy = 1; copy <= 3; copy += 1) {
      const definition = await ctx.upsert(
        'report_definition',
        `${scenario.key}:volx:report-def:${dataset.key}:${copy}`,
        {
          tenant_id: facility.tenant_id,
          created_by: billing?.id || doctor?.id || null,
          facility_id: facility.id,
          name: `${dataset.label || dataset.key} #${copy}`,
          dataset_key: dataset.key,
          category: dataset.category || 'operations',
          status: copy === 3 ? 'ARCHIVED' : copy === 2 ? 'DRAFT' : 'ACTIVE',
          default_format: pick(REPORT_FORMATS, i + copy),
          description: `Volume report definition for ${dataset.key}`,
          definition_json: {
            visualization: dataset.visualization || 'TABLE',
            columns: ['date', 'value'],
          },
          parameter_schema_json: { range: ['today', 'this_month', 'custom'] },
        },
        { ...seedOpts, publicIdPrefix: 'RDEF' }
      );
      definitions.push(definition);
      bump('report_definitions');
    }
  }

  if (definitions.length > 0) {
    await runInBatches(n, 10, async (index) => {
      const definition = at(definitions, index);
      const status = pick(RUN_STATUSES, index);
      await ctx.upsert(
        'report_run',
        `${scenario.key}:volx:report-run:${pad(index)}`,
        {
          tenant_id: facility.tenant_id,
          report_definition_id: definition.id,
          facility_id: facility.id,
          requested_by_user_id: billing?.id || doctor?.id || null,
          trigger_type: index % 4 === 0 ? 'SCHEDULED' : 'MANUAL',
          format: pick(REPORT_FORMATS, index),
          parameters_json: { period: pick(['today', 'this_month', 'year'], index) },
          status,
          output_file_name: status === 'COMPLETED' ? `vol-report-${pad(index)}.pdf` : null,
          output_mime_type: status === 'COMPLETED' ? 'application/pdf' : null,
          queued_at: ctx.date(-((index % 120) + 1), 10),
          started_at: status === 'QUEUED' ? null : ctx.date(-((index % 120) + 1), 12),
          completed_at: status === 'COMPLETED' || status === 'FAILED'
            ? ctx.date(-((index % 120) + 1), 20)
            : null,
          error_message: status === 'FAILED' ? `Volume run failure #${index}` : null,
        },
        { ...seedOpts, publicIdPrefix: 'RRUN' }
      );
      bump('report_runs');
    });

    await runInBatches(Math.min(n, 200), 10, async (index) => {
      const definition = at(definitions, index);
      await ctx.upsert(
        'dashboard_widget',
        `${scenario.key}:volx:widget:${pad(index)}`,
        {
          tenant_id: facility.tenant_id,
          report_definition_id: definition?.id || null,
          name: `Volume widget #${index}`,
          widget_type: pick(WIDGET_TYPES, index),
          placement: pick(['overview', 'billing', 'clinical', 'ops'], index),
          sort_order: index,
          is_pinned: index % 5 === 0,
          config_json: { source: 'volume_seed', index },
        },
        { ...seedOpts, publicIdPrefix: 'DWGT' }
      );
      bump('dashboard_widgets');
    });
  }

  await runInBatches(n, 10, async (index) => {
    await ctx.upsert(
      'kpi_snapshot',
      `${scenario.key}:volx:kpi:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        name: `Volume KPI #${index}`,
        metric_key: pick([
          'collections_today',
          'opd_wait_minutes',
          'bed_occupancy',
          'lab_turnaround',
          'pharmacy_pending',
        ], index),
        metric_group: pick(['billing', 'clinical', 'ops', 'diagnostics'], index),
        value: 10 + (index % 500),
        threshold_state: pick(KPI_STATES, index),
        recorded_at: ctx.date(-((index % 180) + 1), index % 120),
      },
      { ...seedOpts, publicIdPrefix: 'KPI' }
    );
    bump('kpi_snapshots');
  });

  await runInBatches(n, 10, async (index) => {
    await ctx.upsert(
      'analytics_event',
      `${scenario.key}:volx:analytics:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        user_id: at(staffUsers, index)?.id || null,
        facility_id: facility.id,
        event_name: pick([
          'report.run.completed',
          'invoice.paid',
          'appointment.checked_in',
          'lab.result.posted',
        ], index),
        event_category: pick(['reports', 'billing', 'clinical', 'diagnostics'], index),
        entity_type: pick(['report_run', 'invoice', 'appointment', 'lab_result'], index),
        entity_public_id: `VOL-${pad(index)}`,
        severity: pick(['INFO', 'WARNING', 'ERROR'], index),
        payload_json: { volume: true, index },
        occurred_at: ctx.date(-((index % 150) + 1), index % 90),
      },
      { ...seedOpts, publicIdPrefix: 'AEVT' }
    );
    bump('analytics_events');
  });

  // --- Patient report jobs (clinical print/export feel) ---
  if (patients.length > 0) {
    await runInBatches(n, 10, async (index) => {
      const patientId = at(patients, index)?.id;
      if (!patientId) return;
      await ctx.upsert(
        'patient_report_job',
        `${scenario.key}:volx:patient-report:${pad(index)}`,
        {
          tenant_id: facility.tenant_id,
          facility_id: facility.id,
          patient_id: patientId,
          encounter_id: at(encounters, index)?.id || null,
          requested_by_user_id: doctor?.id || receptionist?.id || null,
          report_type: pick(['ENCOUNTER_SUMMARY', 'DISCHARGE', 'LAB_BUNDLE', 'INVOICE'], index),
          action: pick(['PRINT', 'DOWNLOAD', 'EMAIL'], index),
          status: pick(['QUEUED', 'PROCESSING', 'READY', 'FAILED', 'CANCELLED'], index),
          format: 'PDF',
          sections_json: { sections: ['demographics', 'clinical', 'billing'] },
          queued_at: ctx.date(-((index % 60) + 1), 15),
        },
        { ...seedOpts, publicIdPrefix: 'PRJ' }
      );
      bump('patient_report_jobs');
    });
  }

  console.log('Extended demo volume complete:', created);

  return {
    skipped: false,
    created,
    targets,
  };
};

module.exports = {
  seedVolumeExtendedPack,
};
