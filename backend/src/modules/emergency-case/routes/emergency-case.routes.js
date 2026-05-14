/**
 * Emergency case routes
 *
 * @module modules/emergency-case/routes
 * @description Defines emergency case endpoints.
 * Per module-creation.mdc: Mount endpoints as per P010_api_endpoints.mdc.
 * Per api.mdc: Apply all required middlewares in correct order.
 */

const express = require('express');
const router = express.Router();
const emergencyCaseController = require('@controllers/emergency-case/emergency-case.controller');
const validate = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createEmergencyCaseSchema,
  updateEmergencyCaseSchema,
  emergencyCaseIdParamsSchema,
  listEmergencyCasesQuerySchema
} = require('@validations/emergency-case/emergency-case.schema');

/**
 * @route GET /api/v1/emergency-cases
 * @description List emergency cases with pagination
 * @access Private
 */
router.get(
  '/',
  validate({
    query: listEmergencyCasesQuerySchema
  }),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  emergencyCaseController.listEmergencyCases
);

/**
 * @route GET /api/v1/emergency-cases/:id
 * @description Get emergency case by ID
 * @access Private
 */
router.get(
  '/:id',
  validate({
    params: emergencyCaseIdParamsSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  emergencyCaseController.getEmergencyCaseById
);

/**
 * @route POST /api/v1/emergency-cases
 * @description Create new emergency case
 * @access Private
 */
router.post(
  '/',
  validate({
    body: createEmergencyCaseSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  emergencyCaseController.createEmergencyCase
);

/**
 * @route PUT /api/v1/emergency-cases/:id
 * @description Update emergency case
 * @access Private
 */
router.put(
  '/:id',
  validate({
    params: emergencyCaseIdParamsSchema,
    body: updateEmergencyCaseSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  emergencyCaseController.updateEmergencyCase
);

/**
 * @route DELETE /api/v1/emergency-cases/:id
 * @description Soft delete emergency case
 * @access Private
 */
router.delete(
  '/:id',
  validate({
    params: emergencyCaseIdParamsSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_DELETE, 'permission'),
  emergencyCaseController.deleteEmergencyCase
);

module.exports = router;
