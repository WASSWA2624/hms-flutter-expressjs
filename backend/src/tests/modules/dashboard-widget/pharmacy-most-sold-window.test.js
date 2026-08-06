const {
  __private__: {
    resolveMostSoldWindow,
    normalizeMostSoldLimit,
    sumDispenseSalesAmount,
  },
} = require('@modules/dashboard-widget/repositories/dashboard-widget.repository');
const { ROLE_PACKS, metricsToRoleSummary } = require('@lib/dashboard/summary');

describe('pharmacy most-sold window helpers', () => {
  it('maps period presets relative to today start', () => {
    const today = new Date(2026, 7, 6, 0, 0, 0, 0); // local Aug 6, 2026
    const day = (value) =>
      `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, '0')}-${String(value.getDate()).padStart(2, '0')}`;

    expect(day(resolveMostSoldWindow('today', today))).toBe('2026-08-06');
    expect(day(resolveMostSoldWindow('last_week', today))).toBe('2026-07-31');
    expect(day(resolveMostSoldWindow('last_month', today))).toBe('2026-07-07');
    expect(day(resolveMostSoldWindow('last_3_months', today))).toBe('2026-05-08');
    expect(day(resolveMostSoldWindow('last_year', today))).toBe('2025-08-06');
  });

  it('normalizes top-N to supported presets', () => {
    expect(normalizeMostSoldLimit(5)).toBe(5);
    expect(normalizeMostSoldLimit(10)).toBe(10);
    expect(normalizeMostSoldLimit(20)).toBe(20);
    expect(normalizeMostSoldLimit(100)).toBe(100);
    expect(normalizeMostSoldLimit(8)).toBe(5);
    expect(normalizeMostSoldLimit('bad', 20)).toBe(20);
  });

  it('defaults unknown periods to today start', () => {
    const today = new Date(2026, 7, 6, 0, 0, 0, 0);
    const day = (value) =>
      `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, '0')}-${String(value.getDate()).padStart(2, '0')}`;
    expect(day(resolveMostSoldWindow('custom', today))).toBe('2026-08-06');
    expect(day(resolveMostSoldWindow(undefined, today))).toBe('2026-08-06');
  });
});

describe('pharmacy summary sales KPIs', () => {
  it('includes sales today and last-7-days cards with currency format', () => {
    const cards = metricsToRoleSummary(ROLE_PACKS.PHARMACIST, {
      ordersToday: 2,
      pendingDispense: 5,
      dispensedToday: 1,
      lowStock: 3,
      salesToday: 1200,
      salesThisWeek: 5400,
    });
    const byId = Object.fromEntries(cards.map((card) => [card.id, card]));
    expect(byId.orders_today.label).toBe('Orders today');
    expect(byId.dispensed_today.label).toBe('Dispensed today');
    expect(byId.sales_today).toMatchObject({
      label: 'Total sales today',
      value: 1200,
      format: 'currency',
    });
    expect(byId.sales_this_week).toMatchObject({
      label: 'Total sales (last 7 days)',
      value: 5400,
      format: 'currency',
    });
  });

  it('sums dispense sales amount from qty × unit_price', async () => {
    const db = {
      dispense_log: {
        findMany: jest.fn().mockResolvedValue([
          {
            quantity_dispensed: 2,
            pharmacy_order_item: { drug: { unit_price: 100 } },
          },
          {
            quantity_dispensed: 3,
            pharmacy_order_item: { drug: { unit_price: 50 } },
          },
        ]),
      },
    };
    const total = await sumDispenseSalesAmount(
      db,
      {},
      new Date('2026-08-01'),
      new Date('2026-08-07')
    );
    expect(total).toBe(350);
    expect(db.dispense_log.findMany).toHaveBeenCalled();
  });
});
