const subject = require('../../../../modules/shift-swap-request/schemas/shift-swap-request.schema');

describe('shift-swap-request.schema contract', () => {
  it('exports schema definitions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
