const payrollItemRepository = require('@repositories/payroll-item/payroll-item.repository');
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
  payrollItems: [],
  pagination: buildPagination(page, limit, 0),
});

const listPayrollItems = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    const payrollRunId = await resolveIdentifierForFilter({
      value: filters.payroll_run_id,
      model: 'payroll_run',
      where: { deleted_at: null },
    });
    if (filters.payroll_run_id && payrollRunId === null) return emptyResult(page, limit);
    if (payrollRunId) whereClause.payroll_run_id = payrollRunId;

    const staffProfileId = await resolveIdentifierForFilter({
      value: filters.staff_profile_id,
      model: 'staff_profile',
      where: { deleted_at: null },
    });
    if (filters.staff_profile_id && staffProfileId === null) return emptyResult(page, limit);
    if (staffProfileId) whereClause.staff_profile_id = staffProfileId;

    if (filters.currency) whereClause.currency = filters.currency;
    if (filters.amount_min !== undefined || filters.amount_max !== undefined) {
      whereClause.amount = {};
      if (filters.amount_min !== undefined) whereClause.amount.gte = filters.amount_min;
      if (filters.amount_max !== undefined) whereClause.amount.lte = filters.amount_max;
    }

    const [payrollItems, total] = await Promise.all([
      payrollItemRepository.findMany(whereClause, skip, limit, orderBy),
      payrollItemRepository.count(whereClause),
    ]);

    return {
      payrollItems,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getPayrollItemById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payroll_item',
      identifier: id,
      where: { deleted_at: null },
    });
    const payrollItem = await payrollItemRepository.findById(resolvedId);
    if (!payrollItem) throw new HttpError('errors.payroll_item.not_found', 404);
    return payrollItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createPayrollItem = async (data, userId, ipAddress) => {
  try {
    const payload = {
      ...data,
      payroll_run_id: await resolveIdentifierForPayload({
        value: data.payroll_run_id,
        model: 'payroll_run',
        field: 'payroll_run_id',
        where: { deleted_at: null },
      }),
      staff_profile_id: await resolveIdentifierForPayload({
        value: data.staff_profile_id,
        model: 'staff_profile',
        field: 'staff_profile_id',
        where: { deleted_at: null },
      }),
    };

    const payrollItem = await payrollItemRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'payroll_item',
      entity_id: payrollItem.id,
      diff: { after: payrollItem },
      ip_address: ipAddress,
    }).catch(() => {});
    return payrollItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updatePayrollItem = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payroll_item',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await payrollItemRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.payroll_item.not_found', 404);

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(data, 'payroll_run_id')) {
      payload.payroll_run_id = await resolveIdentifierForPayload({
        value: data.payroll_run_id,
        model: 'payroll_run',
        field: 'payroll_run_id',
        where: { deleted_at: null },
      });
    }
    if (Object.prototype.hasOwnProperty.call(data, 'staff_profile_id')) {
      payload.staff_profile_id = await resolveIdentifierForPayload({
        value: data.staff_profile_id,
        model: 'staff_profile',
        field: 'staff_profile_id',
        where: { deleted_at: null },
      });
    }

    const payrollItem = await payrollItemRepository.update(before.id, payload);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'payroll_item',
      entity_id: payrollItem.id,
      diff: { before, after: payrollItem },
      ip_address: ipAddress,
    }).catch(() => {});
    return payrollItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deletePayrollItem = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payroll_item',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await payrollItemRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.payroll_item.not_found', 404);

    await payrollItemRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'payroll_item',
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
  listPayrollItems,
  getPayrollItemById,
  createPayrollItem,
  updatePayrollItem,
  deletePayrollItem,
};
