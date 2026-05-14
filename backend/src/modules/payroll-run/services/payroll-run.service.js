const payrollRunRepository = require('@repositories/payroll-run/payroll-run.repository');
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
  payrollRuns: [],
  pagination: buildPagination(page, limit, 0),
});

const listPayrollRuns = async (filters, page, limit, sortBy, order) => {
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

    if (filters.status) whereClause.status = filters.status;

    if (filters.period_start_from || filters.period_start_to) {
      whereClause.period_start = {};
      if (filters.period_start_from) whereClause.period_start.gte = filters.period_start_from;
      if (filters.period_start_to) whereClause.period_start.lte = filters.period_start_to;
    }

    if (filters.period_end_from || filters.period_end_to) {
      whereClause.period_end = {};
      if (filters.period_end_from) whereClause.period_end.gte = filters.period_end_from;
      if (filters.period_end_to) whereClause.period_end.lte = filters.period_end_to;
    }

    const [payrollRuns, total] = await Promise.all([
      payrollRunRepository.findMany(whereClause, skip, limit, orderBy),
      payrollRunRepository.count(whereClause),
    ]);

    return {
      payrollRuns,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getPayrollRunById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payroll_run',
      identifier: id,
      where: { deleted_at: null },
    });
    const payrollRun = await payrollRunRepository.findById(resolvedId);
    if (!payrollRun) throw new HttpError('errors.payroll_run.not_found', 404);
    return payrollRun;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createPayrollRun = async (data, userId, ipAddress) => {
  try {
    const payload = {
      ...data,
      tenant_id: await resolveIdentifierForPayload({
        value: data.tenant_id,
        model: 'tenant',
        field: 'tenant_id',
        where: { deleted_at: null },
      }),
    };
    const payrollRun = await payrollRunRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'payroll_run',
      entity_id: payrollRun.id,
      diff: { after: payrollRun },
      ip_address: ipAddress,
    }).catch(() => {});
    return payrollRun;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updatePayrollRun = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payroll_run',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await payrollRunRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.payroll_run.not_found', 404);

    const payrollRun = await payrollRunRepository.update(before.id, data);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'payroll_run',
      entity_id: payrollRun.id,
      diff: { before, after: payrollRun },
      ip_address: ipAddress,
    }).catch(() => {});
    return payrollRun;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deletePayrollRun = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'payroll_run',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await payrollRunRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.payroll_run.not_found', 404);

    await payrollRunRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'payroll_run',
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
  listPayrollRuns,
  getPayrollRunById,
  createPayrollRun,
  updatePayrollRun,
  deletePayrollRun,
};
