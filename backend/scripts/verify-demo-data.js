const path = require('path');
const {
  parseSchemaMetadata,
  prisma,
  DEFAULT_RANDOM_SEED,
} = require('./seeders/seed-runtime');
const {
  DEMO_ADD_ON_CATALOG,
  DEMO_PLAN_CATALOG,
  DEMO_ROLE_CODES,
  DEMO_TENANT,
} = require('./seeders/seed-catalog');
const {
  DEFAULT_DEMO_VOLUME_TARGET,
  MIN_APPLICABLE_VOLUME,
  resolveVolumeTargets,
} = require('./seeders/seed-volume-pack');
const env = require('@config/env');

const schemaMetadata = parseSchemaMetadata(path.join(__dirname, '..', 'prisma', 'schema.prisma'));

const findPlanByCode = (plans, code) => plans.find((plan) => plan.code === code);

const resolveVerifyVolumeTarget = () => {
  if (process.env.SEED_RECORD_COUNT !== undefined && process.env.SEED_RECORD_COUNT !== '') {
    const parsed = Number.parseInt(String(process.env.SEED_RECORD_COUNT), 10);
    return Number.isFinite(parsed) ? parsed : DEFAULT_DEMO_VOLUME_TARGET;
  }
  if (env.SEED_RECORD_COUNT !== undefined && env.SEED_RECORD_COUNT !== null) {
    const parsed = Number.parseInt(String(env.SEED_RECORD_COUNT), 10);
    return Number.isFinite(parsed) ? parsed : DEFAULT_DEMO_VOLUME_TARGET;
  }
  return DEFAULT_DEMO_VOLUME_TARGET;
};

const assertStatusCoverage = async (modelName, fieldName, requiredStatuses, errors) => {
  const delegate = prisma[modelName];
  if (!delegate || typeof delegate.groupBy !== 'function') return;

  const groups = await delegate.groupBy({
    by: [fieldName],
    where: { deleted_at: null },
    _count: { _all: true },
  });
  if (!Array.isArray(groups)) return;
  const present = new Set(groups.map((entry) => entry[fieldName]).filter(Boolean));
  const missing = requiredStatuses.filter((status) => !present.has(status));
  if (missing.length > 0) {
    errors.push(
      `Expected ${modelName}.${fieldName} coverage for ${missing.join(', ')} but those statuses are missing.`
    );
  }
};

const countOwnershipMismatches = async (fieldName, expectedId) => {
  const mismatches = [];

  for (const [modelName, meta] of schemaMetadata.modelsByName.entries()) {
    if (modelName === 'tenant' || modelName === 'facility') continue;
    if (!meta.fieldByName.has(fieldName)) continue;

    const delegate = prisma[modelName];
    if (!delegate || typeof delegate.count !== 'function') continue;

    const where = {};
    if (meta.fieldByName.has('deleted_at')) {
      where.deleted_at = null;
    }

    where[fieldName] = { not: expectedId };
    if (meta.fieldByName.get(fieldName)?.isOptional) {
      where.NOT = { [fieldName]: null };
    }

    const mismatchCount = await delegate.count({ where });
    if (mismatchCount > 0) {
      mismatches.push({ model: modelName, count: mismatchCount });
    }
  }

  return mismatches;
};

