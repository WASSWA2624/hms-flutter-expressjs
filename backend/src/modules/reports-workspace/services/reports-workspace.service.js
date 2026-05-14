const reportsWorkspaceRepository = require('@repositories/reports-workspace/reports-workspace.repository');
const dashboardWidgetService = require('@services/dashboard-widget/dashboard-widget.service');
const {
  buildDateWindowFilter,
  buildPagination,
  buildSearchWhere,
  normalizeString,
  resolveScopeIdsForList,
  safePublicId,
  safeUpper,
} = require('@lib/reports/api');
const {
  REPORT_DATASETS,
  REPORT_FORMATS,
  REPORT_PANELS,
  REPORT_RESOURCE_BY_PANEL,
  REPORT_RESOURCES,
  REPORT_SCHEDULE_FREQUENCIES,
  REPORT_TRIGGER_TYPES,
} = require('@lib/reports/constants');
const {
  serializeAnalyticsEvent,
  serializeDashboardWidget,
  serializeKpiSnapshot,
  serializeReportDefinition,
  serializeReportRun,
  serializeReportSchedule,
} = require('@lib/reports/serializers');

const buildWorkspaceFilters = (filters = {}) => ({
  ...filters,
  facility_id: filters.facility_id || filters.facilityId,
  branch_id: filters.branch_id || filters.branchId,
  owner_id: filters.owner_id || filters.ownerId,
  date_preset: filters.date_preset || filters.datePreset,
});

const buildLookups = (lookups = {}) => {
  const facilities = (lookups.facilities || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label: entry.name,
  }));
  const facilityPublicIdByInternalId = facilities.reduce((acc, entry, index) => {
    const source = lookups.facilities?.[index];
    if (source?.id) {
      acc[source.id] = entry.id;
    }
    return acc;
  }, {});

  return {
    facilities,
    branches: (lookups.branches || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label: entry.name,
    meta: {
      facility_id:
        facilityPublicIdByInternalId[entry.facility_id] ||
        safePublicId(undefined, entry.facility_id),
    },
  })),
    owners: (lookups.users || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label:
      [entry?.profile?.first_name, entry?.profile?.last_name].filter(Boolean).join(' ') ||
      entry.email ||
      safePublicId(entry.human_friendly_id, entry.id),
  })),
    datasets: REPORT_DATASETS.map((entry) => ({
    id: entry.key,
    label: entry.label,
    subtitle: entry.description,
    meta: {
      category: entry.category,
      visualization: entry.visualization,
    },
  })),
    statuses: [
    'DRAFT',
    'ACTIVE',
    'ARCHIVED',
    'QUEUED',
    'PROCESSING',
    'COMPLETED',
    'FAILED',
    'CANCELLED',
    'PAUSED',
    'NORMAL',
    'WARNING',
    'CRITICAL',
  ].map((entry) => ({ id: entry, label: entry })),
    formats: REPORT_FORMATS.map((entry) => ({ id: entry, label: entry })),
    triggers: REPORT_TRIGGER_TYPES.map((entry) => ({ id: entry, label: entry })),
    frequencies: REPORT_SCHEDULE_FREQUENCIES.map((entry) => ({ id: entry, label: entry })),
    panels: REPORT_PANELS.map((entry) => ({ id: entry.id, label_key: entry.label_key })),
    resources: REPORT_RESOURCES.map((entry) => ({ id: entry, label: entry })),
  };
};

const resolveScopedPublicId = ({
  explicitValue,
  internalId,
  entries = [],
}) => {
  const explicitPublicId = safePublicId(explicitValue);
  if (explicitPublicId) return explicitPublicId;

  const matchedEntry = entries.find((entry) => entry?.id === internalId);
  return safePublicId(matchedEntry?.human_friendly_id, internalId);
};

const buildSummaryCards = (summary = {}) => [
  { id: 'definitions', label: 'Report definitions', value: Number(summary.total_definitions || 0) },
  { id: 'runs_queued', label: 'Queued runs', value: Number(summary.queued_runs || 0) },
  { id: 'schedules_due', label: 'Due schedules', value: Number(summary.due_schedules || 0) },
  { id: 'widgets_pinned', label: 'Pinned widgets', value: Number(summary.pinned_widgets || 0) },
  { id: 'kpi_critical', label: 'Critical KPIs', value: Number(summary.critical_kpis || 0) },
  { id: 'activity_24h', label: 'Activity (24h)', value: Number(summary.recent_activity || 0) },
];

