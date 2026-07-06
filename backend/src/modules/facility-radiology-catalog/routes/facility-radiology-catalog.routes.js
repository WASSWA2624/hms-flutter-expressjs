/**
 * Facility radiology catalog routes
 */

const express = require('express');
const facilityRadiologyCatalogController = require('@controllers/facility-radiology-catalog/facility-radiology-catalog.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const { PERMISSIONS } = require('@config/permissions');
const {
  upsertFacilityRadiologyTestOfferingSchema,
  disableFacilityRadiologyOfferingSchema,
  facilityRadiologyTestParamsSchema,
  listFacilityRadiologyCatalogQuerySchema,
  searchFacilityRadiologyCatalogQuerySchema,
} = require('@validations/facility-radiology-catalog/facility-radiology-catalog.schema');

const router = express.Router();

const RADIOLOGY_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.RADIOLOGY_TECH,
  ROLES.SONOGRAPHER,
];

const RADIOLOGY_CONFIG_WRITE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.RADIOLOGY_TECH,
  ROLES.SONOGRAPHER,
];

router.get(
  '/search',
  validateRequest({ query: searchFacilityRadiologyCatalogQuerySchema }),
  authenticate(),
  authorize([PERMISSIONS.CLINICAL_READ, PERMISSIONS.RADIOLOGY_READ], 'permission'),
  facilityRadiologyCatalogController.searchFacilityRadiologyCatalog
);

router.get(
  '/tests',
  validateRequest({ query: listFacilityRadiologyCatalogQuerySchema }),
  authenticate(),
  authorize(RADIOLOGY_READ_ROLES, 'role'),
  facilityRadiologyCatalogController.listFacilityRadiologyTests
);

router.get(
  '/tests/:radiology_test_id',
  validateRequest({ params: facilityRadiologyTestParamsSchema }),
  authenticate(),
  authorize(RADIOLOGY_READ_ROLES, 'role'),
  facilityRadiologyCatalogController.getFacilityRadiologyTest
);

router.put(
  '/tests/:radiology_test_id',
  validateRequest({
    params: facilityRadiologyTestParamsSchema,
    body: upsertFacilityRadiologyTestOfferingSchema,
  }),
  authenticate(),
  authorize(RADIOLOGY_CONFIG_WRITE_ROLES, 'role'),
  facilityRadiologyCatalogController.upsertFacilityRadiologyTestOffering
);

router.delete(
  '/tests/:radiology_test_id',
  validateRequest({
    params: facilityRadiologyTestParamsSchema,
    body: disableFacilityRadiologyOfferingSchema,
  }),
  authenticate(),
  authorize(RADIOLOGY_CONFIG_WRITE_ROLES, 'role'),
  facilityRadiologyCatalogController.disableFacilityRadiologyTestOffering
);

module.exports = router;
