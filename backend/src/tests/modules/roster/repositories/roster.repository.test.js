const subject = require('../../../../modules/roster/repositories/roster.repository');

describe('roster.repository contract', () => {
  it('exports repository methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
