/**
 * PHI access log controller
 *
 * @module modules/phi-access-log/controllers
 * @description Controller layer for PHI access log operations.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response/*.
 */

const phiAccessLogService = require('@modules/phi-access-log/services/phi-access-log.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * Get PHI access log by ID
 * GET /api/v1/phi-access-logs/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getPhiAccessLogById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const phiAccessLog = await phiAccessLogService.getPhiAccessLogById(id, req.user);
  
  sendSuccess(res, 200, 'messages.phi_access_log.retrieved', phiAccessLog);
});

/**
 * Get paginated list of PHI access logs
 * GET /api/v1/phi-access-logs
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getPhiAccessLogs = asyncHandler(async (req, res) => {
  const { 
    page, 
    limit, 
    sort_by, 
    order,
    tenant_id,
    user_id,
    patient_id,
    access_scope,
    search,
    date_from,
    date_to
  } = req.query;

  const filters = {
    tenant_id,
    user_id,
    patient_id,
    access_scope,
    search,
    date_from,
    date_to
  };

  const result = await phiAccessLogService.getPhiAccessLogs(
    filters,
    parseInt(page) || 1,
    parseInt(limit) || 20,
    sort_by || 'accessed_at',
    order || 'desc',
    req.user
  );

  sendPaginated(res, 'messages.phi_access_log.list_retrieved', result.data, {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: result.totalPages,
    hasNextPage: result.page < result.totalPages,
    hasPreviousPage: result.page > 1,
  });
});

/**
 * Get PHI access logs by user ID
 * GET /api/v1/phi-access-logs/user/:userId
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getPhiAccessLogsByUserId = asyncHandler(async (req, res) => {
  const { userId } = req.params;
  const { page, limit, sort_by, order } = req.query;

  const result = await phiAccessLogService.getPhiAccessLogsByUserId(
    userId,
    parseInt(page) || 1,
    parseInt(limit) || 20,
    sort_by || 'accessed_at',
    order || 'desc',
    req.user
  );

  sendPaginated(res, 'messages.phi_access_log.user_list_retrieved', result.data, {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: result.totalPages,
    hasNextPage: result.page < result.totalPages,
    hasPreviousPage: result.page > 1,
  });
});

/**
 * Create new PHI access log
 * POST /api/v1/phi-access-logs
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createPhiAccessLog = asyncHandler(async (req, res) => {
  const data = req.body;
  const ipAddress = req.ip || req.connection?.remoteAddress || null;

  const phiAccessLog = await phiAccessLogService.createPhiAccessLog(data, req.user, ipAddress);

  sendSuccess(res, 201, 'messages.phi_access_log.created', phiAccessLog);
});

/**
 * Update PHI access log
 * PUT /api/v1/phi-access-logs/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updatePhiAccessLog = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const ipAddress = req.ip || req.connection?.remoteAddress || null;

  const phiAccessLog = await phiAccessLogService.updatePhiAccessLog(id, data, req.user, ipAddress);

  sendSuccess(res, 200, 'messages.phi_access_log.updated', phiAccessLog);
});

/**
 * Delete PHI access log (soft delete)
 * DELETE /api/v1/phi-access-logs/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deletePhiAccessLog = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const ipAddress = req.ip || req.connection?.remoteAddress || null;

  await phiAccessLogService.deletePhiAccessLog(id, req.user, ipAddress);

  sendNoContent(res);
});

module.exports = {
  getPhiAccessLogById,
  getPhiAccessLogs,
  getPhiAccessLogsByUserId,
  createPhiAccessLog,
  updatePhiAccessLog,
  deletePhiAccessLog
};
