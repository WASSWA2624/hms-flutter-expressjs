const housekeepingWorkspaceRepository = require('@repositories/housekeeping-workspace/housekeeping-workspace.repository');
const { resolvePublicIdentifier, resolveIdentifierForFilter } = require('@lib/billing/identifiers');

const DEFAULT_PANEL = 'overview';
const DEFAULT_RESOURCE_BY_PANEL = Object.freeze({
  overview: 'housekeeping-tasks',
  tasks: 'housekeeping-tasks',
  requests: 'maintenance-requests',
  assets: 'assets',
  history: 'asset-service-logs',
});

const PANEL_DEFINITIONS = Object.freeze([
  { id: 'overview', label_key: 'housekeeping.workspace.panels.overview', default_resource: 'housekeeping-tasks' },
  { id: 'tasks', label_key: 'housekeeping.workspace.panels.tasks', default_resource: 'housekeeping-tasks' },
  { id: 'requests', label_key: 'housekeeping.workspace.panels.requests', default_resource: 'maintenance-requests' },
  { id: 'assets', label_key: 'housekeeping.workspace.panels.assets', default_resource: 'assets' },
  { id: 'history', label_key: 'housekeeping.workspace.panels.history', default_resource: 'asset-service-logs' },
]);

const QUEUE_DEFINITIONS = Object.freeze([
  { id: 'TODAY', label_key: 'housekeeping.workspace.queues.TODAY', panel: 'tasks', resource: 'housekeeping-tasks' },
  { id: 'OVERDUE_TASKS', label_key: 'housekeeping.workspace.queues.OVERDUE_TASKS', panel: 'tasks', resource: 'housekeeping-tasks' },
  { id: 'OPEN_REQUESTS', label_key: 'housekeeping.workspace.queues.OPEN_REQUESTS', panel: 'requests', resource: 'maintenance-requests' },
  { id: 'OVERDUE_REQUESTS', label_key: 'housekeeping.workspace.queues.OVERDUE_REQUESTS', panel: 'requests', resource: 'maintenance-requests' },
  { id: 'SERVICE_HISTORY', label_key: 'housekeeping.workspace.queues.SERVICE_HISTORY', panel: 'history', resource: 'asset-service-logs' },
]);

const STATUS_OPTIONS_BY_RESOURCE = Object.freeze({
  'housekeeping-tasks': ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'],
  'maintenance-requests': ['OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'],
  assets: ['OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'],
});

const normalizeString = (value) => String(value || '').trim();
const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;
const resolveStatusOptions = (resource) => STATUS_OPTIONS_BY_RESOURCE[resource] || [];
const resolvePriorityOptions = () => [];

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
  hasNextPage: page * limit < total,
  hasPreviousPage: page > 1,
});

const buildWorkspacePath = (params = {}) => {
  const query = new URLSearchParams();
  ['panel', 'resource', 'queue', 'status', 'facilityId', 'roomId', 'assigneeId', 'id', 'action'].forEach((key) => {
    const value = normalizeString(params[key]);
    if (value) query.set(key, value);
  });
  const serialized = query.toString();
  return serialized ? `/housekeeping?${serialized}` : '/housekeeping';
};

const mapLookupOption = (record, label, subtitle = null, meta = null) => ({
  id: safePublicId(record?.human_friendly_id, record?.id),
  label,
  subtitle,
  meta,
});

const mapSummaryCards = (summary = {}) => [
  { id: 'pending_tasks', label_key: 'housekeeping.workspace.summary.pendingTasks', value: Number(summary.pending_tasks || 0) },
  { id: 'completed_today', label_key: 'housekeeping.workspace.summary.completedToday', value: Number(summary.completed_today || 0) },
  { id: 'open_requests', label_key: 'housekeeping.workspace.summary.openRequests', value: Number(summary.open_requests || 0) },
  { id: 'overdue_requests', label_key: 'housekeeping.workspace.summary.overdueRequests', value: Number(summary.overdue_requests || 0) },
  { id: 'total_assets', label_key: 'housekeeping.workspace.summary.totalAssets', value: Number(summary.total_assets || 0) },
];

