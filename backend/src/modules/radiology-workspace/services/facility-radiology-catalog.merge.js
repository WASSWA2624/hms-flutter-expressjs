/**
 * Merge master radiology catalog records with facility-specific offerings.
 */

const { mapCatalogUnitPriceFields } = require('@lib/billing/clinical-request-billing');
const { mapRadiologyTestRecord } = require('@services/radiology-workspace/radiology.serializer');

const toOptionalText = (value) => {
  const normalized = String(value ?? '').trim();
  return normalized || null;
};

const mergeRadiologyTestWithOffering = (masterTest = {}, offering = null) => {
  if (!masterTest || !offering || offering.is_active === false) {
    return null;
  }

  return {
    ...masterTest,
    unit_price: offering.unit_price,
    currency: toOptionalText(offering.currency) || masterTest.currency || null,
    facility_offering_id: offering.id,
    is_offered_at_facility: true,
  };
};

const mapMergedRadiologyTestRecord = (masterTest, offering = null) => {
  const merged = offering ? mergeRadiologyTestWithOffering(masterTest, offering) : masterTest;
  if (!merged) return null;
  const mapped = mapRadiologyTestRecord(merged);
  return {
    ...mapped,
    ...mapCatalogUnitPriceFields(merged),
    is_offered_at_facility: Boolean(offering?.is_active),
    facility_offering_id: offering?.id || null,
    offering_is_active: offering?.is_active ?? false,
    offering_sort_order: offering?.sort_order ?? 0,
    uses_platform_defaults: !offering,
  };
};

const mapClinicalCatalogRadiologyTestRow = (masterTest, offering = null) => {
  const merged = mapMergedRadiologyTestRecord(masterTest, offering);
  if (!merged || !offering?.is_active) return null;

  return {
    id: merged.display_id || merged.id,
    item_id: masterTest.id,
    term_type: 'RADIOLOGY_TEST',
    code: merged.code || null,
    description: merged.name,
    name: merged.name,
    category: merged.modality || null,
    source: 'FACILITY',
    origin: 'FACILITY_RADIOLOGY_CATALOG',
    ...mapCatalogUnitPriceFields(merged),
    metadata: {
      modality: merged.modality || null,
      facility_offering_id: offering.id,
    },
  };
};

module.exports = {
  mergeRadiologyTestWithOffering,
  mapMergedRadiologyTestRecord,
  mapClinicalCatalogRadiologyTestRow,
};
