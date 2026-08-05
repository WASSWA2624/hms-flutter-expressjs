const {
  buildBillingFinancialAnalytics,
  resolveDateRange,
  shouldUseMonthlyGranularity,
  summarizeBillingSeries,
} = require('@lib/reports/datasets');

describe('reports datasets billing financial analytics', () => {
  test('resolveDateRange supports day, month, year, and custom', () => {
    const day = resolveDateRange({ date_preset: 'day' });
    expect(day.invalid).toBe(false);
    expect(day.preset).toBe('day');
    expect(day.from.getDate()).toBe(day.to.getDate());

    const month = resolveDateRange({ date_preset: 'month' });
    expect(month.preset).toBe('month');
    expect(month.from.getDate()).toBe(1);

    const year = resolveDateRange({ date_preset: 'year' });
    expect(year.preset).toBe('year');
    expect(year.from.getMonth()).toBe(0);
    expect(year.from.getDate()).toBe(1);
    expect(shouldUseMonthlyGranularity(year)).toBe(true);

    const custom = resolveDateRange({
      date_preset: 'custom',
      from: '2026-01-01T00:00:00.000Z',
      to: '2026-01-31T00:00:00.000Z',
    });
    expect(custom.invalid).toBe(false);
    expect(custom.preset).toBe('custom');

    const invalid = resolveDateRange({
      date_preset: 'custom',
      from: '2026-02-01T00:00:00.000Z',
      to: '2026-01-01T00:00:00.000Z',
    });
    expect(invalid.invalid).toBe(true);
    expect(invalid.reason).toBe('from_after_to');
  });

  test('summarizeBillingSeries computes profit proxy without double-counting refunds', () => {
    const summary = summarizeBillingSeries([
      {
        date: '2026-01-01',
        collections: 100,
        refunds: 10,
        write_offs: 5,
        expenditures: 15,
        profit_proxy: 85,
        net_collections: 90,
        issued_invoices: 2,
        open_invoices: 1,
      },
      {
        date: '2026-01-02',
        collections: 50,
        refunds: 0,
        write_offs: 0,
        expenditures: 0,
        profit_proxy: 50,
        net_collections: 50,
        issued_invoices: 1,
        open_invoices: 0,
      },
    ]);

    expect(summary.collections).toBe(150);
    expect(summary.expenditures).toBe(15);
    expect(summary.profit_proxy).toBe(135);
    expect(summary.net_collections).toBe(140);
    expect(summary.collections - summary.expenditures).toBe(summary.profit_proxy);
  });

  test('buildBillingFinancialAnalytics is exported for billing workspace reuse', () => {
    expect(typeof buildBillingFinancialAnalytics).toBe('function');
  });
});
