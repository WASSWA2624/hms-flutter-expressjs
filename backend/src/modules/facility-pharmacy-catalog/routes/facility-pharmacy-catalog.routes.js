/**
 * Facility pharmacy catalog routes
 */

const express = require('express');
const facilityPharmacyCatalogController = require('@controllers/facility-pharmacy-catalog/facility-pharmacy-catalog.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  upsertFacilityPharmacyOfferingSchema,
  disableFacilityPharmacyOfferingSchema,
  facilityPharmacyDrugParamsSchema,
  listFacilityPharmacyCatalogQuerySchema,
} = require('@validations/facility-pharmacy-catalog/facility-pharmacy-catalog.schema');

const router = express.Router();

const PHARMACY_READ_SCOPES = [
  PERMISSIONS.PHARMACY_READ,
  PERMISSIONS.CLINICAL_READ,
];

const PHARMACY_CONFIG_WRITE_SCOPES = [
  PERMISSIONS.PHARMACY_WRITE,
  PERMISSIONS.OPERATIONS_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.PLATFORM_ADMIN,
];

router.get(
  '/drugs',
  validateRequest({ query: listFacilityPharmacyCatalogQuerySchema }),
  authenticate(),
  authorize(PHARMACY_READ_SCOPES, 'permission'),
  facilityPharmacyCatalogController.listFacilityPharmacyDrugs
);

router.get(
  '/drugs/:drug_id',
  validateRequest({ params: facilityPharmacyDrugParamsSchema }),
  authenticate(),
  authorize(PHARMACY_READ_SCOPES, 'permission'),
  facilityPharmacyCatalogController.getFacilityPharmacyDrug
);

router.put(
  '/drugs/:drug_id',
  validateRequest({
    params: facilityPharmacyDrugParamsSchema,
    body: upsertFacilityPharmacyOfferingSchema,
  }),
  authenticate(),
  authorize(PHARMACY_CONFIG_WRITE_SCOPES, 'permission'),
  facilityPharmacyCatalogController.upsertFacilityPharmacyOffering
);

router.delete(
  '/drugs/:drug_id',
  validateRequest({
    params: facilityPharmacyDrugParamsSchema,
    body: disableFacilityPharmacyOfferingSchema,
  }),
  authenticate(),
  authorize(PHARMACY_CONFIG_WRITE_SCOPES, 'permission'),
  facilityPharmacyCatalogController.disableFacilityPharmacyOffering
);

module.exports = router;
