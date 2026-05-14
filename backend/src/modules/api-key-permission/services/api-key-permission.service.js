/**
 * API Key Permission service
 *
 * @module modules/api-key-permission/services
 * @description Business logic layer for API key permission operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const apiKeyPermissionRepository = require('@repositories/api-key-permission/api-key-permission.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List API key permissions with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} API key permissions and pagination data
 */
const listApiKeyPermissions = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.api_key_id) whereClause.api_key_id = filters.api_key_id;
    if (filters.permission_id) whereClause.permission_id = filters.permission_id;

    const [apiKeyPermissions, total] = await Promise.all([
      apiKeyPermissionRepository.findMany(whereClause, skip, limit, orderBy),
      apiKeyPermissionRepository.count(whereClause)
    ]);

    return {
      api_key_permissions: apiKeyPermissions,
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
 * Get API key permission by ID
 *
 * @param {string} id - API key permission ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} API key permission data
 */
const getApiKeyPermissionById = async (id, userId, ipAddress) => {
  try {
    const apiKeyPermission = await apiKeyPermissionRepository.findById(id);

    if (!apiKeyPermission) {
      throw new HttpError('errors.api_key_permission.not_found', 404);
    }

    return apiKeyPermission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new API key permission
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - API key permission data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created API key permission
 */
const createApiKeyPermission = async (data, userId, ipAddress) => {
  try {
    const apiKeyPermission = await apiKeyPermissionRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'api_key_permission',
      entity_id: apiKeyPermission.id,
      diff: { after: apiKeyPermission },
      ip_address: ipAddress
    }).catch(() => {});

    return apiKeyPermission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update API key permission
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - API key permission ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated API key permission
 */
const updateApiKeyPermission = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await apiKeyPermissionRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.api_key_permission.not_found', 404);
    }

    const apiKeyPermission = await apiKeyPermissionRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'api_key_permission',
      entity_id: apiKeyPermission.id,
      diff: { before, after: apiKeyPermission },
      ip_address: ipAddress
    }).catch(() => {});

    return apiKeyPermission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete API key permission (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - API key permission ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteApiKeyPermission = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await apiKeyPermissionRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.api_key_permission.not_found', 404);
    }

    await apiKeyPermissionRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'api_key_permission',
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
  listApiKeyPermissions,
  getApiKeyPermissionById,
  createApiKeyPermission,
  updateApiKeyPermission,
  deleteApiKeyPermission
};
