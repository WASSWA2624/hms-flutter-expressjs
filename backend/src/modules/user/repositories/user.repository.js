/**
 * User repository
 *
 * @module modules/user/repositories
 * @description Data access layer for user operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const USER_DETAIL_INCLUDE = Object.freeze({
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      slug: true,
    },
  },
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  permissions: {
    where: { deleted_at: null },
    include: {
      permission: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          description: true,
        },
      },
    },
  },
});

const resolveInclude = (include = {}) => ({
  ...USER_DETAIL_INCLUDE,
  ...include,
});

const normalizePermissionIds = (value) => (
  Array.isArray(value)
    ? [...new Set(value.map((entry) => String(entry ?? '').trim()).filter(Boolean))]
    : []
);

const syncUserPermissions = async (tx, userId, permissionIds = []) => {
  const selectedPermissionIds = normalizePermissionIds(permissionIds);
  const existingRecords = await tx.user_permission.findMany({
    where: { user_id: userId },
  });
  const selectedSet = new Set(selectedPermissionIds);
  const existingByPermissionId = new Map(
    existingRecords.map((record) => [String(record.permission_id ?? '').trim(), record])
  );
  const deletedAt = new Date();

  const updates = [];

  existingRecords.forEach((record) => {
    const permissionId = String(record.permission_id ?? '').trim();
    const isSelected = selectedSet.has(permissionId);
    const isDeleted = Boolean(record.deleted_at);

    if (!isSelected && !isDeleted) {
      updates.push(
        tx.user_permission.update({
          where: { id: record.id },
          data: { deleted_at: deletedAt },
        })
      );
      return;
    }

    if (isSelected && isDeleted) {
      updates.push(
        tx.user_permission.update({
          where: { id: record.id },
          data: { deleted_at: null },
        })
      );
    }
  });

  selectedPermissionIds.forEach((permissionId) => {
    if (existingByPermissionId.has(permissionId)) return;
    updates.push(
      tx.user_permission.create({
        data: {
          user_id: userId,
          permission_id: permissionId,
        },
      })
    );
  });

  if (updates.length > 0) {
    await Promise.all(updates);
  }
};

/**
 * Find user by ID
 *
 * @param {string} id - User ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} User object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.user.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many users with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of users
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.user.findMany({
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
 * Count users with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of users
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.user.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new user
 *
 * @param {Object} data - User data
 * @returns {Promise<Object>} Created user
 */
const create = async (data) => {
  try {
    const { permission_ids, ...userData } = data || {};
    const permissionIds = normalizePermissionIds(permission_ids);
    return await prisma.$transaction(async (tx) => {
      const createdUser = await tx.user.create({
        data: userData
      });

      if (permissionIds.length > 0) {
        await syncUserPermissions(tx, createdUser.id, permissionIds);
      }

      return await tx.user.findFirst({
        where: {
          id: createdUser.id,
          deleted_at: null,
        },
        include: resolveInclude(),
      });
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
 * Update user
 *
 * @param {string} id - User ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated user
 */
const update = async (id, data) => {
  try {
    const { permission_ids, ...userData } = data || {};
    const shouldSyncPermissions = permission_ids !== undefined;

    return await prisma.$transaction(async (tx) => {
      if (Object.keys(userData).length > 0) {
        await tx.user.update({
          where: { id },
          data: userData
        });
      } else {
        const existingUser = await tx.user.findFirst({
          where: {
            id,
            deleted_at: null,
          },
        });

        if (!existingUser) {
          const notFoundError = new Error('User not found');
          notFoundError.code = 'P2025';
          throw notFoundError;
        }
      }

      if (shouldSyncPermissions) {
        await syncUserPermissions(tx, id, permission_ids);
      }

      return await tx.user.findFirst({
        where: {
          id,
          deleted_at: null,
        },
        include: resolveInclude(),
      });
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.user.not_found', 404);
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
 * Soft delete user
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - User ID
 * @returns {Promise<Object>} Deleted user
 */
const softDelete = async (id) => {
  try {
    const deletedAt = new Date();

    return await prisma.$transaction(async (tx) => {
      const deletedUser = await tx.user.update({
        where: { id },
        data: {
          deleted_at: deletedAt
        }
      });

      await tx.user_permission.updateMany({
        where: {
          user_id: id,
          deleted_at: null,
        },
        data: {
          deleted_at: deletedAt,
        },
      });

      return deletedUser;
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.user.not_found', 404);
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
