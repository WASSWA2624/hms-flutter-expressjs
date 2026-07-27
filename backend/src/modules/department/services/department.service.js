/**
 * Department service
 *
 * @module modules/department/services
 * @description Business logic for department operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const departmentRepository = require('@repositories/department/department.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveEntityId, resolvePublicIdentifier, resolveIdentifierForPayload, resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const { publishCrudRealtimeEvent, FACILITY_LAYOUT_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');
const { checkDepartmentDuplicates } = require('@lib/department/department-similarity');

const DEPARTMENT_SIMILARITY_LOOKUP_LIMIT = 200;

const FACILITY_LAYOUT_RECIPIENT_ROLES = Object.freeze([
  ROLES.FACILITY_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.NURSE,
]);

const resolveEffectiveShortName = (name, shortName) => {
  const trimmedShort = String(shortName ?? '').trim();
  if (trimmedShort) return trimmedShort;
  return String(name ?? '').trim() || null;
};

const stripSimilarityPayloadFields = (data = {}) => {
  const { confirm_similar: _confirmSimilar, ...payload } = data;
  return payload;
};

const assertDepartmentUniqueness = async ({
  data,
  facilityId,
  confirmSimilar = false,
  excludeDepartmentId = null,
}) => {
  if (!facilityId) {
    return null;
  }

  const existing = await departmentRepository.findMany(
    { facility_id: facilityId },
    0,
    DEPARTMENT_SIMILARITY_LOOKUP_LIMIT,
    { name: 'asc' },
    { includeDeleted: false }
  );

  const duplicateCheck = checkDepartmentDuplicates({
    name: data.name,
    shortName: data.short_name,
    departmentType: data.department_type,
    isActive: data.is_active,
    existing,
    excludeDepartmentId,
  });

  if (duplicateCheck.exactNameConflict) {
    throw new HttpError('errors.department.duplicate_name', 409, [
      {
        field: 'name',
        matches: duplicateCheck.similarMatches
          .filter((match) => match.exactNameConflict)
          .slice(0, 5),
      },
    ]);
  }

  const reviewMatches = duplicateCheck.overridableMatches.slice(0, 5);
  if (reviewMatches.length > 0 && !confirmSimilar) {
    throw new HttpError('errors.department.similar_exists', 409, [
      {
        field: 'name',
        matches: reviewMatches,
      },
    ]);
  }

  return duplicateCheck;
};

const normalizeDepartmentRecord = (department) => {
  if (!department || typeof department !== 'object') {
    return department;
  }

  return {
    ...department,
    resource_uuid: department.id,
    display_id: resolvePublicIdentifier(department.human_friendly_id) || null,
  };
};

const publishFacilityLayoutRealtimeEvent = async (resource, resourceType, actorUserId, payload = {}) => {
  await publishCrudRealtimeEvent({
    event: FACILITY_LAYOUT_EVENTS.FACILITY_LAYOUT_UPDATED,
    resource,
    resource_type: resourceType,
    actor_user_id: actorUserId,
    recipient_roles: FACILITY_LAYOUT_RECIPIENT_ROLES,
    affected: {
      department_id: resource?.id || null,
    },
    payload: {
      layout_entity: resourceType,
      ...payload,
    },
  });
};

const resolveDepartmentId = async (identifier, { includeDeleted = false } = {}) => {
  const normalized = String(identifier ?? '').trim();
  if (!normalized) return normalized;

  if (includeDeleted) {
    const resolved = await resolveModelIdByIdentifier({
      model: 'department',
      identifier: normalized,
      includeDeleted: true,
    });
    return resolved || normalized;
  }

  return resolveEntityId({ model: 'department', identifier: normalized });
};

/**
 * List departments with pagination and filters
 */
