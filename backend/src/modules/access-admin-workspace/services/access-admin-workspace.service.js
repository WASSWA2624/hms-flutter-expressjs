const { HttpError } = require('@lib/errors');
const { hashPassword } = require('@lib/crypto/hashPassword');
const { resolvePublicIdentifier, resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const { ROLES } = require('@config/roles');
const { ROLE_PERMISSIONS } = require('@config/permissions');
const { ensureTenantAccessCatalog, ensureTenantPermissionCatalog } = require('@lib/authorization/permission-catalog-sync');
const { createAuditLog } = require('@lib/audit');
const { provisionTrialSubscription } = require('@lib/subscriptions/tenant-onboarding');
const { listPendingPaymentRequests } = require('@lib/subscriptions/subscription-payment-request');
const authRepository = require('@repositories/auth/auth.repository');
const repository = require('@repositories/access-admin-workspace/access-admin-workspace.repository');

const DEFAULT_DEMO_RESET_PASSWORD = process.env.DEMO_RESET_PASSWORD || 'Hosspi@2624.';

const ACCESS_RESOURCES = [
  'users',
  'roles',
  'permissions',
  'user-roles',
  'role-permissions',
  'demo-users',
  'module-entitlements',
  'registration-follow-ups',
  'subscription-payment-requests',
];

const ACCESS_PANELS = [
  { id: 'overview', label_key: 'access_admin.panels.overview', default_resource: 'users' },
  { id: 'directory', label_key: 'access_admin.panels.directory', default_resource: 'users' },
  { id: 'roles', label_key: 'access_admin.panels.roles', default_resource: 'roles' },
  { id: 'permissions', label_key: 'access_admin.panels.permissions', default_resource: 'permissions' },
  { id: 'entitlements', label_key: 'access_admin.panels.entitlements', default_resource: 'module-entitlements' },
  { id: 'registrations', label_key: 'access_admin.panels.registrations', default_resource: 'registration-follow-ups' },
  { id: 'payments', label_key: 'access_admin.panels.payments', default_resource: 'subscription-payment-requests' },
  { id: 'demo', label_key: 'access_admin.panels.demo', default_resource: 'demo-users' },
];

const PANEL_RESOURCE_MAP = ACCESS_PANELS.reduce((acc, panel) => {
  acc[panel.id] = panel.default_resource;
  return acc;
}, {});

const RESOURCE_PANEL_MAP = {
  users: 'directory',
  roles: 'roles',
  permissions: 'permissions',
  'user-roles': 'roles',
  'role-permissions': 'permissions',
  'demo-users': 'demo',
  'module-entitlements': 'entitlements',
  'registration-follow-ups': 'registrations',
  'subscription-payment-requests': 'payments',
};

const CLINICAL_FLOW_ROLES = new Set([
  ROLES.RECEPTIONIST,
  ROLES.NURSE,
  ROLES.DOCTOR,
  ROLES.BILLING,
  ROLES.LAB_TECH,
  ROLES.RADIOLOGY_TECH,
  ROLES.PHARMACIST,
  ROLES.WARD_MANAGER,
  ROLES.ICU_MANAGER,
]);

const SYSTEM_CRITICAL_ROLES = new Set([ROLES.SUPER_ADMIN]);

const text = (value) => String(value || '').trim();
const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const roleList = (user = {}) => {
  const roles = Array.isArray(user.roles) ? user.roles : [user.role];
  return roles
    .map((entry) => {
      if (typeof entry === 'string') {
        return entry.trim().toUpperCase();
      }
      if (entry && typeof entry === 'object') {
        return String(entry.name || entry.role_name || entry.role?.name || '').trim().toUpperCase();
      }
      return String(entry || '').trim().toUpperCase();
    })
    .filter(Boolean);
};

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
  hasNextPage: page * limit < total,
  hasPreviousPage: page > 1,
});

const canWriteAccess = (user = {}) => {
  const writeRoles = new Set([
    ROLES.SUPER_ADMIN,
    ROLES.TENANT_ADMIN,
    ROLES.FACILITY_ADMIN,
    ROLES.OPERATIONS,
  ]);
  return roleList(user).some((entry) => writeRoles.has(entry));
};

