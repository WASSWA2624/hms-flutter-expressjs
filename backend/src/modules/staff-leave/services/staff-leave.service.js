const staffLeaveRepository = require('@repositories/staff-leave/staff-leave.repository');
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
  staffLeaves: [],
  pagination: buildPagination(page, limit, 0),
});

const listStaffLeaves = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    const staffProfileId = await resolveIdentifierForFilter({
      value: filters.staff_profile_id,
      model: 'staff_profile',
      where: { deleted_at: null },
    });
    if (filters.staff_profile_id && staffProfileId === null) return emptyResult(page, limit);
    if (staffProfileId) whereClause.staff_profile_id = staffProfileId;

    if (filters.status) whereClause.status = filters.status;

    const [staffLeaves, total] = await Promise.all([
      staffLeaveRepository.findMany(whereClause, skip, limit, orderBy),
      staffLeaveRepository.count(whereClause),
    ]);

    return {
      staffLeaves,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getStaffLeaveById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_leave',
      identifier: id,
      where: { deleted_at: null },
    });
    const staffLeave = await staffLeaveRepository.findById(resolvedId);
    if (!staffLeave) throw new HttpError('errors.staff_leave.not_found', 404);
    return staffLeave;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createStaffLeave = async (data, userId, ipAddress) => {
  try {
    const payload = {
      ...data,
      staff_profile_id: await resolveIdentifierForPayload({
        value: data.staff_profile_id,
        model: 'staff_profile',
        field: 'staff_profile_id',
        where: { deleted_at: null },
      }),
    };

    const staffLeave = await staffLeaveRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'staff_leave',
      entity_id: staffLeave.id,
      diff: { after: staffLeave },
      ip_address: ipAddress,
    }).catch(() => {});
    return staffLeave;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateStaffLeave = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_leave',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await staffLeaveRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_leave.not_found', 404);

    const staffLeave = await staffLeaveRepository.update(before.id, data);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'staff_leave',
      entity_id: staffLeave.id,
      diff: { before, after: staffLeave },
      ip_address: ipAddress,
    }).catch(() => {});
    return staffLeave;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteStaffLeave = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_leave',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await staffLeaveRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_leave.not_found', 404);

    await staffLeaveRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'staff_leave',
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
  listStaffLeaves,
  getStaffLeaveById,
  createStaffLeave,
  updateStaffLeave,
  deleteStaffLeave,
};
