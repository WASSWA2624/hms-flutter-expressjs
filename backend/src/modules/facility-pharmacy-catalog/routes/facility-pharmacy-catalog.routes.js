/**
 * Facility pharmacy catalog routes
 */

const express = require('express');
const facilityPharmacyCatalogController = require('@controllers/facility-pharmacy-catalog/facility-pharmacy-catalog.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const { PERMISSIONS } = require('@config/permissions');
const {
  upsertFacilityPharmacyOfferingSchema,
  disableFacilityPharmacyOfferingSchema,
  facilityPharmacyDrugParamsSchema,
  listFacilityPharmacyCatalogQuerySchema,
} = require('@validations/facility-pharmacy-catalog/facility-pharmacy-catalog.schema');

const router = express.Router();

const PHARMACY_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.PHARMACIST,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.OPERATIONS,
];

const PHARMACY_CONFIG_WRITE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.PHARMACIST,
  ROLES.OPERATIONS,
];

router.get(
  '/drugs',
  validateRequest({ query: listFacilityPharmacyCatalogQuerySchema }),
  authenticate(),
  authorize([PERMISSIONS.PHARMACY_READ, PERMISSIONS.CLINICAL_READ], 'permission'),
  facilityPharmacyCatalogController.listFacilityPharmacyDrugs
);

router.get(
  '/drugs/:drug_id',
  validateRequest({ params: facilityPharmacyDrugParamsSchema }),
  authenticate(),
  authorize(PHARMACY_READ_ROLES, 'role'),
  facilityPharmacyCatalogController.getFacilityPharmacyDrug
);

router.put(
  '/drugs/:drug_id',
  validateRequest({
    params: facilityPharmacyDrugParamsSchema,
    body: upsertFacilityPharmacyOfferingSchema,
  }),
  authenticate(),
  authorize(PHARMACY_CONFIG_WRITE_ROLES, 'role'),
  facilityPharmacyCatalogController.upsertFacilityPharmacyOffering
);

router.delete(
  '/drugs/:drug_id',
  validateRequest({
    params: facilityPharmacyDrugParamsSchema,
    body: disableFacilityPharmacyOfferingSchema,
  }),
  authenticate(),
  authorize(PHARMACY_CONFIG_WRITE_ROLES, 'role'),
  facilityPharmacyCatalogController.disableFacilityPharmacyOffering
);

module.exports = router;
