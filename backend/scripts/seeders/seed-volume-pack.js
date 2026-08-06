/**
 * FK-aware demo volume expansion.
 *
 * Seeds status-diverse operational graphs for demonstrations.
 * Skipped when targetCount <= 0 (curated-only mode).
 *
 * Applicable operational models target `targetCount` (default 1000).
 *
 * Intentional exceptions (not volume-filled here): singleton tenant/facility/
 * subscription/license, plan/add-on/module catalogs, role/permission catalogs.
 */

const { DEMO_TENANT } = require('./seed-catalog');

/** Preferred high-traffic volume when SEED_RECORD_COUNT is unset. */
const DEFAULT_DEMO_VOLUME_TARGET = 1000;
/** Minimum rows for applicable operational tables when volume mode is on. */
const MIN_APPLICABLE_VOLUME = 100;

const FIRST_NAMES = Object.freeze([
  'Amina', 'Samuel', 'Nia', 'Grace', 'Noah', 'Diana', 'Ethan', 'Faith', 'Isaac', 'Joy',
  'Kevin', 'Lydia', 'Moses', 'Naomi', 'Oscar', 'Patience', 'Quincy', 'Ruth', 'Silas', 'Tasha',
  'Umar', 'Vera', 'Wesley', 'Xenia', 'Yuri', 'Zara', 'Brian', 'Chloe', 'Daniel', 'Esther',
]);

const LAST_NAMES = Object.freeze([
  'Okello', 'Nakato', 'Ssebunya', 'Achieng', 'Mugisha', 'Nabirye', 'Kato', 'Namukasa',
  'Ochieng', 'Asiimwe', 'Tumusiime', 'Wanyama', 'Birungi', 'Kiggundu', 'Nabukeera', 'Ouma',
]);

