/**
 * Emergency response controller
 *
 * @module modules/emergency-response/controllers
 * @description Request handlers for emergency response endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per module-creation.mdc: Use @lib/response/* for output.
 */

const emergencyResponseService = require('@modules/emergency-response/services/emergency-response.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List emergency responses
 * GET /api/v1/emergency-responses
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const listEmergencyResponses = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
    emergency_case_id,
    search
  } = req.query;

  const filters = {};
  if (emergency_case_id) filters.emergency_case_id = emergency_case_id;
  if (search) filters.search = search;

  const result = await emergencyResponseService.listEmergencyResponses(
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

  sendPaginated(res, 'messages.emergency_response.list.success', result.items, pagination);
});

/**
 * Get emergency response by ID
 * GET /api/v1/emergency-responses/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getEmergencyResponseById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const emergencyResponse = await emergencyResponseService.getEmergencyResponseById(id);

  sendSuccess(res, 200, 'messages.emergency_response.get.success', emergencyResponse);
});

/**
 * Create emergency response
 * POST /api/v1/emergency-responses
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createEmergencyResponse = asyncHandler(async (req, res) => {
  const data = req.body;
  const user = req.user;

  const emergencyResponse = await emergencyResponseService.createEmergencyResponse(data, user);

  sendSuccess(res, 201, 'messages.emergency_response.create.success', emergencyResponse);
});

/**
 * Update emergency response
 * PUT /api/v1/emergency-responses/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updateEmergencyResponse = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const user = req.user;

  const emergencyResponse = await emergencyResponseService.updateEmergencyResponse(id, data, user);

  sendSuccess(res, 200, 'messages.emergency_response.update.success', emergencyResponse);
});

/**
 * Delete emergency response (soft delete)
 * DELETE /api/v1/emergency-responses/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deleteEmergencyResponse = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const user = req.user;

  await emergencyResponseService.deleteEmergencyResponse(id, user);

  sendNoContent(res);
});

module.exports = {
  listEmergencyResponses,
  getEmergencyResponseById,
  createEmergencyResponse,
  updateEmergencyResponse,
  deleteEmergencyResponse
};
