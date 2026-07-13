/**
 * Patient Insurance Enrollment repository
 *
 * @module modules/patient-insurance-enrollment/repositories
 * @description Data access layer for patient insurance enrollment operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find patient insurance enrollment by ID
 *
 * @param {string} id - Patient Insurance Enrollment ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Enrollment object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.patient_insurance_enrollment.findFirst({
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
 * Find many patient insurance enrollments with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of enrollments
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.patient_insurance_enrollment.findMany({
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
 * Count patient insurance enrollments with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of enrollments
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.patient_insurance_enrollment.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new patient insurance enrollment
 *
 * @param {Object} data - Enrollment data
 * @returns {Promise<Object>} Created enrollment
 */
const create = async (data) => {
  try {
    return await prisma.patient_insurance_enrollment.create({
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
 * Update patient insurance enrollment
 *
 * @param {string} id - Enrollment ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated enrollment
 */
const update = async (id, data) => {
  try {
    return await prisma.patient_insurance_enrollment.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.patient_insurance_enrollment.not_found', 404);
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
 * Soft delete patient insurance enrollment
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Enrollment ID
 * @returns {Promise<Object>} Deleted enrollment
 */
const softDelete = async (id) => {
  try {
    return await prisma.patient_insurance_enrollment.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.patient_insurance_enrollment.not_found', 404);
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
