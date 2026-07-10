/**
 * User service
 *
 * @module modules/user/services
 * @description Business logic layer for user operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const crypto = require('crypto');
const userRepository = require('@repositories/user/user.repository');
const { createAuditLog } = require('@lib/audit');
const { hashPassword } = require('@lib/crypto');
const { HttpError } = require('@lib/errors');
const { publishCrudRealtimeEvent } = require('@lib/websocket/crud-realtime');
const { PLATFORM_ADMIN_EVENTS } = require('@lib/websocket/events');
const { ROLES } = require('@config/roles');
const { publishPlatformRealtimeEvent } = require('@lib/realtime/platform-realtime');
const {
  buildRealtimeEntityEnvelope,
  REALTIME_SYNC_ACTIONS
} = require('@lib/realtime/entity-envelope');
const { serializeAccessAdminUserEntity } = require('@lib/realtime/access-admin-realtime');
const { resolveEntityId } = require('@lib/billing/identifiers');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');

const resolveUserId = async (identifier, { includeDeleted = false } = {}) => {
  const normalized = String(identifier ?? '').trim();
  if (!normalized) return normalized;

  if (includeDeleted) {
    const resolved = await resolveModelIdByIdentifier({
      model: 'user',
      identifier: normalized,
      includeDeleted: true,
    });
    return resolved || normalized;
  }

  return resolveEntityId({ model: 'user', identifier: normalized });
};

const USER_REALTIME_RECIPIENT_ROLES = Object.freeze([
  ROLES.FACILITY_ADMIN,
  ROLES.TENANT_ADMIN
]);

const resolveUserRealtimeAction = (event) => {
  if (String(event || '').includes('deleted')) {
    return REALTIME_SYNC_ACTIONS.REMOVE;
  }
  return REALTIME_SYNC_ACTIONS.UPSERT;
};

const publishUserRealtimeEvent = async (event, user, actorUserId) => {
  const action = resolveUserRealtimeAction(event);
  const entity =
    action === REALTIME_SYNC_ACTIONS.REMOVE
      ? {
          id: user?.human_friendly_id || user?.id || null
        }
      : serializeAccessAdminUserEntity(user);
  const envelope = buildRealtimeEntityEnvelope(action, entity, {
    resource_type: 'user'
  });

  await Promise.all([
    publishCrudRealtimeEvent({
      event,
      resource: user,
      resource_type: 'user',
      actor_user_id: actorUserId,
      recipient_roles: USER_REALTIME_RECIPIENT_ROLES,
      payload: envelope
    }),
    publishPlatformRealtimeEvent({
      event,
      resource_type: 'user',
      resource_id: user?.id || null,
      actor_user_id: actorUserId,
      tenant_id: user?.tenant_id || null,
      facility_id: user?.facility_id || null,
      payload: {
        ...envelope,
        email: user?.email || null
      }
    })
  ]);
};

const BCRYPT_PREFIX_REGEX = /^\$2[aby]\$\d{2}\$/;
const USER_LIST_INCLUDE = Object.freeze({
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
  profile: {
    select: {
      first_name: true,
      middle_name: true,
      last_name: true,
    },
  },
});

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

const normalizeEmail = (value) => String(value || '').trim().toLowerCase();

const normalizePhoneDigits = (value) => {
  const digits = String(value || '').replace(/[^\d]/g, '');
  return digits || null;
};

const assertTenantUserContactAvailable = async ({
  tenantId,
  email,
  phone,
  excludeUserId = null,
}) => {
  const resolvedTenantId = String(tenantId || '').trim();
  if (!resolvedTenantId) {
    return;
  }

  const normalizedEmail = email ? normalizeEmail(email) : null;
  const normalizedPhone = phone ? normalizePhoneDigits(phone) : null;
  const conflicts = [];

  if (normalizedEmail) {
    const existingEmail = await userRepository.findActiveByTenantEmail(
      resolvedTenantId,
      normalizedEmail,
      excludeUserId
    );
    if (existingEmail) {
      conflicts.push({
        field: 'email',
        message: 'errors.user.email_exists_in_tenant',
      });
    }
  }

  if (normalizedPhone) {
    const existingPhone = await userRepository.findActiveByTenantPhone(
      resolvedTenantId,
      normalizedPhone,
      excludeUserId
    );
    if (existingPhone) {
      conflicts.push({
        field: 'phone',
        message: 'errors.user.phone_exists_in_tenant',
      });
    }
  }

  if (!conflicts.length) {
    return;
  }

  throw new HttpError(
    conflicts.length > 1
      ? 'errors.user.contact_exists_in_tenant'
      : conflicts[0].message,
    409,
    conflicts
  );
};

const normalizeUserPayload = async (data, isUpdate = false) => {
  const next = { ...(data || {}) };
  const normalizedPositionTitle = typeof next.position_title === 'string' ? next.position_title.trim() : '';
  const rawPassword = typeof next.password === 'string' ? next.password.trim() : '';
  const providedHash = typeof next.password_hash === 'string' ? next.password_hash.trim() : '';
  const permissionIds = Array.isArray(next.permission_ids)
    ? [...new Set(next.permission_ids.map((entry) => String(entry ?? '').trim()).filter(Boolean))]
    : undefined;

  if (!isUpdate) {
    if (!normalizedPositionTitle) {
      throw new HttpError('errors.validation.field.required', 400, [{ field: 'position_title' }]);
    }
    next.position_title = normalizedPositionTitle;
  } else if (next.position_title !== undefined) {
    next.position_title = normalizedPositionTitle;
  }

  if (rawPassword) {
    next.password_hash = await hashPassword(rawPassword);
  } else if (providedHash) {
    next.password_hash = BCRYPT_PREFIX_REGEX.test(providedHash)
      ? providedHash
      : await hashPassword(providedHash);
  } else if (!isUpdate) {
    next.password_hash = await hashPassword(crypto.randomBytes(16).toString('hex'));
  }

  if (permissionIds !== undefined) {
    next.permission_ids = permissionIds;
  }

  if (typeof next.email === 'string') {
    next.email = normalizeEmail(next.email);
  }

  if (next.phone !== undefined && next.phone !== null) {
    const normalizedPhone = normalizePhoneDigits(next.phone);
    next.phone = normalizedPhone;
  }

  delete next.password;
  return next;
};

/**
 * List users with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Users and pagination data
 */
