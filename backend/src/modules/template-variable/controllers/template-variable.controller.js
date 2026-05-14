/**
 * Template Variable controller
 *
 * @module modules/template-variable/controllers
 * @description Request handlers for template variable endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per module-creation.mdc: Use @lib/response/* for output.
 */

const templateVariableService = require('@modules/template-variable/services/template-variable.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List template variables with pagination
 * GET /api/v1/template-variables
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const listTemplateVariables = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, ...filters } = req.query;
  
  const { templateVariables, total } = await templateVariableService.listTemplateVariables(
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

  sendPaginated(res, 'messages.template_variable.list.success', templateVariables, pagination);
});

/**
 * Get template variable by ID
 * GET /api/v1/template-variables/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getTemplateVariable = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  const templateVariable = await templateVariableService.getTemplateVariableById(id);

  sendSuccess(res, 200, 'messages.template_variable.get.success', templateVariable);
});

/**
 * Create new template variable
 * POST /api/v1/template-variables
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createTemplateVariable = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const tenantId = req.body.tenant_id || req.user?.tenant_id;
  
  const templateVariable = await templateVariableService.createTemplateVariable(
    req.body,
    userId,
    tenantId
  );

  sendSuccess(res, 201, 'messages.template_variable.create.success', templateVariable);
});

/**
 * Update template variable
 * PUT /api/v1/template-variables/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updateTemplateVariable = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const tenantId = req.user?.tenant_id;
  
  const templateVariable = await templateVariableService.updateTemplateVariable(
    id,
    req.body,
    userId,
    tenantId
  );

  sendSuccess(res, 200, 'messages.template_variable.update.success', templateVariable);
});

/**
 * Delete template variable (soft delete)
 * DELETE /api/v1/template-variables/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deleteTemplateVariable = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const tenantId = req.user?.tenant_id;
  
  await templateVariableService.deleteTemplateVariable(id, userId, tenantId);

  res.status(204).send();
});

module.exports = {
  listTemplateVariables,
  getTemplateVariable,
  createTemplateVariable,
  updateTemplateVariable,
  deleteTemplateVariable
};
