const { resolvePublicIdentifier } = require('@lib/billing/identifiers');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;
const safeNumber = (value, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const mapFacility = (record) => ({
  facility_id: safePublicId(record?.facility?.human_friendly_id, record?.facility_id),
  facility_label: record?.facility?.name || null,
});

const mapBranch = (record) => ({
  branch_id: safePublicId(record?.branch?.human_friendly_id, record?.branch_id),
  branch_label: record?.branch?.name || null,
});

const serializeReportRun = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    report_definition_id: safePublicId(
      record?.report_definition?.human_friendly_id,
      record.report_definition_id
    ),
    report_definition_label: record?.report_definition?.name || null,
    schedule_id: safePublicId(record?.schedule?.human_friendly_id, record.schedule_id),
    schedule_label: record?.schedule?.name || null,
    requested_by_user_id: safePublicId(
      record?.requested_by?.human_friendly_id,
      record.requested_by_user_id
    ),
    requested_by_label:
      record?.requested_by?.profile?.first_name || record?.requested_by?.email || null,
    trigger_type: record.trigger_type || null,
    format: record.format || null,
    status: record.status || null,
    parameters_json: record.parameters_json || null,
    output_file_name: record.output_file_name || null,
    output_mime_type: record.output_mime_type || null,
    output_size_bytes: safeNumber(record.output_size_bytes, 0),
    download_available: Boolean(record.output_storage_path && record.status === 'COMPLETED'),
    error_message: record.error_message || null,
    queued_at: record.queued_at || null,
    started_at: record.started_at || null,
    completed_at: record.completed_at || null,
    expires_at: record.expires_at || null,
    created_at: record.created_at,
    updated_at: record.updated_at,
    version: safeNumber(record.version, 1),
    ...mapFacility(record),
  };
};

const serializeReportDefinition = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    tenant_label: record?.tenant?.name || null,
    created_by_id: safePublicId(record?.creator?.human_friendly_id, record.created_by),
    created_by_label: record?.creator?.email || null,
    name: record.name,
    description: record.description || null,
    dataset_key: record.dataset_key || record?.definition_json?.dataset_key || null,
    category: record.category || null,
    status: record.status || null,
    default_format: record.default_format || null,
    definition_json: record.definition_json || null,
    parameter_schema_json: record.parameter_schema_json || null,
    latest_run: record?.runs?.[0] ? serializeReportRun(record.runs[0]) : null,
    schedule_count: safeNumber(record?._count?.schedules),
    active_schedule_count: safeNumber(
      (record?.schedules || []).filter((entry) => String(entry?.status || '').toUpperCase() === 'ACTIVE').length
    ),
    created_at: record.created_at,
    updated_at: record.updated_at,
    version: safeNumber(record.version, 1),
    ...mapFacility(record),
  };
};

const serializeReportSchedule = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    report_definition_id: safePublicId(
      record?.report_definition?.human_friendly_id,
      record.report_definition_id
    ),
    report_definition_label: record?.report_definition?.name || null,
    created_by_id: safePublicId(record?.creator?.human_friendly_id, record.created_by),
    created_by_label: record?.creator?.email || null,
    name: record.name,
    status: record.status,
    frequency: record.frequency,
    time_of_day: record.time_of_day || null,
    day_of_week: record.day_of_week,
    day_of_month: record.day_of_month,
    timezone: record.timezone,
    format: record.format,
    parameter_overrides_json: record.parameter_overrides_json || null,
    next_run_at: record.next_run_at || null,
    last_run_at: record.last_run_at || null,
    retention_days: safeNumber(record.retention_days, 30),
    pending_runs: safeNumber(record?._count?.runs),
    created_at: record.created_at,
    updated_at: record.updated_at,
    version: safeNumber(record.version, 1),
    ...mapFacility(record),
  };
};

const serializeDashboardWidget = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    report_definition_id: safePublicId(
      record?.report_definition?.human_friendly_id,
      record.report_definition_id
    ),
    report_definition_label: record?.report_definition?.name || null,
    tenant_label: record?.tenant?.name || null,
    name: record.name,
    widget_type: record.widget_type || null,
    role_scope_json: record.role_scope_json || null,
    placement: record.placement || null,
    sort_order: safeNumber(record.sort_order),
    is_pinned: Boolean(record.is_pinned),
    config_json: record.config_json || null,
    created_at: record.created_at,
    updated_at: record.updated_at,
    version: safeNumber(record.version, 1),
  };
};

const serializeKpiSnapshot = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    tenant_label: record?.tenant?.name || null,
    name: record.name,
    metric_key: record.metric_key || null,
    metric_group: record.metric_group || null,
    threshold_state: record.threshold_state || null,
    value: safeNumber(record.value),
    recorded_at: record.recorded_at || null,
    created_at: record.created_at,
    updated_at: record.updated_at,
    version: safeNumber(record.version, 1),
    ...mapFacility(record),
    ...mapBranch(record),
  };
};

const serializeAnalyticsEvent = (record) => {
  if (!record) return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    tenant_label: record?.tenant?.name || null,
    user_id: safePublicId(record?.user?.human_friendly_id, record.user_id),
    user_label: record?.user?.profile?.first_name || record?.user?.email || null,
    event_name: record.event_name,
    event_category: record.event_category || null,
    entity_type: record.entity_type || null,
    entity_public_id: record.entity_public_id || null,
    severity: record.severity || null,
    payload_json: record.payload_json || null,
    occurred_at: record.occurred_at || null,
    created_at: record.created_at,
    updated_at: record.updated_at,
    version: safeNumber(record.version, 1),
    ...mapFacility(record),
    ...mapBranch(record),
  };
};

module.exports = {
  safeNumber,
  safePublicId,
  serializeAnalyticsEvent,
  serializeDashboardWidget,
  serializeKpiSnapshot,
  serializeReportDefinition,
  serializeReportRun,
  serializeReportSchedule,
};