const listUsers = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const includeDeleted =
      filters.include_deleted === true || filters.include_deleted === 'true';
    const skip = (page - 1) * limit;
    const orderBy = includeDeleted
      ? [{ deleted_at: 'asc' }, { [sortBy || 'created_at']: order || 'desc' }]
      : (sortBy ? { [sortBy]: order } : { created_at: 'desc' });

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.facility_id) whereClause.facility_id = filters.facility_id;
    if (filters.position_title) whereClause.position_title = { contains: filters.position_title };
    if (filters.status) whereClause.status = filters.status;
    if (filters.email) whereClause.email = { contains: filters.email };
    
    // Search filter supports provider lookup by public ID, name, email, phone, and role/title.
    if (filters.search) {
      const searchTerm = String(filters.search).trim();
      const upperSearchTerm = searchTerm.toUpperCase();
      whereClause.OR = [
        { human_friendly_id: { contains: upperSearchTerm } },
        { email: { contains: searchTerm } },
        { phone: { contains: searchTerm } },
        { position_title: { contains: searchTerm } },
        {
          profile: {
            is: {
              OR: [
                { first_name: { contains: searchTerm } },
                { middle_name: { contains: searchTerm } },
                { last_name: { contains: searchTerm } },
              ],
            },
          },
        },
      ];
    }

    const listOptions = { includeDeleted };

    const [users, total] = await Promise.all([
      userRepository.findMany(whereClause, skip, limit, orderBy, USER_LIST_INCLUDE, listOptions),
      userRepository.count(whereClause, listOptions)
    ]);

    return {
      users,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1
      }
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get user by ID
 *
 * @param {string} id - User ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} User data
 */
const getUserById = async (id, userId, ipAddress) => {
  try {
    const resolvedUserId = await resolveUserId(id);
    const user = await userRepository.findById(resolvedUserId, USER_DETAIL_INCLUDE);

    if (!user) {
      throw new HttpError('errors.user.not_found', 404);
    }

    return user;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new user
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - User data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created user
 */
const createUser = async (data, userId, ipAddress) => {
  try {
    const normalizedPayload = await normalizeUserPayload(data, false);
    await assertTenantUserContactAvailable({
      tenantId: normalizedPayload.tenant_id,
      email: normalizedPayload.email,
      phone: normalizedPayload.phone,
    });
    const user = await userRepository.create(normalizedPayload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'user',
      entity_id: user.id,
      diff: { after: user },
      ip_address: ipAddress
    }).catch(() => {});

    await publishUserRealtimeEvent(
      PLATFORM_ADMIN_EVENTS.USER_CREATED,
      user,
      userId
    );

    return user;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update user
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated user
 */
const updateUser = async (id, data, userId, ipAddress) => {
  try {
    const resolvedUserId = await resolveUserId(id);
    // Get current state for audit
    const before = await userRepository.findById(resolvedUserId, USER_DETAIL_INCLUDE);

    if (!before) {
      throw new HttpError('errors.user.not_found', 404);
    }

    const normalizedPayload = await normalizeUserPayload(data, true);
    await assertTenantUserContactAvailable({
      tenantId: normalizedPayload.tenant_id ?? before.tenant_id,
      email: normalizedPayload.email ?? before.email,
      phone: normalizedPayload.phone ?? before.phone,
      excludeUserId: resolvedUserId,
    });
    const user = await userRepository.update(resolvedUserId, normalizedPayload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'user',
      entity_id: user.id,
      diff: { before, after: user },
      ip_address: ipAddress
    }).catch(() => {});

    await publishUserRealtimeEvent(
      PLATFORM_ADMIN_EVENTS.USER_UPDATED,
      user,
      userId
    );

    return user;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete user (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteUser = async (id, userId, ipAddress) => {
  try {
    const resolvedUserId = await resolveUserId(id);
    // Get current state for audit
    const before = await userRepository.findById(resolvedUserId);

    if (!before) {
      throw new HttpError('errors.user.not_found', 404);
    }

    await userRepository.softDelete(resolvedUserId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'user',
      entity_id: resolvedUserId,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});

    await publishUserRealtimeEvent(
      PLATFORM_ADMIN_EVENTS.USER_DELETED,
      before,
      userId
    );
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Restore soft-deleted user
 */
const restoreUser = async (id, userId, ipAddress) => {
  try {
    const resolvedUserId = await resolveUserId(id, { includeDeleted: true });
    const user = await userRepository.restore(resolvedUserId);

    createAuditLog({
      user_id: userId,
      action: 'USER_RESTORED',
      entity: 'user',
      entity_id: resolvedUserId,
      diff: { after: user },
      ip_address: ipAddress,
    }).catch(() => {});

    await publishUserRealtimeEvent(
      PLATFORM_ADMIN_EVENTS.USER_RESTORED,
      user,
      userId
    );

    return user;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser,
  restoreUser,
};
