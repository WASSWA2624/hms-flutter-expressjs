const subject = require('../../../../modules/staff-assignment/schemas/staff-assignment.schema');

describe('staff-assignment.schema contract', () => {
  it('exports schema definitions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