const verifyDemoData = async () => {
  const errors = [];

  const [
    tenants,
    facilities,
    usersCount,
    roles,
    userRoles,
    plans,
    subscriptions,
    moduleSubscriptions,
    subscriptionInvoices,
    licenses,
    patientCount,
    appointmentCount,
    encounterCount,
    admissionCount,
    labResultCount,
    radiologyResultCount,
    pharmacyOrderCount,
    dispenseLogCount,
    paymentCount,
    invoiceCount,
    labOrderCount,
    notificationCount,
    stockMovementCount,
    mortuaryCaseCount,
    conversations,
    notifications,
    notificationDeliveries,
    templates,
    emergencyCaseCount,
    ambulanceTripCount,
    biomedicalCounts,
    complianceCounts,
    accessControlState,
    lastOfficeState,
    paymentTotalCount,
    extendedVolumeCounts,
  ] = await Promise.all([
    prisma.tenant.findMany({
      where: { deleted_at: null },
      orderBy: { name: 'asc' },
      select: { id: true, slug: true, name: true },
    }),
    prisma.facility.findMany({
      where: { deleted_at: null },
      orderBy: { name: 'asc' },
      select: { id: true, tenant_id: true, name: true },
    }),
    prisma.user.count({ where: { deleted_at: null } }),
    prisma.role.findMany({
      where: { deleted_at: null },
      orderBy: { name: 'asc' },
      select: { id: true, name: true },
    }),
    prisma.user_role.findMany({
      where: { deleted_at: null },
      include: {
        role: { select: { name: true } },
        user: { select: { email: true } },
      },
    }),
    prisma.subscription_plan.findMany({
      where: { deleted_at: null, tenant_id: null },
      orderBy: { code: 'asc' },
    }),
    prisma.subscription.findMany({
      where: { deleted_at: null },
      select: {
        id: true,
        tenant_id: true,
        change_status: true,
        plan_fit_status: true,
        status: true,
      },
    }),
    prisma.module_subscription.findMany({
      where: { deleted_at: null },
      include: { module: true, subscription: true },
    }),
    prisma.subscription_invoice.findMany({
      where: { deleted_at: null },
      include: { invoice: true, subscription: true },
    }),
    prisma.license.findMany({
      where: { deleted_at: null },
      select: { id: true, tenant_id: true, expires_at: true, status: true },
    }),
    prisma.patient.count({ where: { deleted_at: null } }),
    prisma.appointment.count({ where: { deleted_at: null } }),
    prisma.encounter.count({ where: { deleted_at: null } }),
    prisma.admission.count({ where: { deleted_at: null } }),
    prisma.lab_result.count({ where: { deleted_at: null } }),
    prisma.radiology_result.count({ where: { deleted_at: null } }),
    prisma.pharmacy_order.count({ where: { deleted_at: null } }),
    prisma.dispense_log.count({ where: { deleted_at: null } }),
    prisma.payment.count({ where: { deleted_at: null, status: 'COMPLETED' } }),
    prisma.invoice.count({ where: { deleted_at: null } }),
    prisma.lab_order.count({ where: { deleted_at: null } }),
    prisma.notification.count({ where: { deleted_at: null } }),
    prisma.stock_movement.count({ where: { deleted_at: null } }),
    prisma.mortuary_case.count({ where: { deleted_at: null } }),
    prisma.conversation.findMany({
      where: { deleted_at: null },
      include: {
        participants: { where: { deleted_at: null } },
        messages: {
          where: { deleted_at: null },
          include: { attachments: { where: { deleted_at: null } } },
        },
        visibility_roles: { where: { deleted_at: null } },
      },
    }),
    prisma.notification.findMany({
      where: { deleted_at: null },
      include: { deliveries: { where: { deleted_at: null } } },
    }),
    prisma.notification_delivery.findMany({ where: { deleted_at: null } }),
    prisma.template.findMany({
      where: { deleted_at: null, is_active: true },
      include: { variables: { where: { deleted_at: null } } },
    }),
    prisma.emergency_case.count({ where: { deleted_at: null } }),
    prisma.ambulance_trip.count({ where: { deleted_at: null } }),
    Promise.all([
      prisma.equipment_maintenance_plan.count({ where: { deleted_at: null } }),
      prisma.equipment_work_order.count({ where: { deleted_at: null } }),
      prisma.equipment_calibration_log.count({ where: { deleted_at: null } }),
      prisma.equipment_safety_test_log.count({ where: { deleted_at: null } }),
      prisma.equipment_downtime_log.count({ where: { deleted_at: null } }),
      prisma.equipment_spare_part.count({ where: { deleted_at: null } }),
      prisma.equipment_incident_report.count({ where: { deleted_at: null } }),
      prisma.equipment_recall_notice.count({ where: { deleted_at: null } }),
      prisma.equipment_utilization_snapshot.count({ where: { deleted_at: null } }),
      prisma.equipment_disposal_transfer.count({ where: { deleted_at: null } }),
    ]),
    Promise.all([
      prisma.audit_log.count({ where: { deleted_at: null } }),
      prisma.phi_access_log.count({ where: { deleted_at: null } }),
      prisma.data_processing_log.count({ where: { deleted_at: null } }),
      prisma.breach_notification.count({ where: { deleted_at: null } }),
      prisma.system_change_log.count({ where: { deleted_at: null } }),
      prisma.integration.count({ where: { deleted_at: null } }),
      prisma.webhook_subscription.count({ where: { deleted_at: null } }),
    ]),
    Promise.all([
      prisma.abac_policy.count({ where: { deleted_at: null, is_active: true } }),
      prisma.break_glass_access.findMany({
        where: { deleted_at: null },
        select: { status: true, review_status: true },
      }),
      prisma.break_glass_review.count({ where: { deleted_at: null } }),
    ]),
    Promise.all([
      prisma.office_context.findMany({ where: { deleted_at: null }, select: { status: true } }),
      prisma.shift_close.findMany({ where: { deleted_at: null }, select: { status: true } }),
      prisma.day_close.findMany({ where: { deleted_at: null }, select: { status: true } }),
      prisma.handover.findMany({ where: { deleted_at: null }, select: { status: true } }),
      prisma.custody_snapshot.findMany({ where: { deleted_at: null }, select: { status: true } }),
      prisma.closeout_pack.findMany({ where: { deleted_at: null }, select: { status: true } }),
    ]),
    prisma.payment.count({ where: { deleted_at: null } }),
    Promise.all([
      prisma.diagnosis.count({ where: { deleted_at: null } }),
      prisma.vital_sign.count({ where: { deleted_at: null } }),
      prisma.procedure.count({ where: { deleted_at: null } }),
      prisma.nursing_note.count({ where: { deleted_at: null } }),
      prisma.visit_queue.count({ where: { deleted_at: null } }),
      prisma.refund.count({ where: { deleted_at: null } }),
      prisma.billing_adjustment.count({ where: { deleted_at: null } }),
      prisma.insurance_claim.count({ where: { deleted_at: null } }),
      prisma.pre_authorization.count({ where: { deleted_at: null } }),
      prisma.triage_assessment.count({ where: { deleted_at: null } }),
      prisma.report_run.count({ where: { deleted_at: null } }),
      prisma.kpi_snapshot.count({ where: { deleted_at: null } }),
      prisma.analytics_event.count({ where: { deleted_at: null } }),
      prisma.patient_report_job.count({ where: { deleted_at: null } }),
      prisma.shift.count({ where: { deleted_at: null } }),
      prisma.message.count({ where: { deleted_at: null } }),
      prisma.clinical_note.count({ where: { deleted_at: null } }),
      prisma.patient_allergy.count({ where: { deleted_at: null } }),
      prisma.care_plan.count({ where: { deleted_at: null } }),
      prisma.clinical_alert.count({ where: { deleted_at: null } }),
      prisma.theatre_case.count({ where: { deleted_at: null } }),
      prisma.patient_insurance_enrollment.count({ where: { deleted_at: null } }),
      prisma.price_book_entry.count({ where: { deleted_at: null } }),
      prisma.bed_assignment.count({ where: { deleted_at: null } }),
      prisma.imaging_study.count({ where: { deleted_at: null } }),
      prisma.referral.count({ where: { deleted_at: null } }),
      prisma.follow_up.count({ where: { deleted_at: null } }),
      prisma.report_schedule.count({ where: { deleted_at: null } }),
      prisma.bed.count({ where: { deleted_at: null } }),
    ]),
  ]);

  if (tenants.length !== 1) {
    errors.push(`Expected exactly 1 tenant but found ${tenants.length}.`);
  }

  if (facilities.length !== 1) {
    errors.push(`Expected exactly 1 facility but found ${facilities.length}.`);
  }

  const demoTenant = tenants[0] || null;
  const demoFacility = facilities[0] || null;

  if (demoTenant && demoTenant.slug !== DEMO_TENANT.slug) {
    errors.push(`Expected tenant slug ${DEMO_TENANT.slug} but found ${demoTenant.slug}.`);
  }

  if (demoFacility && demoFacility.tenant_id !== demoTenant?.id) {
    errors.push('The seeded facility must belong to the single seeded tenant.');
  }

  const expectedPlanCodes = DEMO_PLAN_CATALOG.map((entry) => entry.code).sort();
  const actualPlanCodes = plans.map((entry) => entry.code).sort();
  if (actualPlanCodes.join(',') !== expectedPlanCodes.join(',')) {
    errors.push(`Expected plan codes ${expectedPlanCodes.join(', ')} but found ${actualPlanCodes.join(', ')}.`);
  }

  const basicPlan = findPlanByCode(plans, 'basic');
  if (!basicPlan || basicPlan.max_facilities !== 1) {
    errors.push('Basic plan max_facilities must be 1.');
  }

  const proPlan = findPlanByCode(plans, 'pro');
  if (!proPlan?.extension_json?.price_notes?.yearly) {
    errors.push('Pro yearly pricing must be present in extension_json.');
  }

  const advancedPlan = findPlanByCode(plans, 'advanced');
  if (!advancedPlan?.extension_json?.commercial_terms?.setup_range_usd) {
    errors.push('Advanced commercial terms are missing from extension_json.');
  }

  const customPlan = findPlanByCode(plans, 'custom');
  if (!customPlan?.extension_json?.commercial_terms?.annual_support_percent_range) {
    errors.push('Custom commercial terms are missing from extension_json.');
  }

  if (!DEMO_ADD_ON_CATALOG.every((entry) => entry.minimum_plan_tier_code)) {
    errors.push('Every add-on must declare a minimum plan.');
  }

  const roleNames = [...new Set(roles.map((role) => role.name).filter(Boolean))].sort();
  const expectedRoles = [...DEMO_ROLE_CODES].sort();
  const missingRoles = expectedRoles.filter((roleName) => !roleNames.includes(roleName));
  if (missingRoles.length > 0) {
    errors.push(
      `Missing required demo role codes ${missingRoles.join(', ')}. Found ${roleNames.join(', ')}.`
    );
  }

  const expectedDemoUserCount = (DEMO_TENANT.users || []).length;
  if (usersCount !== expectedDemoUserCount) {
    errors.push(`Expected ${expectedDemoUserCount} users but found ${usersCount}.`);
  }

  const userRolesByName = userRoles.reduce((acc, entry) => {
    const roleName = entry.role?.name;
    if (!roleName) return acc;
    acc[roleName] = (acc[roleName] || 0) + 1;
    return acc;
  }, {});
  const expectedEmailByRole = Object.fromEntries(
    (DEMO_TENANT.users || []).map((entry) => [entry.role, entry.email])
  );
  for (const userDefinition of DEMO_TENANT.users || []) {
    for (const extraRole of userDefinition.extra_roles || []) {
      expectedEmailByRole[extraRole] = userDefinition.email;
    }
  }

  for (const roleName of DEMO_ROLE_CODES) {
    if (userRolesByName[roleName] !== 1) {
      errors.push(`Expected exactly 1 user assigned to role ${roleName} but found ${userRolesByName[roleName] || 0}.`);
      continue;
    }

    const roleAssignment = userRoles.find((entry) => entry.role?.name === roleName);
    const expectedEmail = expectedEmailByRole[roleName];
    const actualEmail = roleAssignment?.user?.email || null;
    if (expectedEmail && actualEmail !== expectedEmail) {
      errors.push(`Expected role ${roleName} to use email ${expectedEmail} but found ${actualEmail || 'none'}.`);
    }
  }

  if (subscriptions.length !== 1) {
    errors.push(`Expected exactly 1 subscription but found ${subscriptions.length}.`);
  } else {
    const subscription = subscriptions[0];
    if (subscription.status !== 'ACTIVE') {
      errors.push(`Expected the demo subscription to be ACTIVE but found ${subscription.status}.`);
    }
    if (subscription.change_status !== 'NONE') {
      errors.push(`Expected the demo subscription change_status to be NONE but found ${subscription.change_status}.`);
    }
    if (subscription.plan_fit_status !== 'HEALTHY') {
      errors.push(`Expected the demo subscription plan_fit_status to be HEALTHY but found ${subscription.plan_fit_status}.`);
    }
  }

  if (!moduleSubscriptions.some((entry) => entry.is_active === true)) {
    errors.push('Expected at least one active module subscription.');
  }

  if (subscriptionInvoices.length !== 1 || subscriptionInvoices[0]?.invoice?.status !== 'PAID') {
    errors.push('Expected exactly one paid subscription invoice.');
  }

  if (licenses.length !== 1 || licenses[0]?.status !== 'ACTIVE') {
    errors.push('Expected exactly one active license.');
  }

  if (patientCount < 5) {
    errors.push(`Expected at least 5 patients but found ${patientCount}.`);
  }
  if (appointmentCount < 1) {
    errors.push('Expected at least one appointment.');
  }
  if (encounterCount < 4) {
    errors.push(`Expected at least 4 encounters but found ${encounterCount}.`);
  }
  if (admissionCount < 1) {
    errors.push('Expected at least one admission.');
  }
  if (labResultCount < 3) {
    errors.push(`Expected at least 3 lab results but found ${labResultCount}.`);
  }
  if (radiologyResultCount < 1) {
    errors.push('Expected at least one radiology result.');
  }
  if (pharmacyOrderCount < 2) {
    errors.push(`Expected at least 2 pharmacy orders but found ${pharmacyOrderCount}.`);
  }
  if (dispenseLogCount < 2) {
    errors.push(`Expected at least 2 dispense logs but found ${dispenseLogCount}.`);
  }
  if (paymentCount < 2) {
    errors.push(`Expected at least 2 completed payments but found ${paymentCount}.`);
  }
  if (emergencyCaseCount < 1 || ambulanceTripCount < 1) {
    errors.push('Expected emergency and ambulance demo records to be present.');
  }

  // Pharmacy dashboard freshness: today orders/dispenses + some low stock when
  // volume seed is on (wall-clock nowDate + forceLowStock catalog slice).
  const volumeTargets = resolveVolumeTargets(resolveVerifyVolumeTarget());
  if (!volumeTargets.skipped) {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const [ordersTodayCount, dispensedTodayCount, inventoryStocks] = await Promise.all([
      prisma.pharmacy_order.count({
        where: { deleted_at: null, ordered_at: { gte: todayStart } },
      }),
      prisma.dispense_log.count({
        where: {
          deleted_at: null,
          status: 'DISPENSED',
          dispensed_at: { gte: todayStart },
        },
      }),
      prisma.inventory_stock.findMany({
        where: { deleted_at: null },
        select: { quantity: true, reorder_level: true },
      }),
    ]);
    const lowStockCount = inventoryStocks.filter((row) => {
      const reorder = Number(row.reorder_level || 0);
      const qty = Number(row.quantity || 0);
      return reorder > 0 && qty <= reorder;
    }).length;
    if (ordersTodayCount < 1) {
      errors.push(
        `Expected at least 1 pharmacy order ordered today for dashboard KPIs but found ${ordersTodayCount}.`
      );
    }
    if (dispensedTodayCount < 1) {
      errors.push(
        `Expected at least 1 dispense today for dashboard KPIs but found ${dispensedTodayCount}.`
      );
    }

    const todayDispenses = await prisma.dispense_log.findMany({
      where: {
        deleted_at: null,
        status: 'DISPENSED',
        dispensed_at: { gte: todayStart },
        quantity_dispensed: { gt: 0 },
      },
      select: {
        quantity_dispensed: true,
        pharmacy_order_item: { select: { drug_id: true } },
      },
      take: 500,
    });
    const distinctDrugsToday = new Set(
      todayDispenses
        .map((row) => row.pharmacy_order_item?.drug_id)
        .filter(Boolean)
    );
    if (distinctDrugsToday.size < 5) {
      errors.push(
        `Expected at least 5 distinct drugs dispensed today for most-sold charts but found ${distinctDrugsToday.size}.`
      );
    }
    if (lowStockCount < 1) {
      errors.push(
        `Expected at least 1 low-stock inventory row for pharmacy dashboard but found ${lowStockCount}.`
      );
    }

    const [expiredBatchCount, nearExpiryBatchCount, outOfStockCount, historyDispenseCount] =
      await Promise.all([
        prisma.drug_batch.count({
          where: {
            deleted_at: null,
            quantity: { gt: 0 },
            expiry_date: { lt: new Date() },
          },
        }),
        prisma.drug_batch.count({
          where: {
            deleted_at: null,
            quantity: { gt: 0 },
            expiry_date: {
              gte: new Date(),
              lte: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
            },
          },
        }),
        prisma.inventory_stock.count({
          where: { deleted_at: null, quantity: { lte: 0 } },
        }),
        prisma.dispense_log.count({
          where: {
            deleted_at: null,
            status: 'DISPENSED',
            dispensed_at: {
              lte: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000),
            },
          },
        }),
      ]);
    if (expiredBatchCount < 1) {
      errors.push(
        `Expected at least 1 expired drug batch for pharmacy reporting but found ${expiredBatchCount}.`
      );
    }
    if (nearExpiryBatchCount < 1) {
      errors.push(
        `Expected at least 1 near-expiry drug batch for pharmacy reporting but found ${nearExpiryBatchCount}.`
      );
    }
    if (outOfStockCount < 1) {
      errors.push(
        `Expected at least 1 out-of-stock inventory row for pharmacy reporting but found ${outOfStockCount}.`
      );
    }
    if (historyDispenseCount < 1) {
      errors.push(
        `Expected at least 1 dispense older than 90 days for pharmacy period reports but found ${historyDispenseCount}.`
      );
    }
  }

  // Volume suite (SEED_RECORD_COUNT > 0). Curated-only seeds set SEED_RECORD_COUNT=0.
  // Singletons/catalogs (tenant, facility, plans, roles, subscription) are intentional exceptions.
  const workOrderCount = biomedicalCounts[1] || 0;
  if (!volumeTargets.skipped) {
    const highFloor = volumeTargets.highTraffic;
    const secondaryFloor = volumeTargets.secondary;

    const highTrafficChecks = [
      ['patients', patientCount, highFloor],
      ['appointments', appointmentCount, highFloor],
      ['encounters', encounterCount, highFloor],
      ['lab_orders', labOrderCount, highFloor],
      ['lab_results', labResultCount, highFloor],
      ['pharmacy_orders', pharmacyOrderCount, highFloor],
      ['dispense_logs', dispenseLogCount, highFloor],
      ['invoices', invoiceCount, highFloor],
      ['payments', paymentTotalCount, highFloor],
      ['notifications', notificationCount, highFloor],
      ['stock_movements', stockMovementCount, highFloor],
      ['diagnoses', extendedVolumeCounts[0], highFloor],
      ['vital_signs', extendedVolumeCounts[1], highFloor],
      ['procedures', extendedVolumeCounts[2], highFloor],
      ['nursing_notes', extendedVolumeCounts[3], highFloor],
      ['visit_queues', extendedVolumeCounts[4], highFloor],
      ['refunds', extendedVolumeCounts[5], highFloor],
      ['billing_adjustments', extendedVolumeCounts[6], highFloor],
      ['insurance_claims', extendedVolumeCounts[7], highFloor],
      ['pre_authorizations', extendedVolumeCounts[8], highFloor],
      ['triage_assessments', extendedVolumeCounts[9], highFloor],
      ['report_runs', extendedVolumeCounts[10], highFloor],
      ['kpi_snapshots', extendedVolumeCounts[11], highFloor],
      ['analytics_events', extendedVolumeCounts[12], highFloor],
      ['patient_report_jobs', extendedVolumeCounts[13], highFloor],
      ['shifts', extendedVolumeCounts[14], highFloor],
      ['clinical_notes', extendedVolumeCounts[16], highFloor],
      ['patient_allergies', extendedVolumeCounts[17], highFloor],
      ['care_plans', extendedVolumeCounts[18], highFloor],
      ['clinical_alerts', extendedVolumeCounts[19], highFloor],
      ['theatre_cases', extendedVolumeCounts[20], highFloor],
      ['patient_insurance_enrollments', extendedVolumeCounts[21], highFloor],
      ['bed_assignments', extendedVolumeCounts[23], highFloor],
      ['imaging_studies', extendedVolumeCounts[24], highFloor],
      ['referrals', extendedVolumeCounts[25], highFloor],
      ['follow_ups', extendedVolumeCounts[26], highFloor],
    ];

    const [dispensedStatusCount, pharmacyPaymentCount, pharmacyRefundCount, pharmacyDiscountCount] =
      await Promise.all([
        prisma.dispense_log.count({
          where: { deleted_at: null, status: 'DISPENSED' },
        }),
        prisma.payment.count({
          where: { deleted_at: null, billing_entity: 'PHARMACY' },
        }),
        prisma.refund.count({
          where: {
            deleted_at: null,
            payment: { deleted_at: null, billing_entity: 'PHARMACY' },
          },
        }),
        prisma.billing_adjustment.count({
          where: {
            deleted_at: null,
            amount: { lt: 0 },
            invoice: { deleted_at: null, billing_entity: 'PHARMACY' },
          },
        }),
      ]);

    highTrafficChecks.push(
      ['dispense_logs_dispensed', dispensedStatusCount, highFloor],
      ['pharmacy_payments', pharmacyPaymentCount, highFloor],
      ['pharmacy_refunds', pharmacyRefundCount, highFloor],
      ['pharmacy_discount_adjustments', pharmacyDiscountCount, highFloor]
    );

    for (const [label, count, floor] of highTrafficChecks) {
      if (count < floor) {
        errors.push(`Expected at least ${floor} ${label} for volume demo seed but found ${count}.`);
      }
    }

    const secondaryChecks = [
      ['admissions', admissionCount, secondaryFloor],
      ['radiology_results', radiologyResultCount, secondaryFloor],
      ['emergency_cases', emergencyCaseCount, secondaryFloor],
      ['equipment_work_orders', workOrderCount, secondaryFloor],
      ['mortuary_cases', mortuaryCaseCount, secondaryFloor],
      ['messages', extendedVolumeCounts[15], Math.min(secondaryFloor, 500)],
      ['price_book_entries', extendedVolumeCounts[22], Math.min(secondaryFloor, 80)],
      ['report_schedules', extendedVolumeCounts[27], Math.min(secondaryFloor, 48)],
      ['beds', extendedVolumeCounts[28], Math.min(secondaryFloor, 40)],
    ];
    for (const [label, count, floor] of secondaryChecks) {
      if (count < floor) {
        errors.push(`Expected at least ${floor} ${label} for volume demo seed but found ${count}.`);
      }
    }

    await assertStatusCoverage(
      'appointment',
      'status',
      ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW'],
      errors
    );
    await assertStatusCoverage('encounter', 'status', ['OPEN', 'CLOSED', 'CANCELLED'], errors);
    await assertStatusCoverage(
      'lab_order',
      'status',
      ['ORDERED', 'COLLECTED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED'],
      errors
    );
    await assertStatusCoverage(
      'pharmacy_order',
      'status',
      ['ORDERED', 'DISPENSED', 'PARTIALLY_DISPENSED', 'CANCELLED'],
      errors
    );
    await assertStatusCoverage(
      'invoice',
      'status',
      ['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED'],
      errors
    );
    await assertStatusCoverage(
      'mortuary_case',
      'status',
      ['RECEIVED', 'IDENTIFICATION_PENDING', 'IN_STORAGE', 'READY_FOR_RELEASE', 'RELEASED'],
      errors
    );
    await assertStatusCoverage(
      'visit_queue',
      'status',
      ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW'],
      errors
    );
    await assertStatusCoverage(
      'insurance_claim',
      'status',
      ['SUBMITTED', 'APPROVED', 'PARTIAL', 'REJECTED', 'PAID', 'CANCELLED'],
      errors
    );
    await assertStatusCoverage(
      'report_run',
      'status',
      ['QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED'],
      errors
    );
  }

  const hasDirectConversationWithAttachment = conversations.some(
    (conversation) =>
      conversation.conversation_type === 'DIRECT'
      && conversation.status === 'OPEN'
      && conversation.messages.some((message) => (message.attachments || []).length > 0)
  );
  if (!hasDirectConversationWithAttachment) {
    errors.push('Expected an open direct conversation with attachments.');
  }

  const hasArchivedConversation = conversations.some(
    (conversation) => conversation.status === 'ARCHIVED' && conversation.conversation_type === 'GROUP'
  );
  if (!hasArchivedConversation) {
    errors.push('Expected an archived group conversation.');
  }

  const hasSensitiveConversation = conversations.some(
    (conversation) =>
      conversation.is_sensitive === true
      && (conversation.visibility_roles || []).length > 0
  );
  if (!hasSensitiveConversation) {
    errors.push('Expected a sensitive conversation with visibility roles.');
  }

  if (!notifications.some((entry) => entry.read_at === null && entry.context_type === 'conversation')) {
    errors.push('Expected an unread conversation notification.');
  }

  if (!notificationDeliveries.some((entry) => entry.channel === 'IN_APP' && entry.status === 'DELIVERED')) {
    errors.push('Expected a delivered in-app notification.');
  }

  if (!notificationDeliveries.some((entry) => entry.channel === 'SMS' && entry.status === 'FAILED' && entry.retryable === true)) {
    errors.push('Expected a retryable failed SMS notification.');
  }

  if (!notificationDeliveries.some((entry) => entry.channel === 'SMS' && entry.status === 'SENT')) {
    errors.push('Expected an outbound SMS notification in SENT state.');
  }

  if (!templates.some((entry) => entry.variables.some((variable) => variable.key === 'patient_name'))) {
    errors.push('Expected a template variable keyed patient_name.');
  }

  if (!templates.some((entry) => entry.variables.some((variable) => variable.key === 'device_name'))) {
    errors.push('Expected a template variable keyed device_name.');
  }

  if (biomedicalCounts.some((count) => count < 1)) {
    errors.push('Expected every biomedical demo model to have at least one record.');
  }

  if (complianceCounts.some((count) => count < 1)) {
    errors.push('Expected every compliance demo model to have at least one record.');
  }

  const [abacPolicyCount, breakGlassAccesses, breakGlassReviewCount] = accessControlState;
  if (abacPolicyCount < 2) {
    errors.push(`Expected at least 2 ABAC policies but found ${abacPolicyCount}.`);
  }
  if (!breakGlassAccesses.some((entry) => entry.status === 'REQUESTED' && entry.review_status === 'PENDING')) {
    errors.push('Expected a pending break-glass access request.');
  }
  if (!breakGlassAccesses.some((entry) => entry.status === 'ACTIVE' && entry.review_status === 'APPROVED')) {
    errors.push('Expected an approved active break-glass access record.');
  }
  if (breakGlassReviewCount < 1) {
    errors.push('Expected at least one break-glass review.');
  }

  const [
    officeContexts,
    shiftCloses,
    dayCloses,
    handovers,
    custodySnapshots,
    closeoutPacks,
  ] = lastOfficeState;

  if (!officeContexts.some((entry) => ['OPEN', 'HANDOVER_PENDING'].includes(entry.status))) {
    errors.push('Expected an active office context for the demo tenant.');
  }
  if (!shiftCloses.some((entry) => entry.status === 'APPROVED')) {
    errors.push('Expected an approved shift close record.');
  }
  if (!dayCloses.some((entry) => entry.status === 'APPROVED')) {
    errors.push('Expected an approved day close record.');
  }
  if (!handovers.some((entry) => entry.status === 'ACCEPTED')) {
    errors.push('Expected an accepted handover record.');
  }
  if (!custodySnapshots.some((entry) => entry.status === 'FINALIZED')) {
    errors.push('Expected a finalized custody snapshot.');
  }
  if (!closeoutPacks.some((entry) => entry.status === 'READY')) {
    errors.push('Expected a ready closeout pack.');
  }

  if (demoTenant?.id) {
    const tenantMismatches = await countOwnershipMismatches('tenant_id', demoTenant.id);
    if (tenantMismatches.length > 0) {
      errors.push(
        `Found tenant ownership mismatches: ${tenantMismatches
          .map((entry) => `${entry.model}(${entry.count})`)
          .join(', ')}.`
      );
    }
  }

  if (demoFacility?.id) {
    const facilityMismatches = await countOwnershipMismatches('facility_id', demoFacility.id);
    if (facilityMismatches.length > 0) {
      errors.push(
        `Found facility ownership mismatches: ${facilityMismatches
          .map((entry) => `${entry.model}(${entry.count})`)
          .join(', ')}.`
      );
    }
  }

  return {
    ok: errors.length === 0,
    errors,
    summary: {
      random_seed: DEFAULT_RANDOM_SEED,
      tenant_count: tenants.length,
      facility_count: facilities.length,
      user_count: usersCount,
      patient_count: patientCount,
      encounter_count: encounterCount,
      appointment_count: appointmentCount,
      invoice_count: invoiceCount,
      notification_count: notificationCount,
      volume_target: volumeTargets.skipped ? 0 : volumeTargets.highTraffic,
      abac_policy_count: abacPolicyCount,
      break_glass_access_count: breakGlassAccesses.length,
      office_context_count: officeContexts.length,
    },
  };
};

const main = async () => {
  try {
    const result = await verifyDemoData({ randomSeed: DEFAULT_RANDOM_SEED });
    if (!result.ok) {
      console.error('Demo data verification failed:');
      result.errors.forEach((entry) => console.error(` - ${entry}`));
      process.exitCode = 1;
      return;
    }

    console.log('Demo data verification passed.');
  } catch (error) {
    console.error('Failed to verify demo data:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
};

if (require.main === module) {
  main();
}

module.exports = {
  verifyDemoData,
  resolveVerifyVolumeTarget,
  assertStatusCoverage,
};
