/**
 * Role service
 *
 * @module modules/role/services
 * @description Business logic layer for role operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const roleRepository = require('@repositories/role/role.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForPayload, resolveEntityId } = require('@lib/billing/identifiers');
const { publishCrudRealtimeEvent } = require('@lib/websocket/crud-realtime');
const { PLATFORM_ADMIN_EVENTS } = require('@lib/websocket/events');
const { ROLES } = require('@config/roles');
const { publishPlatformRealtimeEvent } = require('@lib/realtime/platform-realtime');
const {
  buildRealtimeEntityEnvelope,
  REALTIME_SYNC_ACTIONS
} = require('@lib/realtime/entity-envelope');
const { serializeAccessAdminRoleEntity } = require('@lib/realtime/access-admin-realtime');
const {
  assertActorCanManageRoleRecord,
  assertRoleNotSystemProtected,
  assertRoleScopeAllowed,
  assertPermissionIdsAssignable} = require('@lib/authorization/assignable-access');

const ROLE_REALTIME_RECIPIENT_ROLES = Object.freeze([ROLES.TENANT_ADMIN]);

const resolveRoleRealtimeAction = (event) => {
  if (String(event || '').includes('deleted')) {
    return REALTIME_SYNC_ACTIONS.REMOVE;
  }
  return REALTIME_SYNC_ACTIONS.UPSERT;
};

const publishRoleRealtimeEvent = async (event, role, actorUserId) => {
  const action = resolveRoleRealtimeAction(event);
  const entity =
    action === REALTIME_SYNC_ACTIONS.REMOVE
      ? {
          id: role?.human_friendly_id || role?.id || null
        }
      : serializeAccessAdminRoleEntity(role);
  const envelope = buildRealtimeEntityEnvelope(action, entity, {
    resource_type: 'role'
  });

  await Promise.all([
    publishCrudRealtimeEvent({
      event,
      resource: role,
      resource_type: 'role',
      actor_user_id: actorUserId,
      recipient_roles: ROLE_REALTIME_RECIPIENT_ROLES,
      payload: envelope
    }),
    publishPlatformRealtimeEvent({
      event,
      resource_type: 'role',
      resource_id: role?.id || null,
      actor_user_id: actorUserId,
      tenant_id: role?.tenant_id || null,
      facility_id: role?.facility_id || null,
      payload: {
        ...envelope,
        name: role?.name || null
      }
    })
  ]);
};

const resolveRoleId = async (identifier) =>
  resolveEntityId({ model: 'role', identifier });

const normalizeCreateRolePayload = async (data = {}) => {
  const payload = { ...data };

  payload.tenant_id = await resolveIdentifierForPayload({
    value: data.tenant_id,
    model: 'tenant',
    field: 'tenant_id'});

  if (data.facility_id != null && String(data.facility_id).trim() !== '') {
    payload.facility_id = await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true});
  } else if (data.facility_id === null) {
    payload.facility_id = null;
  }

  return payload;
};

/**
 * List roles with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Roles and pagination data
 */
