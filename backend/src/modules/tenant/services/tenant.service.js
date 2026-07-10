/**
 * Tenant service
 *
 * @module modules/tenant/services
 * @description Business logic for tenant operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const tenantRepository = require('@repositories/tenant/tenant.repository');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT, MAX_PAGE_LIMIT } = require('@config/constants');
const { PLATFORM_ADMIN_EVENTS } = require('@lib/websocket/events');
const {
  publishPlatformRealtimeEvent,
  buildTenantDashboardDeltas,
  buildFacilityDashboardDeltas
} = require('@lib/realtime/platform-realtime');
const { resolveModelIdByIdentifier, resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');

const publishTenantRealtimeEvent = async (
  event,
  tenant,
  actorUserId,
  operation = 'create',
  before = null
) => {
  await publishPlatformRealtimeEvent({
    event,
    resource_type: 'tenant',
    resource_id: tenant?.id || null,
    actor_user_id: actorUserId || null,
    dashboard_deltas: buildTenantDashboardDeltas(tenant, operation, before),
    payload: {
      is_active: tenant?.is_active !== false,
      name: tenant?.name || null
    }
  });
};

const resolveTenantId = async (identifier) => {
  const normalized = String(identifier ?? '').trim();
  if (!normalized) {
    return normalized;
  }

  const resolved = await resolveModelIdByIdentifier({
    model: 'tenant',
    identifier: normalized,
    additionalFriendlyMatchers: [
      (value) => ({ slug: value.toLowerCase() }),
    ],
  });

  return resolved || normalized;
};

const buildDefaultFacilityName = (tenantName) => {
  const normalized = String(tenantName || '').trim();
  if (!normalized) {
    return 'Main Facility';
  }
  return `${normalized} Main Facility`;
};

const normalizeString = (value) => {
  const normalized = String(value ?? '').trim();
  return normalized || null;
};

const toPositiveInt = (value, fallback, max = Number.POSITIVE_INFINITY) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  const normalized = Math.trunc(parsed);
  if (normalized <= 0) return fallback;
  return Math.min(normalized, max);
};

const normalizeSortOrder = (value) => {
  const normalized = String(value || 'desc').toLowerCase();
  return normalized === 'asc' ? 'asc' : 'desc';
};

const buildFullName = (...parts) => {
  const tokens = parts.map(normalizeString).filter(Boolean);
  return tokens.length > 0 ? tokens.join(' ') : null;
};

const buildPrimaryTenantAdmin = (userRole = null) => {
  const user = userRole?.user;
  if (!user || typeof user !== 'object') return null;

  const profile = user.profile || {};
  const role = userRole?.role || {};

  return {
    id: normalizeString(user.id),
    human_friendly_id: normalizeString(user.human_friendly_id),
    email: normalizeString(user.email),
    phone: normalizeString(user.phone),
    status: normalizeString(user.status),
    first_name: normalizeString(profile.first_name),
    middle_name: normalizeString(profile.middle_name),
    last_name: normalizeString(profile.last_name),
    full_name: buildFullName(profile.first_name, profile.middle_name, profile.last_name),
    facility_id: normalizeString(user.facility_id || userRole?.facility_id),
    facility_name: normalizeString(user?.facility?.name),
    role_id: normalizeString(role.id || userRole?.role_id),
    role_human_friendly_id: normalizeString(role.human_friendly_id),
    role_name: normalizeString(role.name || 'TENANT_ADMIN'),
    user_role_id: normalizeString(userRole?.id),
    user_role_human_friendly_id: normalizeString(userRole?.human_friendly_id),
  };
};

const normalizeTenantRecord = (tenant) => {
  if (!tenant || typeof tenant !== 'object') return tenant;

  const normalized = {
    ...tenant,
    resource_uuid: tenant.id,
    display_id:
      resolvePublicIdentifier(tenant.human_friendly_id, tenant.id) || tenant.id,
  };

  if (!Array.isArray(tenant.user_roles)) {
    return normalized;
  }

  const { user_roles, ...tenantRecord } = normalized;
  return {
    ...tenantRecord,
    primary_tenant_admin: buildPrimaryTenantAdmin(user_roles[0] || null),
  };
};

/**
 * List tenants with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {boolean} [filters.is_active] - Filter by active status
 * @param {string} [filters.search] - Search by name or slug
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated tenants
 */
