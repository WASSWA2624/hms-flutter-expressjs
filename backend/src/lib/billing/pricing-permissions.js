/**
 * Pricing permission helpers for pharmacy retail vs facility tariff writes.
 */

const { PERMISSIONS } = require('@config/permissions');
const { HttpError } = require('@lib/errors');
const { getUserPermissions } = require('@middlewares/auth.middleware');

const hasOwn = (value, key) =>
  Object.prototype.hasOwnProperty.call(value || {}, key);

const getPermissionSet = (user = {}) => new Set(getUserPermissions(user));

const hasPermission = (user, permission) => getPermissionSet(user).has(permission);

const assertPricingPharmacyWrite = (user = {}) => {
  if (hasPermission(user, PERMISSIONS.PRICING_PHARMACY_WRITE)) return;
  throw new HttpError('errors.auth.insufficient_permissions', 403);
};

const assertPricingFacilityWrite = (user = {}) => {
  if (hasPermission(user, PERMISSIONS.PRICING_FACILITY_WRITE)) return;
  throw new HttpError('errors.auth.insufficient_permissions', 403);
};

/**
 * Reject payloads that mutate pharmacy retail price fields without permission.
 * Identity/stock updates that omit these keys are allowed.
 */
const assertPharmacyRetailPriceMutationAllowed = (user = {}, payload = {}) => {
  if (!hasOwn(payload, 'unit_price') && !hasOwn(payload, 'currency')) {
    return;
  }
  assertPricingPharmacyWrite(user);
};

/**
 * Reject facility offering payloads that set/activate tariff without permission.
 * Shelf-only updates that omit price/activation fields are allowed.
 */
const assertFacilityTariffMutationAllowed = (user = {}, payload = {}) => {
  const touchesPrice =
    hasOwn(payload, 'unit_price') || hasOwn(payload, 'currency');
  const activates =
    hasOwn(payload, 'is_active') && payload.is_active !== false;
  if (!touchesPrice && !activates) {
    return;
  }
  assertPricingFacilityWrite(user);
};

/**
 * Gate price-book writes by billing_entity.
 */
const assertPriceBookBillingEntityWrite = (
  user = {},
  billingEntity = 'FACILITY'
) => {
  const entity = String(billingEntity || 'FACILITY').trim().toUpperCase();
  if (entity === 'PHARMACY') {
    assertPricingPharmacyWrite(user);
    return;
  }
  assertPricingFacilityWrite(user);
};

module.exports = {
  hasPermission,
  assertPricingPharmacyWrite,
  assertPricingFacilityWrite,
  assertPharmacyRetailPriceMutationAllowed,
  assertFacilityTariffMutationAllowed,
  assertPriceBookBillingEntityWrite,
};
