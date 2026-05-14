/**
 * Audit log controller
 *
 * @module modules/audit-log/controllers
 * @description Controller layer for audit log operations.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response/*.
 */

const auditLogService = require('@modules/audit-log/services/audit-log.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');

/**
 * Get audit log by ID
 * GET /api/v1/audit-logs/:id
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getAuditLogById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const auditLog = await auditLogService.getAuditLogById(id, req.user);
  
  sendSuccess(res, 200, 'messages.audit_log.retrieved', auditLog);
});

/**
 * Get paginated list of audit logs
 * GET /api/v1/audit-logs
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getAuditLogs = asyncHandler(async (req, res) => {
  const { 
    page, 
    limit, 
    sort_by, 
    order,
    tenant_id,
    user_id,
    action,
    entity,
    entity_id,
    ip_address,
    search,
    date_from,
    date_to
  } = req.query;

  const filters = {
    tenant_id,
    user_id,
    action,
    entity,
    entity_id,
    ip_address,
    search,
    date_from,
    date_to
  };

  const result = await auditLogService.getAuditLogs(
    filters,
    parseInt(page) || 1,
    parseInt(limit) || 20,
    sort_by || 'created_at',
    order || 'desc',
    req.user
  );

  sendPaginated(res, 'messages.audit_log.list_retrieved', result.data, {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: result.totalPages,
    hasNextPage: result.page < result.totalPages,
    hasPreviousPage: result.page > 1,
  });
});

/**
 * Get audit logs by user ID
 * GET /api/v1/audit-logs/user/:userId
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getAuditLogsByUserId = asyncHandler(async (req, res) => {
  const { userId } = req.params;
  const { page, limit, sort_by, order } = req.query;

  const result = await auditLogService.getAuditLogsByUserId(
    userId,
    parseInt(page) || 1,
    parseInt(limit) || 20,
    sort_by || 'created_at',
    order || 'desc',
    req.user
  );

  sendPaginated(res, 'messages.audit_log.user_list_retrieved', result.data, {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: result.totalPages,
    hasNextPage: result.page < result.totalPages,
    hasPreviousPage: result.page > 1,
  });
});

/**
 * Get audit logs by entity
 * GET /api/v1/audit-logs/entity/:entity/:entityId
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getAuditLogsByEntity = asyncHandler(async (req, res) => {
  const { entity, entityId } = req.params;
  const { page, limit, sort_by, order } = req.query;

  const result = await auditLogService.getAuditLogsByEntity(
    entity,
    entityId,
    parseInt(page) || 1,
    parseInt(limit) || 20,
    sort_by || 'created_at',
    order || 'desc',
    req.user
  );

  sendPaginated(res, 'messages.audit_log.entity_list_retrieved', result.data, {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: result.totalPages,
    hasNextPage: result.page < result.totalPages,
    hasPreviousPage: result.page > 1,
  });
});

module.exports = {
  getAuditLogById,
  getAuditLogs,
  getAuditLogsByUserId,
  getAuditLogsByEntity
};
