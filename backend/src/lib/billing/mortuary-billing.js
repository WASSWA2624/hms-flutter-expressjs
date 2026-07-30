/**
 * Mortuary fee helpers (storage, embalming, viewing, release).
 *
 * Charges must post through shared clinical-request billing
 * (`persistMortuaryBillableEventBilling` / MORTUARY) so Billing remains the
 * system of record. Custody transfers do not post charges — they preserve
 * payer and balance continuity on the linked mortuary case.
 *
 * @module lib/billing/mortuary-billing
 */

const { toMoneyString, toDecimalNumber } = require('@lib/billing/financials');
const {
  BILLABLE_SOURCE_MODULES,
  applyClinicalRequestBilling,
  buildPendingClinicalRequestBilling,
  findPostedBillableChargeEvent,
  normalizeBillingOfficeClinicalBilling,
  resolveInvoicePaymentStatus,
  shouldApplyClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');
const { extractFacilityBillingFee } = require('@lib/billing/emergency-billing');

const MORTUARY_CHARGE_KEYS = Object.freeze({
  STORAGE: 'MORTUARY_STORAGE',
  EMBALMING: 'MORTUARY_EMBALMING',
  VIEWING: 'MORTUARY_VIEWING',
  RELEASE: 'MORTUARY_RELEASE',
  PRIMARY: 'PRIMARY',
});

const STORAGE_FEE_KEYS = [
  'mortuary_storage_fee',
  'mortuary_cold_storage_fee',
  'storage_fee',
];

const EMBALMING_FEE_KEYS = [
  'mortuary_embalming_fee',
  'embalming_fee',
];

const VIEWING_FEE_KEYS = [
  'mortuary_viewing_fee',
  'viewing_fee',
];

const RELEASE_FEE_KEYS = [
  'mortuary_release_fee',
  'release_fee',
  'mortuary_release_preparation_fee',
];

/**
 * Normalize a mortuary billable event type into a stable charge key.
 *
 * @param {string|null|undefined} eventType
 * @returns {string}
 */
const resolveMortuaryChargeKey = (eventType) => {
  const token = String(eventType || '')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  if (!token) {
    return MORTUARY_CHARGE_KEYS.PRIMARY;
  }
  if (token.includes('EMBALM')) {
    return MORTUARY_CHARGE_KEYS.EMBALMING;
  }
  if (token.includes('VIEW')) {
    return MORTUARY_CHARGE_KEYS.VIEWING;
  }
  if (token.includes('RELEASE')) {
    return MORTUARY_CHARGE_KEYS.RELEASE;
  }
  if (token.includes('STORAGE') || token.includes('INTAKE')) {
    return MORTUARY_CHARGE_KEYS.STORAGE;
  }
  return token.length > 80 ? MORTUARY_CHARGE_KEYS.PRIMARY : token;
};

/**
 * Build PENDING mortuary billing from request payload and/or facility fees.
 *
 * @param {Object} options
 * @returns {Object|null}
 */
const buildMortuaryBillableEventBilling = ({
  billing = null,
  facility = null,
  eventType = null,
  amount = null,
  currency = 'USD',
  description = null,
} = {}) => {
  const fromInput = normalizeBillingOfficeClinicalBilling(billing);
  if (fromInput && shouldApplyClinicalRequestBilling(fromInput)) {
    return fromInput;
  }
  if (billing && shouldApplyClinicalRequestBilling(billing)) {
    return normalizeBillingOfficeClinicalBilling(billing) || billing;
  }

  const chargeKey = resolveMortuaryChargeKey(eventType);
  let fee = null;
  if (chargeKey === MORTUARY_CHARGE_KEYS.EMBALMING) {
    fee = extractFacilityBillingFee(facility, EMBALMING_FEE_KEYS);
  } else if (chargeKey === MORTUARY_CHARGE_KEYS.VIEWING) {
    fee = extractFacilityBillingFee(facility, VIEWING_FEE_KEYS);
  } else if (chargeKey === MORTUARY_CHARGE_KEYS.RELEASE) {
    fee = extractFacilityBillingFee(facility, RELEASE_FEE_KEYS);
  } else {
    fee = extractFacilityBillingFee(facility, STORAGE_FEE_KEYS);
  }

  const explicitAmount =
    amount == null || amount === ''
      ? null
      : toMoneyString(toDecimalNumber(amount));
  const unitPrice = explicitAmount || fee?.amount || null;
  if (!unitPrice) {
    return null;
  }

  const label =
    description ||
    (chargeKey === MORTUARY_CHARGE_KEYS.EMBALMING
      ? 'Mortuary embalming'
      : chargeKey === MORTUARY_CHARGE_KEYS.VIEWING
        ? 'Mortuary viewing'
        : chargeKey === MORTUARY_CHARGE_KEYS.RELEASE
          ? 'Mortuary release'
          : 'Mortuary storage');

  return buildPendingClinicalRequestBilling({
    lineItems: [
      {
        id: chargeKey.toLowerCase().replace(/_/g, '-'),
        label,
        quantity: 1,
        unit_price: unitPrice,
        line_total: unitPrice,
        catalog_type: 'SERVICE',
      },
    ],
    currency: fee?.currency || currency,
  });
};

/**
 * Persist a mortuary billable event through shared Billing (idempotent).
 * Custody transfers must not call this — they are NOT_REQUIRED logistics.
 * Never accepts a local PAID/SETTLED bypass — payload is office PENDING.
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {Object} options
 * @returns {Promise<Object|null>}
 */
const persistMortuaryBillableEventBilling = async (
  tx,
  {
    billableEventId,
    billing,
    tenantId,
    facilityId = null,
    patientId,
    actorUserId = null,
    currency = 'USD',
    eventType = null,
    description = null,
    chargeKey = null,
  } = {}
) => {
  if (!billableEventId || !tenantId || !patientId) {
    return null;
  }

  // Strip pay-now / PAID bypass — Billing office owns settlement.
  const officeBilling = normalizeBillingOfficeClinicalBilling(billing);
  if (!officeBilling || !shouldApplyClinicalRequestBilling(officeBilling)) {
    return null;
  }

  const resolvedChargeKey =
    chargeKey || resolveMortuaryChargeKey(eventType) || MORTUARY_CHARGE_KEYS.PRIMARY;

  return applyClinicalRequestBilling(tx, {
    billing: officeBilling,
    sourceModule: BILLABLE_SOURCE_MODULES.MORTUARY,
    sourceId: String(billableEventId),
    chargeKey: resolvedChargeKey,
    catalogType: 'SERVICE',
    description: description || 'Mortuary service',
    tenantId,
    facilityId,
    patientId,
    actorUserId,
    currency: officeBilling.currency || currency,
  });
};

/**
 * Resolve payment status from Billing ledger for a mortuary billable event.
 * Closes false PAID/SETTLED leakage when no billable_charge_event exists.
 *
 * @param {import('@prisma/client').Prisma.TransactionClient|Object} tx
 * @param {Object} options
 * @returns {Promise<{ payment_status: string|null, invoice_id: string|null }>}
 */
const resolveMortuaryLedgerPaymentStatus = async (
  tx,
  { tenantId, billableEventId, eventType = null, localStatus = null } = {}
) => {
  const local = String(localStatus || '')
    .trim()
    .toUpperCase();
  if (!tenantId || !billableEventId || !tx?.billable_charge_event?.findFirst) {
    // Without ledger access, never trust local SETTLED/PAID as authoritative.
    if (local === 'SETTLED' || local === 'PAID') {
      return { payment_status: 'PENDING', invoice_id: null };
    }
    return { payment_status: local || null, invoice_id: null };
  }

  const chargeKey = resolveMortuaryChargeKey(eventType);
  const keys = [chargeKey, MORTUARY_CHARGE_KEYS.PRIMARY].filter(
    (value, index, all) => value && all.indexOf(value) === index
  );

  for (const key of keys) {
    const event = await findPostedBillableChargeEvent(tx, {
      tenantId,
      sourceModule: BILLABLE_SOURCE_MODULES.MORTUARY,
      sourceId: String(billableEventId),
      chargeKey: key,
    });
    if (!event?.invoice_id) {
      continue;
    }
    if (!tx.invoice?.findFirst) {
      return {
        payment_status:
          local && local !== 'SETTLED' && local !== 'PAID' ? local : 'PENDING',
        invoice_id: event.invoice_id,
      };
    }
    const invoice = await tx.invoice.findFirst({
      where: { id: event.invoice_id, deleted_at: null },
      include: { payments: true },
    });
    if (!invoice) {
      return { payment_status: 'PENDING', invoice_id: event.invoice_id };
    }
    return {
      payment_status: resolveInvoicePaymentStatus(invoice),
      invoice_id: event.invoice_id,
    };
  }

  if (local === 'SETTLED' || local === 'PAID') {
    return { payment_status: 'PENDING', invoice_id: null };
  }
  return { payment_status: local || null, invoice_id: null };
};

/**
 * Custody transfer / chain events do not post ledger rows. Returns true when
 * the event type is logistics-only (payer/balance continuity preserved).
 *
 * @param {string|null|undefined} eventType
 * @returns {boolean}
 */
const isMortuaryCustodyLogisticsEvent = (eventType) => {
  const token = String(eventType || '')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  if (!token) {
    return true;
  }
  if (
    token.includes('TRANSFER') ||
    token.includes('CUSTODY') ||
    token === 'RECEIVED' ||
    token === 'STORAGE_ASSIGNED' ||
    token === 'MOVED' ||
    token === 'HANDOVER'
  ) {
    return true;
  }
  return false;
};

const MORTUARY_SETTLED_STATUSES = new Set(['SETTLED', 'PAID', 'CANCELLED', 'COMPLETED', 'REFUNDED']);
const MORTUARY_PARTIAL_STATUSES = new Set(['PARTIAL', 'PARTIALLY_PAID']);

/**
 * Map Billing invoice / payment status onto mortuary case vocabulary.
 *
 * @param {string|null|undefined} paymentStatus
 * @returns {string}
 */
const mapLedgerPaymentStatusToMortuary = (paymentStatus) => {
  const token = String(paymentStatus || '')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  if (!token) {
    return 'PENDING';
  }
  if (token === 'NOT_BILLED' || token === 'NOT_REQUIRED' || token === 'NO_CHARGE') {
    return token;
  }
  if (MORTUARY_SETTLED_STATUSES.has(token) || token === 'PAID') {
    return token === 'COMPLETED' || token === 'REFUNDED' ? 'SETTLED' : token === 'PAID' ? 'PAID' : 'SETTLED';
  }
  if (MORTUARY_PARTIAL_STATUSES.has(token)) {
    return 'PARTIAL';
  }
  if (token === 'OPEN' || token === 'ISSUED' || token === 'UNSETTLED') {
    return 'PENDING';
  }
  return token.length > 40 ? 'PENDING' : token;
};

/**
 * Aggregate case-level billing status from event statuses (parity helper).
 *
 * @param {Array<string|null|undefined>} eventStatuses
 * @param {string|null|undefined} fallback
 * @returns {string}
 */
const aggregateMortuaryCaseBillingStatus = (eventStatuses = [], fallback = 'PENDING') => {
  const normalized = eventStatuses
    .map((status) => mapLedgerPaymentStatusToMortuary(status))
    .filter(Boolean);
  if (normalized.length === 0) {
    return mapLedgerPaymentStatusToMortuary(fallback);
  }
  if (normalized.every((status) => MORTUARY_SETTLED_STATUSES.has(status) || status === 'PAID')) {
    return 'SETTLED';
  }
  if (normalized.some((status) => status === 'PARTIAL')) {
    return 'PARTIAL';
  }
  if (
    normalized.some(
      (status) =>
        status === 'NOT_BILLED' || status === 'NOT_REQUIRED' || status === 'NO_CHARGE'
    ) &&
    normalized.every(
      (status) =>
        status === 'NOT_BILLED' ||
        status === 'NOT_REQUIRED' ||
        status === 'NO_CHARGE' ||
        MORTUARY_SETTLED_STATUSES.has(status) ||
        status === 'PAID'
    )
  ) {
    return 'NOT_REQUIRED';
  }
  return 'PENDING';
};

/**
 * True when body release must not proceed because required mortuary charges
 * remain outstanding on the Billing ledger (Release tab unpaid gate).
 *
 * Empty / missing status does not block (parity with workspace next-action).
 *
 * @param {string|null|undefined} billingStatus
 * @returns {boolean}
 */
const isMortuaryReleaseBlockedByOutstandingBilling = (billingStatus) => {
  const token = String(billingStatus || '')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  if (!token) {
    return false;
  }
  if (
    token === 'NOT_BILLED' ||
    token === 'NOT_REQUIRED' ||
    token === 'NO_CHARGE'
  ) {
    return false;
  }
  return !(MORTUARY_SETTLED_STATUSES.has(token) || token === 'PAID');
};

/**
 * Post a mortuary fee through Billing and mirror invoice identity onto the
 * local billable event + case (idempotent). Custody logistics must not call this.
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {Object} options
 * @returns {Promise<Object|null>}
 */
const applyMortuaryBillableEventBilling = async (
  tx,
  {
    billableEvent,
    billingInput = null,
    facility = null,
    actorUserId = null,
    auditNotRequired = true,
  } = {}
) => {
  const event = billableEvent || null;
  if (!event?.id) {
    return null;
  }
  if (isMortuaryCustodyLogisticsEvent(event.event_type)) {
    if (auditNotRequired && tx?.mortuary_billable_event?.update) {
      await tx.mortuary_billable_event.update({
        where: { id: event.id },
        data: {
          status: 'NOT_REQUIRED',
          settled_at: event.settled_at || new Date(),
        },
      });
    }
    return {
      payment_status: 'NOT_REQUIRED',
      invoice_id: null,
      skipped: true,
      reason: 'NOT_REQUIRED',
    };
  }

  const patientId =
    event.patient_id ||
    event.mortuary_case?.patient_id ||
    event.patientId ||
    null;
  const tenantId = event.tenant_id || event.tenantId || null;
  const facilityId = event.facility_id || event.facilityId || null;

  const billing = buildMortuaryBillableEventBilling({
    billing: billingInput,
    facility: facility || event.facility || null,
    eventType: event.event_type,
    amount: event.amount,
    currency: event.currency || 'USD',
    description: event.description,
  });

  if (!billing || !shouldApplyClinicalRequestBilling(billing)) {
    if (auditNotRequired && tx?.mortuary_billable_event?.update) {
      await tx.mortuary_billable_event.update({
        where: { id: event.id },
        data: {
          status: 'NOT_REQUIRED',
          settled_at: new Date(),
        },
      });
    }
    return {
      payment_status: 'NOT_REQUIRED',
      invoice_id: null,
      skipped: true,
      reason: 'NOT_REQUIRED',
    };
  }

  if (!tenantId || !patientId) {
    return null;
  }

  const snapshot = await persistMortuaryBillableEventBilling(tx, {
    billableEventId: event.id,
    billing,
    tenantId,
    facilityId,
    patientId,
    actorUserId,
    currency: billing.currency || event.currency || 'USD',
    eventType: event.event_type,
    description: event.description,
  });

  if (!snapshot) {
    return null;
  }

  const mirroredStatus = mapLedgerPaymentStatusToMortuary(
    snapshot.payment_status || 'PENDING'
  );
  const invoiceId = snapshot.invoice_id || snapshot.invoiceId || null;

  if (tx?.mortuary_billable_event?.update) {
    await tx.mortuary_billable_event.update({
      where: { id: event.id },
      data: {
        status: mirroredStatus,
        billing_reference_id: invoiceId || event.billing_reference_id || null,
        settled_at:
          MORTUARY_SETTLED_STATUSES.has(mirroredStatus) || mirroredStatus === 'PAID'
            ? new Date()
            : event.settled_at || null,
      },
    });
  }

  const mortuaryCaseId = event.mortuary_case_id || event.mortuaryCaseId || null;
  if (mortuaryCaseId && tx?.mortuary_case?.update) {
    await tx.mortuary_case.update({
      where: { id: mortuaryCaseId },
      data: { billing_status: mirroredStatus },
    });
  }

  return {
    ...snapshot,
    payment_status: mirroredStatus,
    invoice_id: invoiceId,
  };
};

module.exports = {
  MORTUARY_CHARGE_KEYS,
  resolveMortuaryChargeKey,
  buildMortuaryBillableEventBilling,
  persistMortuaryBillableEventBilling,
  applyMortuaryBillableEventBilling,
  resolveMortuaryLedgerPaymentStatus,
  mapLedgerPaymentStatusToMortuary,
  aggregateMortuaryCaseBillingStatus,
  isMortuaryCustodyLogisticsEvent,
  isMortuaryReleaseBlockedByOutstandingBilling,
  shouldApplyClinicalRequestBilling,
  buildPendingClinicalRequestBilling,
  toMoneyString,
  toDecimalNumber,
};
