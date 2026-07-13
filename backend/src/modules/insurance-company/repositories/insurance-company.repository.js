/**
 * Insurance Company repository
 *
 * @module modules/insurance-company/repositories
 * @description Data access layer for insurance company operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find insurance company by ID
 *
 * @param {string} id - Insurance Company ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Insurance Company object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.insurance_company.findFirst({
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
 * Find many insurance companies with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of insurance companies
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.insurance_company.findMany({
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
 * Count insurance companies with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of insurance companies
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.insurance_company.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new insurance company
 *
 * @param {Object} data - Insurance Company data
 * @returns {Promise<Object>} Created insurance company
 */
const create = async (data) => {
  try {
    return await prisma.insurance_company.create({
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
 * Update insurance company
 *
 * @param {string} id - Insurance Company ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated insurance company
 */
const update = async (id, data) => {
  try {
    return await prisma.insurance_company.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.insurance_company.not_found', 404);
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
 * Soft delete insurance company
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Insurance Company ID
 * @returns {Promise<Object>} Deleted insurance company
 */
const softDelete = async (id) => {
  try {
    return await prisma.insurance_company.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.insurance_company.not_found', 404);
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
