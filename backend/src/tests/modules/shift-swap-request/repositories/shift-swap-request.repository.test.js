const subject = require('../../../../modules/shift-swap-request/repositories/shift-swap-request.repository');

describe('shift-swap-request.repository contract', () => {
  it('exports repository methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
