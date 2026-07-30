/**
 * ICU stay charge helpers (critical-care package / bed-day).
 *
 * ICU clinical actions must not invent a cashier. Stay-start charges post
 * through shared clinical-request billing (ICU_STAY) so Billing remains the
 * system of record. Settlement stays on the Billing workspace.
 *
 * @module lib/billing/icu-billing
 */

const {
  applyClinicalRequestBilling,
  buildPendingClinicalRequestBilling,
  normalizeBillingOfficeClinicalBilling,
  shouldApplyClinicalRequestBilling,
  BILLABLE_SOURCE_MODULES,
} = require('@lib/billing/clinical-request-billing');
const { extractFacilityBillingFee } = require('@lib/billing/emergency-billing');

const ICU_STAY_START_CHARGE_KEY = 'ICU_STAY_START';

const ICU_PACKAGE_FEE_KEYS = [
  'critical_care_package_fee',
  'icu_package_fee',
  'icu_critical_care_fee',
  'icu_fee',
];

const ICU_BED_DAY_FEE_KEYS = [
  'icu_bed_day_fee',
  'icu_daily_fee',
  'critical_care_bed_day_fee',
];

/**
 * Prefer explicit caller billing (normalized PENDING when billable); else
 * build from facility ICU package / bed-day fees.
 *
 * @param {Object} options
 * @returns {Object|null}
 */
const buildIcuStayBilling = ({ billing = null, facility = null, currency = 'USD' } = {}) => {
  const normalized = normalizeBillingOfficeClinicalBilling(billing);
  if (normalized && shouldApplyClinicalRequestBilling(normalized)) {
    return normalized;
  }
  if (billing && shouldApplyClinicalRequestBilling(billing)) {
    return normalizeBillingOfficeClinicalBilling(billing) || billing;
  }

  const packageFee = extractFacilityBillingFee(facility, ICU_PACKAGE_FEE_KEYS);
  const bedDayFee = extractFacilityBillingFee(facility, ICU_BED_DAY_FEE_KEYS);
  if (!packageFee && !bedDayFee) {
    return null;
  }

  const lineItems = [];
  if (packageFee) {
    lineItems.push({
      id: 'ICU_CRITICAL_CARE_PACKAGE',
      label: 'ICU critical-care package',
      quantity: 1,
      unit_price: packageFee.amount,
      line_total: packageFee.amount,
      catalog_type: 'SERVICE',
    });
  }
  if (bedDayFee) {
    lineItems.push({
      id: 'ICU_BED_DAY',
      label: 'ICU bed / day',
      quantity: 1,
      unit_price: bedDayFee.amount,
      line_total: bedDayFee.amount,
      catalog_type: 'SERVICE',
    });
  }

  const resolvedCurrency =
    packageFee?.currency || bedDayFee?.currency || currency || 'USD';

  return buildPendingClinicalRequestBilling({
    lineItems,
    currency: resolvedCurrency,
  });
};

/**
 * Persist ICU stay-start billing via clinical-request-billing (idempotent).
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {Object} options
 * @returns {Promise<Object|null>}
 */
const persistIcuStayStartBilling = async (
  tx,
  {
    icuStayId,
    billing,
    facility = null,
    tenantId,
    facilityId = null,
    patientId,
    encounterId = null,
    actorUserId = null,
    description = 'ICU critical-care package',
  } = {}
) => {
  if (!icuStayId || !tenantId || !patientId) {
    return null;
  }

  const resolved = buildIcuStayBilling({ billing, facility });
  if (!resolved || !shouldApplyClinicalRequestBilling(resolved)) {
    return null;
  }

  return applyClinicalRequestBilling(tx, {
    billing: resolved,
    sourceModule: BILLABLE_SOURCE_MODULES.ICU_STAY,
    sourceId: String(icuStayId),
    chargeKey: ICU_STAY_START_CHARGE_KEY,
    catalogType: 'SERVICE',
    description,
    tenantId,
    facilityId,
    patientId,
    encounterId,
    actorUserId,
  });
};

module.exports = {
  ICU_STAY_START_CHARGE_KEY,
  ICU_PACKAGE_FEE_KEYS,
  ICU_BED_DAY_FEE_KEYS,
  buildIcuStayBilling,
  persistIcuStayStartBilling,
};
