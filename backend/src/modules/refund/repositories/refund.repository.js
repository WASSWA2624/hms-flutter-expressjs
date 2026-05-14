/**
 * Refund repository
 *
 * @module modules/refund/repositories
 * @description Data access layer for refund operations.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find refund by ID
 *
 * @param {string} id - Refund ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>}
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.refund.findFirst({
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
 * Find many refunds with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Records to skip
 * @param {number} take - Records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>}
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { refunded_at: 'desc' }, include = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.refund.findMany({
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
 * Count refunds by filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>}
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };
    return await prisma.refund.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create refund
 *
 * @param {Object} data - Refund data
 * @returns {Promise<Object>}
 */
const create = async (data) => {
  try {
    return await prisma.refund.create({ data });
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
 * Update refund
 *
 * @param {string} id - Refund ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>}
 */
const update = async (id, data) => {
  try {
    return await prisma.refund.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.refund.not_found', 404);
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
 * Soft delete refund
 *
 * @param {string} id - Refund ID
 * @returns {Promise<Object>}
 */
const softDelete = async (id) => {
  try {
    return await prisma.refund.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.refund.not_found', 404);
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

