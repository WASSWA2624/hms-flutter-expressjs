/**
 * User Session controller
 *
 * @module modules/user-session/controllers
 * @description Handles HTTP requests for user session endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const sessionService = require('@services/user-session/user-session.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

/**
 * List user sessions with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listSessions = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, user_id, is_active } = req.query;
  const requesterUserId = req.user?.userId || req.user?.id;

  const filters = {};
  if (user_id) filters.user_id = user_id;
  if (is_active) filters.is_active = is_active;
  const context = {
    user_id: requesterUserId,
  };

  const result = await sessionService.listSessions(
    filters,
    page,
    limit,
    sort_by,
    order,
    context
  );

  return sendPaginated(
    res,
    'messages.session.list.success',
    result.sessions,
    result.pagination
  );
});

/**
 * Get session by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getSessionById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const requesterUserId = req.user?.userId || req.user?.id;

  const session = await sessionService.getSessionById(id, {
    user_id: requesterUserId,
  });

  return sendSuccess(res, 200, 'messages.session.get.success', session);
});

/**
 * Revoke session
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const revokeSession = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const requesterUserId = req.user?.userId || req.user?.id;
  
  // Build context for audit log
  const context = {
    user_id: requesterUserId,
    tenant_id: req.user?.tenantId || req.user?.tenant_id,
    facility_id: req.user?.facilityId || req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await sessionService.revokeSession(id, context);

  return sendNoContent(res);
});

module.exports = {
  listSessions,
  getSessionById,
  revokeSession
};
