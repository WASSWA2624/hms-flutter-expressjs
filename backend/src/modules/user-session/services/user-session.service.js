/**
 * User Session service
 *
 * @module modules/user-session/services
 * @description Business logic for user session operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const sessionRepository = require('@repositories/user-session/user-session.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const resolveRequesterUserId = (context = {}) => context.user_id || context.userId || null;

/**
 * List user sessions with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {string} [filters.user_id] - Filter by user ID
 * @param {boolean} [filters.is_active] - Filter by active status
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @param {Object} [context] - Request context
 * @param {string} [context.user_id] - Requesting user ID
 * @returns {Promise<Object>} Paginated sessions
 */
const listSessions = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc', context = {}) => {
  const requesterUserId = resolveRequesterUserId(context);
  if (!requesterUserId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  // Build repository filters
  const repoFilters = {};

  // Session endpoints are scoped to the authenticated user.
  if (filters.user_id && filters.user_id !== requesterUserId) {
    throw new HttpError('errors.auth.forbidden', 403);
  }
  repoFilters.user_id = requesterUserId;

  // Handle is_active filter
  if (filters.is_active !== undefined) {
    const isActive = filters.is_active === true || filters.is_active === 'true';
    if (isActive) {
      // Active sessions: not revoked and not expired
      repoFilters.revoked_at = null;
      repoFilters.expires_at = {
        gt: new Date()
      };
    } else {
      // Inactive sessions: either revoked or expired
      repoFilters.OR = [
        { revoked_at: { not: null } },
        { expires_at: { lte: new Date() } }
      ];
    }
  }

  // Calculate pagination
  const skip = (page - 1) * limit;

  // Build sort order
  const orderBy = {};
  orderBy[sort_by] = order;

  // Fetch sessions and count
  const [sessions, total] = await Promise.all([
    sessionRepository.findMany(repoFilters, skip, limit, orderBy),
    sessionRepository.count(repoFilters)
  ]);

  // Calculate pagination metadata
  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    sessions,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage
    }
  };
};

/**
 * Get session by ID
 *
 * @param {string} id - Session ID
 * @returns {Promise<Object>} Session data
 */
const getSessionById = async (id, context = {}) => {
  const requesterUserId = resolveRequesterUserId(context);
  if (!requesterUserId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const session = await sessionRepository.findById(id);
  
  if (!session) {
    throw new HttpError('errors.session.not_found', 404);
  }

  if (session.user_id !== requesterUserId) {
    throw new HttpError('errors.session.not_found', 404);
  }

  // Add computed field for is_active
  session.is_active = !session.revoked_at && new Date(session.expires_at) > new Date();

  return session;
};

/**
 * Revoke session (soft delete)
 *
 * @param {string} id - Session ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const revokeSession = async (id, context = {}) => {
  const requesterUserId = resolveRequesterUserId(context);
  if (!requesterUserId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  // Check if session exists
  const session = await sessionRepository.findById(id);
  
  if (!session) {
    throw new HttpError('errors.session.not_found', 404);
  }

  if (session.user_id !== requesterUserId) {
    throw new HttpError('errors.session.not_found', 404);
  }

  // Check if already revoked
  if (session.revoked_at) {
    throw new HttpError('errors.session.already_revoked', 400);
  }

  // Revoke session (soft delete)
  await sessionRepository.softDelete(id);

  // Create audit log
  await createAuditLog({
    action: 'SESSION_REVOKED',
    entity: 'user_session',
    entity_id: id,
    user_id: requesterUserId,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      revoked_session_user_id: session.user_id,
      revoked_by_self: requesterUserId === session.user_id
    }
  });
};

module.exports = {
  listSessions,
  getSessionById,
  revokeSession
};
