/**
 * Emergency deferred / ambulance charge helpers.
 *
 * Urgent care may defer payment, but deferred handoff and ambulance trip
 * charges must still post through shared clinical-request billing (PENDING /
 * outstanding) so Billing remains the system of record.
 *
 * @module lib/billing/emergency-billing
 */

const { toMoneyString, toDecimalNumber } = require('@lib/billing/financials');
const {
  applyClinicalRequestBilling,
  buildPendingClinicalRequestBilling,
  buildConsultationBillingPayload,
  normalizeBillingOfficeClinicalBilling,
  shouldApplyClinicalRequestBilling,
  BILLABLE_SOURCE_MODULES,
} = require('@lib/billing/clinical-request-billing');

const AMBULANCE_TRIP_CHARGE_KEY = 'AMBULANCE_TRIP';
const HANDOFF_ADMISSION_CHARGE_KEY = 'EMERGENCY_HANDOFF_ADMISSION';
const HANDOFF_THEATRE_CHARGE_KEY = 'EMERGENCY_HANDOFF_THEATRE';

const toFiniteAmount = (value) => {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  if (typeof value === 'number') {
    return Number.isFinite(value) && value > 0 ? value : null;
  }
  if (typeof value?.toNumber === 'function') {
    const parsed = value.toNumber();
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }
  const parsed = Number(String(value).trim());
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
};

/**
 * Read a positive fee from facility extension billing settings.
 *
 * @param {Object|null|undefined} facility
 * @param {string[]} keys
 * @returns {{ amount: string, currency: string }|null}
 */
const extractFacilityBillingFee = (facility, keys = []) => {
  const extension =
    facility?.extension_json && typeof facility.extension_json === 'object'
      ? facility.extension_json
      : {};
  const billing =
    extension.billing && typeof extension.billing === 'object'
      ? extension.billing
      : extension;
  for (const key of keys) {
    const amount = toFiniteAmount(billing?.[key]);
    if (amount != null) {
      const currency = String(
        billing?.[`${key}_currency`] ||
          billing?.currency ||
          billing?.default_currency ||
          'USD'
      )
        .trim()
        .toUpperCase() || 'USD';
      return { amount: toMoneyString(amount), currency };
    }
  }
  return null;
};

/**
 * Normalize caller billing to a PENDING office payload, or build from amount.
 *
 * @param {Object|null|undefined} billing
 * @param {{ label: string, id?: string, amount?: unknown, currency?: string }} [fallback]
 * @returns {Object|null}
 */
const resolveDeferredEmergencyBilling = (billing, fallback = {}) => {
  const normalized = normalizeBillingOfficeClinicalBilling(billing);
  if (normalized && shouldApplyClinicalRequestBilling(normalized)) {
    return normalized;
  }

  if (billing && shouldApplyClinicalRequestBilling(billing)) {
    return normalizeBillingOfficeClinicalBilling(billing) || billing;
  }

  const amount = toFiniteAmount(fallback.amount ?? billing?.total_amount);
  if (amount == null) {
    return null;
  }

  return buildPendingClinicalRequestBilling({
    lineItems: [
      {
        id: fallback.id || 'emergency-service',
        label: fallback.label || 'Emergency service',
        quantity: 1,
        unit_price: toMoneyString(amount),
        line_total: toMoneyString(amount),
        catalog_type: 'SERVICE',
      },
    ],
    currency: fallback.currency || billing?.currency || 'USD',
  });
};

/**
 * Build deferred admission fee for IPD/ICU emergency handoff.
 *
 * @param {Object} options
 * @returns {Object|null}
 */
const buildEmergencyAdmissionBilling = ({
  billing,
  facility = null,
  currency = 'USD',
} = {}) => {
  const fromInput = resolveDeferredEmergencyBilling(billing, {
    id: 'emergency-admission',
    label: 'Emergency admission fee',
    currency,
  });
  if (fromInput) {
    return fromInput;
  }

  const facilityFee = extractFacilityBillingFee(facility, [
    'admission_fee',
    'emergency_admission_fee',
    'standard_admission_fee',
  ]);
  if (!facilityFee) {
    return null;
  }

  return buildPendingClinicalRequestBilling({
    lineItems: [
      {
        id: 'emergency-admission',
        label: 'Emergency admission fee',
        quantity: 1,
        unit_price: facilityFee.amount,
        line_total: facilityFee.amount,
        catalog_type: 'SERVICE',
      },
    ],
    currency: facilityFee.currency || currency,
  });
};

/**
 * Build deferred theatre fee for emergency handoff.
 *
 * @param {Object} options
 * @returns {Object|null}
 */
