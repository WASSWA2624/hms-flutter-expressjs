const shiftTemplateRepository = require('@repositories/shift-template/shift-template.repository');
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
  items: [],
  pagination: buildPagination(page, limit, 0),
});

const listShiftTemplates = async (filters, page, limit, sortBy, order) => {
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
    if (filters.is_active !== undefined) whereClause.is_active = filters.is_active === true || filters.is_active === 'true';

    const [items, total] = await Promise.all([
      shiftTemplateRepository.findMany(whereClause, skip, limit, orderBy),
      shiftTemplateRepository.count(whereClause),
    ]);

    return {
      items,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getById = async (id) => {
  const resolvedId = await resolveEntityId({
    model: 'shift_template',
    identifier: id,
    where: { deleted_at: null },
  });
  const item = await shiftTemplateRepository.findById(resolvedId);
  if (!item) throw new HttpError('errors.shift_template.not_found', 404);
  return item;
};

const create = async (data, userId, ipAddress) => {
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
  const item = await shiftTemplateRepository.create(payload);
  createAuditLog({
    user_id: userId,
    action: 'CREATE',
    entity: 'shift_template',
    entity_id: item.id,
    diff: { after: item },
    ip_address: ipAddress,
  }).catch(() => {});
  return item;
};

const update = async (id, data, userId, ipAddress) => {
  const resolvedId = await resolveEntityId({
    model: 'shift_template',
    identifier: id,
    where: { deleted_at: null },
  });
  const before = await shiftTemplateRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.shift_template.not_found', 404);

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

  const item = await shiftTemplateRepository.update(before.id, payload);
  createAuditLog({
    user_id: userId,
    action: 'UPDATE',
    entity: 'shift_template',
    entity_id: before.id,
    diff: { before, after: item },
    ip_address: ipAddress,
  }).catch(() => {});
  return item;
};

const remove = async (id, userId, ipAddress) => {
  const resolvedId = await resolveEntityId({
    model: 'shift_template',
    identifier: id,
    where: { deleted_at: null },
  });
  const before = await shiftTemplateRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.shift_template.not_found', 404);
  await shiftTemplateRepository.softDelete(before.id);
  createAuditLog({
    user_id: userId,
    action: 'DELETE',
    entity: 'shift_template',
    entity_id: before.id,
    diff: { before },
    ip_address: ipAddress,
  }).catch(() => {});
};

module.exports = { listShiftTemplates, getById, create, update, remove };
