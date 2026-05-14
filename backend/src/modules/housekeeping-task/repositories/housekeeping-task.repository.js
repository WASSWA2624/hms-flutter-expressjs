/**
 * Housekeeping task repository
 *
 * @module modules/housekeeping-task/repositories
 * @description Data access layer for housekeeping task operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find housekeeping task by ID
 *
 * @param {string} id - Housekeeping task ID
 * @returns {Promise<Object|null>} Housekeeping task object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.housekeeping_task.findFirst({
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
 * Find many housekeeping tasks with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @returns {Promise<Array>} Array of housekeeping tasks
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.housekeeping_task.findMany({
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
 * Count housekeeping tasks with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of housekeeping tasks
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.housekeeping_task.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new housekeeping task
 *
 * @param {Object} data - Housekeeping task data
 * @returns {Promise<Object>} Created housekeeping task
 */
const create = async (data, include = {}) => {
  try {
    return await prisma.housekeeping_task.create({
      data,
      include
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
 * Update housekeeping task
 *
 * @param {string} id - Housekeeping task ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated housekeeping task
 */
const update = async (id, data, include = {}) => {
  try {
    return await prisma.housekeeping_task.update({
      where: { id },
      data,
      include
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.housekeeping_task.not_found', 404);
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
 * Soft delete housekeeping task
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Housekeeping task ID
 * @returns {Promise<Object>} Deleted housekeeping task
 */
const softDelete = async (id) => {
  try {
    return await prisma.housekeeping_task.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.housekeeping_task.not_found', 404);
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
