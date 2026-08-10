const staffLeaveRepository = require('@repositories/staff-leave/staff-leave.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId} = require('@lib/billing/identifiers');
const {
  requireStaffProfileForUser} = require('@lib/staff/require-staff-profile-for-user');

const buildPagination = (page, limit, total) => {
  const totalPages = Math.ceil(total / limit);
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1};
};

const emptyResult = (page, limit) => ({
  staffLeaves: [],
  pagination: buildPagination(page, limit, 0)});

const listStaffLeaves = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    const staffProfileId = await resolveIdentifierForFilter({
      value: filters.staff_profile_id,
      model: 'staff_profile',
      where: { deleted_at: null }});
    if (filters.staff_profile_id && staffProfileId === null) return emptyResult(page, limit);
    if (staffProfileId) whereClause.staff_profile_id = staffProfileId;

    if (filters.status) whereClause.status = filters.status;
    if (filters.leave_type) whereClause.leave_type = filters.leave_type;

    const [staffLeaves, total] = await Promise.all([
      staffLeaveRepository.findMany(whereClause, skip, limit, orderBy),
      staffLeaveRepository.count(whereClause)]);

    return {
      staffLeaves,
      pagination: buildPagination(page, limit, total)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const listMyStaffLeaves = async (userId, filters, page, limit, sortBy, order) => {
  const profile = await requireStaffProfileForUser(userId);
  return listStaffLeaves(
    {
      ...filters,
      staff_profile_id: profile.id},
    page,
    limit,
    sortBy,
    order
  );
};

const getStaffLeaveById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_leave',
      identifier: id,
      where: { deleted_at: null }});
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
        where: { deleted_at: null }})};

    if (data.covering_staff_profile_id) {
      payload.covering_staff_profile_id = await resolveIdentifierForPayload({
        value: data.covering_staff_profile_id,
        model: 'staff_profile',
        field: 'covering_staff_profile_id',
        where: { deleted_at: null }});
    } else if (data.covering_staff_profile_id === null) {
      payload.covering_staff_profile_id = null;
    }

    if (!payload.is_half_day) {
      payload.is_half_day = false;
      payload.half_day_period = null;
    }

    const staffLeave = await staffLeaveRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'staff_leave',
      entity_id: staffLeave.id,
      diff: { after: staffLeave },
      ip_address: ipAddress}).catch(() => {});
    return staffLeave;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createMyStaffLeave = async (data, userId, ipAddress) => {
  const profile = await requireStaffProfileForUser(userId);
  return createStaffLeave(
    {
      ...data,
      staff_profile_id: profile.id,
      status: 'REQUESTED'},
    userId,
    ipAddress
  );
};

const updateStaffLeave = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'staff_leave',
      identifier: id,
      where: { deleted_at: null }});
    const before = await staffLeaveRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_leave.not_found', 404);

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(data, 'covering_staff_profile_id')) {
      payload.covering_staff_profile_id = data.covering_staff_profile_id
        ? await resolveIdentifierForPayload({
            value: data.covering_staff_profile_id,
            model: 'staff_profile',
            field: 'covering_staff_profile_id',
            where: { deleted_at: null }})
        : null;
    }
    if (payload.is_half_day === false) {
      payload.half_day_period = null;
    }

    const staffLeave = await staffLeaveRepository.update(before.id, payload);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'staff_leave',
      entity_id: staffLeave.id,
      diff: { before, after: staffLeave },
      ip_address: ipAddress}).catch(() => {});
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
      where: { deleted_at: null }});
    const before = await staffLeaveRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.staff_leave.not_found', 404);

    await staffLeaveRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'staff_leave',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress}).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listStaffLeaves,
  listMyStaffLeaves,
  getStaffLeaveById,
  createStaffLeave,
  createMyStaffLeave,
  updateStaffLeave,
  deleteStaffLeave};
