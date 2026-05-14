/**
 * Patient Identifier repository
 *
 * @module modules/patient-identifier/repositories
 * @description Data access layer for patient identifier operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find patient identifier by ID
 *
 * @param {string} id - Patient Identifier ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Patient Identifier object or null
 */
const findById = async (id, include = {}, dbClient = prisma) => {
  try {
    return await dbClient.patient_identifier.findFirst({
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
 * Find many patient identifiers with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of patient identifiers
 */
const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  include = {},
  dbClient = prisma
) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await dbClient.patient_identifier.findMany({
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
 * Count patient identifiers with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of patient identifiers
 */
const count = async (filters = {}, dbClient = prisma) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await dbClient.patient_identifier.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new patient identifier
 *
 * @param {Object} data - Patient Identifier data
 * @returns {Promise<Object>} Created patient identifier
 */
const create = async (data, dbClient = prisma) => {
  try {
    return await dbClient.patient_identifier.create({
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
 * Update patient identifier
 *
 * @param {string} id - Patient Identifier ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated patient identifier
 */
const update = async (id, data, dbClient = prisma) => {
  try {
    return await dbClient.patient_identifier.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.patient_identifier.not_found', 404);
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
 * Soft delete patient identifier
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Patient Identifier ID
 * @returns {Promise<Object>} Deleted patient identifier
 */
const softDelete = async (id, dbClient = prisma) => {
  try {
    return await dbClient.patient_identifier.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.patient_identifier.not_found', 404);
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
