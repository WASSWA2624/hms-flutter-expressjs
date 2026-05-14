const subject = require('../../../../modules/payroll-run/schemas/payroll-run.schema');

describe('payroll-run.schema contract', () => {
  it('exports schema definitions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
