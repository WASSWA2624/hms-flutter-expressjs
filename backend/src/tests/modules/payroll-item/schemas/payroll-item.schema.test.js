const subject = require('../../../../modules/payroll-item/schemas/payroll-item.schema');

describe('payroll-item.schema contract', () => {
  it('exports schema definitions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