const isSuperAdmin = (user = {}) => roleList(user).includes(ROLES.SUPER_ADMIN);

const requireSuperAdmin = (user = {}) => {
  if (!isSuperAdmin(user)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }
};

const serializeUser = (record) => {
  if (!record) return null;

  const profile = record.profile || null;
  const staffProfile = record.staff_profile || null;
  const roleAssignments = Array.isArray(record.roles) ? record.roles : [];
  const roles = roleAssignments
    .map((entry) => entry.role)
    .filter(Boolean)
    .map((role) => ({
      id: safePublicId(role.human_friendly_id, role.id),
      name: role.name,
    }));

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    resource_uuid: record.id,
    display_id: safePublicId(record.human_friendly_id, record.id),
    email: record.email,
    phone: record.phone || null,
    position_title: record.position_title,
    status: record.status,
    tenant_id: safePublicId(record.tenant_id),
    facility_id: safePublicId(record.facility_id),
    profile_name: profile
      ? [profile.first_name, profile.last_name].filter(Boolean).join(' ').trim() || null
      : null,
    staff_profile_id: staffProfile
      ? safePublicId(staffProfile.human_friendly_id, staffProfile.id)
      : null,
    roles,
    role_count: roles.length,
    is_demo: repository.isDemoUser(record),
    updated_at: record.updated_at,
  };
};

const serializeRole = (record) => {
  if (!record) return null;

  const permissions = (record.permissions || [])
    .map((entry) => entry.permission)
    .filter(Boolean)
    .map((permission) => ({
      id: safePublicId(permission.human_friendly_id, permission.id),
      name: permission.name,
    }));

  const roleName = String(record.name || '').trim().toUpperCase();

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    resource_uuid: record.id,
    display_id: safePublicId(record.human_friendly_id, record.id),
    name: record.name,
    display_name: record.display_name || record.name,
    description: record.description || null,
    tenant_id: safePublicId(record.tenant_id),
    facility_id: safePublicId(record.facility_id),
    permission_count: permissions.length,
    permissions,
    user_count: record._count?.users || 0,
    is_clinical_flow_role: CLINICAL_FLOW_ROLES.has(roleName),
    is_system_critical: SYSTEM_CRITICAL_ROLES.has(roleName),
    updated_at: record.updated_at,
  };
};

const serializePermission = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    resource_uuid: record.id,
    display_id: safePublicId(record.human_friendly_id, record.id),
    name: record.name,
    display_name: record.display_name || record.name,
    description: record.description || null,
    tenant_id: safePublicId(record.tenant_id),
    role_count: record._count?.roles || 0,
    user_count: record._count?.users || 0,
    updated_at: record.updated_at,
  };
};

const serializeUserRole = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    resource_uuid: record.id,
    display_id: safePublicId(record.human_friendly_id, record.id),
    user_id: safePublicId(record.user?.human_friendly_id, record.user_id),
    user_label: record.user?.email || record.user?.position_title || null,
    role_id: safePublicId(record.role?.human_friendly_id, record.role_id),
    role_name: record.role?.name || null,
    tenant_id: safePublicId(record.tenant_id),
    facility_id: safePublicId(record.facility_id),
    updated_at: record.updated_at,
  };
};

const serializeRolePermission = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    resource_uuid: record.id,
    display_id: safePublicId(record.human_friendly_id, record.id),
    role_id: safePublicId(record.role?.human_friendly_id, record.role_id),
    role_name: record.role?.name || null,
    permission_id: safePublicId(record.permission?.human_friendly_id, record.permission_id),
    permission_name: record.permission?.name || null,
    updated_at: record.updated_at,
  };
};

const serializeModuleEntitlement = (record, subscription = null) => {
  if (!record) return null;

  const module = record.module || {};

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    resource_uuid: record.id,
    display_id: safePublicId(record.human_friendly_id, record.id),
    module_id: safePublicId(module.human_friendly_id, record.module_id),
    module_label: module.name || null,
    module_slug: module.slug || null,
    module_group: module.module_group || null,
    subscription_id: subscription
      ? safePublicId(subscription.human_friendly_id, subscription.id)
      : null,
    plan_label: subscription?.plan?.name || null,
    is_active: Boolean(record.is_active),
    entitlement_denied: Boolean(record.entitlement_denied),
    entitlement_denial_reason: record.entitlement_denial_reason || null,
    updated_at: record.updated_at,
  };
};

