/**
 * Role repository
 *
 * @module modules/role/repositories
 * @description Data access layer for role operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { runWithoutTenantGuard } = require('../../../prisma/tenant-guard');

/**
 * Tenant-guard findFirst/findUnique inject `deleted_at: null` unless the caller
 * already mentions `deleted_at`. Soft-deleted lookups must either mention it or
 * bypass the guard — otherwise restore/permanent-delete never see the row.
 */
const roleWhereById = (id, { includeDeleted = false } = {}) =>
  includeDeleted
    ? {
        id,
        OR: [{ deleted_at: null }, { deleted_at: { not: null } }]
      }
    : { id, deleted_at: null };

/**
 * Find role by ID
 *
 * @param {string} id - Role ID
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted=false]
 * @returns {Promise<Object|null>} Role object or null
 */
const findById = async (id, { includeDeleted = false } = {}) => {
  try {
    return await prisma.role.findFirst({
      where: roleWhereById(id, { includeDeleted })
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many roles with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @returns {Promise<Array>} Array of roles
 */
const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  { includeDeleted = false } = {}
) => {
  try {
    // Build where clause
    const where = {
      ...(includeDeleted ? {} : { deleted_at: null }),
      ...filters
    };

    return await prisma.role.findMany({
      where,
      skip,
      take,
      orderBy
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count roles with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of roles
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.role.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new role
 *
 * @param {Object} data - Role data
 * @param {string[]} [permissionIds] - Optional permission UUIDs to attach
 * @returns {Promise<Object>} Created role
 */
const create = async (data, permissionIds = []) => {
  try {
    const ids = Array.isArray(permissionIds)
      ? [...new Set(permissionIds.filter(Boolean))]
      : [];

    if (ids.length === 0) {
      return await prisma.role.create({ data });
    }

    return await prisma.$transaction(async (tx) => {
      const role = await tx.role.create({ data });
      await tx.role_permission.createMany({
        data: ids.map((permission_id) => ({
          role_id: role.id,
          permission_id}))});
      return role;
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
 * Replace active role permissions with the given set (soft-delete aware).
 *
 * @param {string} roleId
 * @param {string[]} permissionIds
 * @returns {Promise<void>}
 */
const syncPermissions = async (roleId, permissionIds = []) => {
  try {
    const desired = [
      ...new Set(
        (Array.isArray(permissionIds) ? permissionIds : []).filter(Boolean)
      )];
    const existing = await prisma.role_permission.findMany({
      where: { role_id: roleId },
      select: { id: true, permission_id: true, deleted_at: true }});

    const desiredSet = new Set(desired);
    const existingByPermission = new Map(
      existing.map((row) => [row.permission_id, row])
    );
    const now = new Date();
    const ops = [];

    for (const row of existing) {
      if (desiredSet.has(row.permission_id)) {
        if (row.deleted_at) {
          ops.push(
            prisma.role_permission.update({
              where: { id: row.id },
              data: { deleted_at: null }})
          );
        }
      } else if (!row.deleted_at) {
        ops.push(
          prisma.role_permission.update({
            where: { id: row.id },
            data: { deleted_at: now }})
        );
      }
    }

    const toCreate = desired.filter((id) => !existingByPermission.has(id));
    if (toCreate.length > 0) {
      ops.push(
        prisma.role_permission.createMany({
          data: toCreate.map((permission_id) => ({
            role_id: roleId,
            permission_id}))})
      );
    }

    if (ops.length > 0) {
      await prisma.$transaction(ops);
    }
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message }]);
  }
};

/**
 * Update role
 *
 * @param {string} id - Role ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated role
 */
const update = async (id, data) => {
  try {
    return await prisma.role.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.role.not_found', 404);
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
 * Soft delete role and detach related assignments.
 * Soft-deletes active user_role and role_permission rows for the role.
 *
 * @param {string} id - Role ID
 * @returns {Promise<{ role: Object, detached_user_assignments: number }>}
 */
const softDelete = async (id) => {
  try {
    const now = new Date();
    return await prisma.$transaction(async (tx) => {
      const detachedAssignments = await tx.user_role.updateMany({
        where: { role_id: id, deleted_at: null },
        data: { deleted_at: now }});
      await tx.role_permission.updateMany({
        where: { role_id: id, deleted_at: null },
        data: { deleted_at: now }});
      const role = await tx.role.update({
        where: { id },
        data: { deleted_at: now }});
      return {
        role,
        detached_user_assignments: detachedAssignments.count || 0};
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.role.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Restore a soft-deleted role and matching soft-deleted role_permission /
 * user_role rows (same deleted_at timestamp as the role soft-delete).
 *
 * @param {string} id - Role ID
 * @returns {Promise<{ role: Object, restored_permissions: number, restored_user_assignments: number }>}
 */
const restore = async (id) => {
  try {
    // Soft-deleted rows are invisible to tenant-guard find/update unless we
    // bypass (guard forces deleted_at: null on those operations).
    return await runWithoutTenantGuard(async () => {
      const existing = await prisma.role.findFirst({
        where: roleWhereById(id, { includeDeleted: true }),
        select: { id: true, deleted_at: true }
      });

      if (!existing || !existing.deleted_at) {
        throw Object.assign(new Error('Record not found'), { code: 'P2025' });
      }

      return prisma.$transaction(async (tx) => {
        const restoredPermissions = await tx.role_permission.updateMany({
          where: {
            role_id: id,
            deleted_at: existing.deleted_at
          },
          data: { deleted_at: null }
        });
        const restoredAssignments = await tx.user_role.updateMany({
          where: {
            role_id: id,
            deleted_at: existing.deleted_at
          },
          data: { deleted_at: null }
        });
        const role = await tx.role.update({
          where: { id },
          data: { deleted_at: null }
        });
        return {
          role,
          restored_permissions: restoredPermissions.count || 0,
          restored_user_assignments: restoredAssignments.count || 0
        };
      });
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.role.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Permanently delete a soft-deleted role after removing it from every user
 * that still has (or previously had) this role attached.
 *
 * @param {string} id - Role ID
 * @returns {Promise<{ removed_user_ids: string[], removed_user_assignments: number, removed_permissions: number }>}
 */
const permanentDelete = async (id) => {
  try {
    // Hard-delete must see soft-deleted role / role_permission / user_role rows.
    // Tenant-guard otherwise forces deleted_at: null and the purge no-ops or 404s.
    return await runWithoutTenantGuard(async () => {
      const existing = await prisma.role.findFirst({
        where: roleWhereById(id, { includeDeleted: true }),
        select: { id: true, deleted_at: true }
      });

      if (!existing) {
        return {
          removed_user_ids: [],
          removed_user_assignments: 0,
          removed_permissions: 0
        };
      }
      if (!existing.deleted_at) {
        throw new HttpError('errors.role.permanent_delete_requires_soft_delete', 400);
      }

      return prisma.$transaction(async (tx) => {
        // Scan all attachments (active or soft-deleted) so no user keeps this role.
        const assignments = await tx.user_role.findMany({
          where: { role_id: id },
          select: { id: true, user_id: true }
        });
        const removedUserIds = [
          ...new Set(
            assignments
              .map((row) => String(row.user_id || '').trim())
              .filter(Boolean)
          )
        ];

        const removedAssignments = await tx.user_role.deleteMany({
          where: { role_id: id }
        });
        const removedPermissions = await tx.role_permission.deleteMany({
          where: { role_id: id }
        });
        await tx.role.delete({ where: { id } });

        return {
          removed_user_ids: removedUserIds,
          removed_user_assignments: removedAssignments.count || 0,
          removed_permissions: removedPermissions.count || 0
        };
      });
    });
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.role.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create,
  syncPermissions,
  update,
  softDelete,
  restore,
  permanentDelete
};
