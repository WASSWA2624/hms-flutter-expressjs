const subject = require('../../../../modules/facility/services/facility.service');

describe('facility.service contract', () => {
  it('exports service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
