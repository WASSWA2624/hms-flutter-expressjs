/**
 * User profile service
 *
 * @module modules/user-profile/services
 * @description Business logic layer for user profile operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const userProfileRepository = require('@repositories/user-profile/user-profile.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List user profiles with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} User profiles and pagination data
 */
const listUserProfiles = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.user_id) whereClause.user_id = filters.user_id;
    if (filters.facility_id) whereClause.facility_id = filters.facility_id;
    if (filters.gender) whereClause.gender = filters.gender;
    
    // Search filter (searches in first_name, last_name)
    if (filters.search) {
      whereClause.OR = [
        { first_name: { contains: filters.search } },
        { last_name: { contains: filters.search } }
      ];
    }

    const [userProfiles, total] = await Promise.all([
      userProfileRepository.findMany(whereClause, skip, limit, orderBy),
      userProfileRepository.count(whereClause)
    ]);

    return {
      userProfiles,
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
 * Get user profile by ID
 *
 * @param {string} id - User profile ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} User profile data
 */
const getUserProfileById = async (id, userId, ipAddress) => {
  try {
    const userProfile = await userProfileRepository.findById(id);

    if (!userProfile) {
      throw new HttpError('errors.user_profile.not_found', 404);
    }

    return userProfile;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new user profile
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - User profile data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created user profile
 */
const createUserProfile = async (data, userId, ipAddress) => {
  try {
    const userProfile = await userProfileRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'user_profile',
      entity_id: userProfile.id,
      diff: { after: userProfile },
      ip_address: ipAddress
    }).catch(() => {});

    return userProfile;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update user profile
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User profile ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated user profile
 */
const updateUserProfile = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await userProfileRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.user_profile.not_found', 404);
    }

    const userProfile = await userProfileRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'user_profile',
      entity_id: userProfile.id,
      diff: { before, after: userProfile },
      ip_address: ipAddress
    }).catch(() => {});

    return userProfile;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete user profile (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User profile ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteUserProfile = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await userProfileRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.user_profile.not_found', 404);
    }

    await userProfileRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'user_profile',
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
  listUserProfiles,
  getUserProfileById,
  createUserProfile,
  updateUserProfile,
  deleteUserProfile
};
