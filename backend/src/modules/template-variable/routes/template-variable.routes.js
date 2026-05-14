/**
 * Template Variable routes
 *
 * @module modules/template-variable/routes
 * @description Express router for template variable endpoints.
 * Per module-creation.mdc: Mount endpoints as per dev-plan/P010_api_endpoints.mdc.
 * Per api.mdc: All routes under /api/v1/template-variables base path.
 */

const express = require('express');
const router = express.Router();

const templateVariableController = require('@modules/template-variable/controllers/template-variable.controller');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const { validate } = require('@middlewares/validate.middleware');
const {
  createTemplateVariableSchema,
  updateTemplateVariableSchema,
  templateVariableIdParamsSchema,
  listTemplateVariablesQuerySchema
} = require('@modules/template-variable/schemas/template-variable.schema');

/**
 * @route   GET /api/v1/template-variables
 * @desc    List all template variables with pagination
 * @access  Private
 * @returns {200} Paginated list of template variables
 */
router.get(
  '/',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  validate({ query: listTemplateVariablesQuerySchema }),
  templateVariableController.listTemplateVariables
);

/**
 * @route   GET /api/v1/template-variables/:id
 * @desc    Get single template variable by ID
 * @access  Private
 * @returns {200} Template variable object
 * @returns {404} Template variable not found
 */
router.get(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  validate({ params: templateVariableIdParamsSchema }),
  templateVariableController.getTemplateVariable
);

/**
 * @route   POST /api/v1/template-variables
 * @desc    Create new template variable
 * @access  Private
 * @returns {201} Created template variable object
 * @returns {400} Validation error
 * @returns {409} Duplicate template variable
 */
router.post(
  '/',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  validate({ body: createTemplateVariableSchema }),
  templateVariableController.createTemplateVariable
);

/**
 * @route   PUT /api/v1/template-variables/:id
 * @desc    Update existing template variable
 * @access  Private
 * @returns {200} Updated template variable object
 * @returns {400} Validation error
 * @returns {404} Template variable not found
 */
router.put(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  validate({
    params: templateVariableIdParamsSchema,
    body: updateTemplateVariableSchema
  }),
  templateVariableController.updateTemplateVariable
);

/**
 * @route   DELETE /api/v1/template-variables/:id
 * @desc    Soft delete template variable
 * @access  Private
 * @returns {204} No content (successful deletion)
 * @returns {404} Template variable not found
 */
router.delete(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_DELETE, 'permission'),
  validate({ params: templateVariableIdParamsSchema }),
  templateVariableController.deleteTemplateVariable
);

module.exports = router;
