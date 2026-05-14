const subject = require('../../../../modules/purchase-order/controllers/purchase-order.controller');

describe('purchase-order.controller contract', () => {
  it('exports controller handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
