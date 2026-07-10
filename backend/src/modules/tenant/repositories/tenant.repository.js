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

const parseRestoredSlug = (slug, id) => {
  const value = String(slug || '').trim();
  if (!value) {
    return null;
  }

  const markerIndex = value.indexOf(RELEASED_SLUG_SUFFIX);
  if (markerIndex < 0) {
    return value;
  }

  const base = value.slice(0, markerIndex).trim();
  return base || null;
};

const buildWhereClause = (filters = {}, { includeDeleted = false } = {}) => {
  const where = { ...filters };
  if (!includeDeleted) {
    where.deleted_at = null;
  }
  return where;
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
const findById = async (id, { includeDeleted = false } = {}) => {
  try {
    return await prisma.tenant.findFirst({
      where: {
        id,
        ...(includeDeleted ? {} : { deleted_at: null }),
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
const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  { includeDeleted = false } = {}
) => {
  try {
    const where = buildWhereClause(filters, { includeDeleted });

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
const count = async (filters = {}, { includeDeleted = false } = {}) => {
  try {
    const where = buildWhereClause(filters, { includeDeleted });

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
 * Create tenant with a default facility in one transaction.
 *
 * @param {Object} data - Tenant data
 * @param {Object} [options]
 * @param {string} [options.facilityName]
 * @returns {Promise<{ tenant: Object, facility: Object }>}
 */
const createWithDefaultFacility = async (data, options = {}) => {
  const facilityName = String(options.facilityName || 'Main Facility').trim() || 'Main Facility';

  try {
    return await prisma.$transaction(async (tx) => {
      const tenant = await tx.tenant.create({ data });
      const facility = await tx.facility.create({
        data: {
          tenant_id: tenant.id,
          name: facilityName,
          facility_type: 'HOSPITAL',
          is_active: true,
        },
      });

      return { tenant, facility };
    });
  } catch (error) {
    if (error.code === 'P2002') {
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

/**
 * Restore a soft-deleted tenant.
 *
 * @param {string} id - Tenant ID
 * @returns {Promise<Object>} Restored tenant
 */
const restore = async (id) => {
  try {
    const existing = await prisma.tenant.findUnique({
      where: { id },
      select: {
        id: true,
        slug: true,
        deleted_at: true,
      },
    });

    if (!existing || !existing.deleted_at) {
      throw Object.assign(new Error('Record not found'), { code: 'P2025' });
    }

    const restoredSlug = parseRestoredSlug(existing.slug, id);
    if (restoredSlug) {
      await releaseSlugFromSoftDeletedTenants(restoredSlug, id);
      const conflict = await prisma.tenant.findFirst({
        where: {
          slug: restoredSlug,
          deleted_at: null,
          id: { not: id },
        },
        select: { id: true },
      });
      if (conflict) {
        throw new HttpError('errors.database.unique_field', 409, [{ field: 'slug' }]);
      }
    }

    return await prisma.tenant.update({
      where: { id },
      data: {
        deleted_at: null,
        ...(restoredSlug ? { slug: restoredSlug } : {}),
      },
      include: TENANT_ADMIN_RELATION_INCLUDE,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.tenant.not_found', 404);
    }
    if (error.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Permanently delete a soft-deleted tenant and scoped tenant data.
 *
 * @param {string} id - Tenant ID
 * @returns {Promise<void>}
 */
const permanentDelete = async (id) => {
  try {
    const existing = await prisma.tenant.findUnique({
      where: { id },
      select: {
        id: true,
        deleted_at: true,
      },
    });

    if (!existing) {
      throw new HttpError('errors.tenant.not_found', 404);
    }
    if (!existing.deleted_at) {
      throw new HttpError('errors.tenant.permanent_delete_requires_soft_delete', 400);
    }

    await prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe('SET FOREIGN_KEY_CHECKS = 0');
      try {
        const rows = await tx.$queryRaw`
          SELECT DISTINCT TABLE_NAME AS table_name
          FROM information_schema.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE()
            AND COLUMN_NAME = 'tenant_id'
            AND TABLE_NAME <> 'tenant'
        `;

        for (const row of rows) {
          const tableName = String(row.table_name || row.TABLE_NAME || '')
            .replace(/`/g, '')
            .trim();
          if (!tableName) {
            continue;
          }
          await tx.$executeRawUnsafe(
            `DELETE FROM \`${tableName}\` WHERE tenant_id = ?`,
            id
          );
        }

        await tx.tenant.delete({ where: { id } });
      } finally {
        await tx.$executeRawUnsafe('SET FOREIGN_KEY_CHECKS = 1');
      }
    }, { timeout: 120000 });
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create,
  createWithDefaultFacility,
  update,
  softDelete,
  restore,
  permanentDelete,
  releaseSlugFromSoftDeletedTenants,
  parseRestoredSlug,
};