const serializeRegistrationFollowUp = (record = {}) => {
  const user = record.user || {};
  const tenant = record.tenant || user.tenant || null;
  const facility = record.facility || user.facility || null;

  return {
    id: safePublicId(user.human_friendly_id, user.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    user_id: safePublicId(user.human_friendly_id, user.id),
    email: record.email || user.email || null,
    phone: record.phone || user.phone || null,
    admin_name: record.admin_name || null,
    facility_name: record.facility_name || facility?.name || null,
    tenant_name: tenant?.name || record.facility_name || null,
    facility_type: record.facility_type || facility?.facility_type || null,
    status: 'PENDING_APPROVAL',
    registered_at: record.first_registered_at || record.created_at || null,
    email_verified_at: user.email_verified_at || null,
    location: record.location || null,
    interests: record.interests || null,
    updated_at: record.updated_at || user.updated_at || null,
  };
};

const serializeUserDetail = (record) => {
  const base = serializeUser(record);
  if (!base) return null;

  const directPermissions = (record.permissions || [])
    .map((entry) => entry.permission)
    .filter(Boolean)
    .map((permission) => ({
      id: safePublicId(permission.human_friendly_id, permission.id),
      name: permission.name,
    }));

  const rolePermissions = (record.roles || [])
    .flatMap((entry) => {
      const roleName = String(entry.role?.name || '').trim().toUpperCase();
      const mapped = ROLE_PERMISSIONS[roleName] || [];
      return mapped.map((name) => ({ name, source_role: roleName }));
    });

  const effectivePermissionNames = new Set([
    ...directPermissions.map((entry) => entry.name),
    ...rolePermissions.map((entry) => entry.name),
  ]);

  return {
    ...base,
    direct_permissions: directPermissions,
    effective_permissions: [...effectivePermissionNames].sort(),
    role_permission_preview: rolePermissions,
  };
};

const buildLookups = (records = {}) => ({
  tenants: (records.tenants || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label: entry.name,
  })),
  facilities: (records.facilities || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label: entry.name,
    facility_type: entry.facility_type || null,
  })),
  roles: (records.roles || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label: entry.name,
    display_name: entry.display_name || entry.name,
    facility_id: safePublicId(entry.facility_id),
  })),
  permissions: (records.permissions || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label: entry.name,
    display_name: entry.display_name || entry.name,
    description: entry.description || null,
  })),
  user_statuses: ['ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING'],
  clinical_flow_roles: [...CLINICAL_FLOW_ROLES],
});

const buildOverview = (summary = {}, subscriptionRecord = null) => ({
  active_users: summary.active_users || 0,
  inactive_users: summary.inactive_users || 0,
  total_roles: summary.total_roles || 0,
  total_permissions: summary.total_permissions || 0,
  total_assignments: summary.total_assignments || 0,
  demo_users: summary.demo_users || 0,
  subscription_plan: subscriptionRecord?.plan?.name || null,
  active_modules_count: (subscriptionRecord?.module_subscriptions || []).filter(
    (entry) => entry.is_active && !entry.entitlement_denied
  ).length,
});

const resolveResource = (query = {}) => {
  const panel = text(query.panel).toLowerCase() || 'overview';
  const resource = text(query.resource).toLowerCase() || PANEL_RESOURCE_MAP[panel] || 'users';
  if (!ACCESS_RESOURCES.includes(resource)) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'resource' }]);
  }
  return { panel, resource };
};

const serializeItems = (resource, items = [], subscription = null) => {
  switch (resource) {
    case 'users':
    case 'demo-users':
      return items.map(serializeUser);
    case 'roles':
      return items.map(serializeRole);
    case 'permissions':
      return items.map(serializePermission);
    case 'user-roles':
      return items.map(serializeUserRole);
    case 'role-permissions':
      return items.map(serializeRolePermission);
    case 'module-entitlements':
      return items.map((entry) => serializeModuleEntitlement(entry, subscription));
    case 'registration-follow-ups':
      return items.map(serializeRegistrationFollowUp);
    case 'subscription-payment-requests':
      return items;
    default:
      return [];
  }
};

