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
const { resolveEntityId, resolveIdentifierForPayload } = require('@lib/billing/identifiers');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { checkUserDuplicates } = require('@lib/user/user-similarity');
const {
  assertPermissionNamesIncludeRequiredReads,
} = require('@lib/authorization/permission-read-dependency');
const {
  PLATFORM_ADMIN_MANAGED_ROLES,
  canActorManagePlatformAdmins,
} = require('@lib/authorization/assignable-access');
const { normalizeRoleName } = require('@config/roles');
const prisma = require('@prisma/client');

const USER_SIMILARITY_LOOKUP_LIMIT = 500;

const loadTargetRoleNames = async (userId) => {
  const rows = await prisma.user_role.findMany({
    where: { user_id: userId, deleted_at: null },
    select: { role: { select: { name: true } } },
  });
  return rows
    .map((row) => normalizeRoleName(row?.role?.name))
    .filter(Boolean);
};

/**
 * Platform owners may CRUD every account. Non-owners cannot mutate users that
 * hold PLATFORM_ADMIN / PLATFORM_OWNER roles.
 */
const assertActorCanMutateTargetAccount = async (targetUserId, actor = {}) => {
  if (!targetUserId || canActorManagePlatformAdmins(actor)) {
    return;
  }
  const roleNames = await loadTargetRoleNames(targetUserId);
  if (roleNames.some((name) => PLATFORM_ADMIN_MANAGED_ROLES.has(name))) {
    throw new HttpError('errors.auth.insufficient_permissions', 403, [
      { field: 'user_id', reason: 'platform_admin_account_forbidden' },
    ]);
  }
};

const stripSimilarityPayloadFields = (data = {}) => {
  const { confirm_similar: _confirmSimilar, ...payload } = data;
  return payload;
};

const resolveUserId = async (identifier, { includeDeleted = false } = {}) => {
  const normalized = String(identifier ?? '').trim();
  if (!normalized) return normalized;

  if (includeDeleted) {
    const resolved = await resolveModelIdByIdentifier({
      model: 'user',
      identifier: normalized,
      includeDeleted: true});
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
      slug: true}},
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true}},
  profile: {
    select: {
      first_name: true,
      middle_name: true,
      last_name: true}}});

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
  profile: {
    select: {
      first_name: true,
      middle_name: true,
      last_name: true}},
  permissions: {
    where: { deleted_at: null },
    include: {
      permission: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          description: true}}}}});

const normalizeEmail = (value) => String(value || '').trim().toLowerCase();

const normalizePhoneDigits = (value) => {
  const digits = String(value || '').replace(/[^\d]/g, '');
  return digits || null;
};

/**
 * Load a broad, tenant-scoped peer set for user similarity review.
 *
 * Combines an alphabetical window with search-biased pages on email / phone /
 * position so strong identity matches past the alphabetical limit still surface.
 */
const loadUserSimilarityPeers = async ({
  tenantId,
  email,
  phone,
  positionTitle,
  firstName = null,
  lastName = null
}) => {
  const peerFilters = { tenant_id: tenantId };

  const alphabetical = await userRepository.findMany(
    peerFilters,
    0,
    USER_SIMILARITY_LOOKUP_LIMIT,
    { email: 'asc' },
    USER_LIST_INCLUDE
  );

  const emailTerm = String(email || '').trim();
  const phoneTerm = normalizePhoneDigits(phone) || '';
  const positionTerm = String(positionTitle || '').trim();
  const firstNameTerm = String(firstName || '').trim();
  const lastNameTerm = String(lastName || '').trim();
  const fullNameTerm = [firstNameTerm, lastNameTerm].filter(Boolean).join(' ').trim();
  const searchTerms = [
    ...new Set(
      [emailTerm, phoneTerm, positionTerm, firstNameTerm, lastNameTerm, fullNameTerm].filter(
        (term) => term.length > 0
      )
    )
  ];

  const searched = [];
  for (const term of searchTerms) {
    const page = await userRepository.findMany(
      {
        ...peerFilters,
        OR: [
          { email: { contains: term } },
          { phone: { contains: term } },
          { position_title: { contains: term } },
          { profile: { is: { first_name: { contains: term } } } },
          { profile: { is: { last_name: { contains: term } } } }
        ]
      },
      0,
      USER_SIMILARITY_LOOKUP_LIMIT,
      { email: 'asc' },
      USER_LIST_INCLUDE
    );
    if (Array.isArray(page)) {
      searched.push(...page);
    }
  }

  const seen = new Set();
  const existing = [];
  const combined = [
    ...searched,
    ...(Array.isArray(alphabetical) ? alphabetical : [])
  ];
  for (const user of combined) {
    const key = String(user?.id || user?.human_friendly_id || '').trim();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    existing.push(user);
    if (existing.length >= USER_SIMILARITY_LOOKUP_LIMIT) break;
  }

  return existing;
};

