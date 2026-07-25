/**
 * Radiology test controller
 *
 * @module modules/radiology-procedure/controllers
 * @description Request handlers for radiology test endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const radiologyProcedureService = require('@services/radiology-procedure/radiology-procedure.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List radiology tests with pagination
 * GET /api/v1/radiology-procedures
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listRadiologyProcedures = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    name,
    code,
    modality,
    equipment,
    body_region,
    procedure_type,
    include_standard_catalog,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    name,
    code,
    modality,
    equipment,
    body_region,
    procedure_type,
    include_standard_catalog,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await radiologyProcedureService.listRadiologyProcedures(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.radiology_procedure.list.success', result.radiologyProcedures, result.pagination);
});

/**
 * Get radiology test by ID
 * GET /api/v1/radiology-procedures/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getRadiologyProcedureById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyProcedure = await radiologyProcedureService.getRadiologyProcedureById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.radiology_procedure.get.success', radiologyProcedure);
});

/**
 * Create new radiology test
 * POST /api/v1/radiology-procedures
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createRadiologyProcedure = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyProcedure = await radiologyProcedureService.createRadiologyProcedure(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.radiology_procedure.create.success', radiologyProcedure);
});

/**
 * Update radiology test
 * PUT /api/v1/radiology-procedures/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateRadiologyProcedure = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const radiologyProcedure = await radiologyProcedureService.updateRadiologyProcedure(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.radiology_procedure.update.success', radiologyProcedure);
});

/**
 * Delete radiology test (soft delete)
 * DELETE /api/v1/radiology-procedures/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteRadiologyProcedure = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await radiologyProcedureService.deleteRadiologyProcedure(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listRadiologyProcedures,
  getRadiologyProcedureById,
  createRadiologyProcedure,
  updateRadiologyProcedure,
  deleteRadiologyProcedure
};