const findItemsForResource = async (resource, scope, filters, skip, take) => {
  if (resource === 'demo-users') {
    return repository.findUsers({
      scope,
      filters: { ...filters, is_demo: true },
      skip,
      take,
    });
  }

  if (resource === 'module-entitlements') {
    const result = await repository.findModuleEntitlements(scope);
    const items = result.items || [];
    return {
      items,
      total: result.total || items.length,
      subscription: result.subscription || null,
    };
  }

  if (resource === 'registration-follow-ups') {
    const result = await authRepository.findPendingRegistrationApprovals({
      skip,
      take,
      search: filters.search,
    });
    return {
      items: result.items || [],
      total: result.total || 0,
    };
  }

  if (resource === 'subscription-payment-requests') {
    const items = await listPendingPaymentRequests();
    const search = String(filters.search || '').trim().toLowerCase();
    const filtered = search
      ? items.filter((entry) => {
          const haystack = [
            entry.tenant_label,
            entry.plan_label,
            entry.reference,
            entry.submitted_by_email,
          ]
            .filter(Boolean)
            .join(' ')
            .toLowerCase();
          return haystack.includes(search);
        })
      : items;
    return {
      items: filtered.slice(skip, skip + take),
      total: filtered.length,
    };
  }

  const finderMap = {
    users: repository.findUsers,
    roles: repository.findRoles,
    permissions: repository.findPermissions,
    'user-roles': repository.findUserRoles,
    'role-permissions': repository.findRolePermissions,
  };

  const finder = finderMap[resource];
  if (!finder) {
    return { items: [], total: 0 };
  }

  return finder({ scope, filters, skip, take });
};

const maybeSyncTenantAccessCatalog = async (scope = {}) => {
  const tenantId = scope?.tenant_id;
  if (!tenantId) {
    return;
  }
  await ensureTenantAccessCatalog(tenantId);
};

const getWorkspace = async (query = {}, page = 1, limit = 20, user = {}) => {
  const { panel, resource } = resolveResource(query);
  const isRegistrationQueue = resource === 'registration-follow-ups';
  const isPaymentRequestQueue = resource === 'subscription-payment-requests';

  if (isRegistrationQueue || isPaymentRequestQueue) {
    requireSuperAdmin(user);
  }

  const scopeResult = isRegistrationQueue || isPaymentRequestQueue
    ? { state: 'ready', scope: { tenant_id: null, facility_id: null } }
    : await repository.resolveWorkspaceScope({ filters: query, user });
  const includeAllTenants = roleList(user).includes(ROLES.SUPER_ADMIN);

  if (!isRegistrationQueue && !isPaymentRequestQueue && scopeResult.state === 'tenant_context_required') {
    const lookups = await repository.findLookups(null, includeAllTenants);
    return {
      state: 'tenant_context_required',
      generated_at: new Date().toISOString(),
      summary: {},
      panel_summaries: ACCESS_PANELS.map((entry) => ({
        id: entry.id,
        label_key: entry.label_key,
        default_resource: entry.default_resource,
      })),
      filters: { panel, resource, tenant_id: null, facility_id: null },
      lookups: buildLookups(lookups),
      items: [],
      pagination: buildPagination(page, limit, 0),
      overview: buildOverview(),
      permissions: {
        can_read: true,
        can_write: canWriteAccess(user),
        can_reset_demo_passwords:
          canWriteAccess(user) && process.env.NODE_ENV !== 'production',
      },
    };
  }

  const scope = scopeResult.scope;
  const filters = {
    search: text(query.search),
    status: text(query.status).toUpperCase() || null,
    user_id: text(query.userId || query.user_id) || null,
    role_id: text(query.roleId || query.role_id) || null,
  };

  const skip = (page - 1) * limit;
  if (!isRegistrationQueue && !isPaymentRequestQueue) {
    await maybeSyncTenantAccessCatalog(scope);
  }
  const [summary, lookups, itemsResult] = isRegistrationQueue
    ? [
        {},
        { tenants: [], facilities: [], roles: [], permissions: [] },
        await findItemsForResource(resource, scope, filters, skip, limit),
      ]
    : await Promise.all([
        repository.findSummary(scope),
        repository.findLookups(scope, includeAllTenants),
        findItemsForResource(resource, scope, filters, skip, limit),
      ]);

  const subscription = itemsResult.subscription || null;
  const overviewSubscription = isRegistrationQueue
    ? null
    : resource === 'module-entitlements'
      ? subscription
      : (await repository.findModuleEntitlements(scope)).subscription;

  const visiblePanels = isSuperAdmin(user)
    ? ACCESS_PANELS
    : ACCESS_PANELS.filter((entry) => entry.id !== 'registrations');

  return {
    state: 'ready',
    generated_at: new Date().toISOString(),
    summary,
    panel_summaries: visiblePanels.map((entry) => ({
      id: entry.id,
      label_key: entry.label_key,
      default_resource: entry.default_resource,
    })),
    filters: {
      panel,
      resource,
      search: filters.search,
      status: filters.status,
      tenant_id: safePublicId(undefined, scope.tenant_id),
      facility_id: safePublicId(undefined, scope.facility_id),
      user_id: filters.user_id,
      role_id: filters.role_id,
      record_id: text(query.id || query.recordId) || null,
    },
    lookups: buildLookups(lookups),
    items: serializeItems(resource, itemsResult.items || [], subscription),
    pagination: buildPagination(page, limit, Number(itemsResult.total || 0)),
    overview: buildOverview(summary, overviewSubscription),
    permissions: {
      can_read: true,
      can_write: canWriteAccess(user),
      can_reset_demo_passwords:
        canWriteAccess(user) && process.env.NODE_ENV !== 'production',
    },
  };
};

