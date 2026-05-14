/**
 * System change log controller
 *
 * @module modules/system-change-log/controllers
 * @description Request handlers for system change log endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const systemChangeLogService = require('@services/system-change-log/system-change-log.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List system change logs with pagination
 * GET /api/v1/system-change-logs
 */
const listSystemChangeLogs = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    user_id,
    change_type,
    search,
    from_date,
    to_date,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const filters = {
    tenant_id,
    user_id,
    change_type,
    search,
    from_date,
    to_date
  };

  const result = await systemChangeLogService.listSystemChangeLogs(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user
  );

  sendPaginated(res, 'messages.system_change_log.list.success', result.systemChangeLogs, result.pagination);
});

/**
 * Get system change log by ID
 * GET /api/v1/system-change-logs/:id
 */
const getSystemChangeLogById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const systemChangeLog = await systemChangeLogService.getSystemChangeLogById(id, req.user);

  sendSuccess(res, 200, 'messages.system_change_log.get.success', systemChangeLog);
});

/**
 * Create new system change log
 * POST /api/v1/system-change-logs
 */
const createSystemChangeLog = asyncHandler(async (req, res) => {
  const ipAddress = req.ip;

  const systemChangeLog = await systemChangeLogService.createSystemChangeLog(
    req.body,
    req.user,
    ipAddress
  );

  sendSuccess(res, 201, 'messages.system_change_log.create.success', systemChangeLog);
});

/**
 * Update system change log
 * PUT /api/v1/system-change-logs/:id
 */
const updateSystemChangeLog = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const ipAddress = req.ip;

  const systemChangeLog = await systemChangeLogService.updateSystemChangeLog(
    id,
    req.body,
    req.user,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.system_change_log.update.success', systemChangeLog);
});

/**
 * Approve system change log
 * POST /api/v1/system-change-logs/:id/approve
 */
const approveSystemChangeLog = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { approval_notes } = req.body;
  const ipAddress = req.ip;

  const systemChangeLog = await systemChangeLogService.approveSystemChangeLog(
    id,
    approval_notes,
    req.user,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.system_change_log.approve.success', systemChangeLog);
});

/**
 * Implement system change log
 * POST /api/v1/system-change-logs/:id/implement
 */
const implementSystemChangeLog = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { implementation_notes } = req.body;
  const ipAddress = req.ip;

  const systemChangeLog = await systemChangeLogService.implementSystemChangeLog(
    id,
    implementation_notes,
    req.user,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.system_change_log.implement.success', systemChangeLog);
});

/**
 * Delete system change log (soft delete)
 * DELETE /api/v1/system-change-logs/:id
 */
const deleteSystemChangeLog = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const ipAddress = req.ip;

  await systemChangeLogService.deleteSystemChangeLog(id, req.user, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listSystemChangeLogs,
  getSystemChangeLogById,
  createSystemChangeLog,
  updateSystemChangeLog,
  approveSystemChangeLog,
  implementSystemChangeLog,
  deleteSystemChangeLog
};
