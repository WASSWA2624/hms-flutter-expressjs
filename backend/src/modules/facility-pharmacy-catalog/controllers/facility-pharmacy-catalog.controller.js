/**
 * Facility pharmacy catalog controller
 */

const facilityPharmacyCatalogService = require('@services/facility-pharmacy-catalog/facility-pharmacy-catalog.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const buildContext = (req) => ({
  tenant_id: req.user?.tenant_id || req.user?.tenantId || req.query?.tenant_id || req.body?.tenant_id,
  facility_id: req.user?.facility_id || req.user?.facilityId || req.query?.facility_id || req.body?.facility_id,
  user_id: req.user?.id,
  ip_address: req.ip,
});

const listFacilityPharmacyDrugs = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    search,
    offered_only,
    include_inactive,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc',
  } = req.query;

  const result = await facilityPharmacyCatalogService.listFacilityPharmacyDrugs(
    { tenant_id, facility_id, search, offered_only, include_inactive },
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order,
    buildContext(req)
  );

  sendPaginated(
    res,
    'messages.facility_pharmacy_catalog.drugs.list.success',
    result.items,
    result.pagination
  );
});

const getFacilityPharmacyDrug = asyncHandler(async (req, res) => {
  const { drug_id: drugId } = req.params;
  const item = await facilityPharmacyCatalogService.getFacilityPharmacyDrug(
    drugId,
    buildContext(req),
    req.query
  );
  sendSuccess(res, 200, 'messages.facility_pharmacy_catalog.drugs.get.success', item);
});

const upsertFacilityPharmacyOffering = asyncHandler(async (req, res) => {
  const item = await facilityPharmacyCatalogService.upsertFacilityPharmacyOffering(
    { ...req.body, drug_id: req.params.drug_id },
    buildContext(req)
  );
  sendSuccess(res, 200, 'messages.facility_pharmacy_catalog.drugs.upsert.success', item);
});

const disableFacilityPharmacyOffering = asyncHandler(async (req, res) => {
  const { drug_id: drugId } = req.params;
  await facilityPharmacyCatalogService.disableFacilityPharmacyOffering(
    drugId,
    req.body,
    buildContext(req)
  );
  sendSuccess(res, 200, 'messages.facility_pharmacy_catalog.drugs.disable.success');
});

module.exports = {
  listFacilityPharmacyDrugs,
  getFacilityPharmacyDrug,
  upsertFacilityPharmacyOffering,
  disableFacilityPharmacyOffering,
};
