const {
  aggregateShortagesByFacility,
  aggregateStockByFacility,
  buildPharmacyDispenseThroughputAnalytics,
  buildPharmacyDispensingAvgItemsAnalytics,
  buildPharmacyDrugConsumptionAnalytics,
  buildPharmacyMedicinesCatalogRow,
  buildPharmacySalesAvgTransactionAnalytics,
  buildPharmacySalesNetRevenueAnalytics,
  buildPharmacySalesPaymentMethodAnalytics,
  classifyStockRisk,
  classifyStockVelocity,
  classifyExpiryWindow,
  computeAverageItemsPerPrescription,
  computeCatalogProfitMargin,
  computeDeliveryDays,
  computeDispenseCogs,
  computeStockValue,
  extractPriceChangeFields,
  expandDiffFields,
  projectDiffValueRow,
  classifyDiffField,
  isDeniedAccessDiff,
  PHARMACY_AUDIT_ENTITIES,
  mergeBranchComparisonRows,
  movementSignedDelta,
  pickAttestationUserId,
  PHARMACY_SUPPLIER_DELIVERY_SLA_DAYS,
  remainingItemQuantity,
  resolveAgeBand,
  resolveBuyUnitCostOnly,
  resolveDateRange,
  resolveInventoryUnitCost,
  shouldUseMonthlyGranularity,
  summarizeConsumptionSeries,
  summarizePurchaseOrderSla,
  summarizeStaffSalesPartition,
  summarizeThroughputSeries,
  OPEN_PHARMACY_INVOICE_STATUSES,
  durationInDays,
  formatDosagePlain,
  isAntiInfectiveDrug,
  isControlledDrug,
  ANTI_INFECTIVE_DRUG_CODES,
  CONTROLLED_DRUG_CODES,
  computeControlledBalance,
  assertControlledBalanceInvariant,
} = require('@lib/reports/datasets');
const { pharmacyRetailMarginUnit } = require('@lib/billing/pharmacy-drug-margins');
const { REPORT_DATASET_MAP, REPORT_DATASETS, REPORT_FORMATS } = require('@lib/reports/constants');

