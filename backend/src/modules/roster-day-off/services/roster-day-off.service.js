const rosterDayOffRepository = require('@repositories/roster-day-off/roster-day-off.repository');
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
  const orderBy = sortBy ? { [sortBy]: order } : { off_date: 'asc' };
  const whereClause = {};

  const rosterId = await resolveIdentifierForFilter({
    value: filters.nurse_roster_id,
    model: 'nurse_roster',
    where: { deleted_at: null },
  });
  if (filters.nurse_roster_id && rosterId === null) return emptyResult(page, limit);
  if (rosterId) whereClause.nurse_roster_id = rosterId;

  const staffProfileId = await resolveIdentifierForFilter({
    value: filters.staff_profile_id,
    model: 'staff_profile',
    where: { deleted_at: null },
  });
  if (filters.staff_profile_id && staffProfileId === null) return emptyResult(page, limit);
  if (staffProfileId) whereClause.staff_profile_id = staffProfileId;

  if (filters.off_date_from) whereClause.off_date_from = filters.off_date_from;
  if (filters.off_date_to) whereClause.off_date_to = filters.off_date_to;

  const [items, total] = await Promise.all([
    rosterDayOffRepository.findMany(whereClause, skip, limit, orderBy),
    rosterDayOffRepository.count(whereClause),
  ]);
  return {
    items,
    pagination: buildPagination(page, limit, total),
  };
};

const getById = async (id) => {
  const resolvedId = await resolveEntityId({
    model: 'roster_day_off',
    identifier: id,
    where: { deleted_at: null },
  });
  const item = await rosterDayOffRepository.findById(resolvedId);
  if (!item) throw new HttpError('errors.roster_day_off.not_found', 404);
  return item;
};

const create = async (data, userId, ipAddress) => {
  const payload = {
    ...data,
    nurse_roster_id: await resolveIdentifierForPayload({
      value: data.nurse_roster_id,
      model: 'nurse_roster',
      field: 'nurse_roster_id',
      where: { deleted_at: null },
    }),
    staff_profile_id: await resolveIdentifierForPayload({
      value: data.staff_profile_id,
      model: 'staff_profile',
      field: 'staff_profile_id',
      where: { deleted_at: null },
    }),
  };

  const item = await rosterDayOffRepository.create(payload);
  createAuditLog({
    user_id: userId,
    action: 'CREATE',
    entity: 'roster_day_off',
    entity_id: item.id,
    diff: { after: item },
    ip_address: ipAddress,
  }).catch(() => {});
  return item;
};

const update = async (id, data, userId, ipAddress) => {
  const resolvedId = await resolveEntityId({
    model: 'roster_day_off',
    identifier: id,
    where: { deleted_at: null },
  });
  const before = await rosterDayOffRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.roster_day_off.not_found', 404);
  const item = await rosterDayOffRepository.update(before.id, data);
  createAuditLog({
    user_id: userId,
    action: 'UPDATE',
    entity: 'roster_day_off',
    entity_id: before.id,
    diff: { before, after: item },
    ip_address: ipAddress,
  }).catch(() => {});
  return item;
};

const remove = async (id, userId, ipAddress) => {
  const resolvedId = await resolveEntityId({
    model: 'roster_day_off',
    identifier: id,
    where: { deleted_at: null },
  });
  const before = await rosterDayOffRepository.findById(resolvedId);
  if (!before) throw new HttpError('errors.roster_day_off.not_found', 404);
  await rosterDayOffRepository.softDelete(before.id);
  createAuditLog({
    user_id: userId,
    action: 'DELETE',
    entity: 'roster_day_off',
    entity_id: before.id,
    diff: { before },
    ip_address: ipAddress,
  }).catch(() => {});
};

module.exports = { list, getById, create, update, remove };
