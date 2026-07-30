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
  normalizeBillingOfficeClinicalBilling,
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
  if (!billing || !shouldApplyClinicalRequestBilling(billing)) {
    return null;
  }

  const resolvedChargeKey =
    chargeKey || resolveMortuaryChargeKey(eventType) || MORTUARY_CHARGE_KEYS.PRIMARY;

  return applyClinicalRequestBilling(tx, {
    billing,
    sourceModule: BILLABLE_SOURCE_MODULES.MORTUARY,
    sourceId: String(billableEventId),
    chargeKey: resolvedChargeKey,
    catalogType: 'SERVICE',
    description: description || 'Mortuary service',
    tenantId,
    facilityId,
    patientId,
    actorUserId,
    currency,
  });
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

module.exports = {
  MORTUARY_CHARGE_KEYS,
  resolveMortuaryChargeKey,
  buildMortuaryBillableEventBilling,
  persistMortuaryBillableEventBilling,
  isMortuaryCustodyLogisticsEvent,
  shouldApplyClinicalRequestBilling,
  buildPendingClinicalRequestBilling,
  toMoneyString,
  toDecimalNumber,
};
