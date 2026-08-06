const {
  buildPharmacyDispenseThroughputAnalytics,
  buildPharmacyDrugConsumptionAnalytics,
  resolveDateRange,
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
    expect(REPORT_DATASET_MAP.inventory_stock_risk.description).toMatch(/near-expiry/i);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_drug_consumption')).toBe(true);
    expect(REPORT_DATASETS.some((entry) => entry.key === 'pharmacy_dispense_throughput')).toBe(true);
  });

  test('resolveDateRange supports day, month, year for pharmacy presets', () => {
    expect(resolveDateRange({ date_preset: 'today' }).preset).toBe('day');
    expect(resolveDateRange({ date_preset: 'this_month' }).preset).toBe('month');
    const year = resolveDateRange({ date_preset: 'year' });
    expect(year.preset).toBe('year');
    expect(shouldUseMonthlyGranularity(year)).toBe(true);
  });

  test('inventory stock risk columns cover expiry analytics', () => {
    expect(REPORT_DATASET_MAP.inventory_stock_risk.default_columns).toEqual(
      expect.arrayContaining([
        'risk_state',
        'expiry_date',
        'expiry_alert_status',
        'days_to_expiry',
      ])
    );
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
  });

  test('shared report formats include PDF, Excel XLSX, and CSV', () => {
    expect(REPORT_FORMATS).toEqual(expect.arrayContaining(['PDF', 'CSV', 'XLSX']));
  });
});
