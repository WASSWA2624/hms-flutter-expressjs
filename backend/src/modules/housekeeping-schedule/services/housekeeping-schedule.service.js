/**
 * Housekeeping schedule service
 *
 * @module modules/housekeeping-schedule/services
 * @description Business logic for housekeeping schedule operations.
 */

const housekeepingScheduleRepository = require('@repositories/housekeeping-schedule/housekeeping-schedule.repository');
const { createAuditLog } = require('@lib/audit');
const { resolveEntityId, resolveIdentifierForFilter, resolveIdentifierForPayload, resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { HttpError } = require('@lib/errors');

const SCHEDULE_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'start_date',
  'end_date',
  'frequency',
]);

const HOUSEKEEPING_SCHEDULE_INCLUDE = {
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  room: { select: { id: true, human_friendly_id: true, name: true } },
};

const hasOwn = (object, key) => Object.prototype.hasOwnProperty.call(object || {}, key);
const displayId = (record = {}) => resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id) || record?.id || null;
const publicRelationId = (record, relationName, fieldName) =>
  resolvePublicIdentifier(record?.[relationName]?.human_friendly_id, record?.[fieldName]) || record?.[fieldName] || null;

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
  hasNextPage: page * limit < total,
  hasPreviousPage: page > 1,
});

const resolveOrderBy = (sortBy = 'created_at', order = 'desc') => {
  const field = SCHEDULE_SORT_FIELDS.has(sortBy) ? sortBy : 'created_at';
  return { [field]: order === 'asc' ? 'asc' : 'desc' };
};

const mapHousekeepingSchedule = (record) => {
  if (!record || typeof record !== 'object') return record;
  const id = displayId(record);

  return {
    ...record,
    id,
    human_friendly_id: id,
    display_id: id,
    facility_id: publicRelationId(record, 'facility', 'facility_id'),
    facility_label: record?.facility?.name || null,
    room_id: publicRelationId(record, 'room', 'room_id'),
    room_label: record?.room?.name || null,
  };
};