const loadAssignablePermissionCatalog = async (tenantId) => {
  if (!tenantId) {
    return [];
  }
  return ensureTenantPermissionCatalog(tenantId);
};

const getReferenceData = async (query = {}, user = {}) => {
  const includeAllTenants = roleList(user).includes(ROLES.SUPER_ADMIN);
  const requestedTenantId = text(query.tenant_id || query.tenantId);
  const canAssignPermissions = canWriteAccess(user);

  if (requestedTenantId && canAssignPermissions) {
    const tenantId = await resolveIdentifierForFilter({
      value: requestedTenantId,
      model: 'tenant',
    });
    if (tenantId) {
      const [permissions, lookups] = await Promise.all([
        loadAssignablePermissionCatalog(tenantId),
        repository.findLookups(
          { tenant_id: tenantId, facility_id: null },
          includeAllTenants
        ),
      ]);
      return buildLookups({
        ...lookups,
        permissions,
      });
    }
  }

  const scopeResult = await repository.resolveWorkspaceScope({ filters: query, user });

  if (scopeResult.state === 'tenant_context_required') {
    const lookups = await repository.findLookups(null, includeAllTenants);
    return {
      ...buildLookups(lookups),
      permissions: [],
    };
  }

  const scope = scopeResult.scope;
  const [permissions, lookups] = await Promise.all([
    canAssignPermissions ? loadAssignablePermissionCatalog(scope.tenant_id) : Promise.resolve([]),
    repository.findLookups(scope, includeAllTenants),
  ]);

  return buildLookups({
    ...lookups,
    permissions: canAssignPermissions && permissions.length > 0
      ? permissions
      : lookups.permissions,
  });
};

const getUserDetail = async (identifier, query = {}, user = {}) => {
  const scopeResult = await repository.resolveWorkspaceScope({ filters: query, user });
  if (scopeResult.state === 'tenant_context_required') {
    throw new HttpError('errors.auth.scope_mismatch', 403);
  }

  const record = await repository.findUserByIdentifier(identifier, scopeResult.scope);
  if (!record) {
    throw new HttpError('errors.not_found', 404);
  }

  return serializeUserDetail(record);
};

