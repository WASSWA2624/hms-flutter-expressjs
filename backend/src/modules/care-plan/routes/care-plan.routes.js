/**
 * Care plan routes
 */

const express = require('express');
const router = express.Router();
const carePlanController = require('@controllers/care-plan/care-plan.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { requireClinicalDeletePrivilege } = require('@middlewares/clinical-guard.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createCarePlanSchema,
  updateCarePlanSchema,
  carePlanIdParamsSchema,
  listCarePlansQuerySchema,
} = require('@validations/care-plan/care-plan.schema');

router.get(
  '/',
  validateRequest({ query: listCarePlansQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  carePlanController.listCarePlans
);

router.get(
  '/:id',
  validateRequest({ params: carePlanIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  carePlanController.getCarePlanById
);

router.post(
  '/',
  validateRequest({ body: createCarePlanSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  carePlanController.createCarePlan
);

router.put(
  '/:id',
  validateRequest({ params: carePlanIdParamsSchema, body: updateCarePlanSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  carePlanController.updateCarePlan
);

router.delete(
  '/:id',
  validateRequest({ params: carePlanIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  requireClinicalDeletePrivilege(),
  carePlanController.deleteCarePlan
);

module.exports = router;

