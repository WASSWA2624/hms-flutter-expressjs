/**
 * User Session repository
 *
 * @module modules/user-session/repositories
 * @description Data access layer for user session operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find session by ID
 *
 * @param {string} id - Session ID
 * @returns {Promise<Object|null>} Session object or null
 */
const findById = async (id) => {
  try {
    return await prisma.user_session.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            status: true
          }
        }
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many sessions with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @returns {Promise<Array>} Array of sessions
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.user_session.findMany({
      where,
      skip,
      take,
      orderBy,
      include: {
        user: {
          select: {
            id: true,
            email: true,
            status: true
          }
        }
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count sessions with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of sessions
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.user_session.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new session
 * Note: This is typically used by auth module, not exposed via user-session endpoints
 *
 * @param {Object} data - Session data
 * @returns {Promise<Object>} Created session
 */
const create = async (data) => {
  try {
    return await prisma.user_session.create({
      data
    });
  } catch (error) {
    if (error.code === 'P2002') {
      throw new HttpError('errors.session.duplicate', 409);
    }
    if (error.code === 'P2003') {
      throw new HttpError('errors.session.invalid_user', 400);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update session
 * Note: This is typically used for internal operations (e.g., updating last_used_at)
 *
 * @param {string} id - Session ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated session
 */
const update = async (id, data) => {
  try {
    return await prisma.user_session.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.session.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete session (revoke)
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Session ID
 * @returns {Promise<Object>} Deleted session
 */
const softDelete = async (id) => {
  try {
    return await prisma.user_session.update({
      where: { id },
      data: {
        deleted_at: new Date(),
        revoked_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.session.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
};
