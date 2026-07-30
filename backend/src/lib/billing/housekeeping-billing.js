/**
 * Housekeeping task cleaning surcharge helpers.
 *
 * Staff-only cleaning tasks stay NOT_BILLED. When a facility configures a
 * room-turnover or private-room cleaning fee and patient context is available
 * on Complete, charges post through shared clinical-request billing (SERVICE)
 * so Billing remains the system of record.
 *
 * @module lib/billing/housekeeping-billing
 */

const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const {
  applyClinicalRequestBilling,
  buildPendingClinicalRequestBilling,
  shouldApplyClinicalRequestBilling,
  BILLABLE_SOURCE_MODULES,
} = require('@lib/billing/clinical-request-billing');
const { extractFacilityBillingFee } = require('@lib/billing/emergency-billing');

const ROOM_TURNOVER_CLEANING_CHARGE_KEY = 'ROOM_TURNOVER_CLEANING';
const PRIVATE_ROOM_CLEANING_CHARGE_KEY = 'PRIVATE_ROOM_CLEANING';

const ROOM_TURNOVER_FEE_KEYS = [
  'room_turnover_cleaning_fee',
  'room_turnover_fee',
  'cleaning_surcharge',
  'housekeeping_turnover_fee',
];

const PRIVATE_ROOM_FEE_KEYS = [
  'private_room_cleaning_surcharge',
  'private_room_cleaning_fee',
  'private_cleaning_surcharge',
];

/**
 * Build PENDING billing payload for a housekeeping cleaning surcharge.
 *
 * Prefer private-room fee when [preferPrivateRoom] is true; otherwise
 * room-turnover keys. Returns null when no facility fee is configured.
 *
 * @param {Object} options
 * @returns {Object|null}
 */
const buildHousekeepingCleaningBilling = ({
  facility = null,
  preferPrivateRoom = false,
  currency = 'USD',
} = {}) => {
  const privateFee = extractFacilityBillingFee(facility, PRIVATE_ROOM_FEE_KEYS);
  const turnoverFee = extractFacilityBillingFee(facility, ROOM_TURNOVER_FEE_KEYS);

  const fee = preferPrivateRoom
    ? privateFee || turnoverFee
    : turnoverFee || privateFee;
  if (!fee) {
    return null;
  }

  const isPrivate = Boolean(privateFee) && (preferPrivateRoom || !turnoverFee);
  const id = isPrivate ? 'private-room-cleaning' : 'room-turnover-cleaning';
  const label = isPrivate
    ? 'Private-room cleaning surcharge'
    : 'Room turnover cleaning';

  return buildPendingClinicalRequestBilling({
    lineItems: [
      {
        id,
        label,
        quantity: 1,
        unit_price: fee.amount,
        line_total: fee.amount,
        catalog_type: 'SERVICE',
      },
    ],
    currency: fee.currency || currency,
  });
};

/**
 * Resolve patient for a room via active (or most recent) bed assignment.
 *
 * @param {Object} options
 * @returns {Promise<{ patientId: string, tenantId: string|null, facilityId: string|null }|null>}
 */
const resolvePatientForHousekeepingRoom = async ({
  roomId,
  tenantId = null,
} = {}) => {
  if (!roomId) {
    return null;
  }

  const bedWhere = {
    room_id: roomId,
    deleted_at: null,
    ...(tenantId ? { tenant_id: tenantId } : {}),
  };

  const active = await prisma.bed_assignment.findFirst({
    where: {
      released_at: null,
      deleted_at: null,
      bed: bedWhere,
    },
    include: {
      admission: {
        select: {
          patient_id: true,
          tenant_id: true,
          facility_id: true,
        },
      },
    },
    orderBy: { assigned_at: 'desc' },
  });

  if (active?.admission?.patient_id) {
    return {
      patientId: active.admission.patient_id,
      tenantId: active.admission.tenant_id || tenantId,
      facilityId: active.admission.facility_id || null,
    };
  }

  const recent = await prisma.bed_assignment.findFirst({
    where: {
      deleted_at: null,
      bed: bedWhere,
    },
    include: {
      admission: {
        select: {
          patient_id: true,
          tenant_id: true,
          facility_id: true,
        },
      },
    },
    orderBy: { assigned_at: 'desc' },
  });

  if (recent?.admission?.patient_id) {
    return {
      patientId: recent.admission.patient_id,
      tenantId: recent.admission.tenant_id || tenantId,
      facilityId: recent.admission.facility_id || null,
    };
  }

  return null;
};

/**
 * Persist housekeeping cleaning charge via shared Billing (SERVICE, idempotent).
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {Object} options
 * @returns {Promise<Object|null>}
 */
const persistHousekeepingTaskBilling = async (
  tx,
  {
    taskId,
    billing,
    tenantId,
    facilityId = null,
    patientId,
    chargeKey = ROOM_TURNOVER_CLEANING_CHARGE_KEY,
    description = 'Room turnover cleaning',
    actorUserId = null,
    currency = 'USD',
  } = {}
) => {
  if (!taskId || !tenantId || !patientId) {
    return null;
  }
  if (!billing || !shouldApplyClinicalRequestBilling(billing)) {
    return null;
  }

  return applyClinicalRequestBilling(tx, {
    billing,
    sourceModule: BILLABLE_SOURCE_MODULES.SERVICE,
    sourceId: String(taskId),
    chargeKey: String(chargeKey).toUpperCase(),
    catalogType: 'SERVICE',
    description,
    tenantId,
    facilityId,
    patientId,
    actorUserId,
    currency,
  });
};

