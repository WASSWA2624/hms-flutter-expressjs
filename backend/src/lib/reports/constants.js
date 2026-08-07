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
    label: 'Billing collections, expenditures, and profit',
    category: 'billing',
    description:
      'Period collections, expenditures (refunds and write-offs), profit proxy, and invoice workload.',
    visualization: 'AREA_CHART',
    default_columns: [
      'date',
      'collections',
      'expenditures',
      'profit_proxy',
      'refunds',
      'write_offs',
      'net_collections',
      'issued_invoices',
      'open_invoices',
    ],
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
    key: 'pharmacy_drug_consumption',
    label: 'Pharmacy drug consumption',
    category: 'pharmacy',
    description:
      'Top dispensed drugs by quantity and amount for a period, with walk-in (PHARMACY) vs clinical order-source mix and profit when buy cost is configured.',
    visualization: 'BAR_CHART',
    default_columns: ['drug', 'quantity_dispensed', 'amount', 'profit', 'order_source'],
  },
  {
    key: 'pharmacy_dispense_throughput',
    label: 'Pharmacy dispense throughput',
    category: 'pharmacy',
    description:
      'Order creation and dispense status throughput over time, including returns when logged.',
    visualization: 'LINE_CHART',
    default_columns: [
      'date',
      'orders_created',
      'dispensed',
      'partially_dispensed',
      'cancelled',
      'returns',
    ],
  },
  {
    key: 'pharmacy_sales_by_category',
    label: 'Pharmacy sales by category',
    category: 'pharmacy',
    description:
      'Dispense revenue grouped by inventory_item.category via drug_inventory_map.',
    visualization: 'BAR_CHART',
    default_columns: ['category', 'quantity_dispensed', 'amount'],
  },
  {
    key: 'pharmacy_sales_by_branch',
    label: 'Pharmacy sales by branch',
    category: 'pharmacy',
    description: 'Dispense revenue grouped by patient facility (branch).',
    visualization: 'BAR_CHART',
    default_columns: ['facility', 'amount', 'quantity_dispensed'],
  },
  {
    key: 'pharmacy_profit_by_branch',
    label: 'Pharmacy profit by branch',
    category: 'pharmacy',
    description:
      'Dispense retail profit (unit_price − buy_unit_price) × qty grouped by patient facility.',
    visualization: 'BAR_CHART',
    default_columns: ['facility', 'profit', 'amount'],
  },
  {
    key: 'pharmacy_stock_by_branch',
    label: 'Pharmacy stock by branch',
    category: 'pharmacy',
    description: 'On-hand inventory quantity and value grouped by facility.',
    visualization: 'BAR_CHART',
    default_columns: ['facility', 'quantity', 'value'],
  },
  {
    key: 'pharmacy_purchases_by_branch',
    label: 'Pharmacy purchases by branch',
    category: 'pharmacy',
    description:
      'Purchase request and linked purchase order counts by facility (PO line amounts not modeled).',
    visualization: 'TABLE',
    default_columns: ['facility', 'request_count', 'order_count'],
  },
  {
    key: 'pharmacy_stock_shortages_by_branch',
    label: 'Pharmacy stock shortages by branch',
    category: 'pharmacy',
    description:
      'LOW / CRITICAL / OUT_OF_STOCK inventory risk counts grouped by facility.',
    visualization: 'TABLE',
    default_columns: [
      'facility',
      'shortage_count',
      'low_count',
      'critical_count',
      'out_of_stock_count',
      'quantity',
    ],
  },
  {
    key: 'pharmacy_best_performing_branch',
    label: 'Best-performing branch',
    category: 'pharmacy',
    description: 'Facilities ranked by dispense amount or profit.',
    visualization: 'TABLE',
    default_columns: ['rank', 'facility', 'amount', 'profit', 'quantity_dispensed'],
  },
  {
    key: 'pharmacy_branch_comparison',
    label: 'Branch comparison',
    category: 'pharmacy',
    description:
      'Side-by-side facility comparison of sales, profit, stock, shortages, and purchases.',
    visualization: 'BAR_CHART',
    default_columns: [
      'facility',
      'amount',
      'profit',
      'quantity_dispensed',
      'quantity',
      'value',
      'shortage_count',
      'request_count',
      'order_count',
    ],
  },
  {
    key: 'pharmacy_sales_by_customer',
    label: 'Pharmacy sales by customer',
    category: 'pharmacy',
    description: 'Dispense revenue grouped by pharmacy order patient.',
    visualization: 'BAR_CHART',
    default_columns: ['patient', 'amount', 'quantity_dispensed'],
  },
  {
    key: 'pharmacy_sales_payment_methods',
    label: 'Pharmacy sales by payment method',
    category: 'pharmacy',
    description: 'Pharmacy-scoped payment totals by PaymentMethodType.',
    visualization: 'DONUT_CHART',
    default_columns: ['method', 'amount'],
  },
  {
    key: 'pharmacy_sales_discounts',
    label: 'Pharmacy discounts',
    category: 'pharmacy',
    description: 'Negative applied billing adjustments on pharmacy invoices.',
    visualization: 'TABLE',
    default_columns: ['date', 'amount', 'reason'],
  },
  {
    key: 'pharmacy_sales_refunds',
    label: 'Pharmacy refunds and returns',
    category: 'pharmacy',
    description: 'Pharmacy refund amounts and dispense return counts by period.',
    visualization: 'TABLE',
    default_columns: ['date', 'amount', 'returns'],
  },
  {
    key: 'pharmacy_sales_net_revenue',
    label: 'Pharmacy net revenue',
    category: 'pharmacy',
    description: 'Gross dispense revenue minus pharmacy refunds and discounts.',
    visualization: 'KPI',
    default_columns: ['metric', 'amount'],
  },
  {
    key: 'pharmacy_sales_avg_transaction',
    label: 'Pharmacy average transaction value',
    category: 'pharmacy',
    description: 'Period gross dispense amount divided by orders_created.',
    visualization: 'KPI',
    default_columns: ['average_transaction_value', 'orders_created', 'amount'],
  },
  {
    key: 'pharmacy_customer_count',
    label: 'Pharmacy number of customers',
    category: 'pharmacy',
    description: 'Distinct pharmacy_order.patient_id count in period.',
    visualization: 'KPI',
    default_columns: ['customer_count'],
  },
  {
    key: 'pharmacy_customers_new_vs_returning',
    label: 'Pharmacy new vs returning customers',
    category: 'pharmacy',
    description:
      'New = first-ever pharmacy order in range with none before from; returning = prior order before from and again in range.',
    visualization: 'DONUT_CHART',
    default_columns: ['segment', 'customer_count'],
  },
  {
    key: 'pharmacy_patient_medication_history',
    label: 'Pharmacy patient medication history',
    category: 'pharmacy',
    description:
      'Dispense lines in period with patient label, drug, quantity, dispensed_at, and amount.',
    visualization: 'TABLE',
    default_columns: [
      'patient',
      'drug',
      'quantity_dispensed',
      'dispensed_at',
      'amount',
    ],
  },
  {
    key: 'pharmacy_customer_credit_balance',
    label: 'Pharmacy customer credit balance',
    category: 'pharmacy',
    description:
      'Sum of open pharmacy invoice balances per patient (status DRAFT|SENT|OVERDUE, balance_due > 0).',
    visualization: 'TABLE',
    default_columns: ['patient', 'credit_balance'],
  },
  {
    key: 'pharmacy_customer_outstanding',
    label: 'Pharmacy outstanding payments',
    category: 'pharmacy',
    description:
      'Open pharmacy invoices with balance due (same open status set as billing module).',
    visualization: 'TABLE',
    default_columns: ['patient', 'amount', 'issued_at'],
  },
  {
    key: 'pharmacy_customer_demographics',
    label: 'Pharmacy customer demographics',
    category: 'pharmacy',
    description:
      'Aggregate gender and age-band counts for patients with pharmacy orders in period (no individual PHI columns).',
    visualization: 'BAR_CHART',
    default_columns: ['dimension', 'bucket', 'customer_count'],
  },
  {
    key: 'pharmacy_customer_retention',
    label: 'Pharmacy customer retention',
    category: 'pharmacy',
    description:
      'Share of prior-window purchasers who also purchase in the current window (equal-length prior window).',
    visualization: 'KPI',
    default_columns: ['segment', 'customer_count', 'retention_rate'],
  },
  {
    key: 'inventory_stock_risk',
    label: 'Inventory stock risk',
    category: 'inventory',
    description:
      'On-hand stock plus low-stock, overstock, critical, near-expiry, and expired drug batch pressure. Expiry value at buy cost; windows 0-30/30-60/60-90/90-180.',
    visualization: 'KPI',
    default_columns: [
      'facility',
      'inventory_item',
      'quantity',
      'reorder_level',
      'risk_state',
      'expiry_date',
      'expiry_alert_status',
      'days_to_expiry',
      'expiry_window',
      'batch_number',
      'value',
      'category',
      'supplier',
      'supplier_id',
      'drug',
    ],
  },
  {
    key: 'inventory_stock_value',
    label: 'Inventory stock value',
    category: 'inventory',
    description:
      'On-hand quantity × unit cost (prefer buy_unit_price via drug_inventory_map).',
    visualization: 'TABLE',
    default_columns: [
      'facility',
      'inventory_item',
      'quantity',
      'unit_cost',
      'value',
      'cost_basis',
      'risk_state',
    ],
  },
  {
    key: 'inventory_opening_closing',
    label: 'Opening and closing stock',
    category: 'inventory',
    description:
      'Closing = current on-hand; opening reconstructed from period stock_movement and stock_adjustment net.',
    visualization: 'TABLE',
    default_columns: [
      'inventory_item',
      'facility',
      'opening_quantity',
      'closing_quantity',
      'unit',
    ],
  },
  {
    key: 'inventory_stock_received',
    label: 'Stock received',
    category: 'inventory',
    description: 'INBOUND stock_movement rows with reason PURCHASE.',
    visualization: 'TABLE',
    default_columns: ['occurred_at', 'inventory_item', 'quantity', 'facility'],
  },
  {
    key: 'inventory_stock_issued',
    label: 'Stock issued',
    category: 'inventory',
    description: 'OUTBOUND stock_movement rows with reason DISPENSE.',
    visualization: 'TABLE',
    default_columns: ['occurred_at', 'inventory_item', 'quantity', 'facility'],
  },
  {
    key: 'inventory_stock_adjustments',
    label: 'Stock adjustments',
    category: 'inventory',
    description: 'stock_adjustment rows for the selected period.',
    visualization: 'TABLE',
    default_columns: [
      'adjusted_at',
      'inventory_item',
      'quantity',
      'reason',
      'facility',
    ],
  },
  {
    key: 'inventory_damaged_stock',
    label: 'Damaged stock',
    category: 'inventory',
    description: 'stock_adjustment rows with reason DAMAGE.',
    visualization: 'TABLE',
    default_columns: [
      'adjusted_at',
      'inventory_item',
      'quantity',
      'value',
      'facility',
    ],
  },
  {
    key: 'inventory_lost_stock',
    label: 'Lost or missing stock',
    category: 'inventory',
    description:
      'stock_adjustment reason=OTHER as loss proxy (DAMAGE excluded; no LOSS enum).',
    visualization: 'TABLE',
    default_columns: [
      'adjusted_at',
      'inventory_item',
      'quantity',
      'reason',
      'value',
      'facility',
    ],
  },
  {
    key: 'inventory_stock_write_offs',
    label: 'Stock write-offs',
    category: 'inventory',
    description:
      'stock_adjustment EXPIRY|DAMAGE write-offs with quantity and value at buy cost.',
    visualization: 'TABLE',
    default_columns: [
      'adjusted_at',
      'inventory_item',
      'reason',
      'quantity',
      'value',
      'amount',
      'facility',
    ],
  },
  {
    key: 'inventory_adjustment_reasons',
    label: 'Adjustment reasons',
    category: 'inventory',
    description: 'stock_adjustment grouped by reason with counts, quantity, and value.',
    visualization: 'TABLE',
    default_columns: ['reason', 'adjustment_count', 'quantity', 'value'],
  },
  {
    key: 'inventory_reorder',
    label: 'Inventory reorder levels',
    category: 'inventory',
    description:
      'reorder_level and reorder_quantity = max(0, reorder_level − quantity).',
    visualization: 'TABLE',
    default_columns: [
      'facility',
      'inventory_item',
      'quantity',
      'reorder_level',
      'reorder_quantity',
      'risk_state',
    ],
  },
  {
    key: 'inventory_stock_turnover',
    label: 'Stock turnover',
    category: 'inventory',
    description:
      'Issued qty / average on-hand; days_of_stock = period_days / turnover.',
    visualization: 'BAR_CHART',
    default_columns: [
      'inventory_item',
      'facility',
      'issued_quantity',
      'stock_turnover',
      'days_of_stock',
    ],
  },
  {
    key: 'inventory_stock_velocity',
    label: 'Stock velocity',
    category: 'inventory',
    description:
      'Fast/slow/dead classification from OUTBOUND+DISPENSE vs on-hand.',
    visualization: 'TABLE',
    default_columns: [
      'facility',
      'inventory_item',
      'quantity',
      'issued_quantity',
      'velocity_class',
    ],
  },
  {
    key: 'inventory_stock_movement_history',
    label: 'Stock movement history',
    category: 'inventory',
    description: 'Chronological stock_movement rows for the selected period.',
    visualization: 'TABLE',
    default_columns: [
      'occurred_at',
      'movement_type',
      'reason',
      'quantity',
      'facility',
      'inventory_item',
    ],
  },
  {
    key: 'pharmacy_medicines_catalog',
    label: 'Pharmacy medicines catalog',
    category: 'pharmacy',
    description:
      'Drug / batch catalog attributes (name, form, strength, prices, margins, lots, storage). Barcode and controlled status are schema gaps.',
    visualization: 'TABLE',
    default_columns: [
      'row_kind',
      'drug_id',
      'name',
      'code',
      'human_friendly_id',
      'generic_name',
      'brand_name',
      'category',
      'strength',
      'form',
      'dosage_form',
      'unit',
      'batch_number',
      'quantity',
      'manufactured_at',
      'expiry_date',
      'days_to_expiry',
      'selling_price',
      'unit_price',
      'purchase_price',
      'buy_unit_price',
      'profit_per_unit',
      'profit_margin',
      'currency',
      'storage_room',
      'storage_shelf',
      'storage_requirements',
    ],
  },
  {
    key: 'pharmacy_purchase_orders',
    label: 'Pharmacy purchase orders',
    category: 'pharmacy',
    description:
      'Header-only purchase_order rows with supplier and optional goods_receipt delivery_days. No PO line amounts.',
    visualization: 'TABLE',
    default_columns: [
      'ordered_at',
      'status',
      'supplier',
      'human_friendly_id',
      'received_at',
      'delivery_days',
    ],
  },
  {
    key: 'pharmacy_purchase_inbound_value',
    label: 'Pharmacy purchase inbound value',
    category: 'pharmacy',
    description:
      'INBOUND+PURCHASE stock_movement quantity × drug.buy_unit_price (stock inbound cost basis until PO lines exist).',
    visualization: 'TABLE',
    default_columns: [
      'occurred_at',
      'supplier',
      'inventory_item',
      'quantity',
      'amount',
      'currency',
      'cost_basis',
    ],
  },
  {
    key: 'pharmacy_purchases_by_supplier',
    label: 'Pharmacy purchases by supplier',
    category: 'pharmacy',
    description:
      'PO counts plus inbound purchase value (INBOUND×buy_unit_price) grouped by supplier.',
    visualization: 'BAR_CHART',
    default_columns: [
      'supplier',
      'po_count',
      'quantity',
      'amount',
      'currency',
    ],
  },
  {
    key: 'pharmacy_supplier_pricing',
    label: 'Pharmacy supplier pricing',
    category: 'pharmacy',
    description: 'Current drug.buy_unit_price grouped by drug.supplier_id.',
    visualization: 'TABLE',
    default_columns: ['supplier', 'drug', 'buy_unit_price', 'currency'],
  },
  {
    key: 'pharmacy_purchase_returns',
    label: 'Pharmacy purchase returns',
    category: 'pharmacy',
    description:
      'OUTBOUND+RETURN stock_movement rows (purchase-return-to-supplier proxy).',
    visualization: 'TABLE',
    default_columns: [
      'occurred_at',
      'inventory_item',
      'quantity',
      'facility',
      'reason',
    ],
  },
  {
    key: 'pharmacy_drug_price_changes',
    label: 'Pharmacy drug price changes',
    category: 'pharmacy',
    description:
      'audit_log UPDATE rows on drug with buy_unit_price / unit_price diffs.',
    visualization: 'TABLE',
    default_columns: [
      'changed_at',
      'drug',
      'field',
      'from_value',
      'to_value',
      'currency',
    ],
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
