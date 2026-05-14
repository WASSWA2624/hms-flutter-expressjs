const shiftSwapRequestRepository = require('@repositories/shift-swap-request/shift-swap-request.repository');
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
  shiftSwapRequests: [],
  pagination: buildPagination(page, limit, 0),
});

const listShiftSwapRequests = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    const shiftId = await resolveIdentifierForFilter({
      value: filters.shift_id,
      model: 'shift',
      where: { deleted_at: null },
    });
    if (filters.shift_id && shiftId === null) return emptyResult(page, limit);
    if (shiftId) whereClause.shift_id = shiftId;

    const requesterId = await resolveIdentifierForFilter({
      value: filters.requester_staff_id,
      model: 'staff_profile',
      where: { deleted_at: null },
    });
    if (filters.requester_staff_id && requesterId === null) return emptyResult(page, limit);
    if (requesterId) whereClause.requester_staff_id = requesterId;

    const targetId = await resolveIdentifierForFilter({
      value: filters.target_staff_id,
      model: 'staff_profile',
      where: { deleted_at: null },
    });
    if (filters.target_staff_id && targetId === null) return emptyResult(page, limit);
    if (targetId) whereClause.target_staff_id = targetId;

    if (filters.status) whereClause.status = filters.status;

    const [shiftSwapRequests, total] = await Promise.all([
      shiftSwapRequestRepository.findMany(whereClause, skip, limit, orderBy),
      shiftSwapRequestRepository.count(whereClause),
    ]);

    return {
      shiftSwapRequests,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getShiftSwapRequestById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'shift_swap_request',
      identifier: id,
      where: { deleted_at: null },
    });
    const shiftSwapRequest = await shiftSwapRequestRepository.findById(resolvedId);
    if (!shiftSwapRequest) throw new HttpError('errors.shift_swap_request.not_found', 404);
    return shiftSwapRequest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createShiftSwapRequest = async (data, userId, ipAddress) => {
  try {
    const payload = {
      ...data,
      shift_id: await resolveIdentifierForPayload({
        value: data.shift_id,
        model: 'shift',
        field: 'shift_id',
        where: { deleted_at: null },
      }),
      requester_staff_id: await resolveIdentifierForPayload({
        value: data.requester_staff_id,
        model: 'staff_profile',
        field: 'requester_staff_id',
        where: { deleted_at: null },
      }),
      target_staff_id: await resolveIdentifierForPayload({
        value: data.target_staff_id,
        model: 'staff_profile',
        field: 'target_staff_id',
        where: { deleted_at: null },
        nullable: true,
      }),
    };

    const shiftSwapRequest = await shiftSwapRequestRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'shift_swap_request',
      entity_id: shiftSwapRequest.id,
      diff: { after: shiftSwapRequest },
      ip_address: ipAddress,
    }).catch(() => {});
    return shiftSwapRequest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateShiftSwapRequest = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'shift_swap_request',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await shiftSwapRequestRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.shift_swap_request.not_found', 404);

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(data, 'shift_id')) {
      payload.shift_id = await resolveIdentifierForPayload({
        value: data.shift_id,
        model: 'shift',
        field: 'shift_id',
        where: { deleted_at: null },
      });
    }
    if (Object.prototype.hasOwnProperty.call(data, 'requester_staff_id')) {
      payload.requester_staff_id = await resolveIdentifierForPayload({
        value: data.requester_staff_id,
        model: 'staff_profile',
        field: 'requester_staff_id',
        where: { deleted_at: null },
      });
    }
    if (Object.prototype.hasOwnProperty.call(data, 'target_staff_id')) {
      payload.target_staff_id = await resolveIdentifierForPayload({
        value: data.target_staff_id,
        model: 'staff_profile',
        field: 'target_staff_id',
        where: { deleted_at: null },
        nullable: true,
      });
    }

    const shiftSwapRequest = await shiftSwapRequestRepository.update(before.id, payload);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'shift_swap_request',
      entity_id: shiftSwapRequest.id,
      diff: { before, after: shiftSwapRequest },
      ip_address: ipAddress,
    }).catch(() => {});
    return shiftSwapRequest;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteShiftSwapRequest = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'shift_swap_request',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await shiftSwapRequestRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.shift_swap_request.not_found', 404);

    await shiftSwapRequestRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'shift_swap_request',
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
  listShiftSwapRequests,
  getShiftSwapRequestById,
  createShiftSwapRequest,
  updateShiftSwapRequest,
  deleteShiftSwapRequest,
};
