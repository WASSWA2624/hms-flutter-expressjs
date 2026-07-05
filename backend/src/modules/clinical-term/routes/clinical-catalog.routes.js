/**
 * Clinical catalog layered search routes
 */

const express = require('express');
const router = express.Router();
const clinicalTermController = require('@controllers/clinical-term/clinical-term.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  listClinicalCatalogSearchQuerySchema,
  listFacilityCatalogOfferingsQuerySchema,
  upsertFacilityCatalogOfferingSchema,
  facilityCatalogOfferingIdParamsSchema,
} = require('@validations/clinical-term/clinical-term.schema');

router.get(
  '/search',
  validateRequest({ query: listClinicalCatalogSearchQuerySchema }),
  authenticate(),
  authorize([PERMISSIONS.CLINICAL_READ, PERMISSIONS.LAB_READ], 'permission'),
  clinicalTermController.listClinicalCatalogSearch
);

router.get(
  '/offerings',
  validateRequest({ query: listFacilityCatalogOfferingsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  clinicalTermController.listFacilityCatalogOfferings
);

router.post(
  '/offerings',
  validateRequest({ body: upsertFacilityCatalogOfferingSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalTermController.upsertFacilityCatalogOffering
);

router.delete(
  '/offerings/:id',
  validateRequest({ params: facilityCatalogOfferingIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalTermController.deleteFacilityCatalogOffering
);

module.exports = router;