const resolveListFilters = async (filters = {}, page = 1, limit = 20, context = {}) => {
  const tenantWhere = context?.tenant_id ? { tenant_id: context.tenant_id } : {};
  const repoFilters = {};

  const requestedFacility = filters.facility_id || context?.facility_id;
  if (requestedFacility !== undefined) {
    const facilityId = await resolveIdentifierForFilter({
      value: requestedFacility,
      model: 'facility',
      where: tenantWhere,
    });
    if (facilityId === null) {
      return {
        housekeepingSchedules: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (facilityId !== undefined) repoFilters.facility_id = facilityId;
  }

  if (filters.room_id !== undefined) {
    const roomId = await resolveIdentifierForFilter({
      value: filters.room_id,
      model: 'room',
      where: tenantWhere,
    });
    if (roomId === null) {
      return {
        housekeepingSchedules: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (roomId !== undefined) repoFilters.room_id = roomId;
  }

  if (filters.frequency) {
    repoFilters.frequency = { contains: filters.frequency, mode: 'insensitive' };
  }

  return repoFilters;
};

const resolvePayload = async (data = {}, context = {}, { defaultFacility = true } = {}) => {
  const tenantWhere = context?.tenant_id ? { tenant_id: context.tenant_id } : {};
  const payload = { ...data };

  if (hasOwn(payload, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: payload.facility_id,
      field: 'facility_id',
      model: 'facility',
      nullable: true,
      where: tenantWhere,
    });
  } else if (defaultFacility && context?.facility_id) {
    payload.facility_id = context.facility_id;
  }

  if (hasOwn(payload, 'room_id')) {
    payload.room_id = await resolveIdentifierForPayload({
      value: payload.room_id,
      field: 'room_id',
      model: 'room',
      nullable: true,
      where: tenantWhere,
    });
  }

  if (hasOwn(payload, 'start_date') && payload.start_date) {
    payload.start_date = new Date(payload.start_date);
  }
  if (hasOwn(payload, 'end_date') && payload.end_date) {
    payload.end_date = new Date(payload.end_date);
  }

  return payload;
};

const buildScheduleScope = (context = {}) => ({
  ...(context?.facility_id ? { facility_id: context.facility_id } : {}),
  ...(context?.tenant_id
    ? { facility: { tenant_id: context.tenant_id, deleted_at: null } }
    : {}),
});

const resolveScheduleId = (identifier, context = {}) =>
  resolveEntityId({ model: 'housekeeping_schedule', identifier, where: buildScheduleScope(context) });

const listHousekeepingSchedules = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc', context = {}) => {
  const resolvedFilters = await resolveListFilters(filters, page, limit, context);
  if (resolvedFilters.housekeepingSchedules && resolvedFilters.pagination) return resolvedFilters;

  const skip = (page - 1) * limit;
  const orderBy = resolveOrderBy(sort_by, order);
  const [housekeepingSchedules, total] = await Promise.all([
    housekeepingScheduleRepository.findMany(resolvedFilters, skip, limit, orderBy, HOUSEKEEPING_SCHEDULE_INCLUDE),
    housekeepingScheduleRepository.count(resolvedFilters),
  ]);

  return {
    housekeepingSchedules: housekeepingSchedules.map(mapHousekeepingSchedule),
    pagination: buildPagination(page, limit, total),
  };
};

const getHousekeepingScheduleById = async (id, context = {}) => {
  const resolvedId = await resolveScheduleId(id, context);
  const housekeepingSchedule = await housekeepingScheduleRepository.findById(resolvedId, HOUSEKEEPING_SCHEDULE_INCLUDE);

  if (!housekeepingSchedule) {
    throw new HttpError('errors.housekeeping_schedule.not_found', 404);
  }

  return mapHousekeepingSchedule(housekeepingSchedule);
};

const createHousekeepingSchedule = async (data, context = {}) => {
  const processedData = await resolvePayload(data, context);
  const housekeepingSchedule = await housekeepingScheduleRepository.create(processedData, HOUSEKEEPING_SCHEDULE_INCLUDE);

  await createAuditLog({
    action: 'HOUSEKEEPING_SCHEDULE_CREATED',
    entity: 'housekeeping_schedule',
    entity_id: housekeepingSchedule.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      facility_id: housekeepingSchedule.facility_id,
      room_id: housekeepingSchedule.room_id,
      frequency: housekeepingSchedule.frequency,
      start_date: housekeepingSchedule.start_date,
      end_date: housekeepingSchedule.end_date,
    },
  });

  return mapHousekeepingSchedule(housekeepingSchedule);
};

const updateHousekeepingSchedule = async (id, data, context = {}) => {
  const resolvedId = await resolveScheduleId(id, context);
  const beforeHousekeepingSchedule = await housekeepingScheduleRepository.findById(resolvedId, HOUSEKEEPING_SCHEDULE_INCLUDE);

  if (!beforeHousekeepingSchedule) {
    throw new HttpError('errors.housekeeping_schedule.not_found', 404);
  }

  const processedData = await resolvePayload(data, context, { defaultFacility: false });
  const housekeepingSchedule = await housekeepingScheduleRepository.update(resolvedId, processedData, HOUSEKEEPING_SCHEDULE_INCLUDE);

  await createAuditLog({
    action: 'HOUSEKEEPING_SCHEDULE_UPDATED',
    entity: 'housekeeping_schedule',
    entity_id: housekeepingSchedule.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeHousekeepingSchedule.facility_id,
        room_id: beforeHousekeepingSchedule.room_id,
        frequency: beforeHousekeepingSchedule.frequency,
        start_date: beforeHousekeepingSchedule.start_date,
        end_date: beforeHousekeepingSchedule.end_date,
      },
      after: {
        facility_id: housekeepingSchedule.facility_id,
        room_id: housekeepingSchedule.room_id,
        frequency: housekeepingSchedule.frequency,
        start_date: housekeepingSchedule.start_date,
        end_date: housekeepingSchedule.end_date,
      },
    },
  });

  return mapHousekeepingSchedule(housekeepingSchedule);
};

const deleteHousekeepingSchedule = async (id, context = {}) => {
  const resolvedId = await resolveScheduleId(id, context);
  const housekeepingSchedule = await housekeepingScheduleRepository.findById(resolvedId);

  if (!housekeepingSchedule) {
    throw new HttpError('errors.housekeeping_schedule.not_found', 404);
  }

  await housekeepingScheduleRepository.softDelete(resolvedId);

  await createAuditLog({
    action: 'HOUSEKEEPING_SCHEDULE_DELETED',
    entity: 'housekeeping_schedule',
    entity_id: housekeepingSchedule.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      facility_id: housekeepingSchedule.facility_id,
      room_id: housekeepingSchedule.room_id,
      frequency: housekeepingSchedule.frequency,
    },
  });
};

module.exports = {
  listHousekeepingSchedules,
  getHousekeepingScheduleById,
  createHousekeepingSchedule,
  updateHousekeepingSchedule,
  deleteHousekeepingSchedule,
};
