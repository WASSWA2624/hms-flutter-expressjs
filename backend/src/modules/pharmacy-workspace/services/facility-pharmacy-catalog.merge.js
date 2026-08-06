/**
 * Merge master drug catalog records with facility-specific offerings.
 */

const { mapCatalogUnitPriceFields } = require('@lib/billing/clinical-request-billing');
const { mapDrugRecord } = require('@services/pharmacy-workspace/pharmacy.serializer');
const {
  mapStorageLocationFields,
} = require('@services/pharmacy-workspace/pharmacy-storage.service');

const toOptionalText = (value) => {
  const normalized = String(value ?? '').trim();
  return normalized || null;
};

const mergeDrugWithOffering = (masterDrug = {}, offering = null) => {
  if (!masterDrug || typeof masterDrug !== 'object') {
    return null;
  }

  const pharmacyUnitPrice = masterDrug.unit_price;
  const pharmacyCurrency = masterDrug.currency;
  const buyUnitPrice = masterDrug.buy_unit_price;
  const transferUnitPrice = masterDrug.transfer_unit_price;

  if (!offering || offering.is_active === false) {
    return {
      ...masterDrug,
      buy_unit_price: buyUnitPrice,
      pharmacy_unit_price: pharmacyUnitPrice,
      pharmacy_currency: pharmacyCurrency,
      transfer_unit_price: transferUnitPrice};
  }

  return {
    ...masterDrug,
    buy_unit_price: buyUnitPrice,
    pharmacy_unit_price: pharmacyUnitPrice,
    pharmacy_currency: pharmacyCurrency,
    transfer_unit_price: transferUnitPrice,
    facility_unit_price: offering.unit_price,
    facility_currency: toOptionalText(offering.currency) || pharmacyCurrency || null,
    facility_offering_id: offering.id,
    is_offered_at_facility: true};
};

const mapMergedDrugRecord = (masterDrug, offering = null) => {
  const merged = mergeDrugWithOffering(masterDrug, offering);
  if (!merged) return null;

  const mapped = mapDrugRecord(merged);
  if (!mapped) return null;

  const pharmacyPriceFields = mapCatalogUnitPriceFields({
    unit_price: merged.pharmacy_unit_price,
    currency: merged.pharmacy_currency});
  const buyPriceFields = mapCatalogUnitPriceFields({
    unit_price: merged.buy_unit_price,
    currency: merged.pharmacy_currency});
  const transferPriceFields = mapCatalogUnitPriceFields({
    unit_price: merged.transfer_unit_price,
    currency: merged.pharmacy_currency});
  const facilityPriceFields = mapCatalogUnitPriceFields({
    unit_price: merged.facility_unit_price,
    currency: merged.facility_currency});
  const offeringStorage = offering?.default_storage_shelf
    ? mapStorageLocationFields(
        offering.default_storage_shelf.storage_room,
        offering.default_storage_shelf
      )
    : null;

  return {
    ...mapped,
    ...pharmacyPriceFields,
    buy_unit_price: buyPriceFields.unit_price || null,
    pharmacy_unit_price: pharmacyPriceFields.unit_price || null,
    pharmacy_price: pharmacyPriceFields.price || null,
    pharmacy_currency: pharmacyPriceFields.currency || null,
    transfer_unit_price: transferPriceFields.unit_price || null,
    facility_unit_price: facilityPriceFields.unit_price || null,
    facility_price: facilityPriceFields.price || null,
    facility_currency: facilityPriceFields.currency || null,
    is_offered_at_facility: Boolean(offering?.is_active),
    facility_offering_id: offering?.id || null,
    offering_is_active: offering?.is_active ?? false,
    offering_sort_order: offering?.sort_order ?? 0,
    uses_platform_defaults: !offering,
    ...(offeringStorage &&
    (offeringStorage.storage_shelf_id || offeringStorage.storage_room_id)
      ? offeringStorage
      : {})};
};

module.exports = {
  mergeDrugWithOffering,
  mapMergedDrugRecord};
