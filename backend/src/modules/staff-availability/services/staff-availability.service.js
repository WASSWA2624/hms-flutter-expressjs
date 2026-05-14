const staffAvailabilityRepository = require('@repositories/staff-availability/staff-availability.repository');
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

const list = async (filters, page, limit, sortBy, order) => {
  const skip = (page - 1) * limit;
  const orderBy = sortBy ? { [sortBy]: order } : { effective_from: 'desc' };
  const whereClause = {};

  const staffProfileId = await resolveIdentifierForFilter({
    value: filters.staff_profile_id,
    model: 'staff_profile',
    where: { deleted_at: null },
  });
  if (filters.staff_profile_id && staffProfileId === null) return emptyResult(page, limit);
  if (staffProfileId) whereClause.staff_profile_id = staffProfileId;

  if (filters.day_of_week !== undefined) whereClause.day_of_week = parseInt(filters.day_of_week, 10);
  if (filters.preference) whereClause.preference = filters.preference;

  const [items, total] = await Promise.all([
    staffAvailabilityRepository.findMany(whereClause, skip, limit, orderBy),
    staffAvailabilityRepository.count(whereClause),
  ]);
  return {
    items,
    pagination: buildPagination(page, limit, total),
  };
};

const getById = async (id) => {
  const resolvedId = await resolveEntityId({
    model: 'staff_availability',
    identifier: id,
    where: { deleted_at: null },
  });
  const item = await staffAvailabilityRepository.findById(resolvedId);
  if (!item) throw new HttpError('errors.staff_availability.not_found', 404);
  return item;
};

const create = async (data, userId, ipAddress) => {
  const payload = {
    ...data,
    staff_profile_id: await resolveIdentifierForPayload({
      value: data.staff_profile_id,
      model: 'staff_profile',
      field: 'staff_profile_id',
      where: { deleted_at: null },
    }),
  };

  const item = await staffAvailabilityRepository.create(payload);
  createAuditLog({
    user_id: userId,
    action: 'CREATE',
    entity: 'staff_availability',
    entity_id: item.id,
    diff: { after: item },
    ip_address: ipAddress,
  }).catch(() => {});
  return item;
};

const update = async (id, data, userId, ipAddress) => {
  const resolvedId = await resolveEntityId({
    model: 'staff_availability',
    identifier: id,
    where: { deleted_at: null },
  });
  const before = await staffAvailabilityRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.staff_availability.not_found', 404);
  const item = await staffAvailabilityRepository.update(before.id, data);
  createAuditLog({
    user_id: userId,
    action: 'UPDATE',
    entity: 'staff_availability',
    entity_id: before.id,
    diff: { before, after: item },
    ip_address: ipAddress,
  }).catch(() => {});
  return item;
};

const remove = async (id, userId, ipAddress) => {
  const resolvedId = await resolveEntityId({
    model: 'staff_availability',
    identifier: id,
    where: { deleted_at: null },
  });
  const before = await staffAvailabilityRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.staff_availability.not_found', 404);
  await staffAvailabilityRepository.softDelete(before.id);
  createAuditLog({
    user_id: userId,
    action: 'DELETE',
    entity: 'staff_availability',
    entity_id: before.id,
    diff: { before },
    ip_address: ipAddress,
  }).catch(() => {});
};

module.exports = { list, getById, create, update, remove };
