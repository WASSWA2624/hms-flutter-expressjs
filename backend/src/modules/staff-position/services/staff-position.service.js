const staffPositionRepository = require('@repositories/staff-position/staff-position.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
  resolvePublicIdentifier
} = require('@lib/billing/identifiers');
const {
  resolveModelIdByIdentifier
} = require('@lib/identifiers/resolve-entity-id');
const {
  checkStaffPositionDuplicates
} = require('@lib/staff-position/staff-position-similarity');

const STAFF_POSITION_SIMILARITY_LOOKUP_LIMIT = 200;

const buildPagination = (page, limit, total) => {
  const totalPages = Math.ceil(total / limit);
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1
  };
};

const emptyResult = (page, limit) => ({
  staffPositions: [],
  pagination: buildPagination(page, limit, 0)
});

const stripSimilarityPayloadFields = (data = {}) => {
  const { confirm_similar: _confirmSimilar, ...payload } = data;
  return payload;
};

const normalizeStaffPositionRecord = (position) => {
  if (!position || typeof position !== 'object') {
    return position;
  }
  return {
    ...position,
    resource_uuid: position.id,
    display_id: resolvePublicIdentifier(position.human_friendly_id) || null
  };
};

const resolveStaffPositionId = async (identifier, { includeDeleted = false } = {}) => {
  const normalized = String(identifier ?? '').trim();
  if (!normalized) return normalized;

  if (includeDeleted) {
    const resolved = await resolveModelIdByIdentifier({
      model: 'staff_position',
      identifier: normalized,
      includeDeleted: true
    });
    return resolved || normalized;
  }

  return resolveEntityId({
    model: 'staff_position',
    identifier: normalized,
    where: { deleted_at: null }
  });
};

const assertStaffPositionUniqueness = async ({
  data,
  tenantId,
  facilityId,
  confirmSimilar = false,
  excludePositionId = null
}) => {
  if (!tenantId) {
    return null;
  }

  const whereClause = { tenant_id: tenantId };
  if (facilityId) {
    whereClause.OR = [{ facility_id: facilityId }, { facility_id: null }];
  } else {
    whereClause.facility_id = null;
  }

  const existing = await staffPositionRepository.findMany(
    whereClause,
    0,
    STAFF_POSITION_SIMILARITY_LOOKUP_LIMIT,
    { name: 'asc' },
    { includeDeleted: false }
  );

  const duplicateCheck = checkStaffPositionDuplicates({
    name: data.name,
    isActive: data.is_active,
    existing,
    excludePositionId
  });

  if (duplicateCheck.exactNameConflict) {
    throw new HttpError('errors.staff_position.duplicate_name', 409, [
      {
        field: 'name',
        matches: duplicateCheck.similarMatches
          .filter((match) => match.exactNameConflict)
          .slice(0, 5)
      }
    ]);
  }

  const reviewMatches = duplicateCheck.overridableMatches.slice(0, 5);
  if (reviewMatches.length > 0 && !confirmSimilar) {
    throw new HttpError('errors.staff_position.similar_exists', 409, [
      {
        field: 'name',
        matches: reviewMatches
      }
    ]);
  }

  return duplicateCheck;
};

