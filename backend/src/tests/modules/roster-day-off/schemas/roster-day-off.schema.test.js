const subject = require('../../../../modules/roster-day-off/schemas/roster-day-off.schema');

describe('roster-day-off.schema contract', () => {
  it('exports schema definitions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
