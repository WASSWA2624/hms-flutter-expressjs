/**
 * Pre-authorization limits for Billing coverage splits.
 *
 * Approved / partial pre-auths cap insurer share at remaining amount
 * (`approved_amount - consumed_amount`). Clinical billing consumes against
 * the active pre-auth when posting insured lines (idempotent with charge events).
 *
 * @module lib/billing/pre-authorization-billing
 */

const { toDecimalNumber, toMoneyString, roundMoney } = require('./financials');

const ACTIVE_PRE_AUTH_STATUSES = Object.freeze(['APPROVED', 'PARTIAL']);

const remainingAmount = (record = {}) => {
  const approved = record.approved_amount;
  if (approved === null || approved === undefined || approved === '') {
    return null;
  }
  const approvedNum = roundMoney(toDecimalNumber(approved));
  const consumed = roundMoney(toDecimalNumber(record.consumed_amount));
  return roundMoney(Math.max(0, approvedNum - consumed));
};

/**
 * Resolve the best active pre-authorization limit for a billing context.
 *
 * Preference: encounter match → admission match → patient + coverage plan.
 *
 * @param {object} db Prisma client or transaction
 * @param {object} options
 * @returns {Promise<object|null>}
 */
const findActivePreAuthorizationLimit = async (
  db,
  {
    patientId = null,
    encounterId = null,
    admissionId = null,
    coveragePlanId = null,
  } = {}
) => {
  if (!db?.pre_authorization?.findMany) {
    return null;
  }
  if (!patientId && !encounterId && !admissionId) {
    return null;
  }

  const where = {
    deleted_at: null,
    status: { in: [...ACTIVE_PRE_AUTH_STATUSES] },
    approved_amount: { not: null },
  };
  if (patientId) where.patient_id = patientId;
  if (coveragePlanId) where.coverage_plan_id = coveragePlanId;

  const rows = await db.pre_authorization.findMany({
    where,
    orderBy: [{ approved_at: 'desc' }, { updated_at: 'desc' }],
    take: 40,
  });

  const withRemaining = (Array.isArray(rows) ? rows : []).filter((row) => {
    const remaining = remainingAmount(row);
    return remaining == null || remaining > 0;
  });
  if (!withRemaining.length) {
    return null;
  }

  if (encounterId) {
    const byEncounter = withRemaining.find(
      (row) => row.encounter_id && row.encounter_id === encounterId
    );
    if (byEncounter) return byEncounter;
  }
  if (admissionId) {
    const byAdmission = withRemaining.find(
      (row) => row.admission_id && row.admission_id === admissionId
    );
    if (byAdmission) return byAdmission;
  }
  return withRemaining[0] || null;
};

/**
 * Adjust consumed_amount on a pre-authorization (delta may be negative to release).
 * Clamps to [0, approved_amount]. Idempotent when delta is 0.
 *
 * @param {object} tx Prisma transaction
 * @param {object} options
 * @returns {Promise<object|null>} updated pre-auth or null
 */
const adjustPreAuthorizationConsumedTx = async (
  tx,
  { preAuthorizationId, deltaAmount }
) => {
  if (!tx?.pre_authorization?.findFirst || !preAuthorizationId) {
    return null;
  }
  const delta = roundMoney(toDecimalNumber(deltaAmount));
  if (Math.abs(delta) < 0.005) {
    return null;
  }

  const current = await tx.pre_authorization.findFirst({
    where: { id: preAuthorizationId, deleted_at: null },
  });
  if (!current || current.approved_amount == null) {
    return null;
  }

  const approved = roundMoney(toDecimalNumber(current.approved_amount));
  const prior = roundMoney(toDecimalNumber(current.consumed_amount));
  const next = roundMoney(Math.min(approved, Math.max(0, prior + delta)));
  if (Math.abs(next - prior) < 0.005) {
    return current;
  }

  return tx.pre_authorization.update({
    where: { id: current.id },
    data: { consumed_amount: toMoneyString(next) },
  });
};

/**
 * Consume insurer share against an active pre-auth after a clinical billing post.
 * Pass `previousInsurerShare` on mutable invoice updates so consumption is adjusted
 * by delta instead of double-counting.
 *
 * @param {object} tx
 * @param {object} options
 * @returns {Promise<object|null>}
 */
const consumePreAuthorizationForBillingTx = async (
  tx,
  {
    patientId = null,
    encounterId = null,
    admissionId = null,
    coveragePlanId = null,
    insurerShare = 0,
    previousInsurerShare = 0,
    skip = false,
  } = {}
) => {
  if (skip) {
    return null;
  }
  const delta = roundMoney(
    toDecimalNumber(insurerShare) - toDecimalNumber(previousInsurerShare)
  );
  if (Math.abs(delta) < 0.005) {
    return null;
  }

  const active = await findActivePreAuthorizationLimit(tx, {
    patientId,
    encounterId,
    admissionId,
    coveragePlanId,
  });
  if (!active) {
    return null;
  }

  return adjustPreAuthorizationConsumedTx(tx, {
    preAuthorizationId: active.id,
    deltaAmount: delta,
  });
};

const sumInsurerShareFromItems = (items = []) =>
  roundMoney(
    (Array.isArray(items) ? items : []).reduce((sum, item) => {
      if (!item || item.deleted_at) return sum;
      return sum + toDecimalNumber(item.insurer_share);
    }, 0)
  );

module.exports = {
  ACTIVE_PRE_AUTH_STATUSES,
  remainingAmount,
  findActivePreAuthorizationLimit,
  adjustPreAuthorizationConsumedTx,
  consumePreAuthorizationForBillingTx,
  sumInsurerShareFromItems,
};