const listTenants = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  const resolvedPage = toPositiveInt(page, DEFAULT_PAGE);
  const resolvedLimit = toPositiveInt(limit, DEFAULT_PAGE_LIMIT, MAX_PAGE_LIMIT);
  const resolvedSortBy = typeof sort_by === 'string' && sort_by.trim()
    ? sort_by.trim()
    : 'created_at';
  const resolvedOrder = normalizeSortOrder(order);
  const includeDeleted =
    filters.include_deleted === true || filters.include_deleted === 'true';

  // Build repository filters
  const repoFilters = {};

  if (filters.is_active !== undefined) {
    repoFilters.is_active = filters.is_active === true || filters.is_active === 'true';
  }

  // Handle search filter
  if (filters.search) {
    repoFilters.OR = [
      { name: { contains: filters.search } },
      { slug: { contains: filters.search } }
    ];
  }

  // Calculate pagination
  const skip = (resolvedPage - 1) * resolvedLimit;

  // Build sort order
  const orderBy = includeDeleted
    ? [
        { deleted_at: 'asc' },
        { [resolvedSortBy]: resolvedOrder },
      ]
    : { [resolvedSortBy]: resolvedOrder };

  const listOptions = { includeDeleted };

  // Fetch tenants and count
  const [tenants, total] = await Promise.all([
    tenantRepository.findMany(repoFilters, skip, resolvedLimit, orderBy, listOptions),
    tenantRepository.count(repoFilters, listOptions)
  ]);

  // Calculate pagination metadata
  const totalPages = Math.ceil(total / resolvedLimit);
  const hasNextPage = resolvedPage < totalPages;
  const hasPreviousPage = resolvedPage > 1;

  return {
    tenants: tenants.map((tenant) => normalizeTenantRecord(tenant)),
    pagination: {
      page: resolvedPage,
      limit: resolvedLimit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage
    }
  };
};

/**
 * Get tenant by ID
 *
 * @param {string} id - Tenant ID
 * @returns {Promise<Object>} Tenant data
 */
const getTenantById = async (id) => {
  const tenantId = await resolveTenantId(id);
  const tenant = await tenantRepository.findById(tenantId);
  
  if (!tenant) {
    throw new HttpError('errors.tenant.not_found', 404);
  }

  return normalizeTenantRecord(tenant);
};

/**
 * Create new tenant
 *
 * @param {Object} data - Tenant data
 * @param {string} data.name - Tenant name
 * @param {string} [data.slug] - Tenant slug
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Created tenant
 */
const createTenant = async (data, context = {}) => {
  if (data?.slug) {
    await tenantRepository.releaseSlugFromSoftDeletedTenants(data.slug);
  }

  const { tenant, facility } = await tenantRepository.createWithDefaultFacility(
    data,
    {
      facilityName: buildDefaultFacilityName(data?.name),
    },
  );

  // Create audit log
  await createAuditLog({
    action: 'TENANT_CREATED',
    entity: 'tenant',
    entity_id: tenant.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      name: tenant.name,
      slug: tenant.slug,
      is_active: tenant.is_active,
      default_facility_id: facility.id,
    }
  });

  await createAuditLog({
    action: 'FACILITY_CREATED',
    entity: 'facility',
    entity_id: facility.id,
    user_id: context.user_id,
    tenant_id: tenant.id,
    facility_id: facility.id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: facility.tenant_id,
      name: facility.name,
      facility_type: facility.facility_type,
      is_active: facility.is_active,
      bootstrap: true,
    }
  });

  await publishTenantRealtimeEvent(
    PLATFORM_ADMIN_EVENTS.TENANT_CREATED,
    tenant,
    context.user_id,
    'create'
  );

  await publishPlatformRealtimeEvent({
    event: PLATFORM_ADMIN_EVENTS.FACILITY_CREATED,
    resource_type: 'facility',
    resource_id: facility.id,
    actor_user_id: context.user_id || null,
    tenant_id: facility.tenant_id,
    facility_id: facility.id,
    dashboard_deltas: buildFacilityDashboardDeltas(facility, 'create'),
    payload: {
      is_active: facility.is_active !== false,
      name: facility.name || null,
      bootstrap: true,
    }
  });

  return normalizeTenantRecord(tenant);
};

/**
 * Update tenant
 *
 * @param {string} id - Tenant ID
 * @param {Object} data - Update data
 * @param {string} [data.name] - Tenant name
 * @param {string} [data.slug] - Tenant slug
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Updated tenant
 */
const updateTenant = async (id, data, context = {}) => {
  const tenantId = await resolveTenantId(id);
  // Check if tenant exists and get before state
  const beforeTenant = await tenantRepository.findById(tenantId);
  
  if (!beforeTenant) {
    throw new HttpError('errors.tenant.not_found', 404);
  }

  if (data?.slug) {
    await tenantRepository.releaseSlugFromSoftDeletedTenants(data.slug, tenantId);
  }

  // Update tenant
  const tenant = await tenantRepository.update(tenantId, data);

  // Create audit log
  await createAuditLog({
    action: 'TENANT_UPDATED',
    entity: 'tenant',
    entity_id: tenantId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        name: beforeTenant.name,
        slug: beforeTenant.slug,
        is_active: beforeTenant.is_active
      },
      after: {
        name: tenant.name,
        slug: tenant.slug,
        is_active: tenant.is_active
      }
    }
  });

  await publishTenantRealtimeEvent(
    PLATFORM_ADMIN_EVENTS.TENANT_UPDATED,
    tenant,
    context.user_id,
    'update',
    beforeTenant
  );

  return tenant;
};

