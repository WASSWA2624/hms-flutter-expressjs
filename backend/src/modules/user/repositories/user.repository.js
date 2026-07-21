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
      slug: true}},
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true}},
  permissions: {
    where: { deleted_at: null },
    include: {
      permission: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          description: true}}}}});

const resolveInclude = (include = {}) => ({
  ...USER_DETAIL_INCLUDE,
  ...include});

const normalizePermissionIds = (value) => (
  Array.isArray(value)
    ? [...new Set(value.map((entry) => String(entry ?? '').trim()).filter(Boolean))]
    : []
);

const mapUniqueConstraintField = (target) => {
  const fields = Array.isArray(target)
    ? target.map((entry) => String(entry))
    : [String(target || '')];
  if (fields.some((entry) => entry.includes('email'))) {
    return 'email';
  }
  if (fields.some((entry) => entry.includes('phone'))) {
    return 'phone';
  }
  return fields.find((entry) => entry && entry !== 'tenant_id') || 'field';
};

const findActiveByTenantEmail = async (tenantId, email, excludeUserId = null) => {
  if (!tenantId || !email) {
    return null;
  }

  return prisma.user.findFirst({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      email,
      ...(excludeUserId ? { NOT: { id: excludeUserId } } : {})},
    select: { id: true }});
};

const findActiveByTenantPhone = async (tenantId, phone, excludeUserId = null) => {
  if (!tenantId || !phone) {
    return null;
  }

  const normalizedDigits = String(phone).replace(/[^\d]/g, '');
  if (!normalizedDigits) {
    return null;
  }

  const baseWhere = {
    tenant_id: tenantId,
    deleted_at: null,
    ...(excludeUserId ? { NOT: { id: excludeUserId } } : {})};

  const exactMatch = await prisma.user.findFirst({
    where: {
      ...baseWhere,
      phone},
    select: { id: true }});
  if (exactMatch) {
    return exactMatch;
  }

  const candidates = await prisma.user.findMany({
    where: {
      ...baseWhere,
      phone: { not: null }},
    select: { id: true, phone: true }});

  return (
    candidates.find(
      (entry) =>
        entry.phone &&
        String(entry.phone).replace(/[^\d]/g, '') === normalizedDigits
    ) || null
  );
};

const syncUserPermissions = async (tx, userId, permissionIds = []) => {
  const selectedPermissionIds = normalizePermissionIds(permissionIds);
  const existingRecords = await tx.user_permission.findMany({
    where: { user_id: userId }});
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
          data: { deleted_at: deletedAt }})
      );
      return;
    }

    if (isSelected && isDeleted) {
      updates.push(
        tx.user_permission.update({
          where: { id: record.id },
          data: { deleted_at: null }})
      );
    }
  });

  selectedPermissionIds.forEach((permissionId) => {
    if (existingByPermissionId.has(permissionId)) return;
    updates.push(
      tx.user_permission.create({
        data: {
          user_id: userId,
          permission_id: permissionId}})
    );
  });

  if (updates.length > 0) {
    await Promise.all(updates);
  }
};

const buildWhereClause = (filters = {}, { includeDeleted = false } = {}) => {
  const where = { ...filters };
  if (!includeDeleted) {
    where.deleted_at = null;
  }
  return where;
};

/**
 * Find user by ID
 *
 * @param {string} id - User ID
 * @param {Object} include - Relations to include
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted]
 * @returns {Promise<Object|null>} User object or null
 */
const findById = async (id, include = {}, { includeDeleted = false } = {}) => {
  try {
    return await prisma.user.findFirst({
      where: {
        id,
        ...(includeDeleted ? {} : { deleted_at: null })},
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
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted]
 * @returns {Promise<Array>} Array of users
 */
const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  include = {},
  { includeDeleted = false } = {}
) => {
  try {
    return await prisma.user.findMany({
      where: buildWhereClause(filters, { includeDeleted }),
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
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted]
 * @returns {Promise<number>} Count of users
 */
const count = async (filters = {}, { includeDeleted = false } = {}) => {
  try {
    return await prisma.user.count({
      where: buildWhereClause(filters, { includeDeleted })});
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
          deleted_at: null},
        include: resolveInclude()});
    });
  } catch (error) {
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target;
      const field = mapUniqueConstraintField(target);
      const messageKey =
        field === 'email'
          ? 'errors.user.email_exists_in_tenant'
          : field === 'phone'
            ? 'errors.user.phone_exists_in_tenant'
            : 'errors.database.unique_field';
      throw new HttpError(messageKey, 409, [{ field, message: messageKey }]);
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
            deleted_at: null}});

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
          deleted_at: null},
        include: resolveInclude()});
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.user.not_found', 404);
    }
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target;
      const field = mapUniqueConstraintField(target);
      const messageKey =
        field === 'email'
          ? 'errors.user.email_exists_in_tenant'
          : field === 'phone'
            ? 'errors.user.phone_exists_in_tenant'
            : 'errors.database.unique_field';
      throw new HttpError(messageKey, 409, [{ field, message: messageKey }]);
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
          deleted_at: null},
        data: {
          deleted_at: deletedAt}});

      return deletedUser;
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.user.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Restore a soft-deleted user and user_permissions soft-deleted with the same timestamp.
 *
 * @param {string} id - User ID
 * @returns {Promise<Object>} Restored user
 */
const restore = async (id) => {
  try {
    const existing = await prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        tenant_id: true,
        facility_id: true,
        deleted_at: true}});

    if (!existing || !existing.deleted_at) {
      throw Object.assign(new Error('Record not found'), { code: 'P2025' });
    }

    const tenant = await prisma.tenant.findFirst({
      where: { id: existing.tenant_id, deleted_at: null },
      select: { id: true }});
    if (!tenant) {
      throw new HttpError('errors.user.restore_requires_active_tenant', 409);
    }

    if (existing.facility_id) {
      const facility = await prisma.facility.findFirst({
        where: { id: existing.facility_id, deleted_at: null },
        select: { id: true }});
      if (!facility) {
        throw new HttpError('errors.user.restore_requires_active_facility', 409);
      }
    }

    return await prisma.$transaction(async (tx) => {
      await tx.user_permission.updateMany({
        where: {
          user_id: id,
          deleted_at: existing.deleted_at},
        data: {
          deleted_at: null}});

      return await tx.user.update({
        where: { id },
        data: { deleted_at: null },
        include: resolveInclude()});
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
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
  softDelete,
  restore,
  findActiveByTenantEmail,
  findActiveByTenantPhone};
