/**
 * API Key repository
 *
 * @module modules/api-key/repositories
 * @description Data access layer for API key operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const createPublicId = (prefix = 'KEY') => {
  const now = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `${prefix}-${now}${random}`.slice(0, 32);
};

const AUTH_INCLUDE = {
  user: {
    include: {
      profile: true,
      permissions: {
        where: { deleted_at: null },
        include: {
          permission: true,
        },
      },
      roles: {
        where: { deleted_at: null },
        include: {
          role: {
            include: {
              permissions: {
                where: { deleted_at: null },
                include: {
                  permission: true,
                },
              },
            },
          },
        },
      },
    },
  },
  permissions: {
    where: { deleted_at: null },
    include: {
      permission: true,
    },
  },
};

const buildAuthWhere = () => ({
  deleted_at: null,
  is_active: true,
  OR: [{ expires_at: null }, { expires_at: { gt: new Date() } }],
});

/**
 * Find API key by ID
 *
 * @param {string} id - API key ID
 * @returns {Promise<Object|null>} API key object or null
 */
const findById = async (id) => {
  try {
    return await prisma.api_key.findFirst({
      where: {
        id,
        deleted_at: null
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many API keys with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @returns {Promise<Array>} Array of API keys
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.api_key.findMany({
      where,
      skip,
      take,
      orderBy
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count API keys with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of API keys
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.api_key.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new API key
 *
 * @param {Object} data - API key data
 * @returns {Promise<Object>} Created API key
 */
const create = async (data) => {
  try {
    return await prisma.api_key.create({
      data
    });
  } catch (error) {
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update API key
 *
 * @param {string} id - API key ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated API key
 */
const update = async (id, data) => {
  try {
    return await prisma.api_key.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.api_key.not_found', 404);
    }
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete API key
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - API key ID
 * @returns {Promise<Object>} Deleted API key
 */
const softDelete = async (id) => {
  try {
    return await prisma.api_key.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.api_key.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find active API key candidates by human-friendly identifier for request authentication.
 *
 * @param {string} humanFriendlyId - Human-friendly API key identifier
 * @returns {Promise<Array>} Matching API key records
 */
const findAuthCandidatesByFriendlyId = async (humanFriendlyId) => {
  try {
    return await prisma.api_key.findMany({
      where: {
        ...buildAuthWhere(),
        human_friendly_id: String(humanFriendlyId || '').trim().toUpperCase(),
      },
      include: AUTH_INCLUDE,
      take: 5,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find active API key candidates for legacy prefix-less keys.
 *
 * @param {number} take - Maximum number of candidates to inspect
 * @returns {Promise<Array>} Candidate API key rows
 */
const findAuthCandidates = async (take = 100) => {
  try {
    return await prisma.api_key.findMany({
      where: buildAuthWhere(),
      include: AUTH_INCLUDE,
      orderBy: [{ last_used_at: 'desc' }, { created_at: 'desc' }],
      take,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update API key last-used metadata.
 *
 * @param {string} id - API key ID
 * @returns {Promise<Object>} Updated API key row
 */
const touchLastUsed = async (id) => {
  try {
    return await prisma.api_key.update({
      where: { id },
      data: {
        last_used_at: new Date(),
        updated_at: new Date(),
      },
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.api_key.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  createPublicId,
  findById,
  findMany,
  count,
  create,
  update,
  softDelete,
  findAuthCandidatesByFriendlyId,
  findAuthCandidates,
  touchLastUsed
};
