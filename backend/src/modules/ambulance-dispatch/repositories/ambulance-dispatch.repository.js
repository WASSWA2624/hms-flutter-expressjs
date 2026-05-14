/**
 * Ambulance Dispatch repository
 *
 * @module modules/ambulance-dispatch/repositories
 * @description Data access layer for ambulance dispatch operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DEFAULT_INCLUDE = {
  ambulance: {
    select: {
      id: true,
      human_friendly_id: true,
      identifier: true,
      status: true,
    },
  },
  emergency_case: {
    select: {
      id: true,
      human_friendly_id: true,
      severity: true,
      status: true,
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

const SEARCHABLE_STATUSES = new Set([
  'AVAILABLE',
  'DISPATCHED',
  'EN_ROUTE',
  'ON_SCENE',
  'TRANSPORTING',
  'OUT_OF_SERVICE',
]);

const buildWhere = (filters = {}) => {
  const where = {
    deleted_at: null,
  };

  const {
    search,
    ...rest
  } = filters || {};

  Object.assign(where, rest);

  const normalizedSearch = String(search || '').trim();
  if (!normalizedSearch) return where;

  const searchUpper = normalizedSearch.toUpperCase();
  const searchClauses = [
    { human_friendly_id: { contains: searchUpper } },
    { ambulance: { human_friendly_id: { contains: searchUpper } } },
    { ambulance: { identifier: { contains: normalizedSearch } } },
    { emergency_case: { human_friendly_id: { contains: searchUpper } } },
    { emergency_case: { patient: { human_friendly_id: { contains: searchUpper } } } },
    { emergency_case: { patient: { first_name: { contains: normalizedSearch } } } },
    { emergency_case: { patient: { last_name: { contains: normalizedSearch } } } },
  ];

  if (SEARCHABLE_STATUSES.has(searchUpper)) {
    searchClauses.push({ status: searchUpper });
  }

  where.AND = [
    ...(Array.isArray(where.AND) ? where.AND : []),
    { OR: searchClauses },
  ];

  return where;
};

/**
 * Find ambulance dispatch by ID
 *
 * @param {string} id - Ambulance Dispatch ID
 * @returns {Promise<Object|null>} Ambulance Dispatch object or null
 */
const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.ambulance_dispatch.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many ambulance dispatches with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @returns {Promise<Array>} Array of ambulance dispatches
 */
const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  include = DEFAULT_INCLUDE
) => {
  try {
    const where = buildWhere(filters);

    return await prisma.ambulance_dispatch.findMany({
      where,
      skip,
      take,
      orderBy,
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count ambulance dispatches with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of ambulance dispatches
 */
const count = async (filters = {}) => {
  try {
    const where = buildWhere(filters);

    return await prisma.ambulance_dispatch.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new ambulance dispatch
 *
 * @param {Object} data - Ambulance Dispatch data
 * @returns {Promise<Object>} Created ambulance dispatch
 */
const create = async (data) => {
  try {
    return await prisma.ambulance_dispatch.create({
      data,
      include: DEFAULT_INCLUDE,
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
 * Update ambulance dispatch
 *
 * @param {string} id - Ambulance Dispatch ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated ambulance dispatch
 */
const update = async (id, data) => {
  try {
    return await prisma.ambulance_dispatch.update({
      where: { id },
      data,
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.ambulance_dispatch.not_found', 404);
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
 * Soft delete ambulance dispatch
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Ambulance Dispatch ID
 * @returns {Promise<Object>} Deleted ambulance dispatch
 */
const softDelete = async (id) => {
  try {
    return await prisma.ambulance_dispatch.update({
      where: { id },
      data: {
        deleted_at: new Date()
      },
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.ambulance_dispatch.not_found', 404);
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
