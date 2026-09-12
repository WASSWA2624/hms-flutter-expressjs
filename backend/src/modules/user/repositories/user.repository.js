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
const { runWithoutTenantGuard } = require('../../../prisma/tenant-guard');

/**
 * Tenant-guard findFirst/findUnique inject `deleted_at: null` unless the caller
 * already mentions `deleted_at`. Soft-deleted lookups must either mention it or
 * bypass the guard — otherwise restore never sees the row.
 */
const userWhereById = (id, { includeDeleted = false } = {}) =>
  includeDeleted
    ? {
        id,
        OR: [{ deleted_at: null }, { deleted_at: { not: null } }],
      }
    : { id, deleted_at: null };

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
      id: true,
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
      where: userWhereById(id, { includeDeleted }),
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
    const { permission_ids, profile, ...userData } = data || {};
    const permissionIds = normalizePermissionIds(permission_ids);
    return await prisma.$transaction(async (tx) => {
      const createdUser = await tx.user.create({
        data: {
          ...userData,
          ...(profile
            ? {
                profile: {
                  create: {
                    first_name: profile.first_name,
                    last_name: profile.last_name ?? null,
                    facility_id: userData.facility_id ?? null
                  }
                }
              }
            : {})
        }
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
    const { permission_ids, profile, ...userData } = data || {};
    const shouldSyncPermissions = permission_ids !== undefined;
    const shouldSyncProfile = profile !== undefined;

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

      if (shouldSyncProfile) {
        const existingProfile = await tx.user_profile.findFirst({
          where: { user_id: id, deleted_at: null },
          select: { id: true }
        });
        if (existingProfile) {
          await tx.user_profile.update({
            where: { id: existingProfile.id },
            data: {
              ...(profile.first_name !== undefined
                ? { first_name: profile.first_name }
                : {}),
              ...(profile.last_name !== undefined
                ? { last_name: profile.last_name }
                : {}),
              ...(userData.facility_id !== undefined
                ? { facility_id: userData.facility_id }
                : {})
            }
          });
        } else if (profile.first_name) {
          await tx.user_profile.create({
            data: {
              user_id: id,
              first_name: profile.first_name,
              last_name: profile.last_name ?? null,
              facility_id: userData.facility_id ?? null
            }
          });
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
 * Also clears soft-delete on linked staff_profile rows (HR offboarding).
 *
 * @param {string} id - User ID
 * @returns {Promise<Object>} Restored user
 */
const restore = async (id) => {
  try {
    // Soft-deleted rows are invisible to tenant-guard find/update unless we
    // bypass (guard forces deleted_at: null on those operations).
    return await runWithoutTenantGuard(async () => {
      const existing = await prisma.user.findFirst({
        where: userWhereById(id, { includeDeleted: true }),
        select: {
          id: true,
          tenant_id: true,
          facility_id: true,
          deleted_at: true,
        },
      });

      if (!existing || !existing.deleted_at) {
        throw Object.assign(new Error('Record not found'), { code: 'P2025' });
      }

      const tenant = await prisma.tenant.findFirst({
        where: { id: existing.tenant_id, deleted_at: null },
        select: { id: true },
      });
      if (!tenant) {
        throw new HttpError('errors.user.restore_requires_active_tenant', 409);
      }

      if (existing.facility_id) {
        const facility = await prisma.facility.findFirst({
          where: { id: existing.facility_id, deleted_at: null },
          select: { id: true },
        });
        if (!facility) {
          throw new HttpError('errors.user.restore_requires_active_facility', 409);
        }
      }

      return await prisma.$transaction(async (tx) => {
        await tx.user_permission.updateMany({
          where: {
            user_id: id,
            deleted_at: existing.deleted_at,
          },
          data: {
            deleted_at: null,
          },
        });

        await tx.staff_profile.updateMany({
          where: {
            user_id: id,
            deleted_at: { not: null },
          },
          data: { deleted_at: null },
        });

        return await tx.user.update({
          where: { id },
          data: { deleted_at: null },
          include: resolveInclude(),
        });
      });
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2025') {
      throw new HttpError('errors.user.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

/**
 * Rows that exist only to describe the account itself. A permanent delete
 * removes them; children are listed before their parents so foreign keys stay
 * satisfied while the purge runs.
 */
const USER_OWNED_RELATIONS = Object.freeze([
  { model: 'user_session', column: 'user_id' },
  { model: 'verification_token', column: 'user_id' },
  { model: 'user_mfa', column: 'user_id' },
  { model: 'oauth_account', column: 'user_id' },
  { model: 'user_role', column: 'user_id' },
  { model: 'user_permission', column: 'user_id' },
  { model: 'user_module_assignment', column: 'user_id' },
  { model: 'terms_acceptance', column: 'user_id' },
  { model: 'registration_follow_up', column: 'user_id' },
  { model: 'conversation_participant', column: 'user_id' },
  { model: 'clinical_term_favorite', column: 'owner_user_id' },
  { model: 'provider_schedule', column: 'provider_user_id' },
  { model: 'office_context', column: 'opened_by_user_id' },
  { model: 'unit_management_assignment', column: 'user_id' }
]);

/**
 * Employment rows that only describe the purged staff profile.
 */
const STAFF_PROFILE_OWNED_RELATIONS = Object.freeze([
  { model: 'shift_swap_request', column: 'requester_staff_id' },
  { model: 'staff_assignment', column: 'staff_profile_id' },
  { model: 'staff_availability', column: 'staff_profile_id' },
  { model: 'staff_compensation', column: 'staff_profile_id' },
  { model: 'staff_leave', column: 'staff_profile_id' },
  { model: 'shift_assignment', column: 'staff_profile_id' },
  { model: 'roster_day_off', column: 'staff_profile_id' },
  { model: 'address', column: 'staff_profile_id' },
  { model: 'contact', column: 'staff_profile_id' }
]);

/**
 * Attribution columns on records that outlive the account. Clinical, financial
 * and audit history belongs to the patient or tenant, not to the staff member,
 * so the purge clears the link and keeps the record.
 */
const USER_ATTRIBUTION_LINKS = Object.freeze([
  { model: 'abac_policy', column: 'created_by_user_id' },
  { model: 'abac_policy', column: 'updated_by_user_id' },
  { model: 'analytics_event', column: 'user_id' },
  { model: 'anesthesia_record', column: 'anesthetist_user_id' },
  { model: 'appointment', column: 'provider_user_id' },
  { model: 'appointment_participant', column: 'participant_user_id' },
  { model: 'audit_log', column: 'user_id' },
  { model: 'billable_charge_event', column: 'actor_user_id' },
  { model: 'billing_approval', column: 'approved_by_user_id' },
  { model: 'break_glass_access', column: 'approved_by_user_id' },
  { model: 'break_glass_access', column: 'revoked_by_user_id' },
  { model: 'clinical_alert', column: 'acknowledged_by_user_id' },
  { model: 'clinical_alert', column: 'resolved_by_user_id' },
  { model: 'closeout_pack', column: 'generated_by_user_id' },
  { model: 'configuration_snapshot', column: 'created_by_user_id' },
  { model: 'conversation', column: 'created_by_user_id' },
  { model: 'data_processing_log', column: 'user_id' },
  { model: 'day_close', column: 'approved_by_user_id' },
  { model: 'department', column: 'manager_id' },
  { model: 'department', column: 'budget_owner_id' },
  { model: 'department', column: 'updated_by' },
  { model: 'encounter', column: 'provider_user_id' },
  { model: 'fiscal_period', column: 'reopened_by' },
  { model: 'follow_up', column: 'completed_by_user_id' },
  { model: 'lab_order', column: 'ordered_by_user_id' },
  { model: 'message', column: 'sender_user_id' },
  { model: 'message_attachment', column: 'uploaded_by_user_id' },
  { model: 'office_context', column: 'current_holder_user_id' },
  { model: 'opening_balance_entry', column: 'approved_by' },
  { model: 'patient_report_job', column: 'requested_by_user_id' },
  { model: 'payment_method', column: 'updated_by' },
  { model: 'posting_rule', column: 'reopened_by' },
  { model: 'purchase_request', column: 'requested_by_user_id' },
  { model: 'radiology_order', column: 'assigned_user_id' },
  { model: 'registration_attempt', column: 'user_id' },
  { model: 'report_definition', column: 'created_by' },
  { model: 'report_run', column: 'requested_by_user_id' },
  { model: 'report_schedule', column: 'created_by' },
  { model: 'shift_close', column: 'approved_by_user_id' },
  { model: 'system_change_log', column: 'user_id' },
  { model: 'therapy_episode', column: 'therapist_user_id' },
  { model: 'therapy_session', column: 'therapist_user_id' },
  { model: 'visit_queue', column: 'provider_user_id' }
]);

const STAFF_PROFILE_ATTRIBUTION_LINKS = Object.freeze([
  { model: 'housekeeping_task', column: 'assigned_to_staff_id' },
  { model: 'staff_leave', column: 'covering_staff_profile_id' },
  { model: 'shift_swap_request', column: 'target_staff_id' }
]);

/**
 * Records that must be retained and cannot exist without their actor: clinical
 * authorship, PHI access history, break-glass trails and financial closes.
 * Any hit blocks the purge, and the account stays soft-deleted instead.
 */
const USER_PURGE_BLOCKERS = Object.freeze([
  { model: 'clinical_note', column: 'author_user_id' },
  { model: 'nursing_note', column: 'nurse_user_id' },
  { model: 'phi_access_log', column: 'user_id' },
  { model: 'break_glass_access', column: 'requested_by_user_id' },
  { model: 'break_glass_review', column: 'reviewer_user_id' },
  { model: 'billing_approval', column: 'requested_by_user_id' },
  { model: 'custody_snapshot', column: 'captured_by_user_id' },
  { model: 'day_close', column: 'submitted_by_user_id' },
  { model: 'shift_close', column: 'closed_by_user_id' },
  { model: 'handover', column: 'from_user_id' },
  { model: 'handover', column: 'to_user_id' }
]);

const STAFF_PROFILE_PURGE_BLOCKERS = Object.freeze([
  { model: 'payroll_item', column: 'staff_profile_id' }
]);

/**
 * Count retained records that block a permanent delete.
 *
 * @param {string} id - User ID
 * @param {string[]} staffProfileIds - Staff profile IDs owned by the user
 * @returns {Promise<Array<{entity: string, field: string, count: number}>>}
 */
const countPurgeBlockers = async (id, staffProfileIds = []) => {
  const checks = [
    ...USER_PURGE_BLOCKERS.map((entry) => ({ ...entry, value: id })),
    ...(staffProfileIds.length > 0
      ? STAFF_PROFILE_PURGE_BLOCKERS.map((entry) => ({
          ...entry,
          value: { in: staffProfileIds }
        }))
      : [])
  ];

  const counted = await Promise.all(
    checks.map(async ({ model, column, value }) => ({
      entity: model,
      field: column,
      count: await prisma[model].count({ where: { [column]: value } })
    }))
  );

  return counted.filter((entry) => entry.count > 0);
};

/**
 * Permanently delete a soft-deleted user.
 *
 * Account-owned rows (sessions, roles, permissions, employment records) are
 * removed, attribution links on records that outlive the account are cleared,
 * and the purge is refused when retained clinical or financial history would be
 * orphaned.
 *
 * @param {string} id - User ID
 * @returns {Promise<{removed_rows: number, cleared_links: number, staff_profile_ids: string[]}>}
 */
const permanentDelete = async (id) => {
  try {
    // Soft-deleted rows are invisible to the tenant guard, which forces
    // deleted_at: null on find/update/delete: the purge would no-op without it.
    return await runWithoutTenantGuard(async () => {
      const existing = await prisma.user.findFirst({
        where: userWhereById(id, { includeDeleted: true }),
        select: { id: true, deleted_at: true }
      });

      if (!existing) {
        return { removed_rows: 0, cleared_links: 0, staff_profile_ids: [] };
      }
      if (!existing.deleted_at) {
        throw new HttpError('errors.user.permanent_delete_requires_soft_delete', 400);
      }

      const staffProfiles = await prisma.staff_profile.findMany({
        where: { user_id: id },
        select: { id: true }
      });
      const staffProfileIds = staffProfiles.map((row) => row.id);

      const blockers = await countPurgeBlockers(id, staffProfileIds);
      if (blockers.length > 0) {
        throw new HttpError(
          'errors.user.permanent_delete_has_retained_records',
          409,
          blockers
        );
      }

      const userProfiles = await prisma.user_profile.findMany({
        where: { user_id: id },
        select: { id: true }
      });
      const userProfileIds = userProfiles.map((row) => row.id);

      return await prisma.$transaction(
        async (tx) => {
          let removedRows = 0;
          let clearedLinks = 0;

          const removeMany = async (model, where) => {
            const { count } = await tx[model].deleteMany({ where });
            removedRows += count || 0;
          };
          const clearMany = async (model, column, where) => {
            const { count } = await tx[model].updateMany({
              where,
              data: { [column]: null }
            });
            clearedLinks += count || 0;
          };

          const apiKeys = await tx.api_key.findMany({
            where: { user_id: id },
            select: { id: true }
          });
          const apiKeyIds = apiKeys.map((row) => row.id);
          if (apiKeyIds.length > 0) {
            await removeMany('api_key_permission', {
              api_key_id: { in: apiKeyIds }
            });
            await removeMany('api_key', { id: { in: apiKeyIds } });
          }

          const notifications = await tx.notification.findMany({
            where: { user_id: id },
            select: { id: true }
          });
          const notificationIds = notifications.map((row) => row.id);
          if (notificationIds.length > 0) {
            await removeMany('notification_delivery', {
              notification_id: { in: notificationIds }
            });
            await removeMany('notification', { id: { in: notificationIds } });
          }

          if (staffProfileIds.length > 0) {
            for (const { model, column } of STAFF_PROFILE_ATTRIBUTION_LINKS) {
              await clearMany(model, column, {
                [column]: { in: staffProfileIds }
              });
            }
            for (const { model, column } of STAFF_PROFILE_OWNED_RELATIONS) {
              await removeMany(model, { [column]: { in: staffProfileIds } });
            }
          }

          for (const { model, column } of USER_OWNED_RELATIONS) {
            await removeMany(model, { [column]: id });
          }

          if (userProfileIds.length > 0) {
            await removeMany('address', {
              user_profile_id: { in: userProfileIds }
            });
            await removeMany('contact', {
              user_profile_id: { in: userProfileIds }
            });
          }

          for (const { model, column } of USER_ATTRIBUTION_LINKS) {
            await clearMany(model, column, { [column]: id });
          }

          if (staffProfileIds.length > 0) {
            await removeMany('staff_profile', { id: { in: staffProfileIds } });
          }
          await removeMany('user_profile', { user_id: id });
          await tx.user.delete({ where: { id } });
          removedRows += 1;

          return {
            removed_rows: removedRows,
            cleared_links: clearedLinks,
            staff_profile_ids: staffProfileIds
          };
        },
        { timeout: 120000 }
      );
    });
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.user.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message }
    ]);
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
  permanentDelete,
  findActiveByTenantEmail,
  findActiveByTenantPhone};
