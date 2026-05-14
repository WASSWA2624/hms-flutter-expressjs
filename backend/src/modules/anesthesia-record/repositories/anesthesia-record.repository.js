/**
 * Anesthesia record repository
 *
 * @module modules/anesthesia-record/repositories
 * @description Data access layer for anesthesia record operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const BASE_INCLUDE = {
  theatre_case: {
    select: {
      id: true,
      human_friendly_id: true,
      encounter: {
        select: {
          id: true,
          human_friendly_id: true,
          tenant_id: true,
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
    },
  },
  anesthetist: {
    select: {
      id: true,
      human_friendly_id: true,
      profile: {
        select: {
          first_name: true,
          middle_name: true,
          last_name: true,
        },
      },
      staff_profile: {
        select: {
          human_friendly_id: true,
        },
      },
    },
  },
};

/**
 * Find anesthesia record by ID
 *
 * @param {string} id - Anesthesia record ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Anesthesia record object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.anesthesia_record.findFirst({
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
 * Find many anesthesia records with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of anesthesia records
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.anesthesia_record.findMany({
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
 * Count anesthesia records with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of anesthesia records
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.anesthesia_record.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new anesthesia record
 *
 * @param {Object} data - Anesthesia record data
 * @returns {Promise<Object>} Created anesthesia record
 */
const create = async (data) => {
  try {
    return await prisma.anesthesia_record.create({
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
 * Update anesthesia record
 *
 * @param {string} id - Anesthesia record ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated anesthesia record
 */
const update = async (id, data) => {
  try {
    return await prisma.anesthesia_record.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.anesthesia_record.not_found', 404);
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
 * Soft delete anesthesia record
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Anesthesia record ID
 * @returns {Promise<Object>} Deleted anesthesia record
 */
const softDelete = async (id) => {
  try {
    return await prisma.anesthesia_record.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.anesthesia_record.not_found', 404);
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