const buildQueueSummaries = (summary = {}) => [
  { id: 'FAILED_RUNS', label: 'Failed runs', count: Number(summary.failed_runs || 0), panel: 'delivery', resource: 'report-runs' },
  { id: 'QUEUED_RUNS', label: 'Queued runs', count: Number(summary.queued_runs || 0), panel: 'delivery', resource: 'report-runs' },
  { id: 'DUE_SCHEDULES', label: 'Due schedules', count: Number(summary.due_schedules || 0), panel: 'delivery', resource: 'report-runs' },
  { id: 'STALE_WIDGETS', label: 'Stale widgets', count: Number(summary.stale_widgets || 0), panel: 'dashboards', resource: 'dashboard-widgets' },
  { id: 'KPI_EXCEPTIONS', label: 'KPI exceptions', count: Number(summary.critical_kpis || 0) + Number(summary.warning_kpis || 0), panel: 'monitor', resource: 'kpi-snapshots' },
];

const buildPanelSummaries = (summary = {}) => [
  { id: 'overview', count: Number(summary.queued_runs || 0) + Number(summary.failed_runs || 0), default_resource: 'report-runs' },
  { id: 'catalog', count: Number(summary.total_definitions || 0), default_resource: 'report-definitions' },
  { id: 'delivery', count: Number(summary.queued_runs || 0) + Number(summary.total_schedules || 0), default_resource: 'report-runs' },
  { id: 'dashboards', count: Number(summary.pinned_widgets || 0), default_resource: 'dashboard-widgets' },
  { id: 'monitor', count: Number(summary.critical_kpis || 0) + Number(summary.warning_kpis || 0), default_resource: 'kpi-snapshots' },
  { id: 'activity', count: Number(summary.recent_activity || 0), default_resource: 'analytics-events' },
];

const buildSpotlight = (summary = {}) =>
  buildQueueSummaries(summary)
    .filter((entry) => entry.count > 0)
    .sort((left, right) => right.count - left.count)
    .slice(0, 5);

const mapTimeline = (timeline = {}) => {
  const entries = [];

  (timeline.runs || []).forEach((entry) => {
    const run = serializeReportRun(entry);
    entries.push({
      id: `run:${run.id}`,
      type: 'report_run',
      title: run.report_definition_label || run.human_friendly_id,
      subtitle: run.status,
      occurred_at: run.completed_at || run.queued_at || run.created_at,
      status: run.status,
      resource: 'report-runs',
      target_id: run.id,
    });
  });

  (timeline.schedules || []).forEach((entry) => {
    const schedule = serializeReportSchedule(entry);
    entries.push({
      id: `schedule:${schedule.id}`,
      type: 'report_schedule',
      title: schedule.name,
      subtitle: schedule.status,
      occurred_at: schedule.updated_at || schedule.next_run_at || schedule.created_at,
      status: schedule.status,
      resource: 'report-runs',
      target_id: schedule.id,
    });
  });

  (timeline.kpis || []).forEach((entry) => {
    const snapshot = serializeKpiSnapshot(entry);
    entries.push({
      id: `kpi:${snapshot.id}`,
      type: 'kpi_snapshot',
      title: snapshot.name,
      subtitle: snapshot.threshold_state,
      occurred_at: snapshot.recorded_at || snapshot.created_at,
      status: snapshot.threshold_state,
      resource: 'kpi-snapshots',
      target_id: snapshot.id,
    });
  });

  (timeline.events || []).forEach((entry) => {
    const event = serializeAnalyticsEvent(entry);
    entries.push({
      id: `event:${event.id}`,
      type: 'analytics_event',
      title: event.event_name,
      subtitle: event.severity,
      occurred_at: event.occurred_at || event.created_at,
      status: event.severity,
      resource: 'analytics-events',
      target_id: event.id,
    });
  });

  return entries
    .sort((left, right) => new Date(right.occurred_at || 0).getTime() - new Date(left.occurred_at || 0).getTime())
    .slice(0, 20);
};

const buildResourceWhere = (resource, scoped, filters = {}) => {
  const where = {
    tenant_id: scoped.tenant_id,
  };

  if (scoped.facility_id && ['report-definitions', 'report-runs', 'kpi-snapshots', 'analytics-events'].includes(resource)) {
    where.facility_id = scoped.facility_id;
  }
  if (scoped.branch_id && ['kpi-snapshots', 'analytics-events'].includes(resource)) {
    where.branch_id = scoped.branch_id;
  }
  if (scoped.owner_id && resource === 'report-runs') {
    where.requested_by_user_id = scoped.owner_id;
  }
  if (scoped.owner_id && resource === 'report-definitions') {
    where.created_by = scoped.owner_id;
  }
  if (normalizeString(filters.dataset) && resource === 'report-definitions') {
    where.dataset_key = normalizeString(filters.dataset);
  }
  if (normalizeString(filters.status)) {
    where.status = safeUpper(filters.status);
  }
  if (normalizeString(filters.format) && resource === 'report-runs') {
    where.format = safeUpper(filters.format);
  }
  if (normalizeString(filters.trigger) && resource === 'report-runs') {
    where.trigger_type = safeUpper(filters.trigger);
  }
  if (normalizeString(filters.search)) {
    Object.assign(
      where,
      buildSearchWhere(filters.search, {
        'report-definitions': ['name', 'description', 'dataset_key', 'category'],
        'report-runs': ['status', 'format', 'trigger_type'],
        'dashboard-widgets': ['name', 'placement', 'widget_type'],
        'kpi-snapshots': ['name', 'metric_key', 'metric_group'],
        'analytics-events': ['event_name', 'event_category', 'entity_type', 'entity_public_id'],
      }[resource] || [])
    );
  }
  if (filters.from || filters.to) {
    const field =
      resource === 'report-runs'
        ? 'queued_at'
        : resource === 'kpi-snapshots'
          ? 'recorded_at'
          : resource === 'analytics-events'
            ? 'occurred_at'
            : 'updated_at';
    Object.assign(where, buildDateWindowFilter({ from: filters.from, to: filters.to, field }));
  }

  return where;
};

