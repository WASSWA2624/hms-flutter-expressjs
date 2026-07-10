/**
 * Access-admin workspace list entity serializers for realtime envelopes.
 */

const { resolvePublicIdentifier } = require('@lib/billing/identifiers');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const serializeAccessAdminUserEntity = (record) => {
  if (!record) return null;

  const profile = record.profile || null;
  const roleAssignments = Array.isArray(record.roles) ? record.roles : [];
  const roles = roleAssignments
    .map((entry) => entry.role)
    .filter(Boolean)
    .map((role) => ({
      id: safePublicId(role.human_friendly_id, role.id),
      name: role.name
    }));

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    email: record.email || null,
    phone: record.phone || null,
    position_title: record.position_title || null,
    status: record.status || null,
    tenant_id: safePublicId(record.tenant_id),
    facility_id: safePublicId(record.facility_id),
    profile_name: profile
      ? [profile.first_name, profile.last_name].filter(Boolean).join(' ').trim() || null
      : null,
    roles,
    role_count: roles.length,
    is_demo: record.is_demo === true,
    updated_at: record.updated_at || null
  };
};

const serializeAccessAdminRoleEntity = (record) => {
  if (!record) return null;

  const permissions = (record.permissions || [])
    .map((entry) => entry.permission)
    .filter(Boolean)
    .map((permission) => ({
      id: safePublicId(permission.human_friendly_id, permission.id),
      name: permission.name
    }));

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    name: record.name,
    display_name: record.display_name || record.name,
    description: record.description || null,
    tenant_id: safePublicId(record.tenant_id),
    facility_id: safePublicId(record.facility_id),
    permission_count: permissions.length,
    permissions,
    user_count: record._count?.users || 0,
    updated_at: record.updated_at || null
  };
};

module.exports = {
  serializeAccessAdminUserEntity,
  serializeAccessAdminRoleEntity
};
