/**
 * Ambulance repository
 *
 * @module modules/ambulance/repositories
 * @description Data access layer for ambulance operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DEFAULT_INCLUDE = {
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
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
    { identifier: { contains: normalizedSearch } },
    { tenant: { human_friendly_id: { contains: searchUpper } } },
    { tenant: { name: { contains: normalizedSearch } } },
    { facility: { human_friendly_id: { contains: searchUpper } } },
    { facility: { name: { contains: normalizedSearch } } },
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
 * Find ambulance by ID
 *
 * @param {string} id - Ambulance ID
 * @returns {Promise<Object|null>} Ambulance object or null
 */
const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.ambulance.findFirst({
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
 * Find many ambulances with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @returns {Promise<Array>} Array of ambulances
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

    return await prisma.ambulance.findMany({
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
 * Count ambulances with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of ambulances
 */
const count = async (filters = {}) => {
  try {
    const where = buildWhere(filters);

    return await prisma.ambulance.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new ambulance
 *
 * @param {Object} data - Ambulance data
 * @returns {Promise<Object>} Created ambulance
 */
const create = async (data) => {
  try {
    return await prisma.ambulance.create({
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
 * Update ambulance
 *
 * @param {string} id - Ambulance ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated ambulance
 */
const update = async (id, data) => {
  try {
    return await prisma.ambulance.update({
      where: { id },
      data,
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.ambulance.not_found', 404);
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
 * Soft delete ambulance
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Ambulance ID
 * @returns {Promise<Object>} Deleted ambulance
 */
const softDelete = async (id) => {
  try {
    return await prisma.ambulance.update({
      where: { id },
      data: {
        deleted_at: new Date()
      },
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.ambulance.not_found', 404);
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
