/**
 * IPD admission start + bed-transfer charge helpers (admission fee / deposit /
 * bed-day / rate-change on COMPLETE transfer).
 *
 * Charges must post through shared clinical-request billing
 * (`persistAdmissionBilling` / ADMISSION) so Billing remains the system of
 * record. Prefer an explicit request payload; otherwise fall back to
 * facility billing extension fees.
 *
 * @module lib/billing/admission-billing
 */

const { toDecimalNumber } = require('@lib/billing/financials');
const {
  buildPendingClinicalRequestBilling,
  normalizeBillingOfficeClinicalBilling,
  shouldApplyClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');
const { extractFacilityBillingFee } = require('@lib/billing/emergency-billing');
const { ICU_BED_DAY_FEE_KEYS } = require('@lib/billing/icu-billing');

const ADMISSION_START_CHARGE_KEY = 'ADMISSION_START';
const BED_ASSIGN_CHARGE_KEY = 'BED_ASSIGN';
const BED_TRANSFER_CHARGE_KEY_PREFIX = 'BED_TRANSFER';

const ADMISSION_FEE_KEYS = [
  'admission_fee',
  'standard_admission_fee',
  'ipd_admission_fee',
];

const ADMISSION_DEPOSIT_KEYS = [
  'admission_deposit',
  'ipd_admission_deposit',
  'prepayment_deposit',
  'admission_prepayment',
];

const BED_DAY_FEE_KEYS = [
  'bed_day_fee',
  'ipd_bed_day_fee',
  'ward_bed_day_fee',
  'daily_bed_rate',
  'bed_rate',
];

/**
 * Idempotent charge key for a completed bed transfer.
 *
 * @param {string} transferRequestId
 * @returns {string}
 */
const bedTransferChargeKey = (transferRequestId) =>
  `${BED_TRANSFER_CHARGE_KEY_PREFIX}:${String(transferRequestId || '')}`.slice(
    0,
    120
  );

/**
 * Resolve facility bed/day fee for a ward type (ICU vs general).
 *
 * @param {Object|null|undefined} facility
 * @param {string|null|undefined} wardType
 * @returns {{ amount: string, currency: string }|null}
 */
const resolveBedDayFeeForWardType = (facility, wardType) => {
  const type = String(wardType || '')
    .trim()
    .toUpperCase();
  if (type === 'ICU') {
    return (
      extractFacilityBillingFee(facility, ICU_BED_DAY_FEE_KEYS) ||
      extractFacilityBillingFee(facility, BED_DAY_FEE_KEYS)
    );
  }
  return extractFacilityBillingFee(facility, BED_DAY_FEE_KEYS);
};

/**
 * Build PENDING admission start billing from request payload and/or facility.
 *
 * @param {Object} options
 * @returns {Object|null}
 */
const buildAdmissionBilling = ({
  billing = null,
  facility = null,
  currency = 'USD',
} = {}) => {
  const fromInput = normalizeBillingOfficeClinicalBilling(billing);
  if (fromInput && shouldApplyClinicalRequestBilling(fromInput)) {
    return fromInput;
  }
  if (billing && shouldApplyClinicalRequestBilling(billing)) {
    return normalizeBillingOfficeClinicalBilling(billing) || billing;
  }

  const admissionFee = extractFacilityBillingFee(facility, ADMISSION_FEE_KEYS);
  const depositFee = extractFacilityBillingFee(
    facility,
    ADMISSION_DEPOSIT_KEYS
  );
  const bedDayFee = extractFacilityBillingFee(facility, BED_DAY_FEE_KEYS);
  const lineItems = [];

  if (admissionFee) {
    lineItems.push({
      id: 'admission-fee',
      label: 'Admission fee',
      quantity: 1,
      unit_price: admissionFee.amount,
      line_total: admissionFee.amount,
      catalog_type: 'SERVICE',
    });
  }
  if (depositFee) {
    lineItems.push({
      id: 'admission-deposit',
      label: 'Admission deposit',
      quantity: 1,
      unit_price: depositFee.amount,
      line_total: depositFee.amount,
      catalog_type: 'SERVICE',
    });
  }
  if (bedDayFee) {
    lineItems.push({
      id: 'bed-day',
      label: 'Bed / day',
      quantity: 1,
      unit_price: bedDayFee.amount,
      line_total: bedDayFee.amount,
      catalog_type: 'SERVICE',
    });
  }

  if (lineItems.length === 0) {
    return null;
  }

  const resolvedCurrency =
    admissionFee?.currency ||
    depositFee?.currency ||
    bedDayFee?.currency ||
    currency;

  return buildPendingClinicalRequestBilling({
    lineItems,
    currency: resolvedCurrency,
  });
};

/**
 * Build bed/day-only PENDING billing (assign-bed when start had no bed charge).
 *
 * @param {Object} options
 * @returns {Object|null}
 */
const buildBedDayBilling = ({
  billing = null,
  facility = null,
  currency = 'USD',
  wardType = null,
} = {}) => {
  const fromInput = normalizeBillingOfficeClinicalBilling(billing);
  if (fromInput && shouldApplyClinicalRequestBilling(fromInput)) {
    return fromInput;
  }
  if (billing && shouldApplyClinicalRequestBilling(billing)) {
    return normalizeBillingOfficeClinicalBilling(billing) || billing;
  }

  const bedDayFee = resolveBedDayFeeForWardType(facility, wardType);
  if (!bedDayFee) {
    return null;
  }

  return buildPendingClinicalRequestBilling({
    lineItems: [
      {
        id: 'bed-day',
        label: 'Bed / day',
        quantity: 1,
        unit_price: bedDayFee.amount,
        line_total: bedDayFee.amount,
        catalog_type: 'SERVICE',
      },
    ],
    currency: bedDayFee.currency || currency,
  });
};

/**
 * True when admission snapshot already reflects a posted / pending bed or
 * admission charge so assign-bed must not invent a duplicate bed/day line.
 *
 * @param {Object|null|undefined} snapshot
 * @returns {boolean}
 */
const admissionSnapshotHasBedCharge = (snapshot) => {
  if (!snapshot || typeof snapshot !== 'object') {
    return false;
  }
  const status = String(snapshot.payment_status || '').toUpperCase();
  if (
    status === 'NOT_BILLED' ||
    status === 'NOT_REQUIRED' ||
    status === 'NO_CHARGE'
  ) {
    return false;
  }
  if (snapshot.invoice_id) {
    return true;
  }
  const lines = Array.isArray(snapshot.line_items) ? snapshot.line_items : [];
  return lines.some((line) => {
    const id = String(line?.id || '').toLowerCase();
    const label = String(line?.label || '').toLowerCase();
    return (
      id.includes('bed') ||
      label.includes('bed') ||
      id.includes('admission') ||
      label.includes('admission') ||
      id.includes('deposit') ||
      label.includes('deposit')
    );
  });
};

/**
 * Build PENDING bed-transfer billing when destination rate differs from source.
 *
 * Same-rate moves return null (NOT_REQUIRED logistics). Explicit request
 * billing always wins when it should apply.
 *
 * @param {Object} options
 * @returns {Object|null}
 */
const buildBedTransferBilling = ({
  billing = null,
  facility = null,
  fromWardType = null,
  toWardType = null,
  currency = 'USD',
} = {}) => {
  const fromInput = normalizeBillingOfficeClinicalBilling(billing);
  if (fromInput && shouldApplyClinicalRequestBilling(fromInput)) {
    return fromInput;
  }
  if (billing && shouldApplyClinicalRequestBilling(billing)) {
    return normalizeBillingOfficeClinicalBilling(billing) || billing;
  }

  const fromFee = resolveBedDayFeeForWardType(facility, fromWardType);
  const toFee = resolveBedDayFeeForWardType(facility, toWardType);

  if (!toFee) {
    return null;
  }

  const fromAmount = fromFee ? toDecimalNumber(fromFee.amount) : null;
  const toAmount = toDecimalNumber(toFee.amount);
  const sameCurrency =
    !fromFee ||
    String(fromFee.currency || '').toUpperCase() ===
      String(toFee.currency || '').toUpperCase();
  if (fromAmount != null && sameCurrency && fromAmount === toAmount) {
    return null;
  }

  return buildPendingClinicalRequestBilling({
    lineItems: [
      {
        id: 'bed-transfer-day',
        label: 'Bed / day (transfer rate)',
        quantity: 1,
        unit_price: toFee.amount,
        line_total: toFee.amount,
        catalog_type: 'SERVICE',
      },
    ],
    currency: toFee.currency || currency,
  });
};

module.exports = {
  ADMISSION_START_CHARGE_KEY,
  BED_ASSIGN_CHARGE_KEY,
  BED_TRANSFER_CHARGE_KEY_PREFIX,
  ADMISSION_FEE_KEYS,
  ADMISSION_DEPOSIT_KEYS,
  BED_DAY_FEE_KEYS,
  bedTransferChargeKey,
  resolveBedDayFeeForWardType,
  buildAdmissionBilling,
  buildBedDayBilling,
  buildBedTransferBilling,
  admissionSnapshotHasBedCharge,
};
