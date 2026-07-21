/**
 * Facility lab catalog routes
 */

const express = require('express');
const facilityLabCatalogController = require('@controllers/facility-lab-catalog/facility-lab-catalog.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  upsertFacilityLabTestOfferingSchema,
  upsertFacilityLabPanelOfferingSchema,
  disableFacilityLabOfferingSchema,
  facilityLabTestParamsSchema,
  facilityLabPanelParamsSchema,
  listFacilityLabCatalogQuerySchema,
  searchFacilityLabCatalogQuerySchema,
} = require('@validations/facility-lab-catalog/facility-lab-catalog.schema');

const router = express.Router();

const LAB_READ_SCOPES = [PERMISSIONS.LAB_READ];

const LAB_CONFIG_WRITE_SCOPES = [
  PERMISSIONS.LAB_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

router.get(
  '/search',
  validateRequest({ query: searchFacilityLabCatalogQuerySchema }),
  authenticate(),
  authorize([PERMISSIONS.CLINICAL_READ, PERMISSIONS.LAB_READ], 'permission'),
  facilityLabCatalogController.searchFacilityLabCatalog
);

router.get(
  '/tests',
  validateRequest({ query: listFacilityLabCatalogQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  facilityLabCatalogController.listFacilityLabTests
);

router.get(
  '/tests/:lab_test_id',
  validateRequest({ params: facilityLabTestParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  facilityLabCatalogController.getFacilityLabTest
);

router.put(
  '/tests/:lab_test_id',
  validateRequest({
    params: facilityLabTestParamsSchema,
    body: upsertFacilityLabTestOfferingSchema,
  }),
  authenticate(),
  authorize(LAB_CONFIG_WRITE_SCOPES, 'permission'),
  facilityLabCatalogController.upsertFacilityLabTestOffering
);

router.delete(
  '/tests/:lab_test_id',
  validateRequest({
    params: facilityLabTestParamsSchema,
    body: disableFacilityLabOfferingSchema,
  }),
  authenticate(),
  authorize(LAB_CONFIG_WRITE_SCOPES, 'permission'),
  facilityLabCatalogController.disableFacilityLabTestOffering
);

router.get(
  '/panels',
  validateRequest({ query: listFacilityLabCatalogQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  facilityLabCatalogController.listFacilityLabPanels
);

router.get(
  '/panels/:lab_panel_id',
  validateRequest({ params: facilityLabPanelParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  facilityLabCatalogController.getFacilityLabPanel
);

router.put(
  '/panels/:lab_panel_id',
  validateRequest({
    params: facilityLabPanelParamsSchema,
    body: upsertFacilityLabPanelOfferingSchema,
  }),
  authenticate(),
  authorize(LAB_CONFIG_WRITE_SCOPES, 'permission'),
  facilityLabCatalogController.upsertFacilityLabPanelOffering
);

router.delete(
  '/panels/:lab_panel_id',
  validateRequest({
    params: facilityLabPanelParamsSchema,
    body: disableFacilityLabOfferingSchema,
  }),
  authenticate(),
  authorize(LAB_CONFIG_WRITE_SCOPES, 'permission'),
  facilityLabCatalogController.disableFacilityLabPanelOffering
);

module.exports = router;
