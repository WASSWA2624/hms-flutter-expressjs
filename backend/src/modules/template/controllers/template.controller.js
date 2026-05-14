/**
 * Template controller
 *
 * @module modules/template/controllers
 * @description Request handlers for template endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per module-creation.mdc: Use @lib/response/* for output.
 */

const templateService = require('@modules/template/services/template.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List templates with pagination
 * GET /api/v1/templates
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const listTemplates = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, ...filters } = req.query;
  
  const { templates, total } = await templateService.listTemplates(
    filters,
    parseInt(page),
    parseInt(limit)
  );

  const totalPages = Math.ceil(total / limit);
  const pagination = {
    page: parseInt(page),
    limit: parseInt(limit),
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1
  };

  sendPaginated(res, 'messages.template.list.success', templates, pagination);
});

/**
 * Get template by ID
 * GET /api/v1/templates/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getTemplate = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  const template = await templateService.getTemplateById(id);

  sendSuccess(res, 200, 'messages.template.get.success', template);
});

/**
 * Create new template
 * POST /api/v1/templates
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createTemplate = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  
  const template = await templateService.createTemplate(req.body, userId);

  sendSuccess(res, 201, 'messages.template.create.success', template);
});

/**
 * Update template
 * PUT /api/v1/templates/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updateTemplate = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  
  const template = await templateService.updateTemplate(id, req.body, userId);

  sendSuccess(res, 200, 'messages.template.update.success', template);
});

/**
 * Delete template (soft delete)
 * DELETE /api/v1/templates/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deleteTemplate = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  
  await templateService.deleteTemplate(id, userId);

  res.status(204).send();
});

module.exports = {
  listTemplates,
  getTemplate,
  createTemplate,
  updateTemplate,
  deleteTemplate
};
