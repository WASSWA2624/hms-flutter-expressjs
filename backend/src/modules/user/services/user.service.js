/**
 * User service
 *
 * @module modules/user/services
 * @description Business logic layer for user operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const userRepository = require('@repositories/user/user.repository');
const { createAuditLog } = require('@lib/audit');
const { hashPassword } = require('@lib/crypto');
const { HttpError } = require('@lib/errors');

const BCRYPT_PREFIX_REGEX = /^\$2[aby]\$\d{2}\$/;
const USER_LIST_INCLUDE = Object.freeze({
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      slug: true,
    },
  },
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  profile: {
    select: {
      first_name: true,
      middle_name: true,
      last_name: true,
    },
  },
});

const USER_DETAIL_INCLUDE = Object.freeze({
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      slug: true,
    },
  },
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  permissions: {
    where: { deleted_at: null },
    include: {
      permission: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          description: true,
        },
      },
    },
  },
});

const normalizeUserPayload = async (data, isUpdate = false) => {
  const next = { ...(data || {}) };
  const normalizedPositionTitle = typeof next.position_title === 'string' ? next.position_title.trim() : '';
  const rawPassword = typeof next.password === 'string' ? next.password.trim() : '';
  const providedHash = typeof next.password_hash === 'string' ? next.password_hash.trim() : '';
  const permissionIds = Array.isArray(next.permission_ids)
    ? [...new Set(next.permission_ids.map((entry) => String(entry ?? '').trim()).filter(Boolean))]
    : undefined;

  if (!isUpdate) {
    if (!normalizedPositionTitle) {
      throw new HttpError('errors.validation.field.required', 400, [{ field: 'position_title' }]);
    }
    next.position_title = normalizedPositionTitle;
  } else if (next.position_title !== undefined) {
    next.position_title = normalizedPositionTitle;
  }

  if (rawPassword) {
    next.password_hash = await hashPassword(rawPassword);
  } else if (providedHash) {
    next.password_hash = BCRYPT_PREFIX_REGEX.test(providedHash)
      ? providedHash
      : await hashPassword(providedHash);
  } else if (!isUpdate) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'password' }]);
  }

  if (permissionIds !== undefined) {
    next.permission_ids = permissionIds;
  }

  delete next.password;
  return next;
};

/**
 * List users with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Users and pagination data
 */
const listUsers = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.facility_id) whereClause.facility_id = filters.facility_id;
    if (filters.position_title) whereClause.position_title = { contains: filters.position_title };
    if (filters.status) whereClause.status = filters.status;
    if (filters.email) whereClause.email = { contains: filters.email };
    
    // Search filter supports provider lookup by public ID, name, email, phone, and role/title.
    if (filters.search) {
      const searchTerm = String(filters.search).trim();
      const upperSearchTerm = searchTerm.toUpperCase();
      whereClause.OR = [
        { human_friendly_id: { contains: upperSearchTerm } },
        { email: { contains: searchTerm } },
        { phone: { contains: searchTerm } },
        { position_title: { contains: searchTerm } },
        {
          profile: {
            is: {
              OR: [
                { first_name: { contains: searchTerm } },
                { middle_name: { contains: searchTerm } },
                { last_name: { contains: searchTerm } },
              ],
            },
          },
        },
      ];
    }

    const [users, total] = await Promise.all([
      userRepository.findMany(whereClause, skip, limit, orderBy, USER_LIST_INCLUDE),
      userRepository.count(whereClause)
    ]);

    return {
      users,
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
 * Get user by ID
 *
 * @param {string} id - User ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} User data
 */
const getUserById = async (id, userId, ipAddress) => {
  try {
    const user = await userRepository.findById(id, USER_DETAIL_INCLUDE);

    if (!user) {
      throw new HttpError('errors.user.not_found', 404);
    }

    return user;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new user
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - User data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created user
 */
const createUser = async (data, userId, ipAddress) => {
  try {
    const normalizedPayload = await normalizeUserPayload(data, false);
    const user = await userRepository.create(normalizedPayload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'user',
      entity_id: user.id,
      diff: { after: user },
      ip_address: ipAddress
    }).catch(() => {});

    return user;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update user
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated user
 */
const updateUser = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await userRepository.findById(id, USER_DETAIL_INCLUDE);

    if (!before) {
      throw new HttpError('errors.user.not_found', 404);
    }

    const normalizedPayload = await normalizeUserPayload(data, true);
    const user = await userRepository.update(id, normalizedPayload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'user',
      entity_id: user.id,
      diff: { before, after: user },
      ip_address: ipAddress
    }).catch(() => {});

    return user;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete user (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteUser = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await userRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.user.not_found', 404);
    }

    await userRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'user',
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
  listUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser
};