const listDepartments = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  const includeDeleted =
    filters.include_deleted === true || filters.include_deleted === 'true';
  const repoFilters = {};

  const tenantId = await resolveIdentifierForFilter({
    value: filters.tenant_id,
    model: 'tenant',
    where: { deleted_at: null },
  });
  if (filters.tenant_id && tenantId === null) {
    return {
      departments: [],
      pagination: {
        page,
        limit,
        total: 0,
        totalPages: 0,
        hasNextPage: false,
        hasPreviousPage: page > 1,
      },
    };
  }
  if (tenantId) {
    repoFilters.tenant_id = tenantId;
  }

  const facilityId = await resolveIdentifierForFilter({
    value: filters.facility_id,
    model: 'facility',
    where: { deleted_at: null },
  });
  if (filters.facility_id && facilityId === null) {
    return {
      departments: [],
      pagination: {
        page,
        limit,
        total: 0,
        totalPages: 0,
        hasNextPage: false,
        hasPreviousPage: page > 1,
      },
    };
  }
  if (facilityId) {
    repoFilters.facility_id = facilityId;
  }

  if (filters.department_type) {
    repoFilters.department_type = filters.department_type;
  }

  if (filters.is_active !== undefined) {
    repoFilters.is_active = filters.is_active === true || filters.is_active === 'true';
  }

  if (filters.search) {
    // MySQL collation is case-insensitive; Prisma `mode: 'insensitive'` is unsupported.
    repoFilters.name = { contains: filters.search };
  }

  const skip = (page - 1) * limit;
  const orderBy = includeDeleted
    ? [{ deleted_at: 'asc' }, { [sort_by]: order }]
    : { [sort_by]: order };
  const listOptions = { includeDeleted };

  const [departments, total] = await Promise.all([
    departmentRepository.findMany(repoFilters, skip, limit, orderBy, listOptions),
    departmentRepository.count(repoFilters, listOptions),
  ]);

  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    departments: departments.map((department) =>
      normalizeDepartmentRecord(department)
    ),
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
 * Get department by ID
 */
const getDepartmentById = async (id) => {
  const departmentId = await resolveDepartmentId(id);
  const department = await departmentRepository.findById(departmentId);

  if (!department) {
    throw new HttpError('errors.department.not_found', 404);
  }

  return normalizeDepartmentRecord(department);
};

/**
 * Create new department
 */
const createDepartment = async (data, context = {}) => {
  const confirmSimilar = data?.confirm_similar === true;
  const payload = stripSimilarityPayloadFields(data);
  const name = String(payload.name ?? '').trim();
  const shortName = resolveEffectiveShortName(name, payload.short_name);
  const createPayload = {
    ...payload,
    name,
    short_name: shortName,
    tenant_id: await resolveIdentifierForPayload({
      value: payload.tenant_id,
      model: 'tenant',
      field: 'tenant_id',
      where: { deleted_at: null },
    }),
    facility_id: await resolveIdentifierForPayload({
      value: payload.facility_id,
      model: 'facility',
      field: 'facility_id',
      where: { deleted_at: null },
      nullable: true,
    }),
  };

  await assertDepartmentUniqueness({
    data: createPayload,
    facilityId: createPayload.facility_id,
    confirmSimilar,
  });

  const department = await departmentRepository.create(createPayload);

  await createAuditLog({
    action: 'DEPARTMENT_CREATED',
    entity: 'department',
    entity_id: department.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: department.tenant_id,
      facility_id: department.facility_id,
      name: department.name,
      short_name: department.short_name,
      department_type: department.department_type,
      is_active: department.is_active,
    },
  });

  await publishFacilityLayoutRealtimeEvent(department, 'department', context.user_id, {
    operation: 'created',
    name: department.name,
  });

  return normalizeDepartmentRecord(department);
};

/**
 * Update department
 */
const updateDepartment = async (id, data, context = {}) => {
  const departmentId = await resolveDepartmentId(id);
  const beforeDepartment = await departmentRepository.findById(departmentId);

  if (!beforeDepartment) {
    throw new HttpError('errors.department.not_found', 404);
  }

  const confirmSimilar = data?.confirm_similar === true;
  const payload = stripSimilarityPayloadFields(data);
  const nextName =
    payload.name !== undefined
      ? String(payload.name ?? '').trim()
      : beforeDepartment.name;
  const nextShortName =
    payload.short_name !== undefined
      ? resolveEffectiveShortName(nextName, payload.short_name)
      : beforeDepartment.short_name;
  const updatePayload = {
    ...payload,
    ...(payload.name !== undefined ? { name: nextName } : {}),
    ...(payload.short_name !== undefined || payload.name !== undefined
      ? { short_name: nextShortName }
      : {}),
  };

  if (Object.prototype.hasOwnProperty.call(payload, 'facility_id')) {
    updatePayload.facility_id = await resolveIdentifierForPayload({
      value: payload.facility_id,
      model: 'facility',
      field: 'facility_id',
      where: { deleted_at: null },
      nullable: true,
    });
  }

  await assertDepartmentUniqueness({
    data: {
      name: nextName,
      short_name: nextShortName,
      department_type:
        updatePayload.department_type ?? beforeDepartment.department_type,
      is_active:
        updatePayload.is_active !== undefined
          ? updatePayload.is_active
          : beforeDepartment.is_active,
    },
    facilityId: updatePayload.facility_id ?? beforeDepartment.facility_id,
    confirmSimilar,
    excludeDepartmentId: departmentId,
  });

  const department = await departmentRepository.update(departmentId, updatePayload);

  await createAuditLog({
    action: 'DEPARTMENT_UPDATED',
    entity: 'department',
    entity_id: departmentId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeDepartment.facility_id,
        name: beforeDepartment.name,
        short_name: beforeDepartment.short_name,
        department_type: beforeDepartment.department_type,
        is_active: beforeDepartment.is_active,
      },
      after: {
        facility_id: department.facility_id,
        name: department.name,
        short_name: department.short_name,
        department_type: department.department_type,
        is_active: department.is_active,
      },
    },
  });

  await publishFacilityLayoutRealtimeEvent(department, 'department', context.user_id, {
    operation: 'updated',
    name: department.name,
  });

  return normalizeDepartmentRecord(department);
};

