const subject = require('../../../../modules/staff-position/services/staff-position.service');

describe('staff-position.service contract', () => {
  it('exports service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