const resetDemoUserPassword = async (identifier, user = {}) => {
  if (process.env.NODE_ENV === 'production') {
    throw new HttpError('errors.access_admin.demo_reset_not_allowed', 403);
  }

  if (!canWriteAccess(user)) {
    throw new HttpError('errors.auth.forbidden', 403);
  }

  const scopeResult = await repository.resolveWorkspaceScope({ filters: {}, user });
  if (scopeResult.state === 'tenant_context_required') {
    throw new HttpError('errors.auth.scope_mismatch', 403);
  }

  const record = await repository.findUserByIdentifier(identifier, scopeResult.scope);
  if (!record) {
    throw new HttpError('errors.not_found', 404);
  }

  if (!repository.isDemoUser(record)) {
    throw new HttpError('errors.access_admin.not_demo_user', 400);
  }

  const passwordHash = await hashPassword(DEFAULT_DEMO_RESET_PASSWORD);
  await repository.resetDemoUserPassword(record.id, passwordHash);

  return {
    user_id: safePublicId(record.human_friendly_id, record.id),
    email: record.email,
    reset_at: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
  };
};

const resolveLegacyRoute = async (resource, identifier) => {
  const normalizedResource = text(resource).toLowerCase();
  if (!ACCESS_RESOURCES.includes(normalizedResource)) {
    throw new HttpError('errors.not_found', 404);
  }

  return {
    panel: RESOURCE_PANEL_MAP[normalizedResource] || 'directory',
    resource: normalizedResource,
    id: text(identifier) || null,
    action: 'view',
  };
};

const loadRegistrationUser = async (userIdentifier) => {
  const scopedUser = await repository.findUserByIdentifier(userIdentifier, {
    tenant_id: null,
    facility_id: null,
  });

  if (!scopedUser?.id) {
    throw new HttpError('errors.auth.registration_not_pending', 404);
  }

  const user = await authRepository.findUserById(scopedUser.id);
  if (!user || user.status !== 'PENDING' || !user.email_verified_at) {
    throw new HttpError('errors.auth.registration_not_pending', 404);
  }

  return user;
};

const activateRegistration = async (userIdentifier, actor = {}, ip = null) => {
  requireSuperAdmin(actor);
  const user = await loadRegistrationUser(userIdentifier);

  await authRepository.updateUserStatus(user.id, 'ACTIVE');
  await authRepository.updateRegistrationFollowUpStatus(user.id, 'ACTIVE').catch(() => {});
  await provisionTrialSubscription(user.tenant_id);

  await createAuditLog({
    action: 'TENANT_REGISTRATION_ACTIVATED',
    entity: 'user',
    entity_id: user.id,
    user_id: actor.id || null,
    tenant_id: user.tenant_id,
    facility_id: user.facility_id,
    ip_address: ip,
    details: {
      email: user.email,
      phone: user.phone || null,
    },
  }).catch(() => {});

  return serializeRegistrationFollowUp({
    email: user.email,
    phone: user.phone,
    user: { ...user, status: 'ACTIVE' },
    facility_name: user.facility?.name || null,
    facility_type: user.facility?.facility_type || null,
    tenant: user.tenant || null,
    facility: user.facility || null,
    account_status: 'ACTIVE',
    status: 'ACTIVE',
    updated_at: new Date(),
  });
};

const rejectRegistration = async (userIdentifier, actor = {}, ip = null) => {
  requireSuperAdmin(actor);
  const user = await loadRegistrationUser(userIdentifier);

  await authRepository.updateUserStatus(user.id, 'INACTIVE');
  await authRepository.updateRegistrationFollowUpStatus(user.id, 'INACTIVE').catch(() => {});

  await createAuditLog({
    action: 'TENANT_REGISTRATION_REJECTED',
    entity: 'user',
    entity_id: user.id,
    user_id: actor.id || null,
    tenant_id: user.tenant_id,
    facility_id: user.facility_id,
    ip_address: ip,
    details: {
      email: user.email,
      phone: user.phone || null,
    },
  }).catch(() => {});

  return { status: 'INACTIVE' };
};

module.exports = {
  activateRegistration,
  getReferenceData,
  getUserDetail,
  getWorkspace,
  rejectRegistration,
  resetDemoUserPassword,
  resolveLegacyRoute,
};
