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

const schemaMetadata = parseSchemaMetadata(path.join(__dirname, '..', 'prisma', 'schema.prisma'));

const findPlanByCode = (plans, code) => plans.find((plan) => plan.code === code);

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
  if (!basicPlan?.extension_json?.branch_allowance?.included_branches) {
    errors.push('Basic plan branch allowance must be stored in extension_json.');
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

  const roleNames = roles.map((role) => role.name).sort();
  const expectedRoles = [...DEMO_ROLE_CODES].sort();
  if (roleNames.join(',') !== expectedRoles.join(',')) {
    errors.push(`Expected role codes ${expectedRoles.join(', ')} but found ${roleNames.join(', ')}.`);
  }

  if (usersCount !== DEMO_ROLE_CODES.length) {
    errors.push(`Expected ${DEMO_ROLE_CODES.length} users but found ${usersCount}.`);
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
};