const mapQueueSummaries = (queueCounts = {}) =>
  QUEUE_DEFINITIONS.map((definition) => ({
    queue: definition.id,
    label_key: definition.label_key,
    count: Number(queueCounts[definition.id] || 0),
    panel: definition.panel,
    resource: definition.resource,
    target_path: buildWorkspacePath({
      panel: definition.panel,
      resource: definition.resource,
      queue: definition.id,
    }),
  }));

const mapPanelSummaries = (summary = {}, queueCounts = {}) =>
  PANEL_DEFINITIONS.map((panel) => {
    let count = 0;
    if (panel.id === 'overview') count = Number(summary.pending_tasks || 0) + Number(summary.open_requests || 0);
    if (panel.id === 'tasks') count = Number(queueCounts.TODAY || 0) + Number(queueCounts.OVERDUE_TASKS || 0);
    if (panel.id === 'requests') count = Number(queueCounts.OPEN_REQUESTS || 0) + Number(queueCounts.OVERDUE_REQUESTS || 0);
    if (panel.id === 'assets') count = Number(summary.total_assets || 0);
    if (panel.id === 'history') count = Number(queueCounts.SERVICE_HISTORY || 0);

    return {
      id: panel.id,
      label_key: panel.label_key,
      default_resource: panel.default_resource,
      count,
      target_path: buildWorkspacePath({ panel: panel.id, resource: panel.default_resource }),
    };
  });

const mapSpotlight = (queueCounts = {}) =>
  mapQueueSummaries(queueCounts)
    .filter((entry) => entry.count > 0)
    .sort((left, right) => right.count - left.count)
    .slice(0, 4);