const APPOINTMENT_STATUSES = Object.freeze([
  'SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW',
]);
const ENCOUNTER_STATUSES = Object.freeze(['OPEN', 'CLOSED', 'CANCELLED']);
const ENCOUNTER_TYPES = Object.freeze([
  'OPD', 'IPD', 'EMERGENCY', 'TELEMEDICINE', 'LAB', 'ICU',
]);
const LAB_ORDER_STATUSES = Object.freeze([
  'ORDERED', 'COLLECTED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED',
]);
const LAB_RESULT_STATUSES = Object.freeze(['NORMAL', 'ABNORMAL', 'CRITICAL', 'PENDING']);
const PHARMACY_ORDER_STATUSES = Object.freeze([
  'ORDERED', 'DISPENSED', 'PARTIALLY_DISPENSED', 'CANCELLED',
]);
const DISPENSE_STATUSES = Object.freeze(['PENDING', 'DISPENSED', 'RETURNED', 'CANCELLED']);
const INVOICE_STATUSES = Object.freeze(['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED']);
const BILLING_STATUSES = Object.freeze(['DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED']);
const PAYMENT_STATUSES = Object.freeze(['PENDING', 'COMPLETED', 'FAILED', 'REFUNDED']);
const PAYMENT_METHODS = Object.freeze([
  'CASH', 'MOBILE_MONEY', 'BANK_TRANSFER', 'CREDIT_CARD', 'INSURANCE', 'OTHER',
]);
const RADIOLOGY_ORDER_STATUSES = Object.freeze([
  'ORDERED', 'IN_PROCESS', 'AWAITING_REPORT', 'COMPLETED', 'CANCELLED',
]);
const RADIOLOGY_REPORT_STATUSES = Object.freeze(['DRAFT', 'FINAL', 'AMENDED']);
const ADMISSION_STATUSES = Object.freeze([
  'REQUESTED', 'ADMITTED', 'DISCHARGED', 'TRANSFERRED', 'CANCELLED',
]);
const EMERGENCY_SEVERITIES = Object.freeze(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']);
const WORK_ORDER_STATUSES = Object.freeze([
  'OPEN', 'ASSIGNED', 'IN_PROGRESS', 'TESTING', 'COMPLETED', 'CLOSED', 'CANCELLED',
]);
const WORK_ORDER_PRIORITIES = Object.freeze(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']);
const MORTUARY_CASE_STATUSES = Object.freeze([
  'RECEIVED',
  'IDENTIFICATION_PENDING',
  'IN_STORAGE',
  'POST_MORTEM_PENDING',
  'READY_FOR_RELEASE',
  'RELEASED',
  'CLOSED',
  'CANCELLED',
]);
const MORTUARY_ID_STATUSES = Object.freeze(['UNVERIFIED', 'PARTIAL', 'VERIFIED']);
const NOTIFICATION_TYPES = Object.freeze([
  'SYSTEM', 'APPOINTMENT', 'BILLING', 'LAB', 'PHARMACY', 'EMERGENCY', 'OTHER',
]);
const NOTIFICATION_PRIORITIES = Object.freeze(['LOW', 'MEDIUM', 'HIGH', 'URGENT']);
const DELIVERY_STATUSES = Object.freeze([
  'QUEUED', 'SENDING', 'SENT', 'DELIVERED', 'FAILED', 'READ',
]);
const DELIVERY_CHANNELS = Object.freeze(['IN_APP', 'SMS', 'EMAIL', 'PUSH']);
const STOCK_MOVEMENT_TYPES = Object.freeze(['INBOUND', 'OUTBOUND', 'ADJUSTMENT', 'TRANSFER']);
const STOCK_REASONS = Object.freeze([
  'PURCHASE', 'DISPENSE', 'RETURN', 'DAMAGE', 'EXPIRY', 'OTHER',
]);
const GENDERS = Object.freeze(['MALE', 'FEMALE', 'OTHER', 'UNKNOWN']);

const pick = (values, index) => values[index % values.length];

const pad = (value, width = 4) => String(value).padStart(width, '0');

const resolveSecondaryTarget = (targetCount) => {
  if (!Number.isFinite(targetCount) || targetCount <= 0) return 0;
  // All applicable volume tables use the same target (≥1000 by default).
  return targetCount;
};

const resolveVolumeTargets = (targetCount) => {
  const parsed = Number.parseInt(String(targetCount), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return { skipped: true, highTraffic: 0, secondary: 0 };
  }
  return {
    skipped: false,
    highTraffic: parsed,
    secondary: resolveSecondaryTarget(parsed),
  };
};

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

const firstCatalogValue = (bucket = {}) => {
  const values = Object.values(bucket);
  return values.length > 0 ? values[0] : null;
};

const catalogValues = (bucket = {}, limit = 8) => Object.values(bucket).slice(0, limit);

const seedVolumePack = async (
  ctx,
  targetCount,
  {
    orgPack,
    accessPack,
    clinicalPack,
    clinicalCatalogPack,
    operationsPack,
    biomedicalPack,
    mortuaryPack,
  } = {}
) => {
  const targets = resolveVolumeTargets(targetCount);
  if (targets.skipped) {
    return {
      skipped: true,
      reason: 'target_count_zero',
      targets,
      created: {},
    };
  }

  const scenario = DEMO_TENANT;
  const facility = orgPack?.facilities?.[`${scenario.key}:${scenario.facilities[0].key}`];
  if (!facility) {
    throw new Error('seedVolumePack requires orgPack.facilities for the demo tenant');
  }

  const doctor = accessPack?.users?.[`${scenario.key}:doctor`];
  const nurse = accessPack?.users?.[`${scenario.key}:nurse`] || doctor;
  const labUser = accessPack?.users?.[`${scenario.key}:lab`] || doctor;
  const radiologyUser = accessPack?.users?.[`${scenario.key}:radiology`] || doctor;
  const billingUser = accessPack?.users?.[`${scenario.key}:billing`] || doctor;
  const biomedUser = accessPack?.users?.[`${scenario.key}:biomed`] || nurse;
  const receptionUser = accessPack?.users?.[`${scenario.key}:reception`] || nurse;

  const staffUsers = [
    doctor,
    nurse,
    labUser,
    radiologyUser,
    billingUser,
    biomedUser,
    receptionUser,
  ].filter(Boolean);

  const labTests = catalogValues(clinicalCatalogPack?.lab?.tests, 12);
  const radiologyProcedures = catalogValues(clinicalCatalogPack?.radiology?.tests, 8);
  const drugs = catalogValues(clinicalCatalogPack?.pharmacy?.drugs, 12);
  const inventoryItems = [
    ...catalogValues(clinicalCatalogPack?.pharmacy?.inventoryItems, 12),
    ...Object.values(operationsPack?.inventoryItems || {}),
  ].filter(Boolean);
  const equipmentRegistry =
    biomedicalPack?.registries?.[scenario.key] || firstCatalogValue(biomedicalPack?.registries);
  const mortuaryProfile =
    mortuaryPack?.deceasedProfiles?.[`${scenario.key}:external`]
    || firstCatalogValue(mortuaryPack?.deceasedProfiles);

  const seedOpts = {
    tenantCode: scenario.tenant_code,
    scenarioKey: scenario.scenario_key,
  };

  const patients = [];
  const encounters = [];
  const admissions = [];
  const appointments = [];
  const invoices = [];
  const payments = [];
  const emergencies = [];
  const radiologyOrders = [];
  const created = {
    patients: 0,
    appointments: 0,
    encounters: 0,
    admissions: 0,
    lab_orders: 0,
    lab_results: 0,
    radiology_orders: 0,
    radiology_results: 0,
    pharmacy_orders: 0,
    dispense_logs: 0,
    invoices: 0,
    payments: 0,
    emergency_cases: 0,
    stock_movements: 0,
    equipment_work_orders: 0,
    mortuary_cases: 0,
    notifications: 0,
    notification_deliveries: 0,
  };

  console.log(
    `Seeding demo volume pack (high-traffic=${targets.highTraffic}, secondary=${targets.secondary})...`
  );

  await runInBatches(targets.highTraffic, 10, async (index) => {
    const key = `vol-${pad(index)}`;
    const patient = await ctx.upsert(
      'patient',
      `${scenario.key}:vol:patient:${key}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        first_name: pick(FIRST_NAMES, index),
        last_name: pick(LAST_NAMES, index + 3),
        date_of_birth: ctx.date(-(365 * (18 + (index % 50)) + (index % 30))),
        gender: pick(GENDERS, index),
        is_active: index % 17 !== 0,
        extension_json: {
          demo_profile: true,
          fictional_identity: true,
          volume_index: index,
        },
      },
      { ...seedOpts, publicIdPrefix: 'PAT' }
    );

    await ctx.upsert(
      'patient_identifier',
      `${scenario.key}:vol:patient-id:${key}`,
      {
        tenant_id: facility.tenant_id,
        patient_id: patient.id,
        identifier_type: 'MRN',
        identifier_value: `DMO-VOL-${pad(index, 5)}`,
        is_primary: true,
      },
      { publicIdPrefix: 'PID', seedMeta: false }
    );

    patients.push(patient);
    created.patients += 1;
  });

  const patientAt = (index) => patients[(index - 1) % patients.length]
    || clinicalPack?.patients?.[`${scenario.key}:p${((index - 1) % 5) + 1}`];

  await runInBatches(targets.highTraffic, 10, async (index) => {
    const patient = patientAt(index);
    if (!patient) return;
    const status = pick(APPOINTMENT_STATUSES, index);
    const startOffset = -((index % 120) + 1);
    const appointment = await ctx.upsert(
      'appointment',
      `${scenario.key}:vol:appointment:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        patient_id: patient.id,
        provider_user_id: doctor?.id || null,
        status,
        scheduled_start: ctx.date(startOffset, 30 + (index % 40)),
        scheduled_end: ctx.date(startOffset, 60 + (index % 40)),
        reason: `Volume demo appointment #${index} (${status})`,
      },
      { ...seedOpts, publicIdPrefix: 'APT' }
    );
    appointments.push(appointment);
    created.appointments += 1;
  });

  await runInBatches(targets.highTraffic, 10, async (index) => {
    const patient = patientAt(index);
    if (!patient) return;
    const status = pick(ENCOUNTER_STATUSES, index);
    const encounterType = pick(ENCOUNTER_TYPES, index);
    const started = ctx.date(-((index % 90) + 1), 10 + (index % 50));
    const encounter = await ctx.upsert(
      'encounter',
      `${scenario.key}:vol:encounter:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        patient_id: patient.id,
        provider_user_id: doctor?.id || nurse?.id || null,
        encounter_type: encounterType,
        status,
        started_at: started,
        ended_at: status === 'CLOSED' ? ctx.date(-((index % 90) + 1), 70 + (index % 30)) : null,
      },
      { ...seedOpts, publicIdPrefix: 'ENC' }
    );
    encounters.push(encounter);
    created.encounters += 1;
  });

  const encounterAt = (index) => encounters[(index - 1) % Math.max(1, encounters.length)];

  await runInBatches(targets.secondary, 10, async (index) => {
    const patient = patientAt(index);
    const encounter = encounterAt(index);
    if (!patient) return;
    const status = pick(ADMISSION_STATUSES, index);
    const admission = await ctx.upsert(
      'admission',
      `${scenario.key}:vol:admission:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        patient_id: patient.id,
        encounter_id: encounter?.id || null,
        status,
        admitted_at: ctx.date(-((index % 60) + 1), 15),
        discharged_at: status === 'DISCHARGED' ? ctx.date(-((index % 30) + 1), 80) : null,
      },
      { ...seedOpts, publicIdPrefix: 'ADM' }
    );
    admissions.push(admission);
    created.admissions += 1;
  });

  if (labTests.length > 0) {
    await runInBatches(targets.highTraffic, 10, async (index) => {
      const patient = patientAt(index);
      const encounter = encounterAt(index);
      if (!patient) return;
      const orderStatus = pick(LAB_ORDER_STATUSES, index);
      const labTest = pick(labTests, index);
      const order = await ctx.upsert(
        'lab_order',
        `${scenario.key}:vol:lab-order:${pad(index)}`,
        {
          encounter_id: encounter?.id || null,
          patient_id: patient.id,
          status: orderStatus,
          ordered_at: ctx.date(-((index % 80) + 1), 20),
          ordered_by_user_id: labUser?.id || doctor?.id || null,
        },
        { publicIdPrefix: 'LBO', seedMeta: false }
      );

      const item = await ctx.upsert(
        'lab_order_item',
        `${scenario.key}:vol:lab-order-item:${pad(index)}`,
        {
          lab_order_id: order.id,
          lab_test_id: labTest.id,
          status: orderStatus === 'CANCELLED' ? 'CANCELLED' : orderStatus,
        },
        { publicIdPrefix: 'LBI', seedMeta: false }
      );

      if (orderStatus !== 'ORDERED' && orderStatus !== 'CANCELLED') {
        await ctx.upsert(
          'lab_sample',
          `${scenario.key}:vol:lab-sample:${pad(index)}`,
          {
            lab_order_id: order.id,
            status: orderStatus === 'COLLECTED' ? 'COLLECTED' : 'RECEIVED',
            collected_at: ctx.date(-((index % 80) + 1), 30),
            received_at: orderStatus === 'COLLECTED' ? null : ctx.date(-((index % 80) + 1), 40),
          },
          { publicIdPrefix: 'LBS', seedMeta: false }
        );
      }

      const resultStatus = orderStatus === 'COMPLETED'
        ? pick(LAB_RESULT_STATUSES.filter((status) => status !== 'PENDING'), index)
        : orderStatus === 'CANCELLED'
          ? 'PENDING'
          : pick(LAB_RESULT_STATUSES, index);

      await ctx.upsert(
        'lab_result',
        `${scenario.key}:vol:lab-result:${pad(index)}`,
        {
          lab_order_item_id: item.id,
          status: resultStatus,
          result_value: resultStatus === 'PENDING' ? null : String(4 + (index % 20)),
          result_unit: labTest.unit || 'unit',
          result_text: `Volume lab result #${index} (${resultStatus})`,
          result_flag: resultStatus === 'ABNORMAL' || resultStatus === 'CRITICAL' ? 'HIGH' : null,
          is_positive: resultStatus === 'CRITICAL',
        },
        { publicIdPrefix: 'LBR', seedMeta: false }
      );

      created.lab_orders += 1;
      created.lab_results += 1;
    });
  }

  if (radiologyProcedures.length > 0) {
    await runInBatches(targets.secondary, 10, async (index) => {
      const patient = patientAt(index);
      if (!patient) return;
      const orderStatus = pick(RADIOLOGY_ORDER_STATUSES, index);
      const procedure = pick(radiologyProcedures, index);
      const order = await ctx.upsert(
        'radiology_order',
        `${scenario.key}:vol:rad-order:${pad(index)}`,
        {
          encounter_id: encounterAt(index)?.id || null,
          patient_id: patient.id,
          radiology_procedure_id: procedure.id,
          status: orderStatus,
          clinical_note: `Volume radiology request #${index}`,
          assigned_user_id: radiologyUser?.id || null,
          ordered_at: ctx.date(-((index % 70) + 1), 25),
          scheduled_at: ctx.date(-((index % 70) + 1), 45),
        },
        { publicIdPrefix: 'RDO', seedMeta: false }
      );

      await ctx.upsert(
        'radiology_result',
        `${scenario.key}:vol:rad-result:${pad(index)}`,
        {
          radiology_order_id: order.id,
          status: orderStatus === 'COMPLETED'
            ? pick(RADIOLOGY_REPORT_STATUSES, index)
            : 'DRAFT',
          report_text: `Volume radiology report #${index}`,
          reported_at: orderStatus === 'COMPLETED'
            ? ctx.date(-((index % 70) + 1), 90)
            : null,
        },
        { publicIdPrefix: 'RDR', seedMeta: false }
      );
      radiologyOrders.push(order);
      created.radiology_results += 1;
      created.radiology_orders += 1;
    });
  }

  if (drugs.length > 0) {
    await runInBatches(targets.highTraffic, 10, async (index) => {
      const patient = patientAt(index);
      if (!patient) return;
      const orderStatus = pick(PHARMACY_ORDER_STATUSES, index);
      const drug = pick(drugs, index);
      // Wall-clock freshness: today + last ~28 days so pharmacy dashboard KPIs
      // and most-sold charts are non-empty against live summary windows.
      const recentDayOffset = index % 12 === 0 ? 0 : -((index % 28) + 1);
      const orderedAt = ctx.nowDate(recentDayOffset, 35);
      const order = await ctx.upsert(
        'pharmacy_order',
        `${scenario.key}:vol:rx-order:${pad(index)}`,
        {
          encounter_id: encounterAt(index)?.id || null,
          patient_id: patient.id,
          status: orderStatus,
          ordered_at: orderedAt,
        },
        { publicIdPrefix: 'RXO', seedMeta: false }
      );

      const item = await ctx.upsert(
        'pharmacy_order_item',
        `${scenario.key}:vol:rx-item:${pad(index)}`,
        {
          pharmacy_order_id: order.id,
          drug_id: drug.id,
          quantity: 1 + (index % 5),
          dosage: `${1 + (index % 2)} tab`,
          instructions: `Volume prescription #${index}`,
        },
        { publicIdPrefix: 'RXI', seedMeta: false }
      );

      const dispenseStatus = orderStatus === 'DISPENSED'
        ? 'DISPENSED'
        : orderStatus === 'CANCELLED'
          ? 'CANCELLED'
          : pick(DISPENSE_STATUSES, index);

      await ctx.upsert(
        'dispense_log',
        `${scenario.key}:vol:dispense:${pad(index)}`,
        {
          pharmacy_order_item_id: item.id,
          dispense_batch_ref: `VOL-BATCH-${pad(index, 5)}`,
          status: dispenseStatus,
          dispensed_at: dispenseStatus === 'DISPENSED' || dispenseStatus === 'RETURNED'
            ? ctx.nowDate(recentDayOffset, 55)
            : null,
          quantity_dispensed: dispenseStatus === 'PENDING' || dispenseStatus === 'CANCELLED'
            ? 0
            : 1 + (index % 3),
        },
        { publicIdPrefix: 'DSP', seedMeta: false }
      );

      created.pharmacy_orders += 1;
      created.dispense_logs += 1;
    });
  }

  await runInBatches(targets.highTraffic, 10, async (index) => {
    const patient = patientAt(index);
    if (!patient) return;
    const invoiceStatus = pick(INVOICE_STATUSES, index);
    const billingStatus = invoiceStatus === 'PAID'
      ? 'PAID'
      : invoiceStatus === 'CANCELLED'
        ? 'CANCELLED'
        : invoiceStatus === 'OVERDUE'
          ? 'ISSUED'
          : pick(BILLING_STATUSES, index);
    const amount = 25 + (index % 40) * 5;
    const invoice = await ctx.upsert(
      'invoice',
      `${scenario.key}:vol:invoice:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        patient_id: patient.id,
        status: invoiceStatus,
        billing_status: billingStatus,
        total_amount: amount,
        currency: 'UGX',
        issued_at: ctx.date(-((index % 100) + 1), 50),
      },
      { ...seedOpts, publicIdPrefix: 'INV' }
    );

    await ctx.upsert(
      'invoice_item',
      `${scenario.key}:vol:invoice-item:${pad(index)}`,
      {
        invoice_id: invoice.id,
        description: `Volume charge #${index}`,
        quantity: 1,
        unit_price: amount,
        total_price: amount,
      },
      { publicIdPrefix: 'IITM', seedMeta: false }
    );

    const paymentStatus = invoiceStatus === 'PAID'
      ? 'COMPLETED'
      : invoiceStatus === 'CANCELLED'
        ? 'FAILED'
        : pick(PAYMENT_STATUSES, index);

    const payment = await ctx.upsert(
      'payment',
      `${scenario.key}:vol:payment:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        patient_id: patient.id,
        invoice_id: invoice.id,
        status: paymentStatus,
        method: pick(PAYMENT_METHODS, index),
        amount: paymentStatus === 'COMPLETED' || paymentStatus === 'REFUNDED' ? amount : amount / 2,
        paid_at: paymentStatus === 'PENDING' ? null : ctx.date(-((index % 100) + 1), 70),
        transaction_ref: `VOL-PAY-${pad(index, 5)}`,
      },
      { ...seedOpts, publicIdPrefix: 'PAY' }
    );

    invoices.push(invoice);
    payments.push(payment);
    created.invoices += 1;
    created.payments += 1;
  });

  await runInBatches(targets.secondary, 10, async (index) => {
    const patient = patientAt(index);
    if (!patient) return;
    const emergency = await ctx.upsert(
      'emergency_case',
      `${scenario.key}:vol:emergency:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        patient_id: patient.id,
        severity: pick(EMERGENCY_SEVERITIES, index),
        status: pick(ENCOUNTER_STATUSES, index),
        extension_json: { volume_index: index },
      },
      { ...seedOpts, publicIdPrefix: 'EMC' }
    );
    emergencies.push(emergency);
    created.emergency_cases += 1;
  });

  if (inventoryItems.length > 0) {
    await runInBatches(targets.highTraffic, 10, async (index) => {
      const item = pick(inventoryItems, index);
      await ctx.upsert(
        'stock_movement',
        `${scenario.key}:vol:stock-move:${pad(index)}`,
        {
          inventory_item_id: item.id,
          facility_id: facility.id,
          movement_type: pick(STOCK_MOVEMENT_TYPES, index),
          reason: pick(STOCK_REASONS, index),
          quantity: 1 + (index % 20),
          occurred_at: ctx.date(-((index % 110) + 1), 12),
        },
        { publicIdPrefix: 'STM', seedMeta: false }
      );
      created.stock_movements += 1;
    });
  }

  if (equipmentRegistry) {
    await runInBatches(targets.secondary, 10, async (index) => {
      const status = pick(WORK_ORDER_STATUSES, index);
      await ctx.upsert(
        'equipment_work_order',
        `${scenario.key}:vol:work-order:${pad(index)}`,
        {
          tenant_id: facility.tenant_id,
          equipment_registry_id: equipmentRegistry.id,
          title: `Volume work order #${index}`,
          description: `Demo biomedical work order ${status}`,
          priority: pick(WORK_ORDER_PRIORITIES, index),
          status,
          issue_source: 'VOLUME_SEED',
          reported_by_user_id: nurse?.id || biomedUser?.id || null,
          assigned_engineer_user_id: biomedUser?.id || null,
          opened_at: ctx.date(-((index % 60) + 1), 8),
          started_at: status === 'OPEN' ? null : ctx.date(-((index % 60) + 1), 20),
          completed_at: status === 'COMPLETED' || status === 'CLOSED'
            ? ctx.date(-((index % 40) + 1), 60)
            : null,
          closed_at: status === 'CLOSED' ? ctx.date(-((index % 40) + 1), 70) : null,
        },
        { ...seedOpts, publicIdPrefix: 'EWO' }
      );
      created.equipment_work_orders += 1;
    });
  }

  await runInBatches(targets.secondary, 10, async (index) => {
    const patient = patientAt(index * 3);
    const status = pick(MORTUARY_CASE_STATUSES, index);
    await ctx.upsert(
      'mortuary_case',
      `${scenario.key}:vol:mortuary-case:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        facility_id: facility.id,
        patient_id: patient?.id || null,
        deceased_profile_id: mortuaryProfile?.id || null,
        status,
        identification_status: pick(MORTUARY_ID_STATUSES, index),
        source_workflow: 'VOLUME_SEED',
        received_from: 'DemoCare Ward',
        received_at: ctx.date(-((index % 50) + 1), 5),
        release_ready_at: status === 'READY_FOR_RELEASE' || status === 'RELEASED'
          ? ctx.date(-((index % 20) + 1), 40)
          : null,
        released_at: status === 'RELEASED' ? ctx.date(-((index % 15) + 1), 55) : null,
        closed_at: status === 'CLOSED' ? ctx.date(-((index % 10) + 1), 70) : null,
        next_of_kin_name: `${pick(FIRST_NAMES, index + 5)} ${pick(LAST_NAMES, index + 7)}`,
        billing_status: pick(['PENDING', 'OPEN', 'PAID', 'WAIVED'], index),
        notes: `Volume mortuary case #${index}`,
      },
      { ...seedOpts, publicIdPrefix: 'MCS' }
    );
    created.mortuary_cases += 1;
  });

  await runInBatches(targets.highTraffic, 10, async (index) => {
    const user = pick(staffUsers.length > 0 ? staffUsers : [null], index);
    const notification = await ctx.upsert(
      'notification',
      `${scenario.key}:vol:notification:${pad(index)}`,
      {
        tenant_id: facility.tenant_id,
        user_id: user?.id || null,
        notification_type: pick(NOTIFICATION_TYPES, index),
        priority: pick(NOTIFICATION_PRIORITIES, index),
        title: `Volume notification #${index}`,
        message: `Demo notification body for volume seed item ${index}.`,
        context_type: pick(['appointment', 'invoice', 'lab', 'conversation', 'equipment'], index),
        context_public_id: `VOL-${pad(index)}`,
        read_at: index % 3 === 0 ? ctx.date(-((index % 20) + 1), 90) : null,
      },
      { ...seedOpts, publicIdPrefix: 'NOTI' }
    );

    await ctx.upsert(
      'notification_delivery',
      `${scenario.key}:vol:notification-delivery:${pad(index)}`,
      {
        notification_id: notification.id,
        channel: pick(DELIVERY_CHANNELS, index),
        status: pick(DELIVERY_STATUSES, index),
        retryable: index % 7 === 0,
        last_attempt_at: ctx.date(-((index % 20) + 1), 95),
        attempt_count: 1 + (index % 3),
      },
      { publicIdPrefix: 'NDLV', seedMeta: false }
    );

    created.notifications += 1;
    created.notification_deliveries += 1;
  });

  console.log('Demo volume pack complete:', created);

  return {
    skipped: false,
    targets,
    created,
    patients: patients.length,
    patient_ids: patients.map((patient) => patient.id),
    encounters,
    admissions,
    appointments,
    invoices,
    payments,
    emergencies,
    radiology_orders: radiologyOrders,
    facility,
    doctor,
    nurse,
  };
};

module.exports = {
  DEFAULT_DEMO_VOLUME_TARGET,
  MIN_APPLICABLE_VOLUME,
  resolveSecondaryTarget,
  resolveVolumeTargets,
  seedVolumePack,
};
