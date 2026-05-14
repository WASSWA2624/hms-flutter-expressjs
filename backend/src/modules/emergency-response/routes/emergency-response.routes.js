/**
 * Emergency response routes
 *
 * @module modules/emergency-response/routes
 * @description Defines emergency response endpoints.
 * Per module-creation.mdc: Mount endpoints as per P010_api_endpoints.mdc.
 * Per api.mdc: Apply all required middlewares in correct order.
 */

const express = require('express');
const router = express.Router();
const emergencyResponseController = require('@modules/emergency-response/controllers/emergency-response.controller');
const { validate } = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createEmergencyResponseSchema,
  updateEmergencyResponseSchema,
  emergencyResponseIdParamsSchema,
  listEmergencyResponsesQuerySchema
} = require('@modules/emergency-response/schemas/emergency-response.schema');

/**
 * @route GET /api/v1/emergency-responses
 * @description List emergency responses with pagination
 * @access Private
 */
router.get(
  '/',
  validate({
    query: listEmergencyResponsesQuerySchema
  }),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  emergencyResponseController.listEmergencyResponses
);

/**
 * @route GET /api/v1/emergency-responses/:id
 * @description Get emergency response by ID
 * @access Private
 */
router.get(
  '/:id',
  validate({
    params: emergencyResponseIdParamsSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  emergencyResponseController.getEmergencyResponseById
);

/**
 * @route POST /api/v1/emergency-responses
 * @description Create new emergency response
 * @access Private
 */
router.post(
  '/',
  validate({
    body: createEmergencyResponseSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  emergencyResponseController.createEmergencyResponse
);

/**
 * @route PUT /api/v1/emergency-responses/:id
 * @description Update emergency response
 * @access Private
 */
router.put(
  '/:id',
  validate({
    params: emergencyResponseIdParamsSchema,
    body: updateEmergencyResponseSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  emergencyResponseController.updateEmergencyResponse
);

/**
 * @route DELETE /api/v1/emergency-responses/:id
 * @description Soft delete emergency response
 * @access Private
 */
router.delete(
  '/:id',
  validate({
    params: emergencyResponseIdParamsSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_DELETE, 'permission'),
  emergencyResponseController.deleteEmergencyResponse
);

module.exports = router;
