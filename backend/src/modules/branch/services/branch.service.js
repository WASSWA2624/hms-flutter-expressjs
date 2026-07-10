/**
 * Branch service
 *
 * @module modules/branch/services
 * @description Business logic for branch operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const branchRepository = require('@repositories/branch/branch.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveEntityId } = require('@lib/billing/identifiers');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { publishCrudRealtimeEvent, FACILITY_LAYOUT_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');

const FACILITY_LAYOUT_RECIPIENT_ROLES = Object.freeze([
  ROLES.FACILITY_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.NURSE,
]);

const publishFacilityLayoutRealtimeEvent = async (resource, resourceType, actorUserId, payload = {}) => {
  await publishCrudRealtimeEvent({
    event: FACILITY_LAYOUT_EVENTS.FACILITY_LAYOUT_UPDATED,
    resource,
    resource_type: resourceType,
    actor_user_id: actorUserId,
    recipient_roles: FACILITY_LAYOUT_RECIPIENT_ROLES,
    affected: {
      branch_id: resource?.id || null,
    },
    payload: {
      layout_entity: resourceType,
      ...payload,
    },
  });
};

const resolveBranchId = async (identifier, { includeDeleted = false } = {}) => {
  const normalized = String(identifier ?? '').trim();
  if (!normalized) return normalized;

  if (includeDeleted) {
    const resolved = await resolveModelIdByIdentifier({
      model: 'branch',
      identifier: normalized,
      includeDeleted: true,
    });
    return resolved || normalized;
  }

  return resolveEntityId({ model: 'branch', identifier: normalized });
};

const resolveTenantId = async (identifier) =>
  resolveEntityId({ model: 'tenant', identifier });

const resolveFacilityId = async (identifier) =>
  resolveEntityId({ model: 'facility', identifier });

/**
 * List branches with pagination and filters
 */
const listBranches = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  const includeDeleted =
    filters.include_deleted === true || filters.include_deleted === 'true';
  const repoFilters = {};

  if (filters.tenant_id) {
    repoFilters.tenant_id = await resolveTenantId(filters.tenant_id);
  }

  if (filters.facility_id) {
    repoFilters.facility_id = await resolveFacilityId(filters.facility_id);
  }

  if (filters.is_active !== undefined) {
    repoFilters.is_active = filters.is_active === true || filters.is_active === 'true';
  }

  if (filters.search) {
    repoFilters.name = { contains: filters.search, mode: 'insensitive' };
  }

  const skip = (page - 1) * limit;
  const orderBy = includeDeleted
    ? [{ deleted_at: 'asc' }, { [sort_by]: order }]
    : { [sort_by]: order };
  const listOptions = { includeDeleted };

  const [branches, total] = await Promise.all([
    branchRepository.findMany(repoFilters, skip, limit, orderBy, listOptions),
    branchRepository.count(repoFilters, listOptions),
  ]);

  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    branches,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage,
    },
  };
};

/**
 * Get branch by ID
 */
const getBranchById = async (id) => {
  const branchId = await resolveBranchId(id);
  const branch = await branchRepository.findById(branchId);

  if (!branch) {
    throw new HttpError('errors.branch.not_found', 404);
  }

  return branch;
};

/**
 * Create new branch
 */
const createBranch = async (data, context = {}) => {
  const payload = {
    ...data,
    tenant_id: await resolveTenantId(data.tenant_id),
  };
  if (data.facility_id) {
    payload.facility_id = await resolveFacilityId(data.facility_id);
  }
  const branch = await branchRepository.create(payload);

  await createAuditLog({
    action: 'BRANCH_CREATED',
    entity: 'branch',
    entity_id: branch.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: branch.tenant_id,
      facility_id: branch.facility_id,
      name: branch.name,
      is_active: branch.is_active,
    },
  });

  await publishFacilityLayoutRealtimeEvent(branch, 'branch', context.user_id, {
    operation: 'created',
    name: branch.name,
  });

  return branch;
};

/**
 * Update branch
 */
const updateBranch = async (id, data, context = {}) => {
  const branchId = await resolveBranchId(id);
  const payload = { ...data };
  if (data.facility_id !== undefined && data.facility_id !== null) {
    payload.facility_id = await resolveFacilityId(data.facility_id);
  }
  const beforeBranch = await branchRepository.findById(branchId);

  if (!beforeBranch) {
    throw new HttpError('errors.branch.not_found', 404);
  }

  const branch = await branchRepository.update(branchId, payload);

  await createAuditLog({
    action: 'BRANCH_UPDATED',
    entity: 'branch',
    entity_id: branchId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeBranch.facility_id,
        name: beforeBranch.name,
        is_active: beforeBranch.is_active,
      },
      after: {
        facility_id: branch.facility_id,
        name: branch.name,
        is_active: branch.is_active,
      },
    },
  });

  await publishFacilityLayoutRealtimeEvent(branch, 'branch', context.user_id, {
    operation: 'updated',
    name: branch.name,
  });

  return branch;
};

/**
 * Delete branch (soft delete, cascade)
 */
const deleteBranch = async (id, context = {}) => {
  const normalizedId = String(id ?? '').trim();
  const branchId = await resolveBranchId(normalizedId);
  const branch = await branchRepository.findById(branchId);

  if (!branch) {
    const lookupIds = [...new Set([branchId, normalizedId].filter(Boolean))];
    for (const candidate of lookupIds) {
      const deletedBranch = await resolveModelRecordByIdentifier({
        model: 'branch',
        identifier: candidate,
        includeDeleted: true,
        select: { id: true, deleted_at: true },
      });
      if (deletedBranch?.deleted_at) {
        return;
      }
    }
    throw new HttpError('errors.branch.not_found', 404);
  }

  await branchRepository.softDelete(branchId);

  await createAuditLog({
    action: 'BRANCH_DELETED',
    entity: 'branch',
    entity_id: branchId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: branch.tenant_id,
      facility_id: branch.facility_id,
      name: branch.name,
    },
  });

  await publishFacilityLayoutRealtimeEvent(branch, 'branch', context.user_id, {
    operation: 'deleted',
    name: branch.name,
  });
};

/**
 * Restore soft-deleted branch
 */
const restoreBranch = async (id, context = {}) => {
  const branchId = await resolveBranchId(id, { includeDeleted: true });
  const branch = await branchRepository.restore(branchId);

  await createAuditLog({
    action: 'BRANCH_RESTORED',
    entity: 'branch',
    entity_id: branchId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: branch.tenant_id,
      facility_id: branch.facility_id,
      name: branch.name,
    },
  });

  await publishFacilityLayoutRealtimeEvent(branch, 'branch', context.user_id, {
    operation: 'restored',
    name: branch.name,
  });

  return branch;
};

module.exports = {
  listBranches,
  getBranchById,
  createBranch,
  updateBranch,
  deleteBranch,
  restoreBranch,
};
