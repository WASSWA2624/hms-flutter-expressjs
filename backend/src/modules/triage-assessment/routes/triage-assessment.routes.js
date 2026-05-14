/**
 * Triage assessment routes
 *
 * @module modules/triage-assessment/routes
 * @description Defines triage assessment endpoints.
 * Per module-creation.mdc: Mount endpoints as per P010_api_endpoints.mdc.
 * Per api.mdc: Apply all required middlewares in correct order.
 */

const express = require('express');
const router = express.Router();
const triageAssessmentController = require('@modules/triage-assessment/controllers/triage-assessment.controller');
const { validate } = require('@middlewares/validate.middleware');
const { authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createTriageAssessmentSchema,
  updateTriageAssessmentSchema,
  triageAssessmentIdParamsSchema,
  listTriageAssessmentsQuerySchema
} = require('@modules/triage-assessment/schemas/triage-assessment.schema');

/**
 * @route GET /api/v1/triage-assessments
 * @description List triage assessments with pagination
 * @access Private
 */
router.get(
  '/',
  validate({
    query: listTriageAssessmentsQuerySchema
  }),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  triageAssessmentController.listTriageAssessments
);

/**
 * @route GET /api/v1/triage-assessments/:id
 * @description Get triage assessment by ID
 * @access Private
 */
router.get(
  '/:id',
  validate({
    params: triageAssessmentIdParamsSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  triageAssessmentController.getTriageAssessmentById
);

/**
 * @route POST /api/v1/triage-assessments
 * @description Create new triage assessment
 * @access Private
 */
router.post(
  '/',
  validate({
    body: createTriageAssessmentSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  triageAssessmentController.createTriageAssessment
);

/**
 * @route PUT /api/v1/triage-assessments/:id
 * @description Update triage assessment
 * @access Private
 */
router.put(
  '/:id',
  validate({
    params: triageAssessmentIdParamsSchema,
    body: updateTriageAssessmentSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  triageAssessmentController.updateTriageAssessment
);

/**
 * @route DELETE /api/v1/triage-assessments/:id
 * @description Soft delete triage assessment
 * @access Private
 */
router.delete(
  '/:id',
  validate({
    params: triageAssessmentIdParamsSchema
  }),
  authorize(PERMISSIONS.EMERGENCY_DELETE, 'permission'),
  triageAssessmentController.deleteTriageAssessment
);

module.exports = router;
