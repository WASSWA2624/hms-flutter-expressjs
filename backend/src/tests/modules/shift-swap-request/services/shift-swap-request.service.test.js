const subject = require('../../../../modules/shift-swap-request/services/shift-swap-request.service');

describe('shift-swap-request.service contract', () => {
  it('exports service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
