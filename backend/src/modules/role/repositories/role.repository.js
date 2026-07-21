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

/**
 * Find role by ID
 *
 * @param {string} id - Role ID
 * @returns {Promise<Object|null>} Role object or null
 */
const findById = async (id) => {
  try {
    return await prisma.role.findFirst({
      where: {
        id,
        deleted_at: null
      }
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
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
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

module.exports = {
  findById,
  findMany,
  count,
  create,
  syncPermissions,
  update,
  softDelete
};