const assertUserUniqueness = async ({
  tenantId,
  email,
  phone,
  positionTitle,
  firstName = null,
  middleName = null,
  lastName = null,
  facilityId = null,
  confirmSimilar = false,
  excludeUserId = null
}) => {
  const resolvedTenantId = String(tenantId || '').trim();
  if (!resolvedTenantId) {
    return null;
  }

  const existing = await loadUserSimilarityPeers({
    tenantId: resolvedTenantId,
    email,
    phone,
    positionTitle,
    firstName,
    lastName
  });

  const duplicateCheck = checkUserDuplicates({
    email,
    phone,
    positionTitle,
    firstName,
    middleName,
    lastName,
    facilityId,
    tenantId: resolvedTenantId,
    existing,
    excludeUserId
  });

  // Same-tenant exact email/phone is a hard uniqueness conflict that cannot be
  // overridden with confirm_similar. Keep the existing contact message keys but
  // attach the conflicting match payload so the client can hydrate the dialog.
  if (duplicateCheck.exactEmailConflict || duplicateCheck.exactPhoneConflict) {
    const exactMatches = duplicateCheck.similarMatches
      .filter((match) => match.exactEmailConflict || match.exactPhoneConflict)
      .slice(0, 5);
    const bothConflict =
      duplicateCheck.exactEmailConflict && duplicateCheck.exactPhoneConflict;
    const messageKey = bothConflict
      ? 'errors.user.contact_exists_in_tenant'
      : duplicateCheck.exactEmailConflict
        ? 'errors.user.email_exists_in_tenant'
        : 'errors.user.phone_exists_in_tenant';
    const field = duplicateCheck.exactEmailConflict ? 'email' : 'phone';
    throw new HttpError(messageKey, 409, [
      {
        field,
        message: messageKey,
        matches: exactMatches
      }
    ]);
  }

  const reviewMatches = duplicateCheck.overridableMatches.slice(0, 5);
  if (reviewMatches.length > 0 && !confirmSimilar) {
    throw new HttpError('errors.user.similar_exists', 409, [
      {
        field: 'email',
        matches: reviewMatches
      }
    ]);
  }

  return duplicateCheck;
};