const listRoles = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.facility_id) whereClause.facility_id = filters.facility_id;
    if (filters.name) whereClause.name = { contains: filters.name };
    
    // Search filter (searches in name, display name, and description)
    if (filters.search) {
      whereClause.OR = [
        { name: { contains: filters.search } },
        { display_name: { contains: filters.search } },
        { description: { contains: filters.search } }
      ];
    }

    const [roles, total] = await Promise.all([
      roleRepository.findMany(whereClause, skip, limit, orderBy),
      roleRepository.count(whereClause)
    ]);

    return {
      roles,
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
 * Get role by ID
 *
 * @param {string} id - Role ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Role data
 */
const getRoleById = async (id, userId, ipAddress) => {
  try {
    const resolvedRoleId = await resolveRoleId(id);
    const role = await roleRepository.findById(resolvedRoleId);

    if (!role) {
      throw new HttpError('errors.role.not_found', 404);
    }

    return role;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new role
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Role data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created role
 */
const createRole = async (data, userId, ipAddress, actor = null) => {
  try {
    const { permission_ids: permissionIdsInput, ...roleFields } = data || {};
    const payload = await normalizeCreateRolePayload(roleFields);
    const scopedPayload = await assertRoleScopeAllowed(payload, actor || { id: userId });
    const permissionIds = await assertPermissionIdsAssignable(
      permissionIdsInput,
      actor || { id: userId },
      { tenantId: scopedPayload.tenant_id || null }
    );
    const role = await roleRepository.create(scopedPayload, permissionIds);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'role',
      entity_id: role.id,
      diff: { after: role, permission_ids: permissionIds },
      ip_address: ipAddress
    }).catch(() => {});

    await publishRoleRealtimeEvent(
      PLATFORM_ADMIN_EVENTS.ROLE_CREATED,
      role,
      userId
    );

    return role;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update role
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Role ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated role
 */
const updateRole = async (id, data, userId, ipAddress, actor = null) => {
  try {
    const resolvedRoleId = await resolveRoleId(id);
    // Get current state for audit
    const before = await roleRepository.findById(resolvedRoleId);

    if (!before) {
      throw new HttpError('errors.role.not_found', 404);
    }

    const actorUser = actor || { id: userId };
    assertActorCanManageRoleRecord(before, actorUser);
    assertRoleNotSystemProtected(before, 'update');

    const { permission_ids: permissionIdsInput, ...roleFields } = data || {};
    const payload = { ...roleFields };
    if (Object.prototype.hasOwnProperty.call(roleFields, 'facility_id')) {
      if (roleFields.facility_id != null && String(roleFields.facility_id).trim() !== '') {
        payload.facility_id = await resolveIdentifierForPayload({
          value: roleFields.facility_id,
          model: 'facility',
          field: 'facility_id',
          nullable: true});
      } else {
        payload.facility_id = null;
      }

      await assertRoleScopeAllowed(
        {
          tenant_id: before.tenant_id,
          facility_id: payload.facility_id},
        actorUser
      );
    }

    const shouldSyncPermissions = Object.prototype.hasOwnProperty.call(
      data || {},
      'permission_ids'
    );
    const permissionIds = shouldSyncPermissions
      ? await assertPermissionIdsAssignable(
          permissionIdsInput,
          actorUser,
          { tenantId: before.tenant_id || null }
        )
      : null;

    const role =
      Object.keys(payload).length > 0
        ? await roleRepository.update(resolvedRoleId, payload)
        : before;

    if (shouldSyncPermissions) {
      await roleRepository.syncPermissions(resolvedRoleId, permissionIds);
    }

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'role',
      entity_id: role.id,
      diff: {
        before,
        after: role,
        ...(shouldSyncPermissions ? { permission_ids: permissionIds } : {})},
      ip_address: ipAddress
    }).catch(() => {});

    await publishRoleRealtimeEvent(
      PLATFORM_ADMIN_EVENTS.ROLE_UPDATED,
      role,
      userId
    );

    return role;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete role (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Role ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteRole = async (id, userId, ipAddress, actor = null) => {
  try {
    const resolvedRoleId = await resolveRoleId(id);
    // Get current state for audit
    const before = await roleRepository.findById(resolvedRoleId);

    if (!before) {
      throw new HttpError('errors.role.not_found', 404);
    }

    const actorUser = actor || { id: userId };
    assertActorCanManageRoleRecord(before, actorUser);
    assertRoleNotSystemProtected(before, 'delete');

    const { role, detached_user_assignments: detachedUserAssignments } =
      await roleRepository.softDelete(resolvedRoleId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'role',
      entity_id: resolvedRoleId,
      diff: {
        before,
        after: role,
        detached_user_assignments: detachedUserAssignments},
      ip_address: ipAddress
    }).catch(() => {});

    await publishRoleRealtimeEvent(
      PLATFORM_ADMIN_EVENTS.ROLE_DELETED,
      before,
      userId
    );
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listRoles,
  getRoleById,
  createRole,
  updateRole,
  deleteRole
};
