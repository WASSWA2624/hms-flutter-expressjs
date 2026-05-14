describe('seed-phase12-supplemental', () => {
  it('prioritizes preferred HMS order and preserves remainder sequence', () => {
    const { resolveSeedExecutionOrder } = require('../../../scripts/seed-phase12-supplemental');

    const ordered = ['zeta', 'module', 'alpha', 'subscription'];
    const preferred = ['alpha', 'subscription', 'missing'];

    const result = resolveSeedExecutionOrder(ordered, preferred);

    expect(result).toEqual(['alpha', 'subscription', 'zeta', 'module']);
  });

  it('gracefully skips supplemental seeding when tenant delegate is unavailable', async () => {
    const { seedPhase12SupplementalScenarios } = require('../../../scripts/seed-phase12-supplemental');

    const result = await seedPhase12SupplementalScenarios({
      randomSeed: 20260217
    });

    expect(result).toEqual({
      skipped: true,
      reason: 'tenant unavailable'
    });
  });
});
