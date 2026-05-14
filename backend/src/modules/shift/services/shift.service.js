const shiftRepository = require('@repositories/shift/shift.repository');
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
  shifts: [],
  pagination: buildPagination(page, limit, 0),
});

const listShifts = async (filters, page, limit, sortBy, order) => {
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

    if (filters.shift_type) whereClause.shift_type = filters.shift_type;
    if (filters.status) whereClause.status = filters.status;

    if (filters.start_time_from || filters.start_time_to) {
      whereClause.start_time = {};
      if (filters.start_time_from) whereClause.start_time.gte = new Date(filters.start_time_from);
      if (filters.start_time_to) whereClause.start_time.lte = new Date(filters.start_time_to);
    }

    if (filters.end_time_from || filters.end_time_to) {
      whereClause.end_time = {};
      if (filters.end_time_from) whereClause.end_time.gte = new Date(filters.end_time_from);
      if (filters.end_time_to) whereClause.end_time.lte = new Date(filters.end_time_to);
    }

    const [shifts, total] = await Promise.all([
      shiftRepository.findMany(whereClause, skip, limit, orderBy),
      shiftRepository.count(whereClause),
    ]);

    return {
      shifts,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getShiftById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'shift',
      identifier: id,
      where: { deleted_at: null },
    });
    const shift = await shiftRepository.findById(resolvedId);
    if (!shift) throw new HttpError('errors.shift.not_found', 404);
    return shift;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createShift = async (data, userId, ipAddress) => {
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
    };

    const shift = await shiftRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'shift',
      entity_id: shift.id,
      diff: { after: shift },
      ip_address: ipAddress,
    }).catch(() => {});
    return shift;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateShift = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'shift',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await shiftRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.shift.not_found', 404);

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

    const shift = await shiftRepository.update(before.id, payload);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'shift',
      entity_id: shift.id,
      diff: { before, after: shift },
      ip_address: ipAddress,
    }).catch(() => {});
    return shift;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteShift = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'shift',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await shiftRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.shift.not_found', 404);

    await shiftRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'shift',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const publishShift = async (id, notifyStaff, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'shift',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await shiftRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.shift.not_found', 404);
    if (before.status === 'COMPLETED' || before.status === 'CANCELLED') {
      throw new HttpError('errors.shift.already_published', 400);
    }

    const shift = await shiftRepository.update(before.id, { status: 'SCHEDULED' });
    createAuditLog({
      user_id: userId,
      action: 'PUBLISH',
      entity: 'shift',
      entity_id: shift.id,
      diff: { before, after: shift, metadata: { notifyStaff } },
      ip_address: ipAddress,
    }).catch(() => {});
    return shift;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listShifts,
  getShiftById,
  createShift,
  updateShift,
  deleteShift,
  publishShift,
};