/**
 * On COMPLETED transition: post cleaning surcharge when configured + patient
 * context exists; otherwise audit explicit NOT_BILLED / NOT_REQUIRED.
 *
 * @param {Object} task - Mapped or raw housekeeping_task with room/facility ids
 * @param {Object} context
 * @param {Object} [options]
 * @returns {Promise<Object|null>}
 */
const maybeBillCompletedHousekeepingTask = async (
  task,
  context = {},
  { preferPrivateRoom = false, patientId: explicitPatientId = null } = {}
) => {
  const taskId = task?.id;
  if (!taskId) {
    return null;
  }

  const status = String(task?.status || '')
    .trim()
    .toUpperCase();
  if (status !== 'COMPLETED') {
    return null;
  }

  const facilityId =
    task?.facility_id ||
    task?.facility?.id ||
    context.facility_id ||
    null;
  const roomId = task?.room_id || task?.room?.id || null;
  let tenantId = context.tenant_id || task?.tenant_id || null;

  let facility = task?.facility || null;
  if ((!facility || !facility.extension_json) && facilityId) {
    facility = await prisma.facility.findFirst({
      where: {
        OR: [{ id: facilityId }, { human_friendly_id: facilityId }],
        deleted_at: null,
      },
      select: {
        id: true,
        human_friendly_id: true,
        tenant_id: true,
        extension_json: true,
      },
    });
    if (facility?.tenant_id) {
      tenantId = tenantId || facility.tenant_id;
    }
  }

  const billing = buildHousekeepingCleaningBilling({
    facility,
    preferPrivateRoom,
  });

  if (!billing) {
    await createAuditLog({
      action: 'HOUSEKEEPING_TASK_BILLING_SKIPPED',
      entity: 'housekeeping_task',
      entity_id: taskId,
      user_id: context.user_id,
      tenant_id: tenantId,
      facility_id: facilityId,
      ip_address: context.ip_address,
      user_agent: context.user_agent,
      details: {
        reason: 'NOT_BILLED',
        audit_code: 'NOT_BILLED',
        room_id: roomId,
      },
    });
    return null;
  }

  let patientId = explicitPatientId || null;
  let resolvedFacilityId = facilityId;
  if (!patientId && roomId) {
    const resolved = await resolvePatientForHousekeepingRoom({
      roomId,
      tenantId,
    });
    if (resolved) {
      patientId = resolved.patientId;
      tenantId = tenantId || resolved.tenantId;
      resolvedFacilityId = resolvedFacilityId || resolved.facilityId;
    }
  }

  if (!tenantId || !patientId) {
    await createAuditLog({
      action: 'HOUSEKEEPING_TASK_BILLING_SKIPPED',
      entity: 'housekeeping_task',
      entity_id: taskId,
      user_id: context.user_id,
      tenant_id: tenantId,
      facility_id: facilityId,
      ip_address: context.ip_address,
      user_agent: context.user_agent,
      details: {
        reason: 'NOT_REQUIRED',
        audit_code: 'NOT_REQUIRED',
        room_id: roomId,
        has_fee: true,
        has_patient: Boolean(patientId),
      },
    });
    return null;
  }

  const privateFee = extractFacilityBillingFee(facility, PRIVATE_ROOM_FEE_KEYS);
  const turnoverFee = extractFacilityBillingFee(facility, ROOM_TURNOVER_FEE_KEYS);
  const usePrivate =
    Boolean(privateFee) && (preferPrivateRoom || !turnoverFee);
  const chargeKey = usePrivate
    ? PRIVATE_ROOM_CLEANING_CHARGE_KEY
    : ROOM_TURNOVER_CLEANING_CHARGE_KEY;
  const description = usePrivate
    ? 'Private-room cleaning surcharge'
    : 'Room turnover cleaning';

  const snapshot = await prisma.$transaction(async (tx) =>
    persistHousekeepingTaskBilling(tx, {
      taskId,
      billing,
      tenantId,
      facilityId: resolvedFacilityId,
      patientId,
      chargeKey,
      description,
      actorUserId: context.user_id || null,
    })
  );

  await createAuditLog({
    action: 'HOUSEKEEPING_TASK_BILLED',
    entity: 'housekeeping_task',
    entity_id: taskId,
    user_id: context.user_id,
    tenant_id: tenantId,
    facility_id: resolvedFacilityId,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      invoice_id: snapshot?.invoice_id || null,
      payment_status: snapshot?.payment_status || 'PENDING',
      charge_key: chargeKey,
      patient_id: patientId,
      room_id: roomId,
    },
  });

  return snapshot;
};

module.exports = {
  ROOM_TURNOVER_CLEANING_CHARGE_KEY,
  PRIVATE_ROOM_CLEANING_CHARGE_KEY,
  ROOM_TURNOVER_FEE_KEYS,
  PRIVATE_ROOM_FEE_KEYS,
  buildHousekeepingCleaningBilling,
  resolvePatientForHousekeepingRoom,
  persistHousekeepingTaskBilling,
  maybeBillCompletedHousekeepingTask,
  shouldApplyClinicalRequestBilling,
};
