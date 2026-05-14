const subject = require('../../../../modules/lab-order-item/services/lab-order-item.service');

describe('lab-order-item.service contract', () => {
  it('exports service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
