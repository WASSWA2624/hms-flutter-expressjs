/**
 * Procedure controller
 *
 * @module modules/procedure/controllers
 * @description Request handlers for procedure endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const procedureService = require('@services/procedure/procedure.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List procedures with pagination
 * GET /api/v1/procedures
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listProcedures = asyncHandler(async (req, res) => {
  const {
    encounter_id,
    code,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    code
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await procedureService.listProcedures(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.procedure.list.success', result.procedures, result.pagination);
});

/**
 * Get procedure by ID
 * GET /api/v1/procedures/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getProcedureById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const procedure = await procedureService.getProcedureById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.procedure.get.success', procedure);
});

/**
 * Create new procedure
 * POST /api/v1/procedures
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createProcedure = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const procedure = await procedureService.createProcedure(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.procedure.create.success', procedure);
});

/**
 * Update procedure
 * PUT /api/v1/procedures/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateProcedure = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const procedure = await procedureService.updateProcedure(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.procedure.update.success', procedure);
});

/**
 * Delete procedure (soft delete)
 * DELETE /api/v1/procedures/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteProcedure = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await procedureService.deleteProcedure(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listProcedures,
  getProcedureById,
  createProcedure,
  updateProcedure,
  deleteProcedure
};
