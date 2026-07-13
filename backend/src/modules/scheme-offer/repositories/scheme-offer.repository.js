/**
 * Scheme Offer repository
 *
 * @module modules/scheme-offer/repositories
 * @description Data access layer for scheme offer operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find scheme offer by ID
 *
 * @param {string} id - Scheme Offer ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Scheme Offer object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.scheme_offer.findFirst({
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
 * Find many scheme offers with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of scheme offers
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.scheme_offer.findMany({
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
 * Count scheme offers with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of scheme offers
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.scheme_offer.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new scheme offer
 *
 * @param {Object} data - Scheme Offer data
 * @returns {Promise<Object>} Created scheme offer
 */
const create = async (data) => {
  try {
    return await prisma.scheme_offer.create({
      data
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
 * Update scheme offer
 *
 * @param {string} id - Scheme Offer ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated scheme offer
 */
const update = async (id, data) => {
  try {
    return await prisma.scheme_offer.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.scheme_offer.not_found', 404);
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
 * Soft delete scheme offer
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Scheme Offer ID
 * @returns {Promise<Object>} Deleted scheme offer
 */
const softDelete = async (id) => {
  try {
    return await prisma.scheme_offer.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.scheme_offer.not_found', 404);
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
