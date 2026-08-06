const {
  __private__: { resolveMostSoldWindow, normalizeMostSoldLimit },
} = require('@modules/dashboard-widget/repositories/dashboard-widget.repository');

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
    expect(normalizeMostSoldLimit(8)).toBe(10);
    expect(normalizeMostSoldLimit('bad', 20)).toBe(20);
  });
});
