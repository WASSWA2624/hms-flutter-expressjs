/**
 * Role service
 *
 * @module modules/role/services
 * @description Business logic layer for role operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const roleRepository = require('@repositories/role/role.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List roles with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Roles and pagination data
 */
const listRoles = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.facility_id) whereClause.facility_id = filters.facility_id;
    if (filters.name) whereClause.name = { contains: filters.name };
    
    // Search filter (searches in name and description)
    if (filters.search) {
      whereClause.OR = [
        { name: { contains: filters.search } },
        { description: { contains: filters.search } }
      ];
    }

    const [roles, total] = await Promise.all([
      roleRepository.findMany(whereClause, skip, limit, orderBy),
      roleRepository.count(whereClause)
    ]);

    return {
      roles,
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
 * Get role by ID
 *
 * @param {string} id - Role ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Role data
 */
const getRoleById = async (id, userId, ipAddress) => {
  try {
    const role = await roleRepository.findById(id);

    if (!role) {
      throw new HttpError('errors.role.not_found', 404);
    }

    return role;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new role
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Role data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created role
 */
const createRole = async (data, userId, ipAddress) => {
  try {
    const role = await roleRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'role',
      entity_id: role.id,
      diff: { after: role },
      ip_address: ipAddress
    }).catch(() => {});

    return role;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update role
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Role ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated role
 */
const updateRole = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await roleRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.role.not_found', 404);
    }

    const role = await roleRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'role',
      entity_id: role.id,
      diff: { before, after: role },
      ip_address: ipAddress
    }).catch(() => {});

    return role;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete role (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Role ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteRole = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await roleRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.role.not_found', 404);
    }

    await roleRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'role',
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
  listRoles,
  getRoleById,
  createRole,
  updateRole,
  deleteRole
};
