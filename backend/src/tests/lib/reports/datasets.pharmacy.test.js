const {
  buildPharmacyDispenseThroughputAnalytics,
  buildPharmacyDrugConsumptionAnalytics,
  buildPharmacySalesAvgTransactionAnalytics,
  buildPharmacySalesNetRevenueAnalytics,
  buildPharmacySalesPaymentMethodAnalytics,
  classifyStockRisk,
  classifyStockVelocity,
  computeStockValue,
  movementSignedDelta,
  resolveDateRange,
  resolveInventoryUnitCost,
  shouldUseMonthlyGranularity,
  summarizeConsumptionSeries,
  summarizeThroughputSeries,
} = require('@lib/reports/datasets');
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
    expect(REPORT_DATASET_MAP.pharmacy_sales_by_category).toMatchObject({
      key: 'pharmacy_sales_by_category',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_sales_payment_methods).toMatchObject({
      key: 'pharmacy_sales_payment_methods',
      category: 'pharmacy',
    });
    expect(REPORT_DATASET_MAP.pharmacy_sales_net_revenue).toMatchObject({
      key: 'pharmacy_sales_net_revenue',
      category: 'pharmacy',
    });
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
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_drug_consumption')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_dispense_throughput')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_sales_avg_transaction')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'inventory_stock_turnover')).toBe(true);
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
        'value',
      ])
    );
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
  });

  test('pharmacy analytics builders are exported for reuse and tests', () => {
    expect(typeof buildPharmacyDrugConsumptionAnalytics).toBe('function');
    expect(typeof buildPharmacyDispenseThroughputAnalytics).toBe('function');
    expect(typeof buildPharmacySalesPaymentMethodAnalytics).toBe('function');
    expect(typeof buildPharmacySalesNetRevenueAnalytics).toBe('function');
    expect(typeof buildPharmacySalesAvgTransactionAnalytics).toBe('function');
    expect(typeof classifyStockRisk).toBe('function');
    expect(typeof computeStockValue).toBe('function');
  });

  test('shared report formats include PDF, Excel XLSX, and CSV', () => {
    expect(REPORT_FORMATS).toEqual(expect.arrayContaining(['PDF', 'CSV', 'XLSX']));
  });
});
