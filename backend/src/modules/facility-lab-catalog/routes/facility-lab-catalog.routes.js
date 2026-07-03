/**
 * Facility lab catalog routes
 */

const express = require('express');
const facilityLabCatalogController = require('@controllers/facility-lab-catalog/facility-lab-catalog.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
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

const LAB_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
];

const LAB_CONFIG_WRITE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.LAB_TECH,
];

router.get(
  '/search',
  validateRequest({ query: searchFacilityLabCatalogQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  facilityLabCatalogController.searchFacilityLabCatalog
);

router.get(
  '/tests',
  validateRequest({ query: listFacilityLabCatalogQuerySchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  facilityLabCatalogController.listFacilityLabTests
);

router.get(
  '/tests/:lab_test_id',
  validateRequest({ params: facilityLabTestParamsSchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  facilityLabCatalogController.getFacilityLabTest
);

router.put(
  '/tests/:lab_test_id',
  validateRequest({
    params: facilityLabTestParamsSchema,
    body: upsertFacilityLabTestOfferingSchema,
  }),
  authenticate(),
  authorize(LAB_CONFIG_WRITE_ROLES, 'role'),
  facilityLabCatalogController.upsertFacilityLabTestOffering
);

router.delete(
  '/tests/:lab_test_id',
  validateRequest({
    params: facilityLabTestParamsSchema,
    body: disableFacilityLabOfferingSchema,
  }),
  authenticate(),
  authorize(LAB_CONFIG_WRITE_ROLES, 'role'),
  facilityLabCatalogController.disableFacilityLabTestOffering
);

router.get(
  '/panels',
  validateRequest({ query: listFacilityLabCatalogQuerySchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  facilityLabCatalogController.listFacilityLabPanels
);

router.put(
  '/panels/:lab_panel_id',
  validateRequest({
    params: facilityLabPanelParamsSchema,
    body: upsertFacilityLabPanelOfferingSchema,
  }),
  authenticate(),
  authorize(LAB_CONFIG_WRITE_ROLES, 'role'),
  facilityLabCatalogController.upsertFacilityLabPanelOffering
);

router.delete(
  '/panels/:lab_panel_id',
  validateRequest({
    params: facilityLabPanelParamsSchema,
    body: disableFacilityLabOfferingSchema,
  }),
  authenticate(),
  authorize(LAB_CONFIG_WRITE_ROLES, 'role'),
  facilityLabCatalogController.disableFacilityLabPanelOffering
);

module.exports = router;