const mapItem = (resource, item) => {
  if (resource === 'housekeeping-tasks') {
    return {
      id: safePublicId(item?.human_friendly_id, item?.id),
      human_friendly_id: safePublicId(item?.human_friendly_id, item?.id),
      resource,
      title: item?.room?.name || item?.facility?.name || safePublicId(item?.human_friendly_id, item?.id),
      subtitle: item?.assigned_to?.staff_number || item?.assigned_to?.user?.email || null,
      status: item?.status || null,
      priority: null,
      facility_id: safePublicId(item?.facility?.human_friendly_id, item?.facility_id),
      facility_label: item?.facility?.name || null,
      room_id: safePublicId(item?.room?.human_friendly_id, item?.room_id),
      room_label: item?.room?.name || null,
      assignee_id: safePublicId(item?.assigned_to?.human_friendly_id, item?.assigned_to_staff_id),
      assignee_label: item?.assigned_to?.staff_number || item?.assigned_to?.user?.email || null,
      scheduled_at: item?.scheduled_at || null,
      completed_at: item?.completed_at || null,
      timeline_at: item?.completed_at || item?.scheduled_at || item?.updated_at || item?.created_at || null,
      target_path: `/housekeeping/housekeeping-tasks/${safePublicId(item?.human_friendly_id, item?.id)}`,
    };
  }

  if (resource === 'housekeeping-schedules') {
    return {
      id: safePublicId(item?.human_friendly_id, item?.id),
      human_friendly_id: safePublicId(item?.human_friendly_id, item?.id),
      resource,
      title: item?.room?.name || item?.facility?.name || item?.frequency || safePublicId(item?.human_friendly_id, item?.id),
      subtitle: item?.frequency || null,
      status: null,
      priority: null,
      facility_id: safePublicId(item?.facility?.human_friendly_id, item?.facility_id),
      facility_label: item?.facility?.name || null,
      room_id: safePublicId(item?.room?.human_friendly_id, item?.room_id),
      room_label: item?.room?.name || null,
      start_date: item?.start_date || null,
      end_date: item?.end_date || null,
      timeline_at: item?.start_date || item?.updated_at || item?.created_at || null,
      target_path: `/housekeeping/housekeeping-schedules/${safePublicId(item?.human_friendly_id, item?.id)}`,
    };
  }

  if (resource === 'maintenance-requests') {
    return {
      id: safePublicId(item?.human_friendly_id, item?.id),
      human_friendly_id: safePublicId(item?.human_friendly_id, item?.id),
      resource,
      title: item?.asset?.name || safePublicId(item?.human_friendly_id, item?.id),
      subtitle: item?.description || item?.asset?.asset_tag || null,
      status: item?.status || null,
      priority: null,
      facility_id: safePublicId(item?.facility?.human_friendly_id, item?.facility_id),
      facility_label: item?.facility?.name || null,
      asset_id: safePublicId(item?.asset?.human_friendly_id, item?.asset_id),
      asset_label: item?.asset?.name || item?.asset?.asset_tag || null,
      reported_at: item?.reported_at || null,
      resolved_at: item?.resolved_at || null,
      timeline_at: item?.reported_at || item?.updated_at || item?.created_at || null,
      target_path: `/housekeeping/maintenance-requests/${safePublicId(item?.human_friendly_id, item?.id)}`,
    };
  }

  if (resource === 'assets') {
    return {
      id: safePublicId(item?.human_friendly_id, item?.id),
      human_friendly_id: safePublicId(item?.human_friendly_id, item?.id),
      resource,
      title: item?.name || safePublicId(item?.human_friendly_id, item?.id),
      subtitle: item?.asset_tag || null,
      status: item?.status || null,
      priority: null,
      facility_id: safePublicId(item?.facility?.human_friendly_id, item?.facility_id),
      facility_label: item?.facility?.name || null,
      timeline_at: item?.updated_at || item?.created_at || null,
      target_path: `/housekeeping/assets/${safePublicId(item?.human_friendly_id, item?.id)}`,
    };
  }

  return {
    id: safePublicId(item?.human_friendly_id, item?.id),
    human_friendly_id: safePublicId(item?.human_friendly_id, item?.id),
    resource,
    title: item?.asset?.name || safePublicId(item?.human_friendly_id, item?.id),
    subtitle: item?.notes || item?.asset?.asset_tag || null,
    status: null,
    priority: null,
    asset_id: safePublicId(item?.asset?.human_friendly_id, item?.asset_id),
    asset_label: item?.asset?.name || item?.asset?.asset_tag || null,
    facility_id: safePublicId(item?.asset?.facility?.human_friendly_id, item?.asset?.facility_id),
    facility_label: item?.asset?.facility?.name || null,
    serviced_at: item?.serviced_at || null,
    timeline_at: item?.serviced_at || item?.updated_at || item?.created_at || null,
    target_path: `/housekeeping/asset-service-logs/${safePublicId(item?.human_friendly_id, item?.id)}`,
  };
};

const resolveScopedFilters = async (filters = {}, user = {}) => {
  const tenantId = user?.tenant_id || user?.tenantId || null;
  const scopedFilters = {
    tenantId,
    status: normalizeString(filters.status) || undefined,
    priority: normalizeString(filters.priority) || undefined,
    search: normalizeString(filters.search) || undefined,
    queue: normalizeString(filters.queue) || undefined,
    datePreset: normalizeString(filters.date_preset) || undefined,
  };

  scopedFilters.facilityId = await resolveIdentifierForFilter({
    value: filters.facility_id || user?.facility_id || user?.facilityId,
    model: 'facility',
    where: tenantId ? { tenant_id: tenantId } : {},
  });

  scopedFilters.roomId = await resolveIdentifierForFilter({
    value: filters.room_id,
    model: 'room',
    where: tenantId ? { tenant_id: tenantId } : {},
  });

  scopedFilters.assigneeId = await resolveIdentifierForFilter({
    value: filters.assignee_id,
    model: 'staff_profile',
    where: tenantId ? { tenant_id: tenantId } : {},
  });

  return scopedFilters;
};

