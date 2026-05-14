const subject = require('../../../../modules/facility/repositories/facility.repository');

describe('facility.repository contract', () => {
  it('exports repository methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
