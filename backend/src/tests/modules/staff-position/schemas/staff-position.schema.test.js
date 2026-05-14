const subject = require('../../../../modules/staff-position/schemas/staff-position.schema');

describe('staff-position.schema contract', () => {
  it('exports schema definitions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
