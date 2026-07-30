/**
 * Apply insurer remittance to the patient Billing ledger.
 *
 * Claim status flips alone must not leave insurer share outstanding without a
 * payment row. PAID / PARTIAL post an idempotent INSURANCE payment keyed by
 * claim id, then recalculate invoice balances via shared financials.
 *
 * @module lib/billing/claim-remittance
 */

const {
  recalculateInvoiceStateTx,
  toDecimalNumber,
  toMoneyString,
  roundMoney,
} = require('@lib/billing/financials');
const { publishBillingRealtimeUpdate } = require('@lib/billing/realtime');
const { BILLING_EVENTS, PAYMENT_EVENTS } = require('@lib/websocket');
const { HttpError } = require('@lib/errors');

const REMITTANCE_REF_PREFIX = 'CLAIM-REMIT:';

const remittanceTransactionRef = (claimId) =>
  `${REMITTANCE_REF_PREFIX}${String(claimId || '').trim()}`;

const sumInsurerShare = (invoice = {}) => {
  const items = Array.isArray(invoice.items) ? invoice.items : [];
  return roundMoney(
    items.reduce((sum, item) => {
      if (!item || item.deleted_at) return sum;
      return sum + toDecimalNumber(item.insurer_share);
    }, 0)
  );
};

/**
 * Resolve amount to post for a remittance status.
 * @returns {number|null} null when no payment should post
 */
const resolveRemittanceAmount = ({
  status,
  settlementAmount,
  claim = {},
  invoice = {},
}) => {
  const nextStatus = String(status || '').toUpperCase();
  if (nextStatus !== 'PAID' && nextStatus !== 'PARTIAL') {
    return null;
  }

  if (settlementAmount !== undefined && settlementAmount !== null && settlementAmount !== '') {
    const amount = roundMoney(toDecimalNumber(settlementAmount));
    if (amount <= 0) {
      if (nextStatus === 'PARTIAL') {
        throw new HttpError('errors.insurance_claim.settlement_amount_required', 400);
      }
      return null;
    }
    return amount;
  }

  if (nextStatus === 'PARTIAL') {
    throw new HttpError('errors.insurance_claim.settlement_amount_required', 400);
  }

  const fromClaimSettlement = roundMoney(toDecimalNumber(claim.settlement_amount));
  if (fromClaimSettlement > 0) return fromClaimSettlement;

  const fromClaimAmount = roundMoney(toDecimalNumber(claim.claim_amount));
  if (fromClaimAmount > 0) return fromClaimAmount;

  const fromInsurerShare = sumInsurerShare(invoice);
  if (fromInsurerShare > 0) return fromInsurerShare;

  return null;
};

/**
 * Create or reuse the claim remittance payment inside an existing transaction.
 */
const applyClaimRemittanceTx = async (
  tx,
  {
    claim,
    status,
    settlementAmount,
  }
) => {
  const invoiceId = claim?.invoice_id || claim?.invoice?.id;
  if (!invoiceId) {
    return { payment: null, invoiceState: null, created: false, skipped: true };
  }

  const invoice = await tx.invoice.findFirst({
    where: { id: invoiceId, deleted_at: null },
    include: {
      items: { where: { deleted_at: null } },
      patient: { select: { id: true, human_friendly_id: true } },
    },
  });
  if (!invoice) {
    throw new HttpError('errors.invoice.not_found', 404);
  }

  const amount = resolveRemittanceAmount({
    status,
    settlementAmount,
    claim,
    invoice,
  });
  if (amount == null) {
    const invoiceState = await recalculateInvoiceStateTx(tx, invoice.id);
    return { payment: null, invoiceState, created: false, skipped: true };
  }

  const transactionRef = remittanceTransactionRef(claim.id);
  const existing = await tx.payment.findFirst({
    where: {
      deleted_at: null,
      invoice_id: invoice.id,
      method: 'INSURANCE',
      transaction_ref: transactionRef,
    },
    orderBy: { created_at: 'asc' },
  });

  if (existing) {
    // Idempotent replay: already-posted remittance must not double-charge.
    const existingAmount = roundMoney(toDecimalNumber(existing.amount));
    const invoiceState = await recalculateInvoiceStateTx(tx, invoice.id);
    return {
      payment: existing,
      invoiceState,
      created: false,
      skipped: false,
      amountMatched: existingAmount === amount,
    };
  }

  const payment = await tx.payment.create({
    data: {
      tenant_id: invoice.tenant_id,
      facility_id: invoice.facility_id || null,
      patient_id: invoice.patient_id || null,
      invoice_id: invoice.id,
      status: 'COMPLETED',
      method: 'INSURANCE',
      amount: toMoneyString(amount),
      paid_at: new Date(),
      transaction_ref: transactionRef,
    },
  });

  const invoiceState = await recalculateInvoiceStateTx(tx, invoice.id);
  return {
    payment,
    invoiceState,
    created: true,
    skipped: false,
    amountMatched: true,
  };
};

/**
 * Apply remittance and publish Billing realtime updates.
 */
const applyClaimRemittance = async ({
  claim,
  status,
  settlementAmount,
  actorUserId = null,
}) => {
  const prisma = require('@prisma/client');
  const result = await prisma.$transaction(async (tx) =>
    applyClaimRemittanceTx(tx, { claim, status, settlementAmount })
  );

  const invoice =
    result.invoiceState?.invoice ||
    (claim.invoice_id
      ? await prisma.invoice.findFirst({
          where: { id: claim.invoice_id, deleted_at: null },
          include: {
            patient: { select: { id: true, human_friendly_id: true } },
          },
        })
      : null);

  if (result.payment && invoice) {
    await publishBillingRealtimeUpdate({
      event: BILLING_EVENTS.BILLING_PAYMENT_RECEIVED,
      action: 'CLAIM_REMITTANCE',
      invoice,
      payment: result.payment,
      actorUserId,
    });
    await publishBillingRealtimeUpdate({
      event: PAYMENT_EVENTS.PAYMENT_RECONCILED,
      action: 'CLAIM_REMITTANCE',
      invoice,
      payment: result.payment,
      actorUserId,
    });
    await publishBillingRealtimeUpdate({
      event: BILLING_EVENTS.INVOICE_UPDATED,
      action: 'CLAIM_REMITTANCE',
      invoice,
      payment: result.payment,
      actorUserId,
    });
    await publishBillingRealtimeUpdate({
      event: BILLING_EVENTS.BILLING_BALANCE_UPDATED,
      action: 'BALANCE_UPDATED',
      invoice,
      payment: result.payment,
      actorUserId,
    });
  } else if (invoice && !result.skipped) {
    await publishBillingRealtimeUpdate({
      event: BILLING_EVENTS.BILLING_BALANCE_UPDATED,
      action: 'BALANCE_UPDATED',
      invoice,
      actorUserId,
    });
  }

  return {
    payment: result.payment,
    invoice: result.invoiceState?.invoice || invoice,
    financials: result.invoiceState?.financials || null,
    created: Boolean(result.created),
    skipped: Boolean(result.skipped),
  };
};

module.exports = {
  REMITTANCE_REF_PREFIX,
  remittanceTransactionRef,
  resolveRemittanceAmount,
  applyClaimRemittanceTx,
  applyClaimRemittance,
};
