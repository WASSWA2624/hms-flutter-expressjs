/**
 * Role-Permission service
 *
 * @module modules/role-permission/services
 * @description Business logic layer for role-permission operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const rolePermissionRepository = require('@repositories/role-permission/role-permission.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List role-permissions with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Role-Permissions and pagination data
 */
const listRolePermissions = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.role_id) whereClause.role_id = filters.role_id;
    if (filters.permission_id) whereClause.permission_id = filters.permission_id;

    const [rolePermissions, total] = await Promise.all([
      rolePermissionRepository.findMany(whereClause, skip, limit, orderBy),
      rolePermissionRepository.count(whereClause)
    ]);

    return {
      rolePermissions,
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
 * Get role-permission by ID
 *
 * @param {string} id - Role-Permission ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Role-Permission data
 */
const getRolePermissionById = async (id, userId, ipAddress) => {
  try {
    const rolePermission = await rolePermissionRepository.findById(id);

    if (!rolePermission) {
      throw new HttpError('errors.role_permission.not_found', 404);
    }

    return rolePermission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new role-permission
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Role-Permission data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created role-permission
 */
const createRolePermission = async (data, userId, ipAddress) => {
  try {
    const rolePermission = await rolePermissionRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'role_permission',
      entity_id: rolePermission.id,
      diff: { after: rolePermission },
      ip_address: ipAddress
    }).catch(() => {});

    return rolePermission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update role-permission
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Role-Permission ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated role-permission
 */
const updateRolePermission = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await rolePermissionRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.role_permission.not_found', 404);
    }

    const rolePermission = await rolePermissionRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'role_permission',
      entity_id: rolePermission.id,
      diff: { before, after: rolePermission },
      ip_address: ipAddress
    }).catch(() => {});

    return rolePermission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete role-permission (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Role-Permission ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteRolePermission = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await rolePermissionRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.role_permission.not_found', 404);
    }

    await rolePermissionRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'role_permission',
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
  listRolePermissions,
  getRolePermissionById,
  createRolePermission,
  updateRolePermission,
  deleteRolePermission
};
