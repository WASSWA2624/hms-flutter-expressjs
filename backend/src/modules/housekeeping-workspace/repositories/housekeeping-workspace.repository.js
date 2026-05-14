const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const todayRange = () => {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  return { gte: start, lt: end };
};

const nextSevenDaysRange = () => {
  const start = new Date();
  const end = new Date(start);
  end.setDate(end.getDate() + 7);
  return { gte: start, lte: end };
};

const thisMonthRange = () => {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  return { gte: start, lt: end };
};

const resolveDateRange = (datePreset) => {
  if (datePreset === 'today') return todayRange();
  if (datePreset === 'next_7_days') return nextSevenDaysRange();
  if (datePreset === 'this_month') return thisMonthRange();
  return null;
};

const applyDatePreset = (where, field, datePreset) => {
  const dateRange = resolveDateRange(datePreset);
  if (!dateRange) return;
  where[field] = dateRange;
};

const buildTaskWhere = ({ tenantId, facilityId, roomId, assigneeId, status, search, queue, datePreset }) => {
  const where = {
    deleted_at: null,
    facility: tenantId ? { tenant_id: tenantId, deleted_at: null } : { deleted_at: null },
  };

  if (facilityId) where.facility_id = facilityId;
  if (roomId) where.room_id = roomId;
  if (assigneeId) where.assigned_to_staff_id = assigneeId;
  if (status) where.status = status;

  if (queue === 'TODAY') {
    where.scheduled_at = todayRange();
  } else if (queue === 'OVERDUE_TASKS' || datePreset === 'overdue') {
    where.scheduled_at = { lt: new Date() };
    where.status = where.status || { notIn: ['COMPLETED', 'CANCELLED'] };
  } else {
    applyDatePreset(where, 'scheduled_at', datePreset);
  }

  const normalizedSearch = String(search || '').trim();
  if (normalizedSearch) {
    const upperSearch = normalizedSearch.toUpperCase();
    where.AND = [
      ...(Array.isArray(where.AND) ? where.AND : []),
      {
        OR: [
          { human_friendly_id: { contains: upperSearch } },
          { room: { name: { contains: normalizedSearch } } },
          { facility: { name: { contains: normalizedSearch } } },
          { assigned_to: { staff_number: { contains: normalizedSearch } } },
          { assigned_to: { user: { email: { contains: normalizedSearch } } } },
        ],
      },
    ];
  }

  return where;
};

const buildScheduleWhere = ({ tenantId, facilityId, roomId, search, datePreset }) => {
  const where = {
    deleted_at: null,
    facility: tenantId ? { tenant_id: tenantId, deleted_at: null } : { deleted_at: null },
  };

  if (facilityId) where.facility_id = facilityId;
  if (roomId) where.room_id = roomId;

  if (datePreset === 'overdue') {
    where.start_date = { lt: new Date() };
  } else {
    applyDatePreset(where, 'start_date', datePreset);
  }

  const normalizedSearch = String(search || '').trim();
  if (normalizedSearch) {
    const upperSearch = normalizedSearch.toUpperCase();
    where.AND = [
      ...(Array.isArray(where.AND) ? where.AND : []),
      {
        OR: [
          { human_friendly_id: { contains: upperSearch } },
          { frequency: { contains: normalizedSearch } },
          { room: { name: { contains: normalizedSearch } } },
          { facility: { name: { contains: normalizedSearch } } },
        ],
      },
    ];
  }

  return where;
};

const buildMaintenanceRequestWhere = ({ tenantId, facilityId, status, search, queue, datePreset }) => {
  const where = {
    deleted_at: null,
    OR: [
      { facility: tenantId ? { tenant_id: tenantId, deleted_at: null } : { deleted_at: null } },
      { asset: { tenant_id: tenantId, deleted_at: null } },
    ],
  };

  if (facilityId) where.facility_id = facilityId;
  if (status) where.status = status;

  if (queue === 'OPEN_REQUESTS') {
    where.status = where.status || { in: ['OPEN', 'IN_PROGRESS'] };
  } else if (queue === 'OVERDUE_REQUESTS' || datePreset === 'overdue') {
    const overdueAt = new Date();
    overdueAt.setDate(overdueAt.getDate() - 2);
    where.reported_at = { lt: overdueAt };
    where.status = where.status || { in: ['OPEN', 'IN_PROGRESS'] };
  } else {
    applyDatePreset(where, 'reported_at', datePreset);
  }

  const normalizedSearch = String(search || '').trim();
  if (normalizedSearch) {
    const upperSearch = normalizedSearch.toUpperCase();
    where.AND = [
      ...(Array.isArray(where.AND) ? where.AND : []),
      {
        OR: [
          { human_friendly_id: { contains: upperSearch } },
          { description: { contains: normalizedSearch } },
          { facility: { name: { contains: normalizedSearch } } },
          { asset: { name: { contains: normalizedSearch } } },
          { asset: { asset_tag: { contains: normalizedSearch } } },
        ],
      },
    ];
  }

  return where;
};

