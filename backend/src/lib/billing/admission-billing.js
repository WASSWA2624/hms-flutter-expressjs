/**
 * IPD admission start charge helpers (admission fee / deposit / bed-day).
 *
 * Start-admission charges must post through shared clinical-request billing
 * (`persistAdmissionBilling` / ADMISSION) so Billing remains the system of
 * record. Prefer an explicit request payload; otherwise fall back to
 * facility billing extension fees.
 *
 * @module lib/billing/admission-billing
 */

const {
  buildPendingClinicalRequestBilling,
  normalizeBillingOfficeClinicalBilling,
  shouldApplyClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');
const { extractFacilityBillingFee } = require('@lib/billing/emergency-billing');

const ADMISSION_START_CHARGE_KEY = 'ADMISSION_START';

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

module.exports = {
  ADMISSION_START_CHARGE_KEY,
  ADMISSION_FEE_KEYS,
  ADMISSION_DEPOSIT_KEYS,
  BED_DAY_FEE_KEYS,
  buildAdmissionBilling,
};
