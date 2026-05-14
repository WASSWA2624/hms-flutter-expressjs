const subject = require('../../../../modules/roster-day-off/repositories/roster-day-off.repository');

describe('roster-day-off.repository contract', () => {
  it('exports repository methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