const getWorkspace = async (filters = {}, page = 1, limit = 20, sortBy, order = 'desc', user = {}) => {
  const panel = normalizeString(filters.panel) || DEFAULT_PANEL;
  const resource = normalizeString(filters.resource) || DEFAULT_RESOURCE_BY_PANEL[panel] || DEFAULT_RESOURCE_BY_PANEL[DEFAULT_PANEL];
  const scopedFilters = await resolveScopedFilters(filters, user);
  const statusOptions = resolveStatusOptions(resource);
  const priorityOptions = resolvePriorityOptions(resource);
  const itemFilters = {
    ...scopedFilters,
    status: statusOptions.includes(scopedFilters.status) ? scopedFilters.status : undefined,
    priority: priorityOptions.includes(scopedFilters.priority) ? scopedFilters.priority : undefined,
  };
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy || 'updated_at']: order === 'asc' ? 'asc' : 'desc' };

  const [summary, queueCounts, listResult, lookups] = await Promise.all([
    housekeepingWorkspaceRepository.findSummary(scopedFilters),
    housekeepingWorkspaceRepository.findQueueCounts(scopedFilters),
    housekeepingWorkspaceRepository.findItems({ resource, filters: itemFilters, skip, take: limit, orderBy }),
    housekeepingWorkspaceRepository.findLookups(scopedFilters),
  ]);

  return {
    summary: mapSummaryCards(summary),
    queue_summaries: mapQueueSummaries(queueCounts),
    panel_summaries: mapPanelSummaries(summary, queueCounts),
    filters: {
      panel,
      resource,
      queue: normalizeString(filters.queue) || null,
      search: normalizeString(filters.search) || '',
      status: itemFilters.status || null,
      priority: itemFilters.priority || null,
      facility_id: safePublicId(undefined, scopedFilters.facilityId),
      room_id: safePublicId(undefined, scopedFilters.roomId),
      assignee_id: safePublicId(undefined, scopedFilters.assigneeId),
      date_preset: normalizeString(filters.date_preset) || null,
      id: normalizeString(filters.id) || null,
      action: normalizeString(filters.action) || null,
    },
    lookups: {
      facilities: (lookups.facilities || []).map((entry) =>
        mapLookupOption(entry, entry.name, entry.facility_type || null, { facility_type: entry.facility_type || null })
      ),
      rooms: (lookups.rooms || []).map((entry) =>
        mapLookupOption(entry, entry.name, entry.facility?.name || entry.floor || null, { floor: entry.floor || null })
      ),
      assignees: (lookups.assignees || []).map((entry) =>
        mapLookupOption(entry, entry.staff_number || entry.user?.email || '-', entry.position || null, { position: entry.position || null })
      ),
      assets: (lookups.assets || []).map((entry) =>
        mapLookupOption(entry, entry.name, entry.asset_tag || entry.status || null, { status: entry.status || null })
      ),
      statuses: statusOptions.map((entry) => ({ id: entry, label: entry, subtitle: null, meta: null })),
      priorities: priorityOptions.map((entry) => ({ id: entry, label: entry, subtitle: null, meta: null })),
      queues: QUEUE_DEFINITIONS.map((entry) => ({ id: entry.id, label: entry.id, subtitle: entry.panel, meta: { resource: entry.resource } })),
    },
    items: (listResult.items || []).map((item) => mapItem(resource, item)),
    pagination: buildPagination(page, limit, Number(listResult.total || 0)),
    spotlight: mapSpotlight(queueCounts),
  };
};

const getLookups = async (filters = {}, user = {}) => {
  const scopedFilters = await resolveScopedFilters(filters, user);
  const lookups = await housekeepingWorkspaceRepository.findLookups(scopedFilters);

  return {
    facilities: (lookups.facilities || []).map((entry) =>
      mapLookupOption(entry, entry.name, entry.facility_type || null, { facility_type: entry.facility_type || null })
    ),
    rooms: (lookups.rooms || []).map((entry) =>
      mapLookupOption(entry, entry.name, entry.facility?.name || entry.floor || null, { floor: entry.floor || null })
    ),
    assignees: (lookups.assignees || []).map((entry) =>
      mapLookupOption(entry, entry.staff_number || entry.user?.email || '-', entry.position || null, { position: entry.position || null })
    ),
    assets: (lookups.assets || []).map((entry) =>
      mapLookupOption(entry, entry.name, entry.asset_tag || entry.status || null, { status: entry.status || null })
    ),
  };
};

module.exports = {
  getWorkspace,
  getLookups,
};
