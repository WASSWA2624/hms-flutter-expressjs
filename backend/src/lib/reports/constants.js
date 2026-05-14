const REPORT_PANELS = Object.freeze([
  { id: 'overview', label_key: 'reports.workspace.panels.overview', default_resource: 'report-runs' },
  { id: 'catalog', label_key: 'reports.workspace.panels.catalog', default_resource: 'report-definitions' },
  { id: 'delivery', label_key: 'reports.workspace.panels.delivery', default_resource: 'report-runs' },
  { id: 'dashboards', label_key: 'reports.workspace.panels.dashboards', default_resource: 'dashboard-widgets' },
  { id: 'monitor', label_key: 'reports.workspace.panels.monitor', default_resource: 'kpi-snapshots' },
  { id: 'activity', label_key: 'reports.workspace.panels.activity', default_resource: 'analytics-events' },
]);

const REPORT_RESOURCE_BY_PANEL = Object.freeze(
  REPORT_PANELS.reduce((acc, panel) => {
    acc[panel.id] = panel.default_resource;
    return acc;
  }, {})
);

const REPORT_RESOURCES = Object.freeze([
  'report-definitions',
  'report-runs',
  'dashboard-widgets',
  'kpi-snapshots',
  'analytics-events',
]);

const REPORT_FORMATS = Object.freeze(['PDF', 'CSV', 'JSON', 'XLSX']);
const REPORT_DEFINITION_STATUSES = Object.freeze(['DRAFT', 'ACTIVE', 'ARCHIVED']);
const REPORT_RUN_STATUSES = Object.freeze(['QUEUED', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED']);
const REPORT_TRIGGER_TYPES = Object.freeze(['MANUAL', 'SCHEDULED', 'RETRY']);
const REPORT_SCHEDULE_STATUSES = Object.freeze(['ACTIVE', 'PAUSED']);
const REPORT_SCHEDULE_FREQUENCIES = Object.freeze(['DAILY', 'WEEKLY', 'MONTHLY']);
const REPORT_WIDGET_TYPES = Object.freeze(['TABLE', 'KPI', 'LINE_CHART', 'BAR_CHART', 'AREA_CHART', 'DONUT_CHART']);
const KPI_THRESHOLD_STATES = Object.freeze(['NORMAL', 'WARNING', 'CRITICAL']);
const ANALYTICS_EVENT_SEVERITIES = Object.freeze(['INFO', 'WARNING', 'ERROR', 'CRITICAL']);

const REPORT_DEFAULT_RETENTION_DAYS = 30;
const REPORT_RUNNER_POLL_INTERVAL_MS = 60_000;
const REPORT_RUNNER_MAX_CONCURRENCY = 2;
const REPORT_SCHEDULE_LEASE_MS = 5 * 60_000;

const REPORT_DATASETS = Object.freeze([
  {
    key: 'patient_registrations',
    label: 'Patient registrations',
    category: 'patients',
    description: 'Registration volume and facility mix over time.',
    visualization: 'LINE_CHART',
    default_columns: ['date', 'registrations', 'facility'],
  },
  {
    key: 'appointment_throughput_no_shows',
    label: 'Appointment throughput and no-shows',
    category: 'appointments',
    description: 'Operational throughput and missed appointments.',
    visualization: 'BAR_CHART',
    default_columns: ['date', 'scheduled', 'completed', 'no_show'],
  },
  {
    key: 'billing_collections_open_balances',
    label: 'Billing collections and open balances',
    category: 'billing',
    description: 'Collections, invoice issuance, and open-balance workload.',
    visualization: 'AREA_CHART',
    default_columns: ['date', 'collections', 'open_invoices', 'issued_invoices'],
  },
  {
    key: 'insurance_claims_aging',
    label: 'Insurance claims aging',
    category: 'billing',
    description: 'Claim status distribution and aging buckets.',
    visualization: 'DONUT_CHART',
    default_columns: ['bucket', 'claims', 'status'],
  },
  {
    key: 'inventory_stock_risk',
    label: 'Inventory stock risk',
    category: 'inventory',
    description: 'Low-stock and critical-stock pressure across facilities.',
    visualization: 'KPI',
    default_columns: ['facility', 'inventory_item', 'quantity', 'reorder_level', 'risk_state'],
  },
  {
    key: 'hr_staffing_leave_coverage',
    label: 'HR staffing and leave coverage',
    category: 'hr',
    description: 'Staffing availability, leave pressure, and shift assignment gaps.',
    visualization: 'BAR_CHART',
    default_columns: ['metric', 'value', 'facility'],
  },
  {
    key: 'biomedical_incidents_downtime',
    label: 'Biomedical incidents and downtime',
    category: 'biomedical',
    description: 'Open incident volume, critical downtime, and service-risk indicators.',
    visualization: 'LINE_CHART',
    default_columns: ['metric', 'value', 'facility'],
  },
  {
    key: 'communications_delivery_performance',
    label: 'Communications delivery performance',
    category: 'communications',
    description: 'Channel delivery success and failure distribution.',
    visualization: 'DONUT_CHART',
    default_columns: ['channel', 'status', 'deliveries'],
  },
]);

const REPORT_DATASET_MAP = Object.freeze(
  REPORT_DATASETS.reduce((acc, dataset) => {
    acc[dataset.key] = dataset;
    return acc;
  }, {})
);

const REPORT_OVERVIEW_DATASET_KEYS = Object.freeze(REPORT_DATASETS.map((dataset) => dataset.key));

module.exports = {
  ANALYTICS_EVENT_SEVERITIES,
  KPI_THRESHOLD_STATES,
  REPORT_DATASETS,
  REPORT_DATASET_MAP,
  REPORT_DEFINITION_STATUSES,
  REPORT_DEFAULT_RETENTION_DAYS,
  REPORT_FORMATS,
  REPORT_OVERVIEW_DATASET_KEYS,
  REPORT_PANELS,
  REPORT_RESOURCES,
  REPORT_RESOURCE_BY_PANEL,
  REPORT_RUNNER_MAX_CONCURRENCY,
  REPORT_RUNNER_POLL_INTERVAL_MS,
  REPORT_RUN_STATUSES,
  REPORT_SCHEDULE_FREQUENCIES,
  REPORT_SCHEDULE_LEASE_MS,
  REPORT_SCHEDULE_STATUSES,
  REPORT_TRIGGER_TYPES,
  REPORT_WIDGET_TYPES,
};
