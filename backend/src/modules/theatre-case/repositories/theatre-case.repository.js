/**
 * Theatre case repository
 *
 * @module modules/theatre-case/repositories
 * @description Data access layer for theatre case operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const BASE_INCLUDE = {
  encounter: {
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      facility_id: true,
      patient_id: true,
      patient: {
        select: {
          id: true,
          human_friendly_id: true,
          first_name: true,
          last_name: true,
        },
      },
    },
  },
};

/**
 * Find theatre case by ID
 *
 * @param {string} id - Theatre case ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Theatre case object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.theatre_case.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include: {
        ...BASE_INCLUDE,
        ...include,
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many theatre cases with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of theatre cases
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.theatre_case.findMany({
      where,
      skip,
      take,
      orderBy,
      include: {
        ...BASE_INCLUDE,
        ...include,
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count theatre cases with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of theatre cases
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.theatre_case.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new theatre case
 *
 * @param {Object} data - Theatre case data
 * @returns {Promise<Object>} Created theatre case
 */
const create = async (data) => {
  try {
    return await prisma.theatre_case.create({
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
 * Update theatre case
 *
 * @param {string} id - Theatre case ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated theatre case
 */
const update = async (id, data) => {
  try {
    return await prisma.theatre_case.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.theatre_case.not_found', 404);
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
 * Soft delete theatre case
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Theatre case ID
 * @returns {Promise<Object>} Deleted theatre case
 */
const softDelete = async (id) => {
  try {
    return await prisma.theatre_case.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.theatre_case.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  BASE_INCLUDE,
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
};
