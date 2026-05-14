/**
 * Module controller
 *
 * @module modules/module/controllers
 * @description Request handlers for module endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per api.mdc: Use standard response helpers.
 */

const moduleService = require('@services/module/module.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { getLocale } = require('@lib/i18n');

/**
 * List all modules
 * GET /api/v1/modules
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listModules = asyncHandler(async (req, res) => {
  const locale = getLocale(req);
  const { page = 1, limit = 20, sort_by = 'created_at', order = 'desc', search } = req.query;

  const filters = {};
  if (search) filters.search = search;

  const result = await moduleService.listModules(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order
  );

  sendPaginated(
    res,
    'messages.module.list.success',
    result.modules,
    result.pagination,
    locale
  );
});

/**
 * Get module by ID
 * GET /api/v1/modules/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getModuleById = asyncHandler(async (req, res) => {
  const locale = getLocale(req);
  const { id } = req.params;

  const module = await moduleService.getModuleById(id);

  sendSuccess(
    res,
    200,
    'messages.module.get.success',
    module,
    locale
  );
});

/**
 * Create new module
 * POST /api/v1/modules
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createModule = asyncHandler(async (req, res) => {
  const locale = getLocale(req);
  const context = {
    user: req.user,
    ip: req.ip,
    tenant_id: req.user?.tenant_id
  };

  const module = await moduleService.createModule(req.body, context);

  sendSuccess(
    res,
    201,
    'messages.module.create.success',
    module,
    locale
  );
});

/**
 * Update module
 * PUT /api/v1/modules/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateModule = asyncHandler(async (req, res) => {
  const locale = getLocale(req);
  const { id } = req.params;
  const context = {
    user: req.user,
    ip: req.ip,
    tenant_id: req.user?.tenant_id
  };

  const module = await moduleService.updateModule(id, req.body, context);

  sendSuccess(
    res,
    200,
    'messages.module.update.success',
    module,
    locale
  );
});

/**
 * Delete module
 * DELETE /api/v1/modules/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteModule = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const context = {
    user: req.user,
    ip: req.ip,
    tenant_id: req.user?.tenant_id
  };

  await moduleService.deleteModule(id, context);

  // Per response-format.mdc: DELETE returns 204 with no body
  res.status(204).send();
});

module.exports = {
  listModules,
  getModuleById,
  createModule,
  updateModule,
  deleteModule
};
