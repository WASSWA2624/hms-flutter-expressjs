/**
 * Procedure routes
 */

const express = require('express');
const router = express.Router();
const procedureController = require('@controllers/procedure/procedure.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { requireClinicalDeletePrivilege } = require('@middlewares/clinical-guard.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createProcedureSchema,
  updateProcedureSchema,
  procedureIdParamsSchema,
  listProceduresQuerySchema,
} = require('@validations/procedure/procedure.schema');

router.get(
  '/',
  validateRequest({ query: listProceduresQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  procedureController.listProcedures
);

router.get(
  '/:id',
  validateRequest({ params: procedureIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  procedureController.getProcedureById
);

router.post(
  '/',
  validateRequest({ body: createProcedureSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  procedureController.createProcedure
);

router.put(
  '/:id',
  validateRequest({ params: procedureIdParamsSchema, body: updateProcedureSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  procedureController.updateProcedure
);

router.delete(
  '/:id',
  validateRequest({ params: procedureIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  requireClinicalDeletePrivilege(),
  procedureController.deleteProcedure
);

module.exports = router;

