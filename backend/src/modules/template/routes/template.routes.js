/**
 * Template routes
 *
 * @module modules/template/routes
 * @description Express router for template endpoints.
 * Per module-creation.mdc: Mount endpoints as per dev-plan/P010_api_endpoints.mdc.
 * Per api.mdc: All routes under /api/v1/templates base path.
 */

const express = require('express');
const router = express.Router();

const templateController = require('@modules/template/controllers/template.controller');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const { validate } = require('@middlewares/validate.middleware');
const {
  createTemplateSchema,
  updateTemplateSchema,
  templateIdParamsSchema,
  listTemplatesQuerySchema
} = require('@modules/template/schemas/template.schema');

/**
 * @route   GET /api/v1/templates
 * @desc    List all templates with pagination
 * @access  Private
 * @returns {200} Paginated list of templates
 */
router.get(
  '/',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  validate({ query: listTemplatesQuerySchema }),
  templateController.listTemplates
);

/**
 * @route   GET /api/v1/templates/:id
 * @desc    Get single template by ID
 * @access  Private
 * @returns {200} Template object
 * @returns {404} Template not found
 */
router.get(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_READ, 'permission'),
  validate({ params: templateIdParamsSchema }),
  templateController.getTemplate
);

/**
 * @route   POST /api/v1/templates
 * @desc    Create new template
 * @access  Private
 * @returns {201} Created template object
 * @returns {400} Validation error
 * @returns {409} Duplicate template
 */
router.post(
  '/',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  validate({ body: createTemplateSchema }),
  templateController.createTemplate
);

/**
 * @route   PUT /api/v1/templates/:id
 * @desc    Update existing template
 * @access  Private
 * @returns {200} Updated template object
 * @returns {400} Validation error
 * @returns {404} Template not found
 */
router.put(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_WRITE, 'permission'),
  validate({
    params: templateIdParamsSchema,
    body: updateTemplateSchema
  }),
  templateController.updateTemplate
);

/**
 * @route   DELETE /api/v1/templates/:id
 * @desc    Soft delete template
 * @access  Private
 * @returns {204} No content (successful deletion)
 * @returns {404} Template not found
 */
router.delete(
  '/:id',
  authenticate(),
  authorize(PERMISSIONS.COMMUNICATIONS_DELETE, 'permission'),
  validate({ params: templateIdParamsSchema }),
  templateController.deleteTemplate
);

module.exports = router;
