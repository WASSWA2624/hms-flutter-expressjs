/**
 * Emergency case controller
 *
 * @module modules/emergency-case/controllers
 * @description Request handlers for emergency case endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per module-creation.mdc: Use @lib/response/* for output.
 */

const emergencyCaseService = require('@services/emergency-case/emergency-case.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List emergency cases
 * GET /api/v1/emergency-cases
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const listEmergencyCases = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
    tenant_id,
    facility_id,
    patient_id,
    severity,
    status,
    search
  } = req.query;

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (facility_id) filters.facility_id = facility_id;
  if (patient_id) filters.patient_id = patient_id;
  if (severity) filters.severity = severity;
  if (status) filters.status = status;
  if (search) filters.search = search;

  const result = await emergencyCaseService.listEmergencyCases(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order
  );

  const pagination = {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: result.totalPages,
    hasNextPage: result.page < result.totalPages,
    hasPreviousPage: result.page > 1
  };

  sendPaginated(res, 'messages.emergency_case.list.success', result.items, pagination);
});

/**
 * Get emergency case by ID
 * GET /api/v1/emergency-cases/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getEmergencyCaseById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const emergencyCase = await emergencyCaseService.getEmergencyCaseById(id);

  sendSuccess(res, 200, 'messages.emergency_case.get.success', emergencyCase);
});

/**
 * Create emergency case
 * POST /api/v1/emergency-cases
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createEmergencyCase = asyncHandler(async (req, res) => {
  const data = req.body;
  const user = req.user;

  const emergencyCase = await emergencyCaseService.createEmergencyCase(data, user);

  sendSuccess(res, 201, 'messages.emergency_case.create.success', emergencyCase);
});

/**
 * Update emergency case
 * PUT /api/v1/emergency-cases/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updateEmergencyCase = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const user = req.user;

  const emergencyCase = await emergencyCaseService.updateEmergencyCase(id, data, user);

  sendSuccess(res, 200, 'messages.emergency_case.update.success', emergencyCase);
});

/**
 * Delete emergency case (soft delete)
 * DELETE /api/v1/emergency-cases/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deleteEmergencyCase = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const user = req.user;

  await emergencyCaseService.deleteEmergencyCase(id, user);

  sendNoContent(res);
});

module.exports = {
  listEmergencyCases,
  getEmergencyCaseById,
  createEmergencyCase,
  updateEmergencyCase,
  deleteEmergencyCase
};