const buildAssetWhere = ({ tenantId, facilityId, status, search, datePreset }) => {
  const where = {
    deleted_at: null,
    tenant_id: tenantId,
  };

  if (facilityId) where.facility_id = facilityId;
  if (status) where.status = status;
  applyDatePreset(where, 'updated_at', datePreset);

  const normalizedSearch = String(search || '').trim();
  if (normalizedSearch) {
    const upperSearch = normalizedSearch.toUpperCase();
    where.AND = [
      ...(Array.isArray(where.AND) ? where.AND : []),
      {
        OR: [
          { human_friendly_id: { contains: upperSearch } },
          { name: { contains: normalizedSearch } },
          { asset_tag: { contains: normalizedSearch } },
        ],
      },
    ];
  }

  return where;
};

const buildServiceLogWhere = ({ tenantId, facilityId, search, datePreset }) => {
  const where = {
    deleted_at: null,
    asset: {
      tenant_id: tenantId,
      deleted_at: null,
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
  };

  applyDatePreset(where, 'serviced_at', datePreset);

  const normalizedSearch = String(search || '').trim();
  if (normalizedSearch) {
    const upperSearch = normalizedSearch.toUpperCase();
    where.AND = [
      ...(Array.isArray(where.AND) ? where.AND : []),
      {
        OR: [
          { human_friendly_id: { contains: upperSearch } },
          { notes: { contains: normalizedSearch } },
          { asset: { name: { contains: normalizedSearch } } },
          { asset: { asset_tag: { contains: normalizedSearch } } },
        ],
      },
    ];
  }

  return where;
};

const RESOURCE_INCLUDES = {
  'housekeeping-tasks': {
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
  },
  'housekeeping-schedules': {
    facility: { select: { id: true, human_friendly_id: true, name: true } },
    room: { select: { id: true, human_friendly_id: true, name: true } },
  },
  'maintenance-requests': {
    facility: { select: { id: true, human_friendly_id: true, name: true } },
    asset: { select: { id: true, human_friendly_id: true, name: true, asset_tag: true } },
  },
  assets: {
    facility: { select: { id: true, human_friendly_id: true, name: true } },
  },
  'asset-service-logs': {
    asset: {
      select: {
        id: true,
        human_friendly_id: true,
        name: true,
        asset_tag: true,
        facility_id: true,
        facility: { select: { id: true, human_friendly_id: true, name: true } },
      },
    },
  },
};

const SORT_FIELDS_BY_RESOURCE = {
  'housekeeping-tasks': new Set(['created_at', 'updated_at', 'scheduled_at', 'completed_at', 'status']),
  'housekeeping-schedules': new Set(['created_at', 'updated_at', 'start_date', 'end_date', 'frequency']),
  'maintenance-requests': new Set(['created_at', 'updated_at', 'reported_at', 'resolved_at', 'status']),
  assets: new Set(['created_at', 'updated_at', 'name', 'asset_tag', 'status']),
  'asset-service-logs': new Set(['created_at', 'updated_at', 'serviced_at']),
};

const resolveOrderBy = (resource, orderBy = {}) => {
  const entries = Object.entries(orderBy || {});
  const [field, direction] = entries[0] || ['updated_at', 'desc'];
  const allowedFields = SORT_FIELDS_BY_RESOURCE[resource] || new Set(['updated_at']);
  const safeField = allowedFields.has(field) ? field : 'updated_at';
  return { [safeField]: direction === 'asc' ? 'asc' : 'desc' };
};

const findSummary = async ({ tenantId, facilityId }) => {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date(todayStart);
  todayEnd.setDate(todayEnd.getDate() + 1);

  const [pendingTasks, completedToday, openRequests, overdueRequests, totalAssets] = await Promise.all([
    prisma.housekeeping_task.count({
      where: {
        ...buildTaskWhere({ tenantId, facilityId }),
        status: { in: ['PENDING', 'IN_PROGRESS'] },
      },
    }),
    prisma.housekeeping_task.count({
      where: {
        ...buildTaskWhere({ tenantId, facilityId }),
        status: 'COMPLETED',
        completed_at: { gte: todayStart, lt: todayEnd },
      },
    }),
    prisma.maintenance_request.count({
      where: {
        ...buildMaintenanceRequestWhere({ tenantId, facilityId }),
        status: { in: ['OPEN', 'IN_PROGRESS'] },
      },
    }),
    prisma.maintenance_request.count({
      where: buildMaintenanceRequestWhere({ tenantId, facilityId, queue: 'OVERDUE_REQUESTS' }),
    }),
    prisma.asset.count({
      where: {
        tenant_id: tenantId,
        deleted_at: null,
        ...(facilityId ? { facility_id: facilityId } : {}),
      },
    }),
  ]);

  return {
    pending_tasks: pendingTasks,
    completed_today: completedToday,
    open_requests: openRequests,
    overdue_requests: overdueRequests,
    total_assets: totalAssets,
  };
};

const findQueueCounts = async ({ tenantId, facilityId }) => {
  const [todayTasks, overdueTasks, openRequests, overdueRequests, historyItems] = await Promise.all([
    prisma.housekeeping_task.count({ where: buildTaskWhere({ tenantId, facilityId, queue: 'TODAY' }) }),
    prisma.housekeeping_task.count({ where: buildTaskWhere({ tenantId, facilityId, queue: 'OVERDUE_TASKS' }) }),
    prisma.maintenance_request.count({ where: buildMaintenanceRequestWhere({ tenantId, facilityId, queue: 'OPEN_REQUESTS' }) }),
    prisma.maintenance_request.count({ where: buildMaintenanceRequestWhere({ tenantId, facilityId, queue: 'OVERDUE_REQUESTS' }) }),
    prisma.asset_service_log.count({ where: buildServiceLogWhere({ tenantId, facilityId }) }),
  ]);

  return {
    TODAY: todayTasks,
    OVERDUE_TASKS: overdueTasks,
    OPEN_REQUESTS: openRequests,
    OVERDUE_REQUESTS: overdueRequests,
    SERVICE_HISTORY: historyItems,
  };
};

const findItems = async ({ resource, filters, skip, take, orderBy }) => {
  try {
    const safeOrderBy = resolveOrderBy(resource, orderBy);
    if (resource === 'housekeeping-tasks') {
      const where = buildTaskWhere(filters);
      const [items, total] = await Promise.all([
        prisma.housekeeping_task.findMany({ where, skip, take, orderBy: safeOrderBy, include: RESOURCE_INCLUDES[resource] }),
        prisma.housekeeping_task.count({ where }),
      ]);
      return { items, total };
    }

    if (resource === 'housekeeping-schedules') {
      const where = buildScheduleWhere(filters);
      const [items, total] = await Promise.all([
        prisma.housekeeping_schedule.findMany({ where, skip, take, orderBy: safeOrderBy, include: RESOURCE_INCLUDES[resource] }),
        prisma.housekeeping_schedule.count({ where }),
      ]);
      return { items, total };
    }

    if (resource === 'maintenance-requests') {
      const where = buildMaintenanceRequestWhere(filters);
      const [items, total] = await Promise.all([
        prisma.maintenance_request.findMany({ where, skip, take, orderBy: safeOrderBy, include: RESOURCE_INCLUDES[resource] }),
        prisma.maintenance_request.count({ where }),
      ]);
      return { items, total };
    }

    if (resource === 'assets') {
      const where = buildAssetWhere(filters);
      const [items, total] = await Promise.all([
        prisma.asset.findMany({ where, skip, take, orderBy: safeOrderBy, include: RESOURCE_INCLUDES[resource] }),
        prisma.asset.count({ where }),
      ]);
      return { items, total };
    }

    if (resource === 'asset-service-logs') {
      const where = buildServiceLogWhere(filters);
      const [items, total] = await Promise.all([
        prisma.asset_service_log.findMany({ where, skip, take, orderBy: safeOrderBy, include: RESOURCE_INCLUDES[resource] }),
        prisma.asset_service_log.count({ where }),
      ]);
      return { items, total };
    }

    return { items: [], total: 0 };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findLookups = async ({ tenantId, facilityId, search }) => {
  try {
    const normalizedSearch = String(search || '').trim();
    const searchUpper = normalizedSearch.toUpperCase();

    const [facilities, rooms, assets, assignees] = await Promise.all([
      prisma.facility.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          ...(normalizedSearch
            ? { OR: [{ name: { contains: normalizedSearch } }, { human_friendly_id: { contains: searchUpper } }] }
            : {}),
        },
        take: 50,
        orderBy: { name: 'asc' },
        select: { id: true, human_friendly_id: true, name: true, facility_type: true },
      }),
      prisma.room.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          ...(facilityId ? { facility_id: facilityId } : {}),
          ...(normalizedSearch
            ? { OR: [{ name: { contains: normalizedSearch } }, { human_friendly_id: { contains: searchUpper } }] }
            : {}),
        },
        take: 50,
        orderBy: { name: 'asc' },
        select: { id: true, human_friendly_id: true, name: true, floor: true, facility: { select: { name: true } } },
      }),
      prisma.asset.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          ...(facilityId ? { facility_id: facilityId } : {}),
          ...(normalizedSearch
            ? {
                OR: [
                  { name: { contains: normalizedSearch } },
                  { asset_tag: { contains: normalizedSearch } },
                  { human_friendly_id: { contains: searchUpper } },
                ],
              }
            : {}),
        },
        take: 50,
        orderBy: { name: 'asc' },
        select: { id: true, human_friendly_id: true, name: true, asset_tag: true, status: true },
      }),
      prisma.staff_profile.findMany({
        where: {
          tenant_id: tenantId,
          deleted_at: null,
          ...(normalizedSearch
            ? {
                OR: [
                  { staff_number: { contains: normalizedSearch } },
                  { human_friendly_id: { contains: searchUpper } },
                  { user: { email: { contains: normalizedSearch } } },
                ],
              }
            : {}),
        },
        take: 50,
        orderBy: { staff_number: 'asc' },
        select: {
          id: true,
          human_friendly_id: true,
          staff_number: true,
          position: true,
          user: { select: { email: true } },
        },
      }),
    ]);

    return { facilities, rooms, assets, assignees };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findSummary,
  findQueueCounts,
  findItems,
  findLookups,
};
