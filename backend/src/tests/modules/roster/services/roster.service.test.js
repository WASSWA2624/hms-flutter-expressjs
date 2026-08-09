const subject = require('../../../../modules/roster/services/roster.service');

describe('roster.service contract', () => {
  it('exports service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
