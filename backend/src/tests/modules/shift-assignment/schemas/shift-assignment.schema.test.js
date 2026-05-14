const subject = require('../../../../modules/shift-assignment/schemas/shift-assignment.schema');

describe('shift-assignment.schema contract', () => {
  it('exports schema definitions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
