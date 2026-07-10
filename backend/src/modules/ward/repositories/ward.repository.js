/**
 * Ward repository
 *
 * @module modules/ward/repositories
 * @description Data access layer for ward operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const {
  softDeleteWardCascade,
  restoreWard,
} = require('@lib/facility-structure/cascade-soft-delete');

const buildWhereClause = (filters = {}, { includeDeleted = false } = {}) => {
  const where = { ...filters };
  if (!includeDeleted) {
    where.deleted_at = null;
  }
  return where;
};

/**
 * Find ward by ID
 *
 * @param {string} id - Ward ID
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted]
 * @returns {Promise<Object|null>} Ward object or null
 */
const findById = async (id, { includeDeleted = false } = {}) => {
  try {
    return await prisma.ward.findFirst({
      where: {
        id,
        ...(includeDeleted ? {} : { deleted_at: null }),
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many wards with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted]
 * @returns {Promise<Array>} Array of wards
 */
const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  { includeDeleted = false } = {}
) => {
  try {
    return await prisma.ward.findMany({
      where: buildWhereClause(filters, { includeDeleted }),
      skip,
      take,
      orderBy,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count wards with filters
 *
 * @param {Object} filters - Filter criteria
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted]
 * @returns {Promise<number>} Count of wards
 */
const count = async (filters = {}, { includeDeleted = false } = {}) => {
  try {
    return await prisma.ward.count({
      where: buildWhereClause(filters, { includeDeleted }),
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new ward
 *
 * @param {Object} data - Ward data
 * @returns {Promise<Object>} Created ward
 */
const create = async (data) => {
  try {
    return await prisma.ward.create({
      data,
    });
  } catch (error) {
    if (error.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update ward
 *
 * @param {string} id - Ward ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated ward
 */
const update = async (id, data) => {
  try {
    return await prisma.ward.update({
      where: { id },
      data,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.ward.not_found', 404);
    }
    if (error.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete ward and cascade to rooms/beds.
 *
 * @param {string} id - Ward ID
 * @returns {Promise<Object>} Cascade result
 */
const softDelete = async (id) => {
  try {
    return await softDeleteWardCascade(id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2025') {
      throw new HttpError('errors.ward.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Restore a soft-deleted ward (rooms/beds remain deleted).
 *
 * @param {string} id - Ward ID
 * @returns {Promise<Object>} Restored ward
 */
const restore = async (id) => {
  try {
    return await restoreWard(id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2025') {
      throw new HttpError('errors.ward.not_found', 404);
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
  softDelete,
  restore,
};
