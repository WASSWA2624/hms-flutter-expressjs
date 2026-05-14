/**
 * Patient Contact repository
 *
 * @module modules/patient-contact/repositories
 * @description Data access layer for patient contact operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find patient contact by ID
 *
 * @param {string} id - Patient Contact ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Patient Contact object or null
 */
const findById = async (id, include = {}, dbClient = prisma) => {
  try {
    return await dbClient.patient_contact.findFirst({
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
 * Find many patient contacts with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of patient contacts
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

    return await dbClient.patient_contact.findMany({
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
 * Count patient contacts with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of patient contacts
 */
const count = async (filters = {}, dbClient = prisma) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await dbClient.patient_contact.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new patient contact
 *
 * @param {Object} data - Patient Contact data
 * @returns {Promise<Object>} Created patient contact
 */
const create = async (data, dbClient = prisma) => {
  try {
    return await dbClient.patient_contact.create({
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
 * Update patient contact
 *
 * @param {string} id - Patient Contact ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated patient contact
 */
const update = async (id, data, dbClient = prisma) => {
  try {
    return await dbClient.patient_contact.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.patient_contact.not_found', 404);
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
 * Soft delete patient contact
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Patient Contact ID
 * @returns {Promise<Object>} Deleted patient contact
 */
const softDelete = async (id, dbClient = prisma) => {
  try {
    return await dbClient.patient_contact.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.patient_contact.not_found', 404);
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