const serializeItems = (resource, items = []) => {
  if (resource === 'report-definitions') return items.map(serializeReportDefinition);
  if (resource === 'report-runs') return items.map(serializeReportRun);
  if (resource === 'dashboard-widgets') return items.map(serializeDashboardWidget);
  if (resource === 'kpi-snapshots') return items.map(serializeKpiSnapshot);
  return items.map(serializeAnalyticsEvent);
};

const getWorkspace = async (query = {}, page = 1, limit = 20, sortBy, order = 'desc', user = {}) => {
  const filters = buildWorkspaceFilters(query);
  const panel = normalizeString(filters.panel) || 'overview';
  const resource = normalizeString(filters.resource) || REPORT_RESOURCE_BY_PANEL[panel] || 'report-runs';
  const scoped = await resolveScopeIdsForList({ filters, user, resource });
  const where = buildResourceWhere(resource, scoped, filters);
  const orderBy = {
    [sortBy || (resource === 'report-runs' ? 'queued_at' : resource === 'kpi-snapshots' ? 'recorded_at' : resource === 'analytics-events' ? 'occurred_at' : 'updated_at')]:
      order === 'asc' ? 'asc' : 'desc',
  };
  const skip = (page - 1) * limit;

  const [summary, lookups, itemsResult, timeline, dashboardSummary] = await Promise.all([
    reportsWorkspaceRepository.findSummary(scoped),
    reportsWorkspaceRepository.findLookups(scoped),
    reportsWorkspaceRepository.findItems({ resource, where, skip, take: limit, orderBy }),
    reportsWorkspaceRepository.findTimeline(scoped),
    dashboardWidgetService.getDashboardSummary(
      {
        tenant_id: scoped.tenant_id,
        facility_id: scoped.facility_id,
        branch_id: scoped.branch_id,
        days: filters.date_preset === 'last_30_days' ? 30 : 7,
      },
      user
    ).catch(() => null),
  ]);
  const facilityPublicId = resolveScopedPublicId({
    explicitValue: filters.facility_id || filters.facilityId,
    internalId: scoped.facility_id,
    entries: lookups.facilities,
  });
  const branchPublicId = resolveScopedPublicId({
    explicitValue: filters.branch_id || filters.branchId,
    internalId: scoped.branch_id,
    entries: lookups.branches,
  });
  const ownerPublicId = resolveScopedPublicId({
    explicitValue: filters.owner_id || filters.ownerId,
    internalId: scoped.owner_id,
    entries: lookups.users,
  });

  return {
    summary: buildSummaryCards(summary),
    queue_summaries: buildQueueSummaries(summary),
    panel_summaries: buildPanelSummaries(summary),
    filters: {
      panel,
      resource,
      id: normalizeString(filters.id) || null,
      action: normalizeString(filters.action) || null,
      search: normalizeString(filters.search) || '',
      status: normalizeString(filters.status) || null,
      format: normalizeString(filters.format) || null,
      dataset: normalizeString(filters.dataset) || null,
      facilityId: facilityPublicId,
      branchId: branchPublicId,
      ownerId: ownerPublicId,
      trigger: normalizeString(filters.trigger) || null,
      datePreset: normalizeString(filters.date_preset || filters.datePreset) || null,
      from: filters.from || null,
      to: filters.to || null,
    },
    lookups: buildLookups(lookups),
    items: serializeItems(resource, itemsResult.items),
    pagination: buildPagination(page, limit, Number(itemsResult.total || 0)),
    spotlight: buildSpotlight(summary),
    timeline: mapTimeline(timeline),
    dashboard_summary: dashboardSummary,
  };
};

const getLookups = async (query = {}, user = {}) => {
  const filters = buildWorkspaceFilters(query);
  const scoped = await resolveScopeIdsForList({ filters, user });
  const lookups = await reportsWorkspaceRepository.findLookups(scoped);
  return buildLookups(lookups);
};

module.exports = {
  getLookups,
  getWorkspace,
};
