const {
  PHARMACY_REPORT_RISK_BATCH_TEMPLATES,
  resolveDemoStockQuantity,
} = require('../../../scripts/seeders/seed-clinical-catalog-pack');

describe('clinical catalog pharmacy reporting seed helpers', () => {
  it('defines wall-clock risk batch templates spanning expired through 180-day windows', () => {
    expect(PHARMACY_REPORT_RISK_BATCH_TEMPLATES.length).toBeGreaterThanOrEqual(6);
    const offsets = PHARMACY_REPORT_RISK_BATCH_TEMPLATES.map((row) => row.dayOffset);
    expect(offsets.some((day) => day < 0)).toBe(true);
    expect(offsets.some((day) => day > 0 && day <= 30)).toBe(true);
    expect(offsets.some((day) => day > 30 && day <= 60)).toBe(true);
    expect(offsets.some((day) => day > 60 && day <= 90)).toBe(true);
    expect(offsets.some((day) => day > 90 && day <= 180)).toBe(true);
    // Seed golden offsets used by expiry/loss acceptance tests.
    expect(offsets).toEqual(expect.arrayContaining([-14, 8, 52, 78, 145]));
    expect(
      PHARMACY_REPORT_RISK_BATCH_TEMPLATES.every(
        (row) => Number(row.leadDays) >= 30 && Number(row.quantity) > 0
      )
    ).toBe(true);
  });

  it('resolves a deterministic mix of out-of-stock, low, overstock, and healthy quantities', () => {
    const reorder = 100;
    const out = resolveDemoStockQuantity({
      spec: { key: 'demo_out' },
      drugCatalogIndex: 0,
      reorderLevel: reorder,
    });
    const critical = resolveDemoStockQuantity({
      spec: { key: 'demo_critical' },
      drugCatalogIndex: 1,
      reorderLevel: reorder,
    });
    const low = resolveDemoStockQuantity({
      spec: { key: 'demo_low' },
      drugCatalogIndex: 2,
      reorderLevel: reorder,
    });
    const overstock = resolveDemoStockQuantity({
      spec: { key: 'demo_over' },
      drugCatalogIndex: 3,
      reorderLevel: reorder,
    });
    const healthy = resolveDemoStockQuantity({
      spec: { key: 'demo_healthy', initial_stock: 420, force_low_stock: false },
      drugCatalogIndex: 4,
      reorderLevel: reorder,
    });

    expect(out).toBe(0);
    expect(critical).toBeLessThanOrEqual(Math.floor(reorder / 2));
    expect(low).toBe(reorder);
    expect(overstock).toBeGreaterThanOrEqual(reorder * 3);
    expect(healthy).toBe(420);
  });

  it('honors force_stock_quantity overrides', () => {
    expect(
      resolveDemoStockQuantity({
        spec: { key: 'forced', force_stock_quantity: 7 },
        drugCatalogIndex: 0,
        reorderLevel: 50,
      })
    ).toBe(7);
  });
});