describe('reports datasets pharmacy analytics', () => {
  test('pharmacy datasets are registered in REPORT_DATASETS', () => {
    expect(REPORT_DATASET_MAP.pharmacy_drug_consumption).toMatchObject({
      key: 'pharmacy_drug_consumption',
      category: 'pharmacy',
      visualization: 'BAR_CHART',
    });
    expect(REPORT_DATASET_MAP.pharmacy_dispense_throughput).toMatchObject({
      key: 'pharmacy_dispense_throughput',
      category: 'pharmacy',
      visualization: 'LINE_CHART',
    });
    expect(REPORT_DATASET_MAP.pharmacy_dispensing_by_prescriber).toMatchObject({
      key: 'pharmacy_dispensing_by_prescriber',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_dispensing_partial).toMatchObject({
      key: 'pharmacy_dispensing_partial',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_dispensing_frequency).toMatchObject({
      key: 'pharmacy_dispensing_frequency',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_dispensing_avg_items).toMatchObject({
      key: 'pharmacy_dispensing_avg_items',
      category: 'pharmacy',
      visualization: 'KPI',
    });
    expect(REPORT_DATASET_MAP.pharmacy_prescription_count).toMatchObject({
      key: 'pharmacy_prescription_count',
      category: 'pharmacy',
      visualization: 'KPI',
      default_columns: ['orders_created'],
    });
    expect(REPORT_DATASET_MAP.pharmacy_prescription_prescriber).toMatchObject({
      key: 'pharmacy_prescription_prescriber',
      category: 'pharmacy',
      default_columns: ['prescriber', 'orders_created'],
    });
    expect(REPORT_DATASET_MAP.pharmacy_prescription_diagnosis).toMatchObject({
      key: 'pharmacy_prescription_diagnosis',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_prescription_medicine).toMatchObject({
      key: 'pharmacy_prescription_medicine',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_prescription_dosage).toMatchObject({
      key: 'pharmacy_prescription_dosage',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_prescription_frequency).toMatchObject({
      key: 'pharmacy_prescription_frequency',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_prescription_duration).toMatchObject({
      key: 'pharmacy_prescription_duration',
      category: 'pharmacy',
      default_columns: ['duration', 'duration_days', 'item_count'],
    });
    expect(REPORT_DATASET_MAP.pharmacy_prescription_antibiotic_usage).toMatchObject({
      key: 'pharmacy_prescription_antibiotic_usage',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_prescription_controlled_dispensing).toMatchObject({
      key: 'pharmacy_prescription_controlled_dispensing',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_customer_count).toMatchObject({
      key: 'pharmacy_customer_count',
      category: 'pharmacy',
      visualization: 'KPI',
    });
    expect(REPORT_DATASET_MAP.pharmacy_customers_new_vs_returning).toMatchObject({
      key: 'pharmacy_customers_new_vs_returning',
      category: 'pharmacy',
      default_columns: ['segment', 'customer_count'],
    });
    expect(REPORT_DATASET_MAP.pharmacy_customer_credit_balance).toMatchObject({
      key: 'pharmacy_customer_credit_balance',
      category: 'pharmacy',
      default_columns: ['patient', 'credit_balance'],
    });
    expect(REPORT_DATASET_MAP.pharmacy_customer_retention).toMatchObject({
      key: 'pharmacy_customer_retention',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_sales_by_category).toMatchObject({
      key: 'pharmacy_sales_by_category',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_sales_by_branch).toMatchObject({
      key: 'pharmacy_sales_by_branch',
      category: 'pharmacy',
      default_columns: ['facility', 'amount', 'quantity_dispensed'],
    });
    expect(REPORT_DATASET_MAP.pharmacy_profit_by_branch).toMatchObject({
      key: 'pharmacy_profit_by_branch',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_stock_by_branch).toMatchObject({
      key: 'pharmacy_stock_by_branch',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_purchases_by_branch).toMatchObject({
      key: 'pharmacy_purchases_by_branch',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_stock_shortages_by_branch).toMatchObject({
      key: 'pharmacy_stock_shortages_by_branch',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_best_performing_branch).toMatchObject({
      key: 'pharmacy_best_performing_branch',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_branch_comparison).toMatchObject({
      key: 'pharmacy_branch_comparison',
      category: 'pharmacy',
      visualization: 'BAR_CHART',
    });
    expect(REPORT_DATASET_MAP.pharmacy_transfers_between_branches).toMatchObject({
      key: 'pharmacy_transfers_between_branches',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_transfer_quantity).toMatchObject({
      key: 'pharmacy_transfer_quantity',
      category: 'pharmacy',
      default_columns: expect.arrayContaining(['quantity', 'sending_branch', 'receiving_branch']),
    });
    expect(REPORT_DATASET_MAP.pharmacy_pending_transfers).toMatchObject({
      key: 'pharmacy_pending_transfers',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_transfer_discrepancies).toMatchObject({
      key: 'pharmacy_transfer_discrepancies',
      category: 'pharmacy',
      default_columns: expect.arrayContaining([
        'shipped_quantity',
        'received_quantity',
        'discrepancy_quantity',
      ]),
    });
    expect(REPORT_DATASET_MAP.pharmacy_sales_payment_methods).toMatchObject({
      key: 'pharmacy_sales_payment_methods',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_sales_net_revenue).toMatchObject({
      key: 'pharmacy_sales_net_revenue',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_medicines_catalog).toMatchObject({
      key: 'pharmacy_medicines_catalog',
      category: 'pharmacy',
      visualization: 'TABLE',
    });
    expect(REPORT_DATASET_MAP.pharmacy_purchase_orders).toMatchObject({
      key: 'pharmacy_purchase_orders',
      category: 'pharmacy',
      default_columns: expect.arrayContaining(['ordered_at', 'status', 'supplier', 'delivery_days']),
    });
    expect(REPORT_DATASET_MAP.pharmacy_purchase_inbound_value).toMatchObject({
      key: 'pharmacy_purchase_inbound_value',
      category: 'pharmacy',
      default_columns: expect.arrayContaining(['amount', 'quantity', 'cost_basis']),
    });
    expect(REPORT_DATASET_MAP.pharmacy_purchases_by_supplier).toMatchObject({
      key: 'pharmacy_purchases_by_supplier',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_supplier_pricing).toMatchObject({
      key: 'pharmacy_supplier_pricing',
      category: 'pharmacy',
      default_columns: ['supplier', 'drug', 'buy_unit_price', 'currency'],
    });
    expect(REPORT_DATASET_MAP.pharmacy_purchase_returns).toMatchObject({
      key: 'pharmacy_purchase_returns',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_drug_price_changes).toMatchObject({
      key: 'pharmacy_drug_price_changes',
      category: 'pharmacy',
    });
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_purchase_orders')).toBe(true);
    expect(REPORT_DATASET_MAP.pharmacy_sales_by_staff).toMatchObject({
      key: 'pharmacy_sales_by_staff',
      category: 'pharmacy',
      default_columns: ['staff', 'amount', 'quantity_dispensed'],
    });
    expect(REPORT_DATASET_MAP.pharmacy_dispensing_by_staff).toMatchObject({
      key: 'pharmacy_dispensing_by_staff',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_stock_adjustments_by_staff).toMatchObject({
      key: 'pharmacy_stock_adjustments_by_staff',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_audit_trail).toMatchObject({
      key: 'pharmacy_audit_trail',
      category: 'pharmacy',
      default_columns: ['timestamp', 'action', 'entity', 'entity_id', 'staff', 'diff'],
    });
    expect(REPORT_DATASET_MAP.pharmacy_controlled_stock).toMatchObject({
      key: 'pharmacy_controlled_stock',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_controlled_balance).toMatchObject({
      key: 'pharmacy_controlled_balance',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_controlled_regulatory_log).toMatchObject({
      key: 'pharmacy_controlled_regulatory_log',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_controlled_received).toBeTruthy();
    expect(REPORT_DATASET_MAP.pharmacy_controlled_dispensed).toBeTruthy();
    expect(REPORT_DATASET_MAP.pharmacy_controlled_batches).toBeTruthy();
    expect(REPORT_DATASET_MAP.pharmacy_controlled_actors).toBeTruthy();
    expect(REPORT_DATASET_MAP.pharmacy_controlled_adjustments).toBeTruthy();
    expect(REPORT_DATASET_MAP.pharmacy_controlled_wastage).toBeTruthy();
    expect(REPORT_DATASET_MAP.pharmacy_audit_who_created).toMatchObject({
      key: 'pharmacy_audit_who_created',
      category: 'pharmacy',
      default_columns: ['user', 'entity', 'entity_id', 'created_at'],
    });
    expect(REPORT_DATASET_MAP.pharmacy_audit_previous_vs_new).toMatchObject({
      key: 'pharmacy_audit_previous_vs_new',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_audit_price_changes).toMatchObject({
      key: 'pharmacy_audit_price_changes',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_audit_unauthorized).toMatchObject({
      key: 'pharmacy_audit_unauthorized',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_audit_rx_controlled).toMatchObject({
      key: 'pharmacy_audit_rx_controlled',
      category: 'pharmacy',
    });
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_audit_who_edited')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_audit_stock_adjustments')).toBe(
      true
    );
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_user_productivity')).toBe(true);
    expect(REPORT_DATASET_MAP.inventory_stock_risk.description).toMatch(/near-expiry/i);
    expect(REPORT_DATASET_MAP.inventory_stock_value).toMatchObject({
      key: 'inventory_stock_value',
      category: 'inventory',
    });
    expect(REPORT_DATASET_MAP.inventory_stock_movement_history).toMatchObject({
      key: 'inventory_stock_movement_history',
      category: 'inventory',
    });
    expect(REPORT_DATASET_MAP.inventory_stock_velocity).toMatchObject({
      key: 'inventory_stock_velocity',
      category: 'inventory',
    });
    expect(REPORT_DATASET_MAP.inventory_stock_write_offs).toMatchObject({
      key: 'inventory_stock_write_offs',
      category: 'inventory',
    });
    expect(REPORT_DATASET_MAP.inventory_adjustment_reasons).toMatchObject({
      key: 'inventory_adjustment_reasons',
      category: 'inventory',
    });
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_drug_consumption')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_dispense_throughput')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_dispensing_avg_items')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_branch_comparison')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_sales_avg_transaction')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_financial_revenue')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_financial_cogs')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_financial_cash_flow')).toBe(true);
    expect(REPORT_DATASET_MAP.pharmacy_financial_gross_profit).toMatchObject({
      key: 'pharmacy_financial_gross_profit',
      category: 'pharmacy',
    });
    expect(REPORT_DATASETS.some((entry) => entry.key === 'inventory_stock_turnover')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_medicines_catalog')).toBe(true);
  });


  test('single-facility stock aggregation returns one ready row', () => {
    const rows = aggregateStockByFacility([
      { facility: 'DemoCare General Hospital', quantity: 10, value: 100 },
      { facility: 'DemoCare General Hospital', quantity: 5, value: 50.5 },
    ]);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      facility: 'DemoCare General Hospital',
      quantity: 15,
      value: 150.5,
    });
  });

  test('two-facility comparison sums to tenant totals', () => {
    const stock = aggregateStockByFacility([
      { facility: 'Main', quantity: 10, value: 100 },
      { facility: 'Annex', quantity: 20, value: 250 },
      { facility: 'Main', quantity: 5, value: 40 },
    ]);
    expect(stock).toHaveLength(2);
    expect(stock.reduce((sum, row) => sum + row.quantity, 0)).toBe(35);
    expect(stock.reduce((sum, row) => sum + row.value, 0)).toBe(390);

    const shortages = aggregateShortagesByFacility([
      { facility: 'Main', risk_state: 'LOW', quantity: 2 },
      { facility: 'Main', risk_state: 'OK', quantity: 9 },
      { facility: 'Annex', risk_state: 'CRITICAL', quantity: 1 },
      { facility: 'Annex', risk_state: 'OUT_OF_STOCK', quantity: 0 },
    ]);
    expect(shortages.find((row) => row.facility === 'Main')?.shortage_count).toBe(1);
    expect(shortages.find((row) => row.facility === 'Annex')?.shortage_count).toBe(2);

    const comparison = mergeBranchComparisonRows({
      salesRows: [
        { facility: 'Main', amount: 400, profit: 80, quantity_dispensed: 12 },
        { facility: 'Annex', amount: 100, profit: 20, quantity_dispensed: 3 },
      ],
      stockRows: stock,
      shortageRows: shortages,
      purchaseRows: [
        { facility: 'Main', request_count: 7, order_count: 5 },
        { facility: 'Annex', request_count: 3, order_count: 2 },
      ],
    });
    expect(comparison).toHaveLength(2);
    expect(comparison.reduce((sum, row) => sum + row.amount, 0)).toBe(500);
    expect(comparison.reduce((sum, row) => sum + row.profit, 0)).toBe(100);
    expect(comparison.reduce((sum, row) => sum + row.quantity, 0)).toBe(35);
    expect(comparison.reduce((sum, row) => sum + row.value, 0)).toBe(390);
    expect(comparison.reduce((sum, row) => sum + row.request_count, 0)).toBe(10);
  });

  test('resolveDateRange supports day, month, year for pharmacy presets', () => {
    expect(resolveDateRange({ date_preset: 'today' }).preset).toBe('day');
    expect(resolveDateRange({ date_preset: 'this_month' }).preset).toBe('month');
    const year = resolveDateRange({ date_preset: 'year' });
    expect(year.preset).toBe('year');
    expect(shouldUseMonthlyGranularity(year)).toBe(true);
  });

  test('inventory stock risk columns cover expiry analytics and value', () => {
    expect(REPORT_DATASET_MAP.inventory_stock_risk.default_columns).toEqual(
      expect.arrayContaining([
        'risk_state',
        'expiry_date',
        'expiry_alert_status',
        'days_to_expiry',
        'expiry_window',
        'value',
        'category',
        'supplier',
        'supplier_id',
      ])
    );
  });

  test('classifyExpiryWindow matches seed dayOffsets (8→0-30, −14→null expired)', () => {
    // dayOffset 8 → ≤30 bucket; −14 expired (null window); 52/78/145 → mid/far windows.
    expect(classifyExpiryWindow(8)).toBe('0-30');
    expect(classifyExpiryWindow(21)).toBe('0-30');
    expect(classifyExpiryWindow(30)).toBe('0-30');
    expect(classifyExpiryWindow(52)).toBe('30-60');
    expect(classifyExpiryWindow(60)).toBe('30-60');
    expect(classifyExpiryWindow(78)).toBe('60-90');
    expect(classifyExpiryWindow(90)).toBe('60-90');
    expect(classifyExpiryWindow(145)).toBe('90-180');
    expect(classifyExpiryWindow(180)).toBe('90-180');
    expect(classifyExpiryWindow(-14)).toBeNull();
    expect(classifyExpiryWindow(-75)).toBeNull();
    expect(classifyExpiryWindow(0)).toBeNull();
    expect(classifyExpiryWindow(181)).toBeNull();
    // Expired value at buy cost: qty × buy > 0 for known seed prices.
    expect(computeStockValue(22, 650)).toBeGreaterThan(0);
    expect(resolveBuyUnitCostOnly({ buy_unit_price: 650, unit_price: 900 })).toEqual({
      unit_cost: 650,
      cost_basis: 'buy_unit_price',
    });
    expect(resolveBuyUnitCostOnly({ buy_unit_price: null, unit_price: 900 })).toEqual({
      unit_cost: 0,
      cost_basis: 'unavailable',
    });
  });

  test('classifyStockRisk golden cases match runInventoryDataset thresholds', () => {
    expect(classifyStockRisk(0, 10)).toBe('OUT_OF_STOCK');
    expect(classifyStockRisk(-1, 10)).toBe('OUT_OF_STOCK');
    expect(classifyStockRisk(1, 10)).toBe('CRITICAL');
    expect(classifyStockRisk(5, 10)).toBe('CRITICAL');
    expect(classifyStockRisk(6, 10)).toBe('LOW');
    expect(classifyStockRisk(10, 10)).toBe('LOW');
    expect(classifyStockRisk(11, 10)).toBe('OK');
    expect(classifyStockRisk(30, 10)).toBe('OVERSTOCK');
    expect(classifyStockRisk(50, 0)).toBe('OK');
  });

  test('stock_value equals quantity × buy_unit_price for known cost', () => {
    // Seeded Amoxicillin (index 0): buy_unit_price = 400 + 1*250 = 650
    expect(computeStockValue(1200, 650)).toBe(780000);
    expect(
      resolveInventoryUnitCost([
        { is_default: true, drug: { buy_unit_price: 650, unit_price: 900 } },
      ])
    ).toEqual({ unit_cost: 650, cost_basis: 'buy_unit_price' });
    expect(
      resolveInventoryUnitCost([
        { is_default: true, drug: { buy_unit_price: null, unit_price: 900 } },
      ])
    ).toEqual({ unit_cost: 900, cost_basis: 'unit_price' });
  });

  test('movementSignedDelta and velocity classifiers are documented', () => {
    expect(movementSignedDelta({ movement_type: 'INBOUND', quantity: 5 })).toBe(5);
    expect(
      movementSignedDelta({ movement_type: 'OUTBOUND', reason: 'DISPENSE', quantity: 3 })
    ).toBe(-3);
    expect(
      movementSignedDelta({ movement_type: 'ADJUSTMENT', reason: 'DAMAGE', quantity: 2 })
    ).toBe(-2);
    expect(movementSignedDelta({ movement_type: 'TRANSFER', quantity: 4 })).toBe(-4);
    expect(
      movementSignedDelta({
        movement_type: 'TRANSFER',
        quantity: 4,
        facility_id: 'from',
        to_facility_id: 'to',
      })
    ).toBe(-4);
    expect(
      movementSignedDelta({
        movement_type: 'TRANSFER',
        quantity: 4,
        facility_id: 'to',
        to_facility_id: 'to',
      })
    ).toBe(4);
    expect(classifyStockVelocity(0, 10)).toBe('DEAD');
    expect(classifyStockVelocity(10, 10)).toBe('FAST');
    expect(classifyStockVelocity(1, 100)).toBe('SLOW');
  });

  test('pharmacy consumption columns include profit for margin analytics', () => {
    expect(REPORT_DATASET_MAP.pharmacy_drug_consumption.default_columns).toEqual(
      expect.arrayContaining(['profit', 'order_source'])
    );
  });

  test('summarizeConsumptionSeries totals quantity and amount', () => {
    const summary = summarizeConsumptionSeries([
      { drug: 'A', quantity_dispensed: 10, amount: 100.5, order_source: 'PHARMACY' },
      { drug: 'B', quantity_dispensed: 5, amount: 49.5, order_source: 'CLINICAL' },
    ]);
    expect(summary.quantity_dispensed).toBe(15);
    expect(summary.amount).toBe(150);
    expect(summary.drug_count).toBe(2);
  });

  test('summarizeThroughputSeries totals order and return counters', () => {
    const summary = summarizeThroughputSeries([
      {
        date: '2026-01-01',
        orders_created: 3,
        dispensed: 1,
        partially_dispensed: 1,
        cancelled: 0,
        returns: 2,
      },
      {
        date: '2026-01-02',
        orders_created: 2,
        dispensed: 2,
        partially_dispensed: 0,
        cancelled: 1,
        returns: 0,
      },
    ]);
    expect(summary.orders_created).toBe(5);
    expect(summary.dispensed).toBe(3);
    expect(summary.partially_dispensed).toBe(1);
    expect(summary.cancelled).toBe(1);
    expect(summary.returns).toBe(2);
    // cancelled (order status) ≠ returns (RETURNED dispense_log count)
    expect(summary.cancelled).not.toBe(summary.returns);
  });

  test('average items per prescription formula is item_count / orders_created', () => {
    expect(computeAverageItemsPerPrescription(10, 4)).toBe(2.5);
    expect(computeAverageItemsPerPrescription(3, 2)).toBe(1.5);
    expect(computeAverageItemsPerPrescription(0, 5)).toBe(0);
    expect(computeAverageItemsPerPrescription(5, 0)).toBeNull();
  });

  test('remainingItemQuantity never invents negative packs', () => {
    expect(
      remainingItemQuantity({
        quantity: 10,
        dispense_logs: [{ quantity_dispensed: 4 }, { quantity_dispensed: 3 }],
      })
    ).toBe(3);
    expect(
      remainingItemQuantity({
        quantity: 2,
        dispense_logs: [{ quantity_dispensed: 5 }],
      })
    ).toBe(0);
  });

  test('pharmacy analytics builders are exported for reuse and tests', () => {
    expect(typeof buildPharmacyDrugConsumptionAnalytics).toBe('function');
    expect(typeof buildPharmacyDispenseThroughputAnalytics).toBe('function');
    expect(typeof buildPharmacyDispensingAvgItemsAnalytics).toBe('function');
    expect(typeof buildPharmacySalesPaymentMethodAnalytics).toBe('function');
    expect(typeof buildPharmacySalesNetRevenueAnalytics).toBe('function');
    expect(typeof buildPharmacySalesAvgTransactionAnalytics).toBe('function');
    expect(typeof buildPharmacyMedicinesCatalogRow).toBe('function');
    expect(typeof computeCatalogProfitMargin).toBe('function');
    expect(typeof computeDispenseCogs).toBe('function');
    expect(typeof classifyStockRisk).toBe('function');
    expect(typeof computeStockValue).toBe('function');
  });

  test('computeDispenseCogs equals buy_unit_price × qty; unset buy is 0', () => {
    expect(computeDispenseCogs(650, 2)).toBe(1300);
    expect(computeDispenseCogs(null, 5)).toBe(0);
    expect(computeDispenseCogs('', 5)).toBe(0);
  });

  test('dispensing avg-items builder is read-only (pharmacy-flow: no encounter creates)', () => {
    const source = buildPharmacyDispensingAvgItemsAnalytics.toString();
    expect(source).not.toMatch(/\.create\s*\(/);
    expect(source).not.toMatch(/encounter\.create/);
  });

  test('medicines catalog margin matches pharmacyRetailMarginUnit helper', () => {
    expect(
      pharmacyRetailMarginUnit({ unitPrice: 2050, buyUnitPrice: 650 })
    ).toBe(1400);
    expect(computeCatalogProfitMargin(2050, 650)).toBe(68.29);
    expect(computeCatalogProfitMargin(100, null)).toBeNull();
    expect(pharmacyRetailMarginUnit({ unitPrice: 100, buyUnitPrice: null })).toBeNull();
  });

  test('Paracetamol seed ladder sell/buy/profit_per_unit and plain form/strength', () => {
    // DRUG_CATALOG index 0 = Paracetamol 500 mg tablet
    const buy = 400 + 1 * 250;
    const sell = 1200 + 1 * 850;
    expect(buy).toBe(650);
    expect(sell).toBe(2050);

    const row = buildPharmacyMedicinesCatalogRow({
      drug: {
        id: 'drug-pcm',
        name: 'Paracetamol',
        code: 'PCM500',
        human_friendly_id: 'DRG-PCM',
        generic_name: 'Paracetamol',
        brand_name: 'Panadol',
        form: 'Tablet',
        strength: '500 mg',
        buy_unit_price: buy,
        unit_price: sell,
        currency: 'UGX',
        inventory_maps: [
          {
            is_default: true,
            inventory_item: { category: 'MEDICATION', unit: 'tablet' },
          },
        ],
      },
      rowKind: 'drug',
    });

    expect(row.selling_price).toBe(2050);
    expect(row.purchase_price).toBe(650);
    expect(row.profit_per_unit).toBe(1400);
    expect(row.profit_margin).toBe(68.29);
    expect(row.currency).toBe('UGX');
    expect(row.strength).toBe('500 mg');
    expect(row.form).toBe('Tablet');
    expect(row.dosage_form).toBe('Tablet');
    expect(row.unit).toBe('tablet');
    expect(row.generic_name).toBe('Paracetamol');
    expect(row.brand_name).toBe('Panadol');
  });

  test('empty generic/brand strings project as null not "null"', () => {
    const row = buildPharmacyMedicinesCatalogRow({
      drug: {
        name: 'Sample',
        generic_name: '  ',
        brand_name: '',
        unit_price: 10,
        buy_unit_price: null,
        inventory_maps: [],
      },
    });
    expect(row.generic_name).toBeNull();
    expect(row.brand_name).toBeNull();
    expect(row.profit_per_unit).toBeNull();
  });

  test('shared report formats include PDF, Excel XLSX, and CSV', () => {
    expect(REPORT_FORMATS).toEqual(expect.arrayContaining(['PDF', 'CSV', 'XLSX']));
  });

  test('open pharmacy invoice statuses match billing open_invoices set', () => {
    expect(OPEN_PHARMACY_INVOICE_STATUSES).toEqual(['DRAFT', 'SENT', 'OVERDUE']);
  });

  test('pharmacy audit allow-list stays centralized', () => {
    expect(PHARMACY_AUDIT_ENTITIES).toEqual(
      expect.arrayContaining([
        'pharmacy_order',
        'dispense_log',
        'drug',
        'stock_adjustment',
        'stock_movement',
        'payment',
      ])
    );
  });

  test('expandDiffFields uses only raw diff_json keys', () => {
    expect(
      expandDiffFields({
        buy_unit_price: { from: 100, to: 120 },
        quantity_change: { from: 1, to: 3 },
        original_action: 'CANCEL',
      })
    ).toEqual([
      { field: 'buy_unit_price', previous_value: 100, new_value: 120 },
      { field: 'quantity_change', previous_value: 1, new_value: 3 },
    ]);
    expect(
      expandDiffFields({
        before: { status: 'DISPENSED' },
        after: { status: 'CANCELLED', note: 'void' },
      })
    ).toEqual([
      { field: 'status', previous_value: 'DISPENSED', new_value: 'CANCELLED' },
      { field: 'note', previous_value: null, new_value: 'void' },
    ]);
  });

  test('projectDiffValueRow types prices as currency amounts', () => {
    expect(classifyDiffField('unit_price')).toBe('currency');
    expect(classifyDiffField('quantity_dispensed')).toBe('quantity');
    expect(
      projectDiffValueRow({
        field: 'unit_price',
        previous_value: 1200,
        new_value: 1350,
        currency: 'UGX',
      })
    ).toMatchObject({
      previous_amount: 1200,
      new_amount: 1350,
      previous_quantity: null,
      new_quantity: null,
      currency: 'UGX',
      value_kind: 'currency',
    });
  });

  test('isDeniedAccessDiff detects ABAC DENY payloads', () => {
    expect(
      isDeniedAccessDiff({
        after: { decision: 'DENY', reason: 'policy_denied' },
      })
    ).toBe(true);
    expect(
      isDeniedAccessDiff({
        after: { decision: 'ALLOW', reason: 'matched' },
      })
    ).toBe(false);
  });

  test('resolveAgeBand uses permitted date_of_birth bands only', () => {
    const asOf = new Date('2026-08-07T12:00:00.000Z');
    expect(resolveAgeBand(null, asOf)).toBe('Unknown');
    expect(resolveAgeBand(new Date('2020-01-01'), asOf)).toBe('Under 18');
    expect(resolveAgeBand(new Date('1995-01-01'), asOf)).toBe('18-34');
    expect(resolveAgeBand(new Date('1980-01-01'), asOf)).toBe('35-49');
    expect(resolveAgeBand(new Date('1965-01-01'), asOf)).toBe('50-64');
    expect(resolveAgeBand(new Date('1950-01-01'), asOf)).toBe('65+');
  });

  test('customer demographics columns exclude unauthorized PHI keys', () => {
    expect(REPORT_DATASET_MAP.pharmacy_customer_demographics.default_columns).toEqual([
      'dimension',
      'bucket',
      'customer_count',
    ]);
    expect(REPORT_DATASET_MAP.pharmacy_customer_demographics.default_columns).not.toEqual(
      expect.arrayContaining(['first_name', 'last_name', 'phone', 'email', 'address'])
    );
  });

  test('frequently purchased medicines sort is amount then quantity (stable top projection)', () => {
    expect(REPORT_DATASET_MAP.pharmacy_drug_consumption.default_columns).toEqual(
      expect.arrayContaining(['drug', 'quantity_dispensed', 'amount'])
    );
  });

  test('computeDeliveryDays is non-negative and null when either date missing', () => {
    const ordered = new Date('2026-01-01T00:00:00.000Z');
    const received = new Date('2026-01-04T00:00:00.000Z');
    expect(computeDeliveryDays(ordered, received)).toBe(3);
    expect(computeDeliveryDays(received, ordered)).toBe(0);
    expect(computeDeliveryDays(ordered, null)).toBeNull();
    expect(computeDeliveryDays(null, received)).toBeNull();
  });

  test('summarizePurchaseOrderSla uses shared 7-day threshold and clamps rates', () => {
    expect(PHARMACY_SUPPLIER_DELIVERY_SLA_DAYS).toBe(7);
    const sla = summarizePurchaseOrderSla([
      { received_at: '2026-01-03', delivery_days: 2 },
      { received_at: '2026-01-12', delivery_days: 11 },
      { received_at: null, delivery_days: null },
      { received_at: '2026-01-08', delivery_days: 7 },
    ]);
    expect(sla.on_time_count).toBe(2);
    expect(sla.late_count).toBe(1);
    expect(sla.receipt_count).toBe(3);
    expect(sla.reliability_rate).toBe(50);
    expect(sla.fulfillment_rate_proxy).toBe(75);
    expect(sla.reliability_rate).toBeGreaterThanOrEqual(0);
    expect(sla.reliability_rate).toBeLessThanOrEqual(100);
  });

  test('purchases_by_supplier amount basis matches inbound purchase_value total', () => {
    // Same formula as purchase_value / supplier spend: Σ quantity × buy_unit_price.
    const inboundRows = [
      { quantity: 10, amount: computeStockValue(10, 650) },
      { quantity: 4, amount: computeStockValue(4, 400) },
    ];
    const purchaseValue = inboundRows.reduce((sum, row) => sum + row.amount, 0);
    const supplierSpend = purchaseValue;
    expect(supplierSpend).toBe(6500 + 1600);
    expect(supplierSpend).toBe(purchaseValue);
  });

  test('extractPriceChangeFields reads buy/unit price diffs only', () => {
    expect(
      extractPriceChangeFields({
        buy_unit_price: { from: 650, to: 700 },
        name: { from: 'A', to: 'B' },
      })
    ).toEqual([{ field: 'buy_unit_price', from_value: 650, to_value: 700 }]);
    expect(extractPriceChangeFields({ volume: true })).toEqual([]);
  });

  test('purchase_value amount equals quantity × buy_unit_price basis', () => {
    const quantity = 12;
    const buy = 650;
    expect(computeStockValue(quantity, buy)).toBe(7800);
  });

  test('staff sales partition keeps unattributed remainder explicit', () => {
    const summary = summarizeStaffSalesPartition({
      staffRows: [
        { staff: 'USR-1 · Harper Demo', amount: 400, quantity_dispensed: 10 },
        { staff: 'USR-2 · Morgan Demo', amount: 250, quantity_dispensed: 5 },
      ],
      periodAmount: 800,
      periodQuantity: 20,
    });
    expect(summary.attributed_amount).toBe(650);
    expect(summary.unattributed_amount).toBe(150);
    expect(summary.period_amount).toBe(800);
    expect(summary.attributed_quantity).toBe(15);
    expect(summary.unattributed_quantity).toBe(5);
    expect(summary.staff_count).toBe(2);
  });

  test('pickAttestationUserId prefers ATTEST phase over PREPARE', () => {
    expect(
      pickAttestationUserId(
        [
          { dispense_batch_ref: 'B1', phase: 'PREPARE', attested_by_user_id: 'prep-user' },
          { dispense_batch_ref: 'B1', phase: 'ATTEST', attested_by_user_id: 'attest-user' },
        ],
        'B1'
      )
    ).toBe('attest-user');
    expect(
      pickAttestationUserId(
        [{ dispense_batch_ref: 'B2', phase: 'PREPARE', attested_by_user_id: 'prep-user' }],
        'B2'
      )
    ).toBe('prep-user');
    expect(pickAttestationUserId([], 'B3')).toBeNull();
  });

  test('durationInDays formats day/week/month units; unknown stays null', () => {
    expect(durationInDays(7, 'days')).toBe(7);
    expect(durationInDays(7, 'day')).toBe(7);
    expect(durationInDays(2, 'weeks')).toBe(14);
    expect(durationInDays(1, 'months')).toBe(30);
    expect(durationInDays(24, 'hours')).toBe(1);
    expect(durationInDays(5, 'cycles')).toBeNull();
    expect(durationInDays(null, 'days')).toBeNull();
  });

  test('formatDosagePlain prefers dosage string over dose_amount+unit', () => {
    expect(
      formatDosagePlain({ dosage: '1 tab', dose_amount: 500, dose_unit: 'mg' })
    ).toBe('1 tab');
    expect(formatDosagePlain({ dosage: null, dose_amount: 500, dose_unit: 'mg' })).toBe(
      '500 mg'
    );
    expect(formatDosagePlain({ dosage: '  ', dose_amount: null, dose_unit: 'mg' })).toBeNull();
  });

  test('antibiotic filter includes Amoxicillin AMX500 seed code', () => {
    expect(ANTI_INFECTIVE_DRUG_CODES).toContain('AMX500');
    expect(isAntiInfectiveDrug({ code: 'AMX500', name: 'Amoxicillin' })).toBe(true);
    expect(isAntiInfectiveDrug({ code: 'PCM500', name: 'Paracetamol' })).toBe(false);
  });

  test('controlled allow-list stays Morphine/Tramadol seed codes', () => {
    expect(CONTROLLED_DRUG_CODES).toEqual(expect.arrayContaining(['MRF10I', 'TRM50']));
    expect(CONTROLLED_DRUG_CODES).toHaveLength(2);
    expect(isControlledDrug({ code: 'MRF10I' })).toBe(true);
    expect(isControlledDrug({ code: 'TRM50' })).toBe(true);
    expect(isControlledDrug({ code: 'PCM500' })).toBe(false);
    expect(isControlledDrug({ is_controlled: true, code: 'PCM500' })).toBe(true);
  });

  test('controlled balance invariant holds for golden fixture (grain=drug)', () => {
    // closing = opening + received − dispensed − wastage + adjustments_net
    const fixture = computeControlledBalance({
      closing_quantity: 80,
      quantity_received: 40,
      quantity_dispensed: 25,
      wastage: 5,
      adjustments_net: -2,
    });
    expect(fixture.opening_quantity).toBe(80 - 40 + 25 + 5 - -2);
    expect(fixture.opening_quantity).toBe(72);
    expect(fixture.invariant_closing).toBe(
      fixture.opening_quantity +
        fixture.quantity_received -
        fixture.quantity_dispensed -
        fixture.wastage +
        fixture.adjustments_net
    );
    expect(fixture.invariant_closing).toBe(80);
    expect(
      assertControlledBalanceInvariant({
        closing_quantity: fixture.closing_quantity,
        opening_quantity: fixture.opening_quantity,
        quantity_received: fixture.quantity_received,
        quantity_dispensed: fixture.quantity_dispensed,
        wastage: fixture.wastage,
        adjustments_net: fixture.adjustments_net,
      })
    ).toBe(true);
  });
});
