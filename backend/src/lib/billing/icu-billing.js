/**
 * ICU stay charge helpers (critical-care package / bed-day).
 *
 * Start-stay charges must post through shared clinical-request billing
 * (`persistIcuStayBilling` / ICU_STAY) so Billing remains the system of
 * record. Prefer an explicit request payload; otherwise fall back to
 * facility billing extension fees.
 *
 * @module lib/billing/icu-billing
 */

const { toMoneyString, toDecimalNumber } = require('@lib/billing/financials');
const {
  buildPendingClinicalRequestBilling,
  normalizeBillingOfficeClinicalBilling,
  shouldApplyClinicalRequestBilling,
} = require('@lib/billing/clinical-request-billing');
const { extractFacilityBillingFee } = require('@lib/billing/emergency-billing');

const ICU_STAY_START_CHARGE_KEY = 'ICU_STAY_START';

const ICU_PACKAGE_FEE_KEYS = [
  'icu_critical_care_package_fee',
  'critical_care_package_fee',
  'icu_package_fee',
  'icu_admission_fee',
];

const ICU_BED_DAY_FEE_KEYS = [
  'icu_bed_day_fee',
  'icu_daily_rate',
  'icu_bed_fee',
  'critical_care_bed_day_fee',
];

/**
 * Build PENDING ICU stay start billing from request payload and/or facility.
 *
 * @param {Object} options
 * @returns {Object|null}
 */
const buildIcuStayBilling = ({
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

  const packageFee = extractFacilityBillingFee(facility, ICU_PACKAGE_FEE_KEYS);
  const bedDayFee = extractFacilityBillingFee(facility, ICU_BED_DAY_FEE_KEYS);
  const lineItems = [];

  if (packageFee) {
    lineItems.push({
      id: 'icu-critical-care-package',
      label: 'ICU critical-care package',
      quantity: 1,
      unit_price: packageFee.amount,
      line_total: packageFee.amount,
      catalog_type: 'SERVICE',
    });
  }
  if (bedDayFee) {
    lineItems.push({
      id: 'icu-bed-day',
      label: 'ICU bed/day',
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
    packageFee?.currency || bedDayFee?.currency || currency;

  return buildPendingClinicalRequestBilling({
    lineItems,
    currency: resolvedCurrency,
  });
};

/**
 * Sum line totals for diagnostics / tests.
 *
 * @param {Object|null|undefined} billing
 * @returns {number}
 */
const icuStayBillingTotal = (billing) => {
  if (!billing) {
    return 0;
  }
  if (billing.total_amount != null) {
    return toDecimalNumber(billing.total_amount);
  }
  const items = Array.isArray(billing.line_items) ? billing.line_items : [];
  return items.reduce(
    (sum, item) => sum + toDecimalNumber(item?.line_total || item?.unit_price),
    0
  );
};

module.exports = {
  ICU_STAY_START_CHARGE_KEY,
  ICU_PACKAGE_FEE_KEYS,
  ICU_BED_DAY_FEE_KEYS,
  buildIcuStayBilling,
  icuStayBillingTotal,
  toMoneyString,
};
