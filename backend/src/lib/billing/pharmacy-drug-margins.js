/**
 * Pharmacy / facility drug margin helpers for sales and profit views.
 */

const toDecimalNumber = (value) => {
  const num = Number(value);
  return Number.isFinite(num) ? num : 0;
};

/**
 * Pharmacy retail margin unit: external sell − buy (COGS).
 * Returns null when buy cost is not configured.
 */
const pharmacyRetailMarginUnit = ({ unitPrice, buyUnitPrice } = {}) => {
  if (buyUnitPrice == null || buyUnitPrice === '') {
    return null;
  }
  return toDecimalNumber(unitPrice) - toDecimalNumber(buyUnitPrice);
};

/**
 * Facility margin unit: patient sell − transfer (facility buy).
 * Returns null when transfer price is not configured.
 */
const facilityPatientMarginUnit = ({
  facilityUnitPrice,
  transferUnitPrice,
} = {}) => {
  if (transferUnitPrice == null || transferUnitPrice === '') {
    return null;
  }
  return (
    toDecimalNumber(facilityUnitPrice) - toDecimalNumber(transferUnitPrice)
  );
};

module.exports = {
  pharmacyRetailMarginUnit,
  facilityPatientMarginUnit,
};
