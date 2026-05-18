/**
 * Admission repository
 *
 * @module modules/admission/repositories
 * @description Data access layer for admission operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { withActivePatient } = require('@lib/patient-query-filters');

/**
 * Find admission by ID
 *
 * @param {string} id - Admission ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Admission object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.admission.findFirst({
      where: withActivePatient({ id }),
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many admissions with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of admissions
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    const where = withActivePatient(filters);

    return await prisma.admission.findMany({
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
 * Count admissions with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of admissions
 */
const count = async (filters = {}) => {
  try {
    const where = withActivePatient(filters);

    return await prisma.admission.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new admission
 *
 * @param {Object} data - Admission data
 * @returns {Promise<Object>} Created admission
 */
const create = async (data) => {
  try {
    return await prisma.admission.create({
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
 * Update admission
 *
 * @param {string} id - Admission ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated admission
 */
const update = async (id, data) => {
  try {
    return await prisma.admission.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.admission.not_found', 404);
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
 * Soft delete admission
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Admission ID
 * @returns {Promise<Object>} Deleted admission
 */
const softDelete = async (id) => {
  try {
    return await prisma.admission.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.admission.not_found', 404);
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
