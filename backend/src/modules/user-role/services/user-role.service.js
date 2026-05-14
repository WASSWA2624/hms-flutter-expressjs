/**
 * User-Role service
 *
 * @module modules/user-role/services
 * @description Business logic layer for user-role operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const userRoleRepository = require('@repositories/user-role/user-role.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List user-roles with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} User-Roles and pagination data
 */
const listUserRoles = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.user_id) whereClause.user_id = filters.user_id;
    if (filters.role_id) whereClause.role_id = filters.role_id;
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.facility_id) whereClause.facility_id = filters.facility_id;

    const [userRoles, total] = await Promise.all([
      userRoleRepository.findMany(whereClause, skip, limit, orderBy),
      userRoleRepository.count(whereClause)
    ]);

    return {
      userRoles,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1
      }
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get user-role by ID
 *
 * @param {string} id - User-Role ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} User-Role data
 */
const getUserRoleById = async (id, userId, ipAddress) => {
  try {
    const userRole = await userRoleRepository.findById(id);

    if (!userRole) {
      throw new HttpError('errors.user_role.not_found', 404);
    }

    return userRole;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new user-role
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - User-Role data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created user-role
 */
const createUserRole = async (data, userId, ipAddress) => {
  try {
    const userRole = await userRoleRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'user_role',
      entity_id: userRole.id,
      diff: { after: userRole },
      ip_address: ipAddress
    }).catch(() => {});

    return userRole;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update user-role
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User-Role ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated user-role
 */
const updateUserRole = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await userRoleRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.user_role.not_found', 404);
    }

    const userRole = await userRoleRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'user_role',
      entity_id: userRole.id,
      diff: { before, after: userRole },
      ip_address: ipAddress
    }).catch(() => {});

    return userRole;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete user-role (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User-Role ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteUserRole = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await userRoleRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.user_role.not_found', 404);
    }

    await userRoleRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'user_role',
      entity_id: id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listUserRoles,
  getUserRoleById,
  createUserRole,
  updateUserRole,
  deleteUserRole
};