const listStaffPositions = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const includeDeleted =
      filters.include_deleted === true || filters.include_deleted === 'true';
    const orderBy = includeDeleted
      ? [{ deleted_at: 'asc' }, { [sortBy || 'name']: order || 'asc' }]
      : sortBy
        ? { [sortBy]: order }
        : { name: 'asc' };
    const whereClause = {};

    const tenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
      where: { deleted_at: null }
    });
    if (filters.tenant_id && tenantId === null) return emptyResult(page, limit);
    if (tenantId) whereClause.tenant_id = tenantId;

    const facilityId = await resolveIdentifierForFilter({
      value: filters.facility_id,
      model: 'facility',
      where: { deleted_at: null }
    });
    if (filters.facility_id && facilityId === null) return emptyResult(page, limit);
    if (facilityId) {
      whereClause.OR = [{ facility_id: facilityId }, { facility_id: null }];
    }

    const departmentId = await resolveIdentifierForFilter({
      value: filters.department_id,
      model: 'department',
      where: { deleted_at: null }
    });
    if (filters.department_id && departmentId === null) {
      return emptyResult(page, limit);
    }
    if (departmentId) whereClause.department_id = departmentId;

    if (filters.is_active !== undefined) whereClause.is_active = filters.is_active;
    if (filters.name) whereClause.name = { contains: filters.name };

    if (filters.search) {
      whereClause.AND = [
        ...(whereClause.AND || []),
        {
          OR: [
            { name: { contains: filters.search } },
            { description: { contains: filters.search } },
            { human_friendly_id: { contains: filters.search } }
          ]
        }
      ];
    }

    const listOptions = { includeDeleted };
    const [staffPositions, total] = await Promise.all([
      staffPositionRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        listOptions
      ),
      staffPositionRepository.count(whereClause, listOptions)
    ]);

    return {
      staffPositions: staffPositions.map(normalizeStaffPositionRecord),
      pagination: buildPagination(page, limit, total)
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

const getStaffPositionById = async (id) => {
  try {
    const resolvedId = await resolveStaffPositionId(id, { includeDeleted: true });
    const staffPosition = await staffPositionRepository.findById(resolvedId, {
      includeDeleted: true
    });
    if (!staffPosition) throw new HttpError('errors.staff_position.not_found', 404);
    return normalizeStaffPositionRecord(staffPosition);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

const createStaffPosition = async (data, userId, ipAddress) => {
  try {
    const confirmSimilar = data?.confirm_similar === true;
    const raw = stripSimilarityPayloadFields(data);
    const payload = {
      ...raw,
      name: String(raw.name ?? '').trim(),
      tenant_id: await resolveIdentifierForPayload({
        value: raw.tenant_id,
        model: 'tenant',
        field: 'tenant_id',
        where: { deleted_at: null }
      }),
      facility_id: await resolveIdentifierForPayload({
        value: raw.facility_id,
        model: 'facility',
        field: 'facility_id',
        where: { deleted_at: null },
        nullable: true
      }),
      department_id: await resolveIdentifierForPayload({
        value: raw.department_id,
        model: 'department',
        field: 'department_id',
        where: { deleted_at: null },
        nullable: true
      })
    };

    await assertStaffPositionUniqueness({
      data: payload,
      tenantId: payload.tenant_id,
      facilityId: payload.facility_id,
      confirmSimilar
    });

    const staffPosition = await staffPositionRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'staff_position',
      entity_id: staffPosition.id,
      diff: { after: staffPosition },
      ip_address: ipAddress
    }).catch(() => {});
    return normalizeStaffPositionRecord(staffPosition);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

const assertFacilityScopedMutation = (position) => {
  if (!position?.facility_id) {
    throw new HttpError('errors.staff_position.shared_readonly', 403);
  }
};

const updateStaffPosition = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveStaffPositionId(id);
    const before = await staffPositionRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_position.not_found', 404);
    assertFacilityScopedMutation(before);

    const confirmSimilar = data?.confirm_similar === true;
    const raw = stripSimilarityPayloadFields(data);
    const payload = { ...raw };
    if (Object.prototype.hasOwnProperty.call(raw, 'facility_id')) {
      payload.facility_id = await resolveIdentifierForPayload({
        value: raw.facility_id,
        model: 'facility',
        field: 'facility_id',
        where: { deleted_at: null },
        nullable: true
      });
    }
    if (Object.prototype.hasOwnProperty.call(raw, 'department_id')) {
      payload.department_id = await resolveIdentifierForPayload({
        value: raw.department_id,
        model: 'department',
        field: 'department_id',
        where: { deleted_at: null },
        nullable: true
      });
    }
    if (Object.prototype.hasOwnProperty.call(raw, 'name')) {
      payload.name = String(raw.name ?? '').trim();
    }

    const nextName =
      payload.name !== undefined ? payload.name : before.name;
    const nextFacilityId =
      payload.facility_id !== undefined ? payload.facility_id : before.facility_id;
    const nextIsActive =
      payload.is_active !== undefined ? payload.is_active : before.is_active;

    await assertStaffPositionUniqueness({
      data: { name: nextName, is_active: nextIsActive },
      tenantId: before.tenant_id,
      facilityId: nextFacilityId,
      confirmSimilar,
      excludePositionId: before.id
    });

    const staffPosition = await staffPositionRepository.update(before.id, payload);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'staff_position',
      entity_id: staffPosition.id,
      diff: { before, after: staffPosition },
      ip_address: ipAddress
    }).catch(() => {});
    return normalizeStaffPositionRecord(staffPosition);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

const deleteStaffPosition = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveStaffPositionId(id);
    const before = await staffPositionRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_position.not_found', 404);
    assertFacilityScopedMutation(before);

    await staffPositionRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'staff_position',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

const restoreStaffPosition = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveStaffPositionId(id, { includeDeleted: true });
    const before = await staffPositionRepository.findById(resolvedId, {
      includeDeleted: true
    });
    if (!before) throw new HttpError('errors.staff_position.not_found', 404);
    assertFacilityScopedMutation(before);

    const staffPosition = await staffPositionRepository.restore(before.id);
    createAuditLog({
      user_id: userId,
      action: 'RESTORE',
      entity: 'staff_position',
      entity_id: staffPosition.id,
      diff: { before, after: staffPosition },
      ip_address: ipAddress
    }).catch(() => {});
    return normalizeStaffPositionRecord(staffPosition);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

const permanentDeleteStaffPosition = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveStaffPositionId(id, { includeDeleted: true });
    const before = await staffPositionRepository.findById(resolvedId, {
      includeDeleted: true
    });
    if (!before) {
      return;
    }
    assertFacilityScopedMutation(before);

    await staffPositionRepository.permanentDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'PERMANENT_DELETE',
      entity: 'staff_position',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

module.exports = {
  listStaffPositions,
  getStaffPositionById,
  createStaffPosition,
  updateStaffPosition,
  deleteStaffPosition,
  restoreStaffPosition,
  permanentDeleteStaffPosition
};