/**
 * Delete tenant (soft delete)
 *
 * @param {string} id - Tenant ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const deleteTenant = async (id, context = {}) => {
  const normalizedId = String(id ?? '').trim();
  const tenantId = await resolveTenantId(normalizedId);
  const tenant = await tenantRepository.findById(tenantId);

  if (!tenant) {
    const lookupIds = [...new Set([tenantId, normalizedId].filter(Boolean))];
    for (const candidate of lookupIds) {
      const deletedTenant = await resolveModelRecordByIdentifier({
        model: 'tenant',
        identifier: candidate,
        includeDeleted: true,
        select: { id: true, deleted_at: true },
        additionalFriendlyMatchers: [
          (value) => ({ slug: value.toLowerCase() }),
        ],
      });
      if (deletedTenant?.deleted_at) {
        return;
      }
    }
    throw new HttpError('errors.tenant.not_found', 404);
  }

  // Soft delete tenant
  await tenantRepository.softDelete(tenantId);

  // Create audit log
  await createAuditLog({
    action: 'TENANT_DELETED',
    entity: 'tenant',
    entity_id: tenantId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      name: tenant.name,
      slug: tenant.slug
    }
  });

  await publishTenantRealtimeEvent(
    PLATFORM_ADMIN_EVENTS.TENANT_DELETED,
    tenant,
    context.user_id,
    'delete'
  );
};

const resolveTenantIdIncludingDeleted = async (identifier) => {
  const normalized = String(identifier ?? '').trim();
  if (!normalized) {
    return normalized;
  }

  const resolved = await resolveModelIdByIdentifier({
    model: 'tenant',
    identifier: normalized,
    includeDeleted: true,
    additionalFriendlyMatchers: [
      (value) => ({ slug: value.toLowerCase() }),
    ],
  });

  return resolved || normalized;
};

const assertNoActiveSubscriptions = async (tenantId) => {
  const activeSubscriptions = await prisma.subscription.count({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
    },
  });

  if (activeSubscriptions > 0) {
    throw new HttpError('errors.tenant.permanent_delete_blocked', 409, [
      { reason: 'active_subscription' },
    ]);
  }
};

/**
 * Restore soft-deleted tenant
 */
const restoreTenant = async (id, context = {}) => {
  const normalizedId = String(id ?? '').trim();
  const tenantId = await resolveTenantIdIncludingDeleted(normalizedId);
  const tenant = await tenantRepository.restore(tenantId);

  await createAuditLog({
    action: 'TENANT_RESTORED',
    entity: 'tenant',
    entity_id: tenantId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      name: tenant.name,
      slug: tenant.slug,
    },
  });

  await publishTenantRealtimeEvent(
    PLATFORM_ADMIN_EVENTS.TENANT_RESTORED,
    tenant,
    context.user_id,
    'create'
  );

  return normalizeTenantRecord(tenant);
};

/**
 * Permanently delete a soft-deleted tenant
 */
const permanentDeleteTenant = async (id, context = {}) => {
  const normalizedId = String(id ?? '').trim();
  const tenantId = await resolveTenantIdIncludingDeleted(normalizedId);
  const tenant = await tenantRepository.findById(tenantId, { includeDeleted: true });

  if (!tenant) {
    throw new HttpError('errors.tenant.not_found', 404);
  }
  if (!tenant.deleted_at) {
    throw new HttpError('errors.tenant.permanent_delete_requires_soft_delete', 400);
  }

  await assertNoActiveSubscriptions(tenantId);

  await createAuditLog({
    action: 'TENANT_PERMANENTLY_DELETED',
    entity: 'tenant',
    entity_id: tenantId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      name: tenant.name,
      slug: tenant.slug,
    },
  });

  await tenantRepository.permanentDelete(tenantId);

  await publishPlatformRealtimeEvent({
    event: PLATFORM_ADMIN_EVENTS.TENANT_PERMANENTLY_DELETED,
    resource_type: 'tenant',
    resource_id: tenantId,
    actor_user_id: context.user_id || null,
    payload: {
      name: tenant.name,
      permanent: true,
    },
  });
};

module.exports = {
  listTenants,
  getTenantById,
  createTenant,
  updateTenant,
  deleteTenant,
  restoreTenant,
  permanentDeleteTenant,
};