const buildEmergencyTheatreBilling = ({
  billing,
  facility = null,
  currency = 'USD',
} = {}) => {
  const fromInput = resolveDeferredEmergencyBilling(billing, {
    id: 'emergency-theatre',
    label: 'Emergency theatre fee',
    currency,
  });
  if (fromInput) {
    return fromInput;
  }

  const facilityFee = extractFacilityBillingFee(facility, [
    'theatre_fee',
    'theater_fee',
    'emergency_theatre_fee',
  ]);
  if (!facilityFee) {
    return null;
  }

  return buildPendingClinicalRequestBilling({
    lineItems: [
      {
        id: 'emergency-theatre',
        label: 'Emergency theatre fee',
        quantity: 1,
        unit_price: facilityFee.amount,
        line_total: facilityFee.amount,
        catalog_type: 'SERVICE',
      },
    ],
    currency: facilityFee.currency || currency,
  });
};

/**
 * Build deferred ambulance trip transport charge.
 *
 * @param {Object} options
 * @returns {Object|null}
 */
const buildAmbulanceTripBilling = ({
  billing,
  facility = null,
  currency = 'USD',
} = {}) => {
  const fromInput = resolveDeferredEmergencyBilling(billing, {
    id: 'ambulance-trip',
    label: 'Ambulance transport',
    currency,
  });
  if (fromInput) {
    return fromInput;
  }

  const facilityFee = extractFacilityBillingFee(facility, [
    'ambulance_trip_fee',
    'ambulance_fee',
    'ambulance_transport_fee',
  ]);
  if (!facilityFee) {
    return null;
  }

  return buildPendingClinicalRequestBilling({
    lineItems: [
      {
        id: 'ambulance-trip',
        label: 'Ambulance transport',
        quantity: 1,
        unit_price: facilityFee.amount,
        line_total: facilityFee.amount,
        catalog_type: 'SERVICE',
      },
    ],
    currency: facilityFee.currency || currency,
  });
};

/**
 * Persist ambulance trip charge via shared Billing (SERVICE source, idempotent).
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {Object} options
 * @returns {Promise<Object|null>}
 */
const persistAmbulanceTripBilling = async (
  tx,
  {
    tripId,
    billing,
    tenantId,
    facilityId = null,
    patientId,
    actorUserId = null,
    currency = 'USD',
  } = {}
) => {
  if (!tripId || !tenantId || !patientId) {
    return null;
  }
  if (!billing || !shouldApplyClinicalRequestBilling(billing)) {
    return null;
  }

  return applyClinicalRequestBilling(tx, {
    billing,
    sourceModule: BILLABLE_SOURCE_MODULES.SERVICE,
    sourceId: String(tripId),
    chargeKey: AMBULANCE_TRIP_CHARGE_KEY,
    catalogType: 'SERVICE',
    description: 'Ambulance transport',
    tenantId,
    facilityId,
    patientId,
    actorUserId,
    currency,
  });
};

/**
 * Persist a deferred emergency SERVICE charge keyed by emergency case + charge key.
 * Used when receiving workflows do not accept a billing payload directly.
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {Object} options
 * @returns {Promise<Object|null>}
 */
const persistEmergencyCaseServiceBilling = async (
  tx,
  {
    emergencyCaseId,
    chargeKey,
    billing,
    tenantId,
    facilityId = null,
    patientId,
    description = 'Emergency service',
    actorUserId = null,
    currency = 'USD',
  } = {}
) => {
  if (!emergencyCaseId || !tenantId || !patientId || !chargeKey) {
    return null;
  }
  if (!billing || !shouldApplyClinicalRequestBilling(billing)) {
    return null;
  }

  return applyClinicalRequestBilling(tx, {
    billing,
    sourceModule: BILLABLE_SOURCE_MODULES.SERVICE,
    sourceId: String(emergencyCaseId),
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

module.exports = {
  AMBULANCE_TRIP_CHARGE_KEY,
  HANDOFF_ADMISSION_CHARGE_KEY,
  HANDOFF_THEATRE_CHARGE_KEY,
  extractFacilityBillingFee,
  resolveDeferredEmergencyBilling,
  buildEmergencyAdmissionBilling,
  buildEmergencyTheatreBilling,
  buildAmbulanceTripBilling,
  persistAmbulanceTripBilling,
  persistEmergencyCaseServiceBilling,
  buildConsultationBillingPayload,
  buildPendingClinicalRequestBilling,
  shouldApplyClinicalRequestBilling,
  toDecimalNumber,
  toMoneyString,
};