const normalizeUserPayload = async (data, isUpdate = false) => {
  const next = { ...(data || {}) };
  const normalizedPositionTitle = typeof next.position_title === 'string' ? next.position_title.trim() : '';
  const rawPassword = typeof next.password === 'string' ? next.password.trim() : '';
  const providedHash = typeof next.password_hash === 'string' ? next.password_hash.trim() : '';
  const permissionIds = Array.isArray(next.permission_ids)
    ? [...new Set(next.permission_ids.map((entry) => String(entry ?? '').trim()).filter(Boolean))]
    : undefined;

  const hasFirstName = Object.prototype.hasOwnProperty.call(next, 'first_name');
  const hasLastName = Object.prototype.hasOwnProperty.call(next, 'last_name');
  const normalizedFirstName = hasFirstName
    ? String(next.first_name || '').trim()
    : undefined;
  const normalizedLastName = hasLastName
    ? (next.last_name == null || String(next.last_name).trim() === ''
        ? null
        : String(next.last_name).trim())
    : undefined;

  if (!isUpdate) {
    if (!normalizedPositionTitle) {
      throw new HttpError('errors.validation.field.required', 400, [{ field: 'position_title' }]);
    }
    next.position_title = normalizedPositionTitle;
    if (!normalizedFirstName) {
      throw new HttpError('errors.validation.field.required', 400, [{ field: 'first_name' }]);
    }
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
    next.permission_ids = await Promise.all(
      permissionIds.map((permissionId) =>
        resolveIdentifierForPayload({
          value: permissionId,
          model: 'permission',
          field: 'permission_ids'})
      )
    );
    if (next.permission_ids.length > 0) {
      const permissionRecords = await prisma.permission.findMany({
        where: {
          id: { in: next.permission_ids },
          deleted_at: null,
        },
        select: { name: true },
      });
      assertPermissionNamesIncludeRequiredReads(
        permissionRecords.map((entry) => entry.name)
      );
    }
  }

  if (next.tenant_id !== undefined) {
    next.tenant_id = await resolveIdentifierForPayload({
      value: next.tenant_id,
      model: 'tenant',
      field: 'tenant_id'});
  }

  if (next.facility_id !== undefined) {
    next.facility_id = await resolveIdentifierForPayload({
      value: next.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true});
  }

  if (typeof next.email === 'string') {
    next.email = normalizeEmail(next.email);
  }

  if (next.phone !== undefined && next.phone !== null) {
    const normalizedPhone = normalizePhoneDigits(next.phone);
    next.phone = normalizedPhone;
  }

  delete next.password;
  delete next.first_name;
  delete next.last_name;

  if (!isUpdate || hasFirstName || hasLastName) {
    next.profile = {
      ...(hasFirstName || !isUpdate ? { first_name: normalizedFirstName } : {}),
      ...(hasLastName || !isUpdate ? { last_name: normalizedLastName ?? null } : {})
    };
  }

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
    
    if (filters.tenant_id) {
      whereClause.tenant_id = await resolveIdentifierForPayload({
        value: filters.tenant_id,
        model: 'tenant',
        field: 'tenant_id'});
    }
    if (filters.facility_id) {
      whereClause.facility_id = await resolveIdentifierForPayload({
        value: filters.facility_id,
        model: 'facility',
        field: 'facility_id'});
    }
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
                { last_name: { contains: searchTerm } }]}}}];
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
    const confirmSimilar = data?.confirm_similar === true;
    const strippedData = stripSimilarityPayloadFields(data || {});
    const normalizedPayload = await normalizeUserPayload(strippedData, false);
    await assertUserUniqueness({
      tenantId: normalizedPayload.tenant_id,
      email: normalizedPayload.email,
      phone: normalizedPayload.phone,
      positionTitle: normalizedPayload.position_title,
      firstName: normalizedPayload.profile?.first_name,
      middleName: normalizedPayload.profile?.middle_name,
      lastName: normalizedPayload.profile?.last_name,
      facilityId: normalizedPayload.facility_id,
      confirmSimilar});
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
const updateUser = async (id, data, userId, ipAddress, actor = {}) => {
  try {
    const resolvedUserId = await resolveUserId(id);
    // Get current state for audit
    const before = await userRepository.findById(resolvedUserId, USER_DETAIL_INCLUDE);

    if (!before) {
      throw new HttpError('errors.user.not_found', 404);
    }

    await assertActorCanMutateTargetAccount(resolvedUserId, actor);

    const confirmSimilar = data?.confirm_similar === true;
    const strippedData = stripSimilarityPayloadFields(data || {});
    const normalizedPayload = await normalizeUserPayload(strippedData, true);
    await assertUserUniqueness({
      tenantId: normalizedPayload.tenant_id ?? before.tenant_id,
      email: normalizedPayload.email ?? before.email,
      phone: normalizedPayload.phone ?? before.phone,
      positionTitle: normalizedPayload.position_title ?? before.position_title,
      firstName:
        normalizedPayload.profile?.first_name ?? before.profile?.first_name,
      middleName:
        normalizedPayload.profile?.middle_name ?? before.profile?.middle_name,
      lastName: normalizedPayload.profile?.last_name ?? before.profile?.last_name,
      facilityId: normalizedPayload.facility_id ?? before.facility_id,
      confirmSimilar,
      excludeUserId: resolvedUserId});
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
const deleteUser = async (id, userId, ipAddress, actor = {}) => {
  try {
    const resolvedUserId = await resolveUserId(id);
    // Get current state for audit
    const before = await userRepository.findById(resolvedUserId);

    if (!before) {
      throw new HttpError('errors.user.not_found', 404);
    }

    await assertActorCanMutateTargetAccount(resolvedUserId, actor);

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
const restoreUser = async (id, userId, ipAddress, actor = {}) => {
  try {
    const resolvedUserId = await resolveUserId(id, { includeDeleted: true });
    await assertActorCanMutateTargetAccount(resolvedUserId, actor);
    const user = await userRepository.restore(resolvedUserId);

    createAuditLog({
      user_id: userId,
      action: 'USER_RESTORED',
      entity: 'user',
      entity_id: resolvedUserId,
      diff: { after: user },
      ip_address: ipAddress}).catch(() => {});

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
  restoreUser};
