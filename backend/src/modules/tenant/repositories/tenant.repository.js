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

const TENANT_SLUG_MAX_LENGTH = 191;
const RELEASED_SLUG_SUFFIX = '__deleted__';

const buildReleasedSlug = (slug, id) => {
  const base = String(slug || '').trim();
  if (!base) {
    return null;
  }

  const suffix = String(id).replace(/-/g, '').slice(0, 8);
  const released = `${base}${RELEASED_SLUG_SUFFIX}${suffix}`;
  return released.length > TENANT_SLUG_MAX_LENGTH
    ? released.slice(0, TENANT_SLUG_MAX_LENGTH)
    : released;
};

/**
 * Free a slug held by soft-deleted tenants so it can be reused.
 *
 * @param {string} slug - Desired tenant slug
 * @param {string} [excludeId] - Active tenant ID to exclude
 * @returns {Promise<void>}
 */
const releaseSlugFromSoftDeletedTenants = async (slug, excludeId = null) => {
  try {
    const normalizedSlug = String(slug || '').trim();
    if (!normalizedSlug) {
      return;
    }

    const conflicts = await prisma.tenant.findMany({
      where: {
        slug: normalizedSlug,
        deleted_at: { not: null },
        ...(excludeId ? { id: { not: excludeId } } : {})
      },
      select: {
        id: true,
        slug: true
      }
    });

    await Promise.all(
      conflicts.map((tenant) =>
        prisma.tenant.update({
          where: { id: tenant.id },
          data: {
            slug: buildReleasedSlug(tenant.slug, tenant.id)
          }
        })
      )
    );
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

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
    const existing = await prisma.tenant.findUnique({
      where: { id },
      select: {
        id: true,
        slug: true,
        deleted_at: true
      }
    });

    if (!existing || existing.deleted_at) {
      throw Object.assign(new Error('Record not found'), { code: 'P2025' });
    }

    const releasedSlug = buildReleasedSlug(existing.slug, id);

    return await prisma.tenant.update({
      where: { id },
      data: {
        deleted_at: new Date(),
        ...(releasedSlug ? { slug: releasedSlug } : {})
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
  softDelete,
  releaseSlugFromSoftDeletedTenants
};
