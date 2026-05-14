const subject = require('../../../../modules/roster-day-off/services/roster-day-off.service');

describe('roster-day-off.service contract', () => {
  it('exports service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
