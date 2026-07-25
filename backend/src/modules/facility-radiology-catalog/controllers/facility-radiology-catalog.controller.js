/**
 * Facility radiology catalog controller
 */

const facilityRadiologyCatalogService = require('@services/facility-radiology-catalog/facility-radiology-catalog.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const buildContext = (req) => ({
  tenant_id: req.user?.tenant_id || req.user?.tenantId || req.query?.tenant_id || req.body?.tenant_id,
  facility_id: req.user?.facility_id || req.user?.facilityId || req.query?.facility_id || req.body?.facility_id,
  user_id: req.user?.id,
  ip_address: req.ip,
});

const listFacilityRadiologyTests = asyncHandler(async (req, res) => {
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

  const result = await facilityRadiologyCatalogService.listFacilityRadiologyTests(
    { tenant_id, facility_id, search, offered_only, include_inactive },
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order,
    buildContext(req)
  );

  sendPaginated(
    res,
    'messages.facility_radiology_catalog.tests.list.success',
    result.items,
    result.pagination
  );
});

const getFacilityRadiologyTest = asyncHandler(async (req, res) => {
  const radiologyTestId = req.params.radiology_procedure_id ?? req.params.radiology_test_id;
  const item = await facilityRadiologyCatalogService.getFacilityRadiologyTest(
    radiologyTestId,
    buildContext(req),
    req.query
  );
  sendSuccess(res, 200, 'messages.facility_radiology_catalog.tests.get.success', item);
});

const upsertFacilityRadiologyTestOffering = asyncHandler(async (req, res) => {
  const radiologyTestId = req.params.radiology_procedure_id ?? req.params.radiology_test_id;
  const item = await facilityRadiologyCatalogService.upsertFacilityRadiologyTestOffering(
    { ...req.body, radiology_procedure_id: radiologyTestId },
    buildContext(req)
  );
  sendSuccess(res, 200, 'messages.facility_radiology_catalog.tests.upsert.success', item);
});

const disableFacilityRadiologyTestOffering = asyncHandler(async (req, res) => {
  const radiologyTestId = req.params.radiology_procedure_id ?? req.params.radiology_test_id;
  await facilityRadiologyCatalogService.disableFacilityRadiologyTestOffering(
    radiologyTestId,
    req.body,
    buildContext(req)
  );
  sendSuccess(res, 200, 'messages.facility_radiology_catalog.tests.disable.success');
});

const searchFacilityRadiologyCatalog = asyncHandler(async (req, res) => {
  const items = await facilityRadiologyCatalogService.searchFacilityRadiologyCatalog(
    req.query,
    buildContext(req)
  );
  sendSuccess(res, 200, 'messages.facility_radiology_catalog.search.success', items);
});

module.exports = {
  listFacilityRadiologyTests,
  getFacilityRadiologyTest,
  upsertFacilityRadiologyTestOffering,
  disableFacilityRadiologyTestOffering,
  searchFacilityRadiologyCatalog,
};
