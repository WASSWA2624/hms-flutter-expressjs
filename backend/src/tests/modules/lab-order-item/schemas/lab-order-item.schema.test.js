const subject = require('../../../../modules/lab-order-item/schemas/lab-order-item.schema');

describe('lab-order-item.schema contract', () => {
  it('exports schema definitions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
