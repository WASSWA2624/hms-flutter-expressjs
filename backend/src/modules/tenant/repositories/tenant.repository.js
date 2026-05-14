/**
 * Tenant repository
 *
 * @module modules/tenant/repositories
 * @description Data access layer for tenant operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const TENANT_ADMIN_RELATION_INCLUDE = Object.freeze({
  user_roles: {
    where: {
      deleted_at: null,
      role: {
        deleted_at: null,
        name: 'TENANT_ADMIN',
      },
      user: {
        deleted_at: null,
      },
    },
    orderBy: [
      { created_at: 'asc' },
      { id: 'asc' },
    ],
    take: 1,
    include: {
      role: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      },
      user: {
        select: {
          id: true,
          human_friendly_id: true,
          email: true,
          phone: true,
          status: true,
          facility_id: true,
          profile: {
            select: {
              first_name: true,
              middle_name: true,
              last_name: true,
            },
          },
          facility: {
            select: {
              id: true,
              human_friendly_id: true,
              name: true,
            },
          },
        },
      },
    },
  },
});

/**
 * Find tenant by ID
 *
 * @param {string} id - Tenant ID
 * @returns {Promise<Object|null>} Tenant object or null
 */
const findById = async (id) => {
  try {
    return await prisma.tenant.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include: TENANT_ADMIN_RELATION_INCLUDE,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many tenants with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @returns {Promise<Array>} Array of tenants
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.tenant.findMany({
      where,
      skip,
      take,
      orderBy,
      include: TENANT_ADMIN_RELATION_INCLUDE,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count tenants with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of tenants
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.tenant.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new tenant
 *
 * @param {Object} data - Tenant data
 * @returns {Promise<Object>} Created tenant
 */
const create = async (data) => {
  try {
    return await prisma.tenant.create({
      data
    });
  } catch (error) {
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update tenant
 *
 * @param {string} id - Tenant ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated tenant
 */
const update = async (id, data) => {
  try {
    return await prisma.tenant.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.tenant.not_found', 404);
    }
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete tenant
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Tenant ID
 * @returns {Promise<Object>} Deleted tenant
 */
const softDelete = async (id) => {
  try {
    return await prisma.tenant.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.tenant.not_found', 404);
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
