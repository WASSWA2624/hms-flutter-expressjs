/**
 * Facility lab catalog controller
 */

const facilityLabCatalogService = require('@services/facility-lab-catalog/facility-lab-catalog.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const buildContext = (req) => ({
  tenant_id: req.user?.tenant_id || req.user?.tenantId || req.query?.tenant_id || req.body?.tenant_id,
  facility_id: req.user?.facility_id || req.user?.facilityId || req.query?.facility_id || req.body?.facility_id,
  user_id: req.user?.id,
  ip_address: req.ip});

const listFacilityLabTests = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    search,
    offered_only,
    include_inactive,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'} = req.query;

  const result = await facilityLabCatalogService.listFacilityLabTests(
    { tenant_id, facility_id, search, offered_only, include_inactive },
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order,
    buildContext(req)
  );

  sendPaginated(res, 'messages.facility_lab_catalog.tests.list.success', result.items, result.pagination);
});

const listFacilityLabPanels = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    search,
    offered_only,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'} = req.query;

  const result = await facilityLabCatalogService.listFacilityLabPanels(
    { tenant_id, facility_id, search, offered_only },
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order,
    buildContext(req)
  );

  sendPaginated(res, 'messages.facility_lab_catalog.panels.list.success', result.items, result.pagination);
});

const getFacilityLabTest = asyncHandler(async (req, res) => {
  const { lab_test_id: labTestId } = req.params;
  const item = await facilityLabCatalogService.getFacilityLabTest(
    labTestId,
    buildContext(req),
    req.query
  );
  sendSuccess(res, 200, 'messages.facility_lab_catalog.tests.get.success', item);
});

const getFacilityLabPanel = asyncHandler(async (req, res) => {
  const { lab_panel_id: labPanelId } = req.params;
  const item = await facilityLabCatalogService.getFacilityLabPanel(
    labPanelId,
    buildContext(req),
    req.query
  );
  sendSuccess(res, 200, 'messages.facility_lab_catalog.panels.get.success', item);
});

const upsertFacilityLabTestOffering = asyncHandler(async (req, res) => {
  const item = await facilityLabCatalogService.upsertFacilityLabTestOffering(
    { ...req.body, lab_test_id: req.params.lab_test_id },
    buildContext(req)
  );
  sendSuccess(res, 200, 'messages.facility_lab_catalog.tests.upsert.success', item);
});

const disableFacilityLabTestOffering = asyncHandler(async (req, res) => {
  const { lab_test_id: labTestId } = req.params;
  await facilityLabCatalogService.disableFacilityLabTestOffering(
    labTestId,
    req.body,
    buildContext(req)
  );
  sendSuccess(res, 200, 'messages.facility_lab_catalog.tests.disable.success');
});

const upsertFacilityLabPanelOffering = asyncHandler(async (req, res) => {
  const item = await facilityLabCatalogService.upsertFacilityLabPanelOffering(
    { ...req.body, lab_panel_id: req.params.lab_panel_id },
    buildContext(req)
  );
  sendSuccess(res, 200, 'messages.facility_lab_catalog.panels.upsert.success', item);
});

const disableFacilityLabPanelOffering = asyncHandler(async (req, res) => {
  const { lab_panel_id: labPanelId } = req.params;
  await facilityLabCatalogService.disableFacilityLabPanelOffering(
    labPanelId,
    req.body,
    buildContext(req)
  );
  sendSuccess(res, 200, 'messages.facility_lab_catalog.panels.disable.success');
});

const searchFacilityLabCatalog = asyncHandler(async (req, res) => {
  const items = await facilityLabCatalogService.searchFacilityLabCatalog(
    req.query,
    buildContext(req)
  );
  sendSuccess(res, 200, 'messages.facility_lab_catalog.search.success', items);
});

module.exports = {
  listFacilityLabTests,
  listFacilityLabPanels,
  getFacilityLabTest,
  getFacilityLabPanel,
  upsertFacilityLabTestOffering,
  disableFacilityLabTestOffering,
  upsertFacilityLabPanelOffering,
  disableFacilityLabPanelOffering,
  searchFacilityLabCatalog};
