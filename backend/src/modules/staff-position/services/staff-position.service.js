const staffPositionRepository = require('@repositories/staff-position/staff-position.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

const buildPagination = (page, limit, total) => {
  const totalPages = Math.ceil(total / limit);
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const emptyResult = (page, limit) => ({
  staffPositions: [],
  pagination: buildPagination(page, limit, 0),
});

const listStaffPositions = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    const tenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
      where: { deleted_at: null },
    });
    if (filters.tenant_id && tenantId === null) return emptyResult(page, limit);
    if (tenantId) whereClause.tenant_id = tenantId;

    const facilityId = await resolveIdentifierForFilter({
      value: filters.facility_id,
      model: 'facility',
      where: { deleted_at: null },
    });
    if (filters.facility_id && facilityId === null) return emptyResult(page, limit);
    if (facilityId) whereClause.facility_id = facilityId;

    const departmentId = await resolveIdentifierForFilter({
      value: filters.department_id,
      model: 'department',
      where: { deleted_at: null },
    });
    if (filters.department_id && departmentId === null) return emptyResult(page, limit);
    if (departmentId) whereClause.department_id = departmentId;

    if (filters.is_active !== undefined) whereClause.is_active = filters.is_active;
    if (filters.name) whereClause.name = { contains: filters.name };

    if (filters.search) {
      whereClause.OR = [
        { name: { contains: filters.search } },
        { description: { contains: filters.search } },
      ];
    }

    const [staffPositions, total] = await Promise.all([
      staffPositionRepository.findMany(whereClause, skip, limit, orderBy),
      staffPositionRepository.count(whereClause),
    ]);

    return {
      staffPositions,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getStaffPositionById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_position',
      identifier: id,
      where: { deleted_at: null },
    });
    const staffPosition = await staffPositionRepository.findById(resolvedId);
    if (!staffPosition) throw new HttpError('errors.staff_position.not_found', 404);
    return staffPosition;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createStaffPosition = async (data, userId, ipAddress) => {
  try {
    const payload = {
      ...data,
      tenant_id: await resolveIdentifierForPayload({
        value: data.tenant_id,
        model: 'tenant',
        field: 'tenant_id',
        where: { deleted_at: null },
      }),
      facility_id: await resolveIdentifierForPayload({
        value: data.facility_id,
        model: 'facility',
        field: 'facility_id',
        where: { deleted_at: null },
        nullable: true,
      }),
      department_id: await resolveIdentifierForPayload({
        value: data.department_id,
        model: 'department',
        field: 'department_id',
        where: { deleted_at: null },
        nullable: true,
      }),
    };

    const staffPosition = await staffPositionRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'staff_position',
      entity_id: staffPosition.id,
      diff: { after: staffPosition },
      ip_address: ipAddress,
    }).catch(() => {});
    return staffPosition;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateStaffPosition = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_position',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await staffPositionRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_position.not_found', 404);

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(data, 'facility_id')) {
      payload.facility_id = await resolveIdentifierForPayload({
        value: data.facility_id,
        model: 'facility',
        field: 'facility_id',
        where: { deleted_at: null },
        nullable: true,
      });
    }
    if (Object.prototype.hasOwnProperty.call(data, 'department_id')) {
      payload.department_id = await resolveIdentifierForPayload({
        value: data.department_id,
        model: 'department',
        field: 'department_id',
        where: { deleted_at: null },
        nullable: true,
      });
    }

    const staffPosition = await staffPositionRepository.update(before.id, payload);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'staff_position',
      entity_id: staffPosition.id,
      diff: { before, after: staffPosition },
      ip_address: ipAddress,
    }).catch(() => {});
    return staffPosition;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteStaffPosition = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_position',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await staffPositionRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_position.not_found', 404);

    await staffPositionRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'staff_position',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listStaffPositions,
  getStaffPositionById,
  createStaffPosition,
  updateStaffPosition,
  deleteStaffPosition,
};
