/**
 * User-Role service
 *
 * @module modules/user-role/services
 * @description Business logic layer for user-role operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const userRoleRepository = require('@repositories/user-role/user-role.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForPayload } = require('@lib/billing/identifiers');
const { assertRoleIdAssignable } = require('@lib/authorization/assignable-access');
const { assertUserIdNotDemoProtected } = require('@lib/authorization/demo-user-guard');

const text = (value) => String(value ?? '').trim();

const fieldError = (messageKey, statusCode, field) =>
  new HttpError(messageKey, statusCode, [{ field, message: messageKey }]);

const resolveUserRoleId = async (identifier) =>
  resolveIdentifierForPayload({
    value: identifier,
    model: 'user_role',
    field: 'id'});

const normalizeUserRolePayload = async (data = {}) => {
  const payload = { ...data };

  if (data.user_id !== undefined) {
    payload.user_id = await resolveIdentifierForPayload({
      value: data.user_id,
      model: 'user',
      field: 'user_id'});
  }
  if (data.role_id !== undefined) {
    payload.role_id = await resolveIdentifierForPayload({
      value: data.role_id,
      model: 'role',
      field: 'role_id'});
  }
  if (data.tenant_id !== undefined) {
    payload.tenant_id = await resolveIdentifierForPayload({
      value: data.tenant_id,
      model: 'tenant',
      field: 'tenant_id'});
  }
  if (data.facility_id !== undefined && data.facility_id !== null) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id'});
  }

  return payload;
};

/**
 * Bind an assignment to the account's own tenant and a facility inside it.
 *
 * A role recorded under another tenant never applies to the user, and one bound
 * to a foreign facility would grant access outside the user's scope.
 */
const resolveAssignmentScope = async (payload) => {
  const target = await userRoleRepository.findUserScope(payload.user_id);
  if (!target) {
    throw fieldError('errors.user.not_found', 404, 'user_id');
  }

  if (text(payload.tenant_id) && text(payload.tenant_id) !== text(target.tenant_id)) {
    throw fieldError('errors.user_role.tenant_mismatch', 400, 'tenant_id');
  }

  const facilityId =
    payload.facility_id === undefined
      ? target.facility_id || null
      : payload.facility_id || null;
  if (facilityId) {
    const facility = await userRoleRepository.findFacilityScope(facilityId);
    if (!facility || text(facility.tenant_id) !== text(target.tenant_id)) {
      throw fieldError('errors.user_role.facility_tenant_mismatch', 400, 'facility_id');
    }
  }

  return { ...payload, tenant_id: target.tenant_id, facility_id: facilityId };
};

/**
 * Confirm the role is within the actor's assignment ceiling (when an actor is
 * present) and can apply inside the assignment's tenant and facility, so an
 * assignment never grants access the user's scope does not imply.
 */
const assertRoleFitsAssignment = async (assignment, actor) => {
  const role = actor
    ? await assertRoleIdAssignable(assignment.role_id, actor)
    : await userRoleRepository.findRoleScope(assignment.role_id);
  if (!role) {
    throw fieldError('errors.role.not_found', 404, 'role_id');
  }
  if (role.tenant_id && text(role.tenant_id) !== text(assignment.tenant_id)) {
    throw fieldError('errors.user_role.role_tenant_mismatch', 400, 'role_id');
  }
  if (role.facility_id && text(role.facility_id) !== text(assignment.facility_id)) {
    throw fieldError('errors.user_role.role_facility_mismatch', 400, 'role_id');
  }
  return role;
};

/**
 * List user-roles with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} User-Roles and pagination data
 */
const listUserRoles = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};

    if (filters.user_id) {
      whereClause.user_id = await resolveIdentifierForPayload({
        value: filters.user_id,
        model: 'user',
        field: 'user_id'});
    }
    if (filters.role_id) {
      whereClause.role_id = await resolveIdentifierForPayload({
        value: filters.role_id,
        model: 'role',
        field: 'role_id'});
    }
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

    const [userRoles, total] = await Promise.all([
      userRoleRepository.findMany(whereClause, skip, limit, orderBy),
      userRoleRepository.count(whereClause)
    ]);

    return {
      userRoles,
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
 * Get user-role by ID
 *
 * @param {string} id - User-Role ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} User-Role data
 */
const getUserRoleById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveUserRoleId(id);
    const userRole = await userRoleRepository.findById(resolvedId);

    if (!userRole) {
      throw new HttpError('errors.user_role.not_found', 404);
    }

    return userRole;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new user-role
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - User-Role data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created user-role
 */
const createUserRole = async (data, userId, ipAddress, actor = null) => {
  try {
    const normalized = await normalizeUserRolePayload(data);
    await assertUserIdNotDemoProtected(normalized.user_id, 'assign_role');
    const payload = await resolveAssignmentScope(normalized);
    await assertRoleFitsAssignment(payload, actor);
    const userRole = await userRoleRepository.create(payload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'user_role',
      entity_id: userRole.id,
      diff: { after: userRole },
      ip_address: ipAddress
    }).catch(() => {});

    return userRole;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update user-role
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User-Role ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated user-role
 */
const updateUserRole = async (id, data, userId, ipAddress, actor = null) => {
  try {
    const resolvedId = await resolveUserRoleId(id);
    // Get current state for audit
    const before = await userRoleRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.user_role.not_found', 404);
    }

    await assertUserIdNotDemoProtected(before.user_id, 'update_role');
    const normalized = await normalizeUserRolePayload(data);
    if (normalized.user_id) {
      await assertUserIdNotDemoProtected(normalized.user_id, 'update_role');
    }
    // Validate the assignment as it will exist after the update, not just the
    // fields that changed.
    const payload = await resolveAssignmentScope({
      user_id: normalized.user_id ?? before.user_id,
      role_id: normalized.role_id ?? before.role_id,
      tenant_id: normalized.tenant_id ?? before.tenant_id,
      facility_id:
        normalized.facility_id !== undefined
          ? normalized.facility_id
          : before.facility_id ?? null});
    await assertRoleFitsAssignment(payload, actor);
    const userRole = await userRoleRepository.update(resolvedId, payload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'user_role',
      entity_id: userRole.id,
      diff: { before, after: userRole },
      ip_address: ipAddress
    }).catch(() => {});

    return userRole;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete user-role (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - User-Role ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteUserRole = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveUserRoleId(id);
    // Get current state for audit
    const before = await userRoleRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.user_role.not_found', 404);
    }

    await assertUserIdNotDemoProtected(before.user_id, 'remove_role');

    await userRoleRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'user_role',
      entity_id: resolvedId,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listUserRoles,
  getUserRoleById,
  createUserRole,
  updateUserRole,
  deleteUserRole
};
