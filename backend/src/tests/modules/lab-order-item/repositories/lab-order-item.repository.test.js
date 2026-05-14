const subject = require('../../../../modules/lab-order-item/repositories/lab-order-item.repository');

describe('lab-order-item.repository contract', () => {
  it('exports repository methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
