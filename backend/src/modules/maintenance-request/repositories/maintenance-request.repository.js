/**
 * Maintenance request repository
 *
 * @module modules/maintenance-request/repositories
 * @description Data access layer for maintenance request operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DEFAULT_INCLUDE = {
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  asset: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      asset_tag: true,
      tenant_id: true,
    },
  },
};

const buildWhere = (filters = {}) => {
  const {
    search,
    ...rest
  } = filters || {};

  const where = {
    deleted_at: null,
    ...rest,
  };

  const normalizedSearch = String(search || '').trim();
  if (!normalizedSearch) return where;

  const searchUpper = normalizedSearch.toUpperCase();
  where.AND = [
    ...(Array.isArray(where.AND) ? where.AND : []),
    {
      OR: [
        { human_friendly_id: { contains: searchUpper } },
        { description: { contains: normalizedSearch } },
        { facility: { name: { contains: normalizedSearch } } },
        { asset: { name: { contains: normalizedSearch } } },
        { asset: { asset_tag: { contains: normalizedSearch } } },
      ],
    },
  ];

  return where;
};

/**
 * Find maintenance request by ID
 *
 * @param {string} id - Maintenance request ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Maintenance request object or null
 */
const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.maintenance_request.findFirst({
      where: buildWhere({ id }),
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many maintenance requests with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of maintenance requests
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = DEFAULT_INCLUDE) => {
  try {
    const where = buildWhere(filters);

    return await prisma.maintenance_request.findMany({
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
 * Count maintenance requests with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of maintenance requests
 */
const count = async (filters = {}) => {
  try {
    const where = buildWhere(filters);

    return await prisma.maintenance_request.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new maintenance request
 *
 * @param {Object} data - Maintenance request data
 * @returns {Promise<Object>} Created maintenance request
 */
const create = async (data) => {
  try {
    return await prisma.maintenance_request.create({
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
 * Update maintenance request
 *
 * @param {string} id - Maintenance request ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated maintenance request
 */
const update = async (id, data) => {
  try {
    return await prisma.maintenance_request.update({
      where: { id },
      data,
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.maintenance_request.not_found', 404);
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
 * Soft delete maintenance request
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Maintenance request ID
 * @returns {Promise<Object>} Deleted maintenance request
 */
const softDelete = async (id) => {
  try {
    return await prisma.maintenance_request.update({
      where: { id },
      data: {
        deleted_at: new Date()
      },
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.maintenance_request.not_found', 404);
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
