/**
 * PHI access log repository
 *
 * @module modules/phi-access-log/repositories
 * @description Data access layer for PHI access log operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find PHI access log by ID
 *
 * @param {string} id - PHI access log ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} PHI access log object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.phi_access_log.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many PHI access logs with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of PHI access logs
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { accessed_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.phi_access_log.findMany({
      where,
      skip,
      take,
      orderBy,
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count PHI access logs with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of PHI access logs
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.phi_access_log.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new PHI access log
 *
 * @param {Object} data - PHI access log data
 * @returns {Promise<Object>} Created PHI access log
 */
const create = async (data) => {
  try {
    return await prisma.phi_access_log.create({
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
 * Update PHI access log
 *
 * @param {string} id - PHI access log ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated PHI access log
 */
const update = async (id, data) => {
  try {
    return await prisma.phi_access_log.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.phi_access_log.not_found', 404);
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
 * Soft delete PHI access log
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - PHI access log ID
 * @returns {Promise<Object>} Deleted PHI access log
 */
const softDelete = async (id) => {
  try {
    return await prisma.phi_access_log.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.phi_access_log.not_found', 404);
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
