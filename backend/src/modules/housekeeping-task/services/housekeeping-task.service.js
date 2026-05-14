/**
 * Housekeeping task service
 *
 * @module modules/housekeeping-task/services
 * @description Business logic for housekeeping task operations.
 */

const housekeepingTaskRepository = require('@repositories/housekeeping-task/housekeeping-task.repository');
const { createAuditLog } = require('@lib/audit');
const { resolveEntityId, resolveIdentifierForFilter, resolveIdentifierForPayload, resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { HttpError } = require('@lib/errors');

const TASK_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'scheduled_at',
  'completed_at',
  'status',
]);

const HOUSEKEEPING_TASK_INCLUDE = {
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  room: { select: { id: true, human_friendly_id: true, name: true } },
  assigned_to: {
    select: {
      id: true,
      human_friendly_id: true,
      staff_number: true,
      position: true,
      user: { select: { email: true } },
    },
  },
};

const normalizeString = (value) => String(value || '').trim();
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
  const field = TASK_SORT_FIELDS.has(sortBy) ? sortBy : 'created_at';
  return { [field]: order === 'asc' ? 'asc' : 'desc' };
};

const mapHousekeepingTask = (record) => {
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
    assigned_to_staff_id: publicRelationId(record, 'assigned_to', 'assigned_to_staff_id'),
    assigned_to_staff_label:
      record?.assigned_to?.staff_number || record?.assigned_to?.user?.email || null,
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
        housekeepingTasks: [],
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
        housekeepingTasks: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (roomId !== undefined) repoFilters.room_id = roomId;
  }

  if (filters.assigned_to_staff_id !== undefined) {
    const staffId = await resolveIdentifierForFilter({
      value: filters.assigned_to_staff_id,
      model: 'staff_profile',
      where: tenantWhere,
    });
    if (staffId === null) {
      return {
        housekeepingTasks: [],
        pagination: buildPagination(page, limit, 0),
      };
    }
    if (staffId !== undefined) repoFilters.assigned_to_staff_id = staffId;
  }

  if (filters.status) repoFilters.status = filters.status;

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

  if (hasOwn(payload, 'assigned_to_staff_id')) {
    payload.assigned_to_staff_id = await resolveIdentifierForPayload({
      value: payload.assigned_to_staff_id,
      field: 'assigned_to_staff_id',
      model: 'staff_profile',
      nullable: true,
      where: tenantWhere,
    });
  }

  if (hasOwn(payload, 'scheduled_at') && payload.scheduled_at) {
    payload.scheduled_at = new Date(payload.scheduled_at);
  }
  if (hasOwn(payload, 'completed_at') && payload.completed_at) {
    payload.completed_at = new Date(payload.completed_at);
  }

  return payload;
};

const buildTaskScope = (context = {}) => ({
  ...(context?.facility_id ? { facility_id: context.facility_id } : {}),
  ...(context?.tenant_id
    ? { facility: { tenant_id: context.tenant_id, deleted_at: null } }
    : {}),
});

const resolveTaskId = (identifier, context = {}) =>
  resolveEntityId({ model: 'housekeeping_task', identifier, where: buildTaskScope(context) });

const listHousekeepingTasks = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc', context = {}) => {
  const resolvedFilters = await resolveListFilters(filters, page, limit, context);
  if (resolvedFilters.housekeepingTasks && resolvedFilters.pagination) return resolvedFilters;

  const skip = (page - 1) * limit;
  const orderBy = resolveOrderBy(sort_by, order);
  const [housekeepingTasks, total] = await Promise.all([
    housekeepingTaskRepository.findMany(resolvedFilters, skip, limit, orderBy, HOUSEKEEPING_TASK_INCLUDE),
    housekeepingTaskRepository.count(resolvedFilters),
  ]);

  return {
    housekeepingTasks: housekeepingTasks.map(mapHousekeepingTask),
    pagination: buildPagination(page, limit, total),
  };
};

const getHousekeepingTaskById = async (id, context = {}) => {
  const resolvedId = await resolveTaskId(id, context);
  const housekeepingTask = await housekeepingTaskRepository.findById(resolvedId, HOUSEKEEPING_TASK_INCLUDE);

  if (!housekeepingTask) {
    throw new HttpError('errors.housekeeping_task.not_found', 404);
  }

  return mapHousekeepingTask(housekeepingTask);
};

const createHousekeepingTask = async (data, context = {}) => {
  const processedData = await resolvePayload(data, context);
  const housekeepingTask = await housekeepingTaskRepository.create(processedData, HOUSEKEEPING_TASK_INCLUDE);

  await createAuditLog({
    action: 'HOUSEKEEPING_TASK_CREATED',
    entity: 'housekeeping_task',
    entity_id: housekeepingTask.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      facility_id: housekeepingTask.facility_id,
      room_id: housekeepingTask.room_id,
      assigned_to_staff_id: housekeepingTask.assigned_to_staff_id,
      status: housekeepingTask.status,
      scheduled_at: housekeepingTask.scheduled_at,
      completed_at: housekeepingTask.completed_at,
    },
  });

  return mapHousekeepingTask(housekeepingTask);
};

const updateHousekeepingTask = async (id, data, context = {}) => {
  const resolvedId = await resolveTaskId(id, context);
  const beforeHousekeepingTask = await housekeepingTaskRepository.findById(resolvedId, HOUSEKEEPING_TASK_INCLUDE);

  if (!beforeHousekeepingTask) {
    throw new HttpError('errors.housekeeping_task.not_found', 404);
  }

  const processedData = await resolvePayload(data, context, { defaultFacility: false });
  const housekeepingTask = await housekeepingTaskRepository.update(resolvedId, processedData, HOUSEKEEPING_TASK_INCLUDE);

  await createAuditLog({
    action: 'HOUSEKEEPING_TASK_UPDATED',
    entity: 'housekeeping_task',
    entity_id: housekeepingTask.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeHousekeepingTask.facility_id,
        room_id: beforeHousekeepingTask.room_id,
        assigned_to_staff_id: beforeHousekeepingTask.assigned_to_staff_id,
        status: beforeHousekeepingTask.status,
        scheduled_at: beforeHousekeepingTask.scheduled_at,
        completed_at: beforeHousekeepingTask.completed_at,
      },
      after: {
        facility_id: housekeepingTask.facility_id,
        room_id: housekeepingTask.room_id,
        assigned_to_staff_id: housekeepingTask.assigned_to_staff_id,
        status: housekeepingTask.status,
        scheduled_at: housekeepingTask.scheduled_at,
        completed_at: housekeepingTask.completed_at,
      },
    },
  });

  return mapHousekeepingTask(housekeepingTask);
};

const deleteHousekeepingTask = async (id, context = {}) => {
  const resolvedId = await resolveTaskId(id, context);
  const housekeepingTask = await housekeepingTaskRepository.findById(resolvedId);

  if (!housekeepingTask) {
    throw new HttpError('errors.housekeeping_task.not_found', 404);
  }

  await housekeepingTaskRepository.softDelete(resolvedId);

  await createAuditLog({
    action: 'HOUSEKEEPING_TASK_DELETED',
    entity: 'housekeeping_task',
    entity_id: housekeepingTask.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      facility_id: housekeepingTask.facility_id,
      room_id: housekeepingTask.room_id,
      assigned_to_staff_id: housekeepingTask.assigned_to_staff_id,
      status: housekeepingTask.status,
    },
  });
};

module.exports = {
  listHousekeepingTasks,
  getHousekeepingTaskById,
  createHousekeepingTask,
  updateHousekeepingTask,
  deleteHousekeepingTask,
};
