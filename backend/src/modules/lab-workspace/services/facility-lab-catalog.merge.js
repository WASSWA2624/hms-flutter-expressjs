/**
 * Merge master lab catalog records with facility-specific offerings.
 */

const { mapCatalogUnitPriceFields } = require('@lib/billing/clinical-request-billing');
const { mapLabTestRecord, mapLabPanelRecord } = require('@services/lab-workspace/lab.serializer');

const toOptionalText = (value) => {
  const normalized = String(value ?? '').trim();
  return normalized || null;
};

const hasRows = (value) => Array.isArray(value) && value.length > 0;

const mergeLabTestWithOffering = (masterTest = {}, offering = null) => {
  if (!masterTest || !offering || offering.is_active === false) {
    return null;
  }

  const useOfferingRanges = hasRows(offering.reference_ranges);
  const useOfferingUnits = hasRows(offering.unit_options);
  const useOfferingResults = hasRows(offering.result_options);

  const merged = {
    ...masterTest,
    specimen_type: toOptionalText(offering.specimen_type) || masterTest.specimen_type || null,
    result_kind: offering.result_kind || masterTest.result_kind || null,
    unit: toOptionalText(offering.unit) || masterTest.unit || null,
    description: toOptionalText(offering.description) || masterTest.description || null,
    reference_range: toOptionalText(offering.reference_range) || masterTest.reference_range || null,
    reference_ranges: useOfferingRanges ? offering.reference_ranges : masterTest.reference_ranges || [],
    unit_options: useOfferingUnits ? offering.unit_options : masterTest.unit_options || [],
    result_options: useOfferingResults ? offering.result_options : masterTest.result_options || [],
    unit_price: offering.unit_price,
    currency: toOptionalText(offering.currency) || masterTest.currency || null,
    facility_offering_id: offering.id,
    is_offered_at_facility: true,
  };

  return merged;
};

const mapMergedLabTestRecord = (masterTest, offering = null) => {
  const merged = offering ? mergeLabTestWithOffering(masterTest, offering) : masterTest;
  if (!merged) return null;
  const mapped = mapLabTestRecord(merged);
  return {
    ...mapped,
    ...mapCatalogUnitPriceFields(merged),
    is_offered_at_facility: Boolean(offering?.is_active),
    facility_offering_id: offering?.id || null,
    offering_is_active: offering?.is_active ?? false,
    offering_sort_order: offering?.sort_order ?? 0,
    uses_platform_defaults: !offering
      || (!hasRows(offering.reference_ranges)
        && !hasRows(offering.unit_options)
        && !hasRows(offering.result_options)
        && !toOptionalText(offering.specimen_type)
        && !offering.result_kind
        && !toOptionalText(offering.unit)
        && !toOptionalText(offering.description)),
  };
};

const mapMergedLabPanelRecord = (masterPanel, offering = null) => {
  if (!masterPanel) return null;
  if (offering && offering.is_active === false) return null;

  const mapped = mapLabPanelRecord(masterPanel);
  if (!offering) {
    return {
      ...mapped,
      ...mapCatalogUnitPriceFields(masterPanel),
      is_offered_at_facility: false,
      facility_offering_id: null,
      offering_is_active: false,
    };
  }

  return {
    ...mapped,
    unit_price: offering.unit_price,
    currency: toOptionalText(offering.currency) || masterPanel.currency || null,
    ...mapCatalogUnitPriceFields({ ...masterPanel, unit_price: offering.unit_price, currency: offering.currency }),
    is_offered_at_facility: true,
    facility_offering_id: offering.id,
    offering_is_active: offering.is_active,
    offering_sort_order: offering.sort_order,
  };
};

const mapClinicalCatalogLabTestRow = (masterTest, offering = null) => {
  const merged = mapMergedLabTestRecord(masterTest, offering);
  if (!merged || !offering?.is_active) return null;

  return {
    id: merged.display_id || merged.id,
    item_id: masterTest.id,
    term_type: 'LAB_TEST',
    code: merged.code || null,
    description: merged.name,
    name: merged.name,
    category: merged.category || null,
    source: 'FACILITY',
    origin: 'FACILITY_LAB_CATALOG',
    ...mapCatalogUnitPriceFields(merged),
    metadata: {
      specimen_type: merged.specimen_type || null,
      result_kind: merged.result_kind || null,
      facility_offering_id: offering.id,
    },
  };
};

const mapClinicalCatalogLabPanelRow = (masterPanel, offering = null) => {
  const merged = mapMergedLabPanelRecord(masterPanel, offering);
  if (!merged || !offering?.is_active) return null;

  return {
    id: merged.display_id || merged.id,
    item_id: masterPanel.id,
    term_type: 'LAB_PANEL',
    code: merged.code || null,
    description: merged.name,
    name: merged.name,
    category: merged.category || null,
    source: 'FACILITY',
    origin: 'FACILITY_LAB_CATALOG',
    ...mapCatalogUnitPriceFields(merged),
    metadata: {
      facility_offering_id: offering.id,
      test_count: merged.test_count || 0,
    },
  };
};

module.exports = {
  mergeLabTestWithOffering,
  mapMergedLabTestRecord,
  mapMergedLabPanelRecord,
  mapClinicalCatalogLabTestRow,
  mapClinicalCatalogLabPanelRow,
};
