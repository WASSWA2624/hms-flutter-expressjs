const subject = require('../../../../modules/lab-order-item/controllers/lab-order-item.controller');

describe('lab-order-item.controller contract', () => {
  it('exports controller handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