/**
 * Delete department (soft delete, cascade)
 */
const deleteDepartment = async (id, context = {}) => {
  const normalizedId = String(id ?? '').trim();
  const departmentId = await resolveDepartmentId(normalizedId);
  const department = await departmentRepository.findById(departmentId);

  if (!department) {
    const lookupIds = [...new Set([departmentId, normalizedId].filter(Boolean))];
    for (const candidate of lookupIds) {
      const deletedDepartment = await resolveModelRecordByIdentifier({
        model: 'department',
        identifier: candidate,
        includeDeleted: true,
        select: { id: true, deleted_at: true },
      });
      if (deletedDepartment?.deleted_at) {
        return;
      }
    }
    throw new HttpError('errors.department.not_found', 404);
  }

  await departmentRepository.softDelete(departmentId);

  await createAuditLog({
    action: 'DEPARTMENT_DELETED',
    entity: 'department',
    entity_id: departmentId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: department.tenant_id,
      facility_id: department.facility_id,
      name: department.name,
      short_name: department.short_name,
      department_type: department.department_type,
    },
  });

  await publishFacilityLayoutRealtimeEvent(department, 'department', context.user_id, {
    operation: 'deleted',
    name: department.name,
  });
};

/**
 * Restore soft-deleted department
 */
const restoreDepartment = async (id, context = {}) => {
  const departmentId = await resolveDepartmentId(id, { includeDeleted: true });
  const department = await departmentRepository.restore(departmentId);

  await createAuditLog({
    action: 'DEPARTMENT_RESTORED',
    entity: 'department',
    entity_id: departmentId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: department.tenant_id,
      facility_id: department.facility_id,
      name: department.name,
    },
  });

  await publishFacilityLayoutRealtimeEvent(department, 'department', context.user_id, {
    operation: 'restored',
    name: department.name,
  });

  return normalizeDepartmentRecord(department);
};

/**
 * Permanently delete a soft-deleted department and related department-scoped data.
 */
const permanentDeleteDepartment = async (id, context = {}) => {
  const normalizedId = String(id ?? '').trim();
  const departmentId = await resolveDepartmentId(normalizedId, { includeDeleted: true });
  const department = await departmentRepository.findById(departmentId, {
    includeDeleted: true,
  });

  if (!department) {
    return;
  }
  if (!department.deleted_at) {
    throw new HttpError('errors.department.permanent_delete_requires_soft_delete', 400);
  }

  await createAuditLog({
    action: 'DEPARTMENT_PERMANENTLY_DELETED',
    entity: 'department',
    entity_id: departmentId,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: department.tenant_id,
      facility_id: department.facility_id,
      name: department.name,
      short_name: department.short_name,
      department_type: department.department_type,
      irreversible: true,
    },
  });

  await departmentRepository.permanentDelete(departmentId);

  await publishFacilityLayoutRealtimeEvent(department, 'department', context.user_id, {
    operation: 'permanently_deleted',
    name: department.name,
    permanent: true,
  });
};

/**
 * Get department units (nested resource)
 */
const getDepartmentUnits = async (departmentId, page = 1, limit = 20) => {
  const resolvedId = await resolveDepartmentId(departmentId);
  const department = await departmentRepository.findById(resolvedId);

  if (!department) {
    throw new HttpError('errors.department.not_found', 404);
  }

  const unitService = require('@services/unit/unit.service');

  return await unitService.listUnits(
    { department_id: resolvedId },
    page,
    limit
  );
};

module.exports = {
  listDepartments,
  getDepartmentById,
  createDepartment,
  updateDepartment,
  deleteDepartment,
  restoreDepartment,
  permanentDeleteDepartment,
  getDepartmentUnits,
};
