/**
 * Facility radiology catalog routes
 */

const express = require('express');
const facilityRadiologyCatalogController = require('@controllers/facility-radiology-catalog/facility-radiology-catalog.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  upsertFacilityRadiologyTestOfferingSchema,
  disableFacilityRadiologyOfferingSchema,
  facilityRadiologyTestParamsSchema,
  listFacilityRadiologyCatalogQuerySchema,
  searchFacilityRadiologyCatalogQuerySchema,
} = require('@validations/facility-radiology-catalog/facility-radiology-catalog.schema');

const router = express.Router();

const RADIOLOGY_READ_SCOPES = [PERMISSIONS.RADIOLOGY_READ];

const RADIOLOGY_CONFIG_WRITE_SCOPES = [
  PERMISSIONS.RADIOLOGY_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
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
  authorize(RADIOLOGY_READ_SCOPES, 'permission'),
  facilityRadiologyCatalogController.listFacilityRadiologyTests
);

router.get(
  '/tests/:radiology_test_id',
  validateRequest({ params: facilityRadiologyTestParamsSchema }),
  authenticate(),
  authorize(RADIOLOGY_READ_SCOPES, 'permission'),
  facilityRadiologyCatalogController.getFacilityRadiologyTest
);

router.put(
  '/tests/:radiology_test_id',
  validateRequest({
    params: facilityRadiologyTestParamsSchema,
    body: upsertFacilityRadiologyTestOfferingSchema,
  }),
  authenticate(),
  authorize(RADIOLOGY_CONFIG_WRITE_SCOPES, 'permission'),
  facilityRadiologyCatalogController.upsertFacilityRadiologyTestOffering
);

router.delete(
  '/tests/:radiology_test_id',
  validateRequest({
    params: facilityRadiologyTestParamsSchema,
    body: disableFacilityRadiologyOfferingSchema,
  }),
  authenticate(),
  authorize(RADIOLOGY_CONFIG_WRITE_SCOPES, 'permission'),
  facilityRadiologyCatalogController.disableFacilityRadiologyTestOffering
);

module.exports = router;
