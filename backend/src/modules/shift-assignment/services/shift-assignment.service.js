const shiftAssignmentRepository = require('@repositories/shift-assignment/shift-assignment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const prisma = require('@prisma/client');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId} = require('@lib/billing/identifiers');

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
  shiftAssignments: [],
  pagination: buildPagination(page, limit, 0)});

const listShiftAssignments = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    const shiftId = await resolveIdentifierForFilter({
      value: filters.shift_id,
      model: 'shift',
      where: { deleted_at: null }});
    if (filters.shift_id && shiftId === null) return emptyResult(page, limit);
    if (shiftId) whereClause.shift_id = shiftId;

    const staffProfileId = await resolveIdentifierForFilter({
      value: filters.staff_profile_id,
      model: 'staff_profile',
      where: { deleted_at: null }});
    if (filters.staff_profile_id && staffProfileId === null) return emptyResult(page, limit);
    if (staffProfileId) whereClause.staff_profile_id = staffProfileId;

    if (filters.assigned_at_from || filters.assigned_at_to) {
      whereClause.assigned_at = {};
      if (filters.assigned_at_from) whereClause.assigned_at.gte = new Date(filters.assigned_at_from);
      if (filters.assigned_at_to) whereClause.assigned_at.lte = new Date(filters.assigned_at_to);
    }

    const [shiftAssignments, total] = await Promise.all([
      shiftAssignmentRepository.findMany(whereClause, skip, limit, orderBy),
      shiftAssignmentRepository.count(whereClause)]);

    return {
      shiftAssignments,
      pagination: buildPagination(page, limit, total)};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getShiftAssignmentById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'shift_assignment',
      identifier: id,
      where: { deleted_at: null }});
    const shiftAssignment = await shiftAssignmentRepository.findById(resolvedId);
    if (!shiftAssignment) throw new HttpError('errors.shift_assignment.not_found', 404);
    return shiftAssignment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createShiftAssignment = async (data, userId, ipAddress) => {
  try {
    const payload = {
      ...data,
      shift_id: await resolveIdentifierForPayload({
        value: data.shift_id,
        model: 'shift',
        field: 'shift_id',
        where: { deleted_at: null }}),
      staff_profile_id: await resolveIdentifierForPayload({
        value: data.staff_profile_id,
        model: 'staff_profile',
        field: 'staff_profile_id',
        where: { deleted_at: null }})};

    const shift = await prisma.shift.findFirst({
      where: { id: payload.shift_id, deleted_at: null },
      select: {
        id: true,
        start_time: true,
        end_time: true,
        roster_id: true,
      },
    });
    if (!shift) throw new HttpError('errors.shift.not_found', 404);

    const duplicateOnShift = await prisma.shift_assignment.findFirst({
      where: {
        deleted_at: null,
        shift_id: payload.shift_id,
        staff_profile_id: payload.staff_profile_id,
      },
      select: { id: true },
    });
    if (duplicateOnShift) {
      throw new HttpError('errors.shift_assignment.duplicate', 409, [
        { staff_profile_id: payload.staff_profile_id, shift_id: payload.shift_id },
      ]);
    }

    const overlapping = await prisma.shift_assignment.findFirst({
      where: {
        deleted_at: null,
        staff_profile_id: payload.staff_profile_id,
        shift: {
          deleted_at: null,
          id: { not: shift.id },
          start_time: { lt: shift.end_time },
          end_time: { gt: shift.start_time },
        },
      },
      select: {
        id: true,
        shift_id: true,
      },
    });
    if (overlapping) {
      throw new HttpError('errors.shift_assignment.schedule_conflict', 409, [
        {
          staff_profile_id: payload.staff_profile_id,
          conflicting_shift_id: overlapping.shift_id,
        },
      ]);
    }

    const shiftAssignment = await shiftAssignmentRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'shift_assignment',
      entity_id: shiftAssignment.id,
      diff: { after: shiftAssignment },
      ip_address: ipAddress}).catch(() => {});
    return shiftAssignment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateShiftAssignment = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'shift_assignment',
      identifier: id,
      where: { deleted_at: null }});
    const before = await shiftAssignmentRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.shift_assignment.not_found', 404);

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(data, 'shift_id')) {
      payload.shift_id = await resolveIdentifierForPayload({
        value: data.shift_id,
        model: 'shift',
        field: 'shift_id',
        where: { deleted_at: null }});
    }
    if (Object.prototype.hasOwnProperty.call(data, 'staff_profile_id')) {
      payload.staff_profile_id = await resolveIdentifierForPayload({
        value: data.staff_profile_id,
        model: 'staff_profile',
        field: 'staff_profile_id',
        where: { deleted_at: null }});
    }

    const shiftAssignment = await shiftAssignmentRepository.update(before.id, payload);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'shift_assignment',
      entity_id: shiftAssignment.id,
      diff: { before, after: shiftAssignment },
      ip_address: ipAddress}).catch(() => {});
    return shiftAssignment;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteShiftAssignment = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'shift_assignment',
      identifier: id,
      where: { deleted_at: null }});
    const before = await shiftAssignmentRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.shift_assignment.not_found', 404);

    await shiftAssignmentRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'shift_assignment',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress}).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listShiftAssignments,
  getShiftAssignmentById,
  createShiftAssignment,
  updateShiftAssignment,
  deleteShiftAssignment};
