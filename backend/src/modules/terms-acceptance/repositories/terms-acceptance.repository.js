/**
 * Terms acceptance repository
 *
 * @module modules/terms-acceptance/repositories
 * @description Data access layer for terms acceptance operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 * Note: Terms acceptance has no update operation per API spec
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find terms acceptance by ID
 *
 * @param {string} id - Terms acceptance ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Terms acceptance object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.terms_acceptance.findFirst({
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
 * Find many terms acceptances with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of terms acceptances
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.terms_acceptance.findMany({
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
 * Count terms acceptances with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of terms acceptances
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.terms_acceptance.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new terms acceptance
 *
 * @param {Object} data - Terms acceptance data
 * @returns {Promise<Object>} Created terms acceptance
 */
const create = async (data) => {
  try {
    return await prisma.terms_acceptance.create({
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
 * Soft delete terms acceptance
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Terms acceptance ID
 * @returns {Promise<Object>} Deleted terms acceptance
 */
const softDelete = async (id) => {
  try {
    return await prisma.terms_acceptance.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.terms_acceptance.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create,
  softDelete
};
