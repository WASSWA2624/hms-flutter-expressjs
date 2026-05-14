const staffAssignmentRepository = require('@repositories/staff-assignment/staff-assignment.repository');
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
  staffAssignments: [],
  pagination: buildPagination(page, limit, 0),
});

const listStaffAssignments = async (filters, page, limit, sortBy, order) => {
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

    const departmentId = await resolveIdentifierForFilter({
      value: filters.department_id,
      model: 'department',
      where: { deleted_at: null },
    });
    if (filters.department_id && departmentId === null) return emptyResult(page, limit);
    if (departmentId) whereClause.department_id = departmentId;

    const unitId = await resolveIdentifierForFilter({
      value: filters.unit_id,
      model: 'unit',
      where: { deleted_at: null },
    });
    if (filters.unit_id && unitId === null) return emptyResult(page, limit);
    if (unitId) whereClause.unit_id = unitId;

    const [staffAssignments, total] = await Promise.all([
      staffAssignmentRepository.findMany(whereClause, skip, limit, orderBy),
      staffAssignmentRepository.count(whereClause),
    ]);

    return {
      staffAssignments,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getStaffAssignmentById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_assignment',
      identifier: id,
      where: { deleted_at: null },
    });
    const staffAssignment = await staffAssignmentRepository.findById(resolvedId);
    if (!staffAssignment) throw new HttpError('errors.staff_assignment.not_found', 404);
    return staffAssignment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createStaffAssignment = async (data, userId, ipAddress) => {
  try {
    const payload = {
      ...data,
      staff_profile_id: await resolveIdentifierForPayload({
        value: data.staff_profile_id,
        model: 'staff_profile',
        field: 'staff_profile_id',
        where: { deleted_at: null },
      }),
      department_id: await resolveIdentifierForPayload({
        value: data.department_id,
        model: 'department',
        field: 'department_id',
        where: { deleted_at: null },
        nullable: true,
      }),
      unit_id: await resolveIdentifierForPayload({
        value: data.unit_id,
        model: 'unit',
        field: 'unit_id',
        where: { deleted_at: null },
        nullable: true,
      }),
    };

    const staffAssignment = await staffAssignmentRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'staff_assignment',
      entity_id: staffAssignment.id,
      diff: { after: staffAssignment },
      ip_address: ipAddress,
    }).catch(() => {});
    return staffAssignment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateStaffAssignment = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_assignment',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await staffAssignmentRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_assignment.not_found', 404);

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(data, 'department_id')) {
      payload.department_id = await resolveIdentifierForPayload({
        value: data.department_id,
        model: 'department',
        field: 'department_id',
        where: { deleted_at: null },
        nullable: true,
      });
    }
    if (Object.prototype.hasOwnProperty.call(data, 'unit_id')) {
      payload.unit_id = await resolveIdentifierForPayload({
        value: data.unit_id,
        model: 'unit',
        field: 'unit_id',
        where: { deleted_at: null },
        nullable: true,
      });
    }

    const staffAssignment = await staffAssignmentRepository.update(before.id, payload);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'staff_assignment',
      entity_id: staffAssignment.id,
      diff: { before, after: staffAssignment },
      ip_address: ipAddress,
    }).catch(() => {});
    return staffAssignment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteStaffAssignment = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_assignment',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await staffAssignmentRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_assignment.not_found', 404);

    await staffAssignmentRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'staff_assignment',
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
  listStaffAssignments,
  getStaffAssignmentById,
  createStaffAssignment,
  updateStaffAssignment,
  deleteStaffAssignment,
};
